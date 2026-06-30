import Foundation
@testable import FlashTodo

@MainActor
final class FakeReminderClient: ReminderClientProtocol {
    var status: ReminderAuthorizationStatus = .fullAccess
    var lists: [ReminderListSummary] = [
        ReminderListSummary(id: "inbox", title: "Inbox", isDefault: true),
        ReminderListSummary(id: "work", title: "Work", isDefault: false)
    ]
    var tasksByListID: [String: [ReminderItemSnapshot]] = [:]
    var createdTasks: [(title: String, listID: String, dueDate: Date?)] = []
    var updatedTasks: [(id: String, mutation: ReminderMutation)] = []
    var toggledTasks: [(id: String, isCompleted: Bool)] = []
    var deletedTaskIDs: [String] = []
    var fetchTasksCallCount = 0

    func authorizationStatus() -> ReminderAuthorizationStatus {
        status
    }

    func requestAccess() async throws -> Bool {
        status = .fullAccess
        return true
    }

    func fetchReminderLists() async throws -> [ReminderListSummary] {
        guard status.canReadAndWrite else { throw ReminderClientError.accessDenied }
        return lists
    }

    func fetchTasks(listID: String) async throws -> [ReminderItemSnapshot] {
        fetchTasksCallCount += 1
        guard lists.contains(where: { $0.id == listID }) else {
            throw ReminderClientError.listNotFound
        }
        return tasksByListID[listID] ?? []
    }

    func createTask(title: String, listID: String, dueDate: Date?) async throws {
        createdTasks.append((title, listID, dueDate))
    }

    func updateTask(id: String, mutation: ReminderMutation) async throws {
        updatedTasks.append((id, mutation))
    }

    func toggleCompleted(id: String, isCompleted: Bool) async throws {
        toggledTasks.append((id, isCompleted))
    }

    func deleteTask(id: String) async throws {
        deletedTaskIDs.append(id)
    }
}
