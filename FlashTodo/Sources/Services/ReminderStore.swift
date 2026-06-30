import AppKit
import Foundation
import ServiceManagement
@preconcurrency import EventKit
import Observation

protocol LaunchAtLoginManaging {
    var isEnabled: Bool { get }
    func setEnabled(_ isEnabled: Bool) throws
}

struct SystemLaunchAtLoginManager: LaunchAtLoginManaging {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
@Observable
final class ReminderStore {
    private let client: ReminderClientProtocol
    private let launchAtLoginManager: LaunchAtLoginManaging
    private var preferences: TodoPreferences
    private var changeObserver: NSObjectProtocol?
    private var suppressEventStoreChangesUntil: Date?

    private(set) var authorizationStatus: ReminderAuthorizationStatus = .notDetermined
    private(set) var lists: [ReminderListSummary] = []
    private(set) var tasks: [ReminderItemSnapshot] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var quickCaptureText = ""

    var selectedListID: String? {
        didSet {
            guard oldValue != selectedListID else { return }
            preferences.selectedListID = selectedListID
            Task { await reloadTasks() }
        }
    }

    private(set) var showFutureTasks: Bool

    var panelWidth: Double {
        didSet {
            preferences.panelWidth = panelWidth
        }
    }

    var appLanguage: AppLanguage {
        didSet {
            preferences.appLanguage = appLanguage
        }
    }

    private(set) var launchAtLoginEnabled: Bool

    var selectedList: ReminderListSummary? {
        guard let selectedListID else { return nil }
        return lists.first { $0.id == selectedListID }
    }

    var visibleSections: [TaskSectionGroup] {
        TaskSectioner.group(tasks, includeFuture: showFutureTasks)
    }

    init(
        client: ReminderClientProtocol,
        preferences: TodoPreferences = TodoPreferences(),
        launchAtLoginManager: LaunchAtLoginManaging = SystemLaunchAtLoginManager()
    ) {
        self.client = client
        self.preferences = preferences
        self.launchAtLoginManager = launchAtLoginManager
        selectedListID = preferences.selectedListID
        showFutureTasks = preferences.showFutureTasks
        panelWidth = preferences.panelWidth
        appLanguage = preferences.appLanguage
        launchAtLoginEnabled = launchAtLoginManager.isEnabled
        authorizationStatus = client.authorizationStatus()
        observeEventStoreChanges()
    }

    func start() async {
        await reloadAll()
    }

    func requestAccess() async {
        do {
            _ = try await client.requestAccess()
            await reloadAll()
        } catch {
            errorMessage = error.localizedDescription
            authorizationStatus = client.authorizationStatus()
        }
    }

    func reloadAll() async {
        authorizationStatus = client.authorizationStatus()
        guard authorizationStatus.canReadAndWrite else {
            lists = []
            tasks = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedLists = try await client.fetchReminderLists()
            lists = fetchedLists
            ensureSelectedList()
            await reloadTasks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadTasks() async {
        guard authorizationStatus.canReadAndWrite, let selectedListID else {
            tasks = []
            return
        }

        do {
            tasks = try await client.fetchTasks(listID: selectedListID)
            errorMessage = nil
        } catch ReminderClientError.listNotFound {
            self.selectedListID = lists.first(where: \.isDefault)?.id ?? lists.first?.id
            if let fallbackListID = self.selectedListID {
                tasks = (try? await client.fetchTasks(listID: fallbackListID)) ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func captureQuickTask() async {
        guard let selectedListID else { return }
        let captureService = CaptureService(client: client)
        do {
            try await captureService.capture(text: quickCaptureText, listID: selectedListID)
            quickCaptureText = ""
            await reloadTasks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setShowFutureTasks(_ isEnabled: Bool) {
        guard showFutureTasks != isEnabled else { return }
        showFutureTasks = isEnabled
        preferences.showFutureTasks = isEnabled
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(isEnabled)
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            errorMessage = nil
        } catch {
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            errorMessage = error.localizedDescription
        }
    }

    func updateTask(id: String, mutation: ReminderMutation) async {
        do {
            suppressEventStoreReloadBriefly()
            try await client.updateTask(id: id, mutation: mutation)
            applyLocalMutation(id: id, mutation: mutation)
            suppressEventStoreReloadBriefly()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCompleted(id: String, isCompleted: Bool) async {
        do {
            suppressEventStoreReloadBriefly()
            try await client.toggleCompleted(id: id, isCompleted: isCompleted)
            applyLocalCompletion(id: id, isCompleted: isCompleted)
            suppressEventStoreReloadBriefly()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTask(id: String) async {
        do {
            suppressEventStoreReloadBriefly()
            try await client.deleteTask(id: id)
            tasks.removeAll { $0.id == id }
            errorMessage = nil
            suppressEventStoreReloadBriefly()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openRemindersPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func ensureSelectedList() {
        if let selectedListID, lists.contains(where: { $0.id == selectedListID }) {
            return
        }
        selectedListID = lists.first(where: \.isDefault)?.id ?? lists.first?.id
    }

    private func observeEventStoreChanges() {
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.shouldReloadForEventStoreChange() == true else { return }
                await self?.reloadAll()
            }
        }
    }

    private func applyLocalMutation(id: String, mutation: ReminderMutation) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        if let title = mutation.title {
            tasks[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let notes = mutation.notes {
            tasks[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let dueDate = mutation.dueDate {
            tasks[index].dueDate = dueDate
        }
        if let priority = mutation.priority {
            tasks[index].priority = priority
        }
        errorMessage = nil
    }

    private func applyLocalCompletion(id: String, isCompleted: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isCompleted = isCompleted
        tasks[index].completionDate = isCompleted ? Date() : nil
        errorMessage = nil
    }

    private func suppressEventStoreReloadBriefly() {
        suppressEventStoreChangesUntil = Date().addingTimeInterval(1)
    }

    private func shouldReloadForEventStoreChange() -> Bool {
        guard let suppressEventStoreChangesUntil else { return true }
        if Date() < suppressEventStoreChangesUntil {
            return false
        }
        self.suppressEventStoreChangesUntil = nil
        return true
    }
}
