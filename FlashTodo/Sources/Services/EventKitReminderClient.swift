import Foundation
@preconcurrency import EventKit

@MainActor
final class EventKitReminderClient: ReminderClientProtocol {
    private let eventStore: EKEventStore
    private let calendar: Calendar

    init(eventStore: EKEventStore = EKEventStore(), calendar: Calendar = .current) {
        self.eventStore = eventStore
        self.calendar = calendar
    }

    func authorizationStatus() -> ReminderAuthorizationStatus {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .fullAccess: .fullAccess
        case .writeOnly: .writeOnly
        @unknown default: .unknown
        }
    }

    func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToReminders { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func fetchReminderLists() async throws -> [ReminderListSummary] {
        guard authorizationStatus().canReadAndWrite else {
            throw ReminderClientError.accessDenied
        }

        let defaultID = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
        return eventStore.calendars(for: .reminder)
            .map {
                ReminderListSummary(
                    id: $0.calendarIdentifier,
                    title: $0.title,
                    isDefault: $0.calendarIdentifier == defaultID
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    func fetchTasks(listID: String) async throws -> [ReminderItemSnapshot] {
        guard authorizationStatus().canReadAndWrite else {
            throw ReminderClientError.accessDenied
        }
        guard let reminderList = eventStore.calendar(withIdentifier: listID) else {
            throw ReminderClientError.listNotFound
        }

        let predicate = eventStore.predicateForReminders(in: [reminderList])
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { [calendar] reminders in
                DispatchQueue.main.async {
                    let snapshots = (reminders ?? []).map { reminder in
                        Self.snapshot(from: reminder, calendar: calendar)
                    }
                    continuation.resume(returning: snapshots)
                }
            }
        }
    }

    func createTask(title: String, listID: String, dueDate: Date?) async throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw ReminderClientError.emptyTitle }
        guard let reminderList = eventStore.calendar(withIdentifier: listID) else {
            throw ReminderClientError.listNotFound
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = reminderList
        reminder.title = cleanTitle
        if let dueDate {
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day], from: dueDate)
        }
        try save(reminder)
    }

    func updateTask(id: String, mutation: ReminderMutation) async throws {
        guard let reminder = reminder(with: id) else { throw ReminderClientError.taskNotFound }
        if let title = mutation.title {
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else { throw ReminderClientError.emptyTitle }
            reminder.title = cleanTitle
        }
        if let notes = mutation.notes {
            reminder.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        if let dueDate = mutation.dueDate {
            reminder.dueDateComponents = dueDate.map {
                calendar.dateComponents([.year, .month, .day], from: $0)
            }
        }
        if let priority = mutation.priority {
            reminder.priority = priority.rawValue
        }
        try save(reminder)
    }

    func toggleCompleted(id: String, isCompleted: Bool) async throws {
        guard let reminder = reminder(with: id) else { throw ReminderClientError.taskNotFound }
        reminder.isCompleted = isCompleted
        reminder.completionDate = isCompleted ? Date() : nil
        try save(reminder)
    }

    func deleteTask(id: String) async throws {
        guard let reminder = reminder(with: id) else { throw ReminderClientError.taskNotFound }
        try eventStore.remove(reminder, commit: true)
    }

    private func reminder(with id: String) -> EKReminder? {
        eventStore.calendarItem(withIdentifier: id) as? EKReminder
    }

    private func save(_ reminder: EKReminder) throws {
        try eventStore.save(reminder, commit: true)
    }

    private nonisolated static func snapshot(from reminder: EKReminder, calendar: Calendar) -> ReminderItemSnapshot {
        ReminderItemSnapshot(
            id: reminder.calendarItemIdentifier,
            calendarID: reminder.calendar.calendarIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes ?? "",
            dueDate: reminder.dueDateComponents.flatMap { calendar.date(from: $0) },
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate,
            priority: ReminderPriority.fromEventKitValue(reminder.priority)
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
