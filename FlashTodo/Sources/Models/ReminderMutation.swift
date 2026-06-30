import Foundation

struct ReminderMutation: Equatable {
    var title: String?
    var notes: String?
    var dueDate: Date??
    var priority: ReminderPriority?
}
