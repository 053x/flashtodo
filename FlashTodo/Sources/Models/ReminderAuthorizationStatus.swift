import Foundation

enum ReminderAuthorizationStatus: Equatable {
    case notDetermined
    case restricted
    case denied
    case fullAccess
    case writeOnly
    case unknown

    var canReadAndWrite: Bool {
        self == .fullAccess
    }
}
