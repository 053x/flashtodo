import Foundation

struct ReminderItemSnapshot: Identifiable, Hashable {
    let id: String
    var calendarID: String
    var title: String
    var notes: String
    var dueDate: Date?
    var isCompleted: Bool
    var completionDate: Date?
    var priority: ReminderPriority
}

enum ReminderPriority: Int, CaseIterable, Identifiable, Hashable {
    case none = 0
    case high = 1
    case medium = 5
    case low = 9

    var id: Int { rawValue }

    var localizedKey: String {
        switch self {
        case .none: "priority.none"
        case .high: "priority.high"
        case .medium: "priority.medium"
        case .low: "priority.low"
        }
    }

    static func fromEventKitValue(_ value: Int) -> ReminderPriority {
        switch value {
        case 1...4: .high
        case 5: .medium
        case 6...9: .low
        default: .none
        }
    }
}
