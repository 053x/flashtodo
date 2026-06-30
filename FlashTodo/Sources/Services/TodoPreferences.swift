import Foundation

struct TodoPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedListID: String? {
        get { defaults.string(forKey: Keys.selectedListID) }
        nonmutating set { defaults.set(newValue, forKey: Keys.selectedListID) }
    }

    var showFutureTasks: Bool {
        get {
            guard defaults.object(forKey: Keys.showFutureTasks) != nil else { return true }
            return defaults.bool(forKey: Keys.showFutureTasks)
        }
        nonmutating set { defaults.set(newValue, forKey: Keys.showFutureTasks) }
    }

    var panelWidth: Double {
        get {
            let value = defaults.double(forKey: Keys.panelWidth)
            return value > 0 ? value : 420
        }
        nonmutating set { defaults.set(newValue, forKey: Keys.panelWidth) }
    }

    var appLanguage: AppLanguage {
        get {
            guard let rawValue = defaults.string(forKey: Keys.appLanguage) else {
                return .automatic
            }
            return AppLanguage(rawValue: rawValue) ?? .automatic
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Keys.appLanguage) }
    }

    private enum Keys {
        static let selectedListID = "selectedListID"
        static let showFutureTasks = "showFutureTasks"
        static let panelWidth = "panelWidth"
        static let appLanguage = "appLanguage"
    }
}
