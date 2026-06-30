import Foundation

@MainActor
protocol ReminderClientProtocol {
    func authorizationStatus() -> ReminderAuthorizationStatus
    func requestAccess() async throws -> Bool
    func fetchReminderLists() async throws -> [ReminderListSummary]
    func fetchTasks(listID: String) async throws -> [ReminderItemSnapshot]
    func createTask(title: String, listID: String, dueDate: Date?) async throws
    func updateTask(id: String, mutation: ReminderMutation) async throws
    func toggleCompleted(id: String, isCompleted: Bool) async throws
    func deleteTask(id: String) async throws
}

enum ReminderClientError: LocalizedError, Equatable {
    case accessDenied
    case listNotFound
    case taskNotFound
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .accessDenied: String(localized: "error.accessDenied")
        case .listNotFound: String(localized: "error.listNotFound")
        case .taskNotFound: String(localized: "error.taskNotFound")
        case .emptyTitle: String(localized: "error.emptyTitle")
        }
    }
}
