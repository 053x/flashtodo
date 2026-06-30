import Foundation

@MainActor
struct CaptureService {
    var client: ReminderClientProtocol

    init(client: ReminderClientProtocol) {
        self.client = client
    }

    func capture(text: String, listID: String) async throws {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        try await client.createTask(title: title, listID: listID, dueDate: nil)
    }
}
