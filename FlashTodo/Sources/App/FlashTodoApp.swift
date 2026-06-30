import SwiftUI

@main
struct FlashTodoApp: App {
    @State private var reminderStore = ReminderStore(client: EventKitReminderClient())

    var body: some Scene {
        MenuBarExtra("app.title", systemImage: "checklist") {
            LocalizedPanelRoot(store: reminderStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            LocalizedSettingsRoot(store: reminderStore)
        }
    }
}

enum AppVersion {
    static var shortDisplayString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "v\(version)"
    }
}

enum AppLinks {
    static let github = "https://github.com/053x/flashtodo"
}

private struct LocalizedPanelRoot: View {
    @Bindable var store: ReminderStore

    var body: some View {
        PanelView(store: store)
            .appLocale(store.appLanguage)
    }
}

private struct LocalizedSettingsRoot: View {
    @Bindable var store: ReminderStore

    var body: some View {
        SettingsView(store: store)
            .appLocale(store.appLanguage)
    }
}

private extension View {
    @ViewBuilder
    func appLocale(_ language: AppLanguage) -> some View {
        if let locale = language.locale {
            environment(\.locale, locale)
        } else {
            self
        }
    }
}
