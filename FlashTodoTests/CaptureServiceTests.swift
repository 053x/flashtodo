import XCTest
@testable import FlashTodo

@MainActor
final class CaptureServiceTests: XCTestCase {
    func testCaptureTrimsTextAndUsesNoDueDate() async throws {
        let client = FakeReminderClient()
        let service = CaptureService(client: client)

        try await service.capture(text: "  follow up with agent  ", listID: "inbox")

        XCTAssertEqual(client.createdTasks.count, 1)
        XCTAssertEqual(client.createdTasks.first?.title, "follow up with agent")
        XCTAssertEqual(client.createdTasks.first?.listID, "inbox")
        XCTAssertNil(client.createdTasks.first?.dueDate)
    }

    func testCaptureIgnoresEmptyText() async throws {
        let client = FakeReminderClient()
        let service = CaptureService(client: client)

        try await service.capture(text: "   \n ", listID: "inbox")

        XCTAssertTrue(client.createdTasks.isEmpty)
    }
}
