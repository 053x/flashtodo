import XCTest
@testable import FlashTodo

@MainActor
final class ReminderStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "FlashTodoTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testReloadSelectsDefaultListWhenNoPreferenceExists() async {
        let client = FakeReminderClient()
        let store = ReminderStore(client: client, preferences: TodoPreferences(defaults: defaults))

        await store.reloadAll()

        XCTAssertEqual(store.selectedListID, "inbox")
        XCTAssertEqual(store.lists.map(\.id), ["inbox", "work"])
    }

    func testReloadFallsBackWhenSelectedListDisappears() async {
        defaults.set("missing", forKey: "selectedListID")
        let client = FakeReminderClient()
        client.tasksByListID["inbox"] = [
            ReminderItemSnapshot(
                id: "task",
                calendarID: "inbox",
                title: "Recovered",
                notes: "",
                dueDate: nil,
                isCompleted: false,
                completionDate: nil,
                priority: .none
            )
        ]
        let store = ReminderStore(client: client, preferences: TodoPreferences(defaults: defaults))

        await store.reloadAll()

        XCTAssertEqual(store.selectedListID, "inbox")
        XCTAssertEqual(store.tasks.map(\.title), ["Recovered"])
    }

    func testSelectingListPersistsAndReloadsTasks() async throws {
        let client = FakeReminderClient()
        client.tasksByListID["work"] = [
            ReminderItemSnapshot(
                id: "work-task",
                calendarID: "work",
                title: "Work item",
                notes: "",
                dueDate: nil,
                isCompleted: false,
                completionDate: nil,
                priority: .none
            )
        ]
        let store = ReminderStore(client: client, preferences: TodoPreferences(defaults: defaults))
        await store.reloadAll()

        store.selectedListID = "work"
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(defaults.string(forKey: "selectedListID"), "work")
        XCTAssertEqual(store.selectedListID, "work")
        XCTAssertEqual(store.tasks.map(\.title), ["Work item"])
    }

    func testShowFutureTogglePersistsAndUpdatesVisibleSections() async {
        let client = FakeReminderClient()
        client.tasksByListID["inbox"] = [
            ReminderItemSnapshot(
                id: "future",
                calendarID: "inbox",
                title: "Future item",
                notes: "",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                isCompleted: false,
                completionDate: nil,
                priority: .none
            )
        ]
        let store = ReminderStore(client: client, preferences: TodoPreferences(defaults: defaults))
        await store.reloadAll()
        XCTAssertEqual(store.visibleSections.map(\.section), [.future])

        store.setShowFutureTasks(false)

        XCTAssertFalse(defaults.bool(forKey: "showFutureTasks"))
        XCTAssertFalse(store.showFutureTasks)
        XCTAssertTrue(store.visibleSections.isEmpty)
    }

    func testLanguagePreferencePersistsAndRestores() {
        let store = ReminderStore(client: FakeReminderClient(), preferences: TodoPreferences(defaults: defaults))
        XCTAssertEqual(store.appLanguage, .automatic)

        store.appLanguage = .english

        XCTAssertEqual(defaults.string(forKey: "appLanguage"), "en")
        XCTAssertEqual(TodoPreferences(defaults: defaults).appLanguage, .english)
    }

    func testLaunchAtLoginDefaultsOffAndDelegatesToManager() {
        let launchManager = FakeLaunchAtLoginManager()
        let store = ReminderStore(
            client: FakeReminderClient(),
            preferences: TodoPreferences(defaults: defaults),
            launchAtLoginManager: launchManager
        )

        XCTAssertFalse(store.launchAtLoginEnabled)

        store.setLaunchAtLoginEnabled(true)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(launchManager.requestedStates, [true])
        XCTAssertNil(defaults.object(forKey: "launchAtLogin"))
    }

    func testInvalidLanguagePreferenceFallsBackToAutomatic() {
        defaults.set("fr", forKey: "appLanguage")

        XCTAssertEqual(TodoPreferences(defaults: defaults).appLanguage, .automatic)
    }

    func testMutationsDelegateToClientAndPatchLocalSnapshots() async {
        let client = FakeReminderClient()
        client.tasksByListID["inbox"] = [
            ReminderItemSnapshot(
                id: "task",
                calendarID: "inbox",
                title: "Old",
                notes: "",
                dueDate: nil,
                isCompleted: false,
                completionDate: nil,
                priority: .none
            )
        ]
        let store = ReminderStore(client: client, preferences: TodoPreferences(defaults: defaults))
        await store.reloadAll()
        let fetchCountAfterInitialLoad = client.fetchTasksCallCount

        let dueDate = Calendar.current.startOfDay(for: Date())
        await store.updateTask(id: "task", mutation: ReminderMutation(title: "New", notes: " Note ", dueDate: .some(dueDate), priority: .high))
        await store.toggleCompleted(id: "task", isCompleted: true)
        await store.deleteTask(id: "task")

        XCTAssertEqual(client.updatedTasks.first?.id, "task")
        XCTAssertEqual(client.updatedTasks.first?.mutation.title, "New")
        XCTAssertEqual(client.updatedTasks.first?.mutation.priority, .high)
        XCTAssertEqual(client.toggledTasks.first?.id, "task")
        XCTAssertEqual(client.toggledTasks.first?.isCompleted, true)
        XCTAssertEqual(client.deletedTaskIDs, ["task"])
        XCTAssertEqual(client.fetchTasksCallCount, fetchCountAfterInitialLoad)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    func testUpdateTaskPatchesSnapshotWithoutReloading() async {
        let client = FakeReminderClient()
        client.tasksByListID["inbox"] = [
            ReminderItemSnapshot(
                id: "task",
                calendarID: "inbox",
                title: "Old",
                notes: "",
                dueDate: nil,
                isCompleted: false,
                completionDate: nil,
                priority: .none
            )
        ]
        let store = ReminderStore(client: client, preferences: TodoPreferences(defaults: defaults))
        await store.reloadAll()
        let fetchCountAfterInitialLoad = client.fetchTasksCallCount

        let dueDate = Calendar.current.startOfDay(for: Date())
        await store.updateTask(id: "task", mutation: ReminderMutation(title: "New", notes: " Note ", dueDate: .some(dueDate), priority: .high))

        XCTAssertEqual(client.fetchTasksCallCount, fetchCountAfterInitialLoad)
        XCTAssertEqual(store.tasks.first?.title, "New")
        XCTAssertEqual(store.tasks.first?.notes, "Note")
        XCTAssertEqual(store.tasks.first?.dueDate, dueDate)
        XCTAssertEqual(store.tasks.first?.priority, .high)
    }

    func testPreferencesDoNotStoreTaskContent() {
        let preferences = TodoPreferences(defaults: defaults)
        preferences.selectedListID = "inbox"
        preferences.showFutureTasks = false
        preferences.panelWidth = 480

        XCTAssertEqual(defaults.string(forKey: "selectedListID"), "inbox")
        XCTAssertFalse(defaults.bool(forKey: "showFutureTasks"))
        XCTAssertEqual(defaults.double(forKey: "panelWidth"), 480)
        XCTAssertNil(defaults.object(forKey: "title"))
        XCTAssertNil(defaults.object(forKey: "notes"))
        XCTAssertNil(defaults.object(forKey: "tasks"))
    }
}

private final class FakeLaunchAtLoginManager: LaunchAtLoginManaging {
    private(set) var requestedStates: [Bool] = []
    var isEnabled = false

    func setEnabled(_ isEnabled: Bool) throws {
        requestedStates.append(isEnabled)
        self.isEnabled = isEnabled
    }
}
