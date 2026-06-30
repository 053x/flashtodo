import XCTest
@testable import FlashTodo

final class TaskSectionerTests: XCTestCase {
    func testGroupsIncompleteTasksByInboxOverdueTodayFuture() {
        let calendar = Calendar(identifier: .gregorian)
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 30, hour: 12).date!
        let yesterday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 29).date!
        let today = DateComponents(calendar: calendar, year: 2026, month: 6, day: 30).date!
        let tomorrow = DateComponents(calendar: calendar, year: 2026, month: 7, day: 1).date!

        let sections = TaskSectioner.group(
            [
                task(id: "done", title: "Done", dueDate: today, isCompleted: true, completionDate: now),
                task(id: "future", title: "Future", dueDate: tomorrow),
                task(id: "undated", title: "Undated", dueDate: nil),
                task(id: "today", title: "Today", dueDate: today),
                task(id: "overdue", title: "Overdue", dueDate: yesterday)
            ],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(sections.map(\.section), [.undated, .overdue, .today, .future])
        XCTAssertEqual(sections.flatMap(\.items).map(\.id), ["undated", "overdue", "done", "today", "future"])
    }

    func testKeepsOnlyTasksCompletedTodayVisible() {
        let calendar = Calendar(identifier: .gregorian)
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 30, hour: 12).date!
        let today = DateComponents(calendar: calendar, year: 2026, month: 6, day: 30).date!
        let tomorrow = DateComponents(calendar: calendar, year: 2026, month: 7, day: 1).date!
        let yesterdayCompletion = DateComponents(calendar: calendar, year: 2026, month: 6, day: 29, hour: 18).date!
        let todayCompletion = DateComponents(calendar: calendar, year: 2026, month: 6, day: 30, hour: 9).date!
        let tomorrowCompletion = DateComponents(calendar: calendar, year: 2026, month: 7, day: 1, hour: 9).date!

        let sections = TaskSectioner.group(
            [
                task(id: "done-yesterday", title: "Done yesterday", dueDate: today, isCompleted: true, completionDate: yesterdayCompletion),
                task(id: "done-today-undated", title: "Done today undated", dueDate: nil, isCompleted: true, completionDate: todayCompletion),
                task(id: "done-today-future", title: "Done today future", dueDate: tomorrow, isCompleted: true, completionDate: todayCompletion),
                task(id: "done-tomorrow", title: "Done tomorrow", dueDate: today, isCompleted: true, completionDate: tomorrowCompletion),
                task(id: "done-without-completion-date", title: "Done without completion date", dueDate: today, isCompleted: true)
            ],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(sections.map(\.section), [.today])
        XCTAssertEqual(sections.flatMap(\.items).map(\.id), ["done-today-future", "done-today-undated"])
    }

    func testCanHideFutureTasks() {
        let calendar = Calendar(identifier: .gregorian)
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 30).date!
        let tomorrow = DateComponents(calendar: calendar, year: 2026, month: 7, day: 1).date!

        let sections = TaskSectioner.group(
            [task(id: "future", title: "Future", dueDate: tomorrow)],
            now: now,
            calendar: calendar,
            includeFuture: false
        )

        XCTAssertTrue(sections.isEmpty)
    }

    private func task(
        id: String,
        title: String,
        dueDate: Date?,
        isCompleted: Bool = false,
        completionDate: Date? = nil
    ) -> ReminderItemSnapshot {
        ReminderItemSnapshot(
            id: id,
            calendarID: "inbox",
            title: title,
            notes: "",
            dueDate: dueDate,
            isCompleted: isCompleted,
            completionDate: completionDate,
            priority: .none
        )
    }
}
