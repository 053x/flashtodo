import Foundation

enum TaskSection: String, CaseIterable, Identifiable {
    case undated
    case overdue
    case today
    case future

    var id: String { rawValue }

    static let displayOrder: [TaskSection] = [.undated, .overdue, .today, .future]

    var localizedTitleKey: String {
        switch self {
        case .overdue: "section.overdue"
        case .today: "section.today"
        case .undated: "section.undated"
        case .future: "section.future"
        }
    }

}

struct TaskSectionGroup: Identifiable, Equatable {
    let section: TaskSection
    var items: [ReminderItemSnapshot]

    var id: TaskSection { section }
}

enum TaskSectioner {
    static func group(
        _ items: [ReminderItemSnapshot],
        now: Date = Date(),
        calendar: Calendar = .current,
        includeFuture: Bool = true
    ) -> [TaskSectionGroup] {
        var buckets: [TaskSection: [ReminderItemSnapshot]] = Dictionary(
            uniqueKeysWithValues: TaskSection.allCases.map { ($0, []) }
        )
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now

        for item in items {
            if item.isCompleted {
                guard let completionDate = item.completionDate,
                      completionDate >= todayStart,
                      completionDate < tomorrowStart
                else { continue }
                buckets[.today, default: []].append(item)
                continue
            }

            guard let dueDate = item.dueDate else {
                buckets[.undated, default: []].append(item)
                continue
            }

            let isDueToday = dueDate >= todayStart && dueDate < tomorrowStart
            if dueDate < todayStart {
                buckets[.overdue, default: []].append(item)
            } else if isDueToday {
                buckets[.today, default: []].append(item)
            } else if includeFuture {
                buckets[.future, default: []].append(item)
            }
        }

        return TaskSection.displayOrder.compactMap { section in
            let sortedItems = (buckets[section] ?? []).sorted(by: sortTasks)
            return sortedItems.isEmpty ? nil : TaskSectionGroup(section: section, items: sortedItems)
        }
    }

    private static func sortTasks(_ lhs: ReminderItemSnapshot, _ rhs: ReminderItemSnapshot) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            if left != right { return left < right }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}
