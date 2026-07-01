import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var store: ReminderStore

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("settings.permission", systemImage: "lock")
                    Spacer()
                    Text(statusText)
                        .foregroundStyle(statusColor)
                }

                if store.authorizationStatus == .notDetermined {
                    Button("permission.request") {
                        Task { await store.requestAccess() }
                    }
                } else if !store.authorizationStatus.canReadAndWrite {
                    Button("permission.openSettings") {
                        store.openRemindersPrivacySettings()
                    }
                }
            }

            Section {
                Picker("settings.language", selection: $store.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.localizedTitleKey))
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)

                Picker("settings.list", selection: Binding(
                    get: { store.selectedListID ?? "" },
                    set: { store.selectedListID = $0.isEmpty ? nil : $0 }
                )) {
                    if store.lists.isEmpty {
                        Text("list.none").tag("")
                    }
                    ForEach(store.lists) { list in
                        Text(list.title).tag(list.id)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!store.authorizationStatus.canReadAndWrite || store.lists.isEmpty)

                Toggle(isOn: Binding(
                    get: { store.launchAtLoginEnabled },
                    set: { store.setLaunchAtLoginEnabled($0) }
                )) {
                    Text("settings.launchAtLogin")
                }
            }

            Section {
                Text("settings.storageNote")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .background(SettingsWindowTitleSetter(title: settingsWindowTitle))
        .padding(20)
        .frame(width: 460, height: 360)
        .task {
            await store.reloadAll()
        }
    }

    private var statusText: LocalizedStringKey {
        switch store.authorizationStatus {
        case .notDetermined: "permission.status.notDetermined"
        case .restricted: "permission.status.restricted"
        case .denied: "permission.status.denied"
        case .fullAccess: "permission.status.fullAccess"
        case .writeOnly: "permission.status.writeOnly"
        case .unknown: "permission.status.unknown"
        }
    }

    private var statusColor: Color {
        store.authorizationStatus.canReadAndWrite ? .green : .orange
    }

    private var settingsWindowTitle: String {
        switch store.appLanguage {
        case .automatic:
            String(localized: "settings.title")
        case .simplifiedChinese:
            "设置"
        case .english:
            "Settings"
        }
    }
}

private struct SettingsWindowTitleSetter: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> TitleSettingView {
        let view = TitleSettingView()
        view.title = title
        return view
    }

    func updateNSView(_ nsView: TitleSettingView, context: Context) {
        nsView.title = title
    }

    final class TitleSettingView: NSView {
        var title: String = "" {
            didSet {
                updateWindowTitle()
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateWindowTitle()
        }

        private func updateWindowTitle() {
            window?.title = title
        }
    }
}
