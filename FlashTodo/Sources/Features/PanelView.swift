import AppKit
import SwiftUI

struct PanelView: View {
    @Bindable var store: ReminderStore
    @Environment(\.openSettings) private var openSettings
    @FocusState private var isCaptureFocused: Bool
    @State private var editingTaskID: String?
    @State private var lastTaskRowTapTime = Date.distantPast

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: store.panelWidth, height: 560)
        .task {
            await store.start()
            isCaptureFocused = true
        }
        .onChange(of: store.tasks) { _, tasks in
            guard let editingTaskID,
                  !tasks.contains(where: { $0.id == editingTaskID })
            else { return }
            endTaskEditing()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("app.title")
                        .font(.headline)
                    Text(store.selectedList?.title ?? String(localized: "list.notSelected"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    Task { await store.reloadAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(Text("action.refresh"))

                Button {
                    NSApplication.shared.activate()
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help(Text("action.settings"))
            }

            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                TextField("capture.placeholder", text: $store.quickCaptureText)
                    .textFieldStyle(.plain)
                    .focused($isCaptureFocused)
                    .onSubmit {
                        Task { await store.captureQuickTask() }
                    }
                Button {
                    Task { await store.captureQuickTask() }
                } label: {
                    Image(systemName: "return")
                }
                .buttonStyle(.borderless)
                .help(Text("action.capture"))
                .disabled(store.quickCaptureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        switch store.authorizationStatus {
        case .notDetermined:
            PermissionPromptView(store: store)
        case .denied, .restricted, .writeOnly, .unknown:
            PermissionDeniedView(store: store)
        case .fullAccess:
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.selectedListID == nil {
                EmptyStateView(systemImage: "list.bullet.rectangle", titleKey: "empty.noList", messageKey: "empty.noList.message")
            } else if store.visibleSections.isEmpty {
                EmptyStateView(systemImage: "checkmark.circle", titleKey: "empty.noTasks", messageKey: "empty.noTasks.message")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.visibleSections) { group in
                            TaskSectionView(
                                group: group,
                                store: store,
                                editingTaskID: $editingTaskID,
                                lastTaskRowTapTime: $lastTaskRowTapTime
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        endTaskEditingUnlessTaskRowWasTapped()
                    }
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { store.showFutureTasks },
                set: { store.setShowFutureTasks($0) }
            )) {
                Text("filter.showFuture")
                    .font(.caption)
                    .textCase(.uppercase)
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)

            Spacer()

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Menu {
                Button("menu.about", action: showAbout)
                Button("menu.github", action: openGitHub)

                Divider()

                Button("menu.checkUpdates", action: checkForUpdates)
                Button("action.quit", role: .destructive, action: quit)
            } label: {
                Text(AppVersion.shortDisplayString)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: String(localized: "app.title"),
            .applicationVersion: AppVersion.shortDisplayString
        ])
        NSApp.activate()
    }

    private func checkForUpdates() {
        let alert = NSAlert()
        alert.messageText = String(localized: "updates.unavailable.title")
        alert.informativeText = String(localized: "updates.unavailable.message")
        alert.addButton(withTitle: String(localized: "action.ok"))
        alert.runModal()
    }

    private func openGitHub() {
        guard let url = URL(string: AppLinks.github) else { return }
        NSWorkspace.shared.open(url)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func endTaskEditing() {
        editingTaskID = nil
    }

    private func endTaskEditingUnlessTaskRowWasTapped() {
        DispatchQueue.main.async {
            if Date().timeIntervalSince(lastTaskRowTapTime) > 0.2 {
                endTaskEditing()
            }
        }
    }
}

private struct TaskSectionView: View {
    let group: TaskSectionGroup
    @Bindable var store: ReminderStore
    @Binding var editingTaskID: String?
    @Binding var lastTaskRowTapTime: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(group.section.localizedTitleKey))
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(sectionColor)

            VStack(spacing: 0) {
                ForEach(group.items) { item in
                    TaskRowView(
                        item: item,
                        store: store,
                        editingTaskID: $editingTaskID,
                        lastTaskRowTapTime: $lastTaskRowTapTime
                    )
                }
            }
        }
    }

    private var sectionColor: Color {
        switch group.section {
        case .undated:
            .secondary
        case .overdue:
            .red
        case .today:
            .orange
        case .future:
            .blue
        }
    }
}

private struct PermissionPromptView: View {
    @Bindable var store: ReminderStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 34))
                .foregroundStyle(Color.accentColor)
            Text("permission.prompt.title")
                .font(.headline)
            Text("permission.prompt.message")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("permission.request") {
                Task { await store.requestAccess() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PermissionDeniedView: View {
    @Bindable var store: ReminderStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.trianglebadge.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(.orange)
            Text("permission.denied.title")
                .font(.headline)
            Text("permission.denied.message")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("permission.openSettings") {
                store.openRemindersPrivacySettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyStateView: View {
    let systemImage: String
    let titleKey: String
    let messageKey: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey(titleKey))
                .font(.headline)
            Text(LocalizedStringKey(messageKey))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
