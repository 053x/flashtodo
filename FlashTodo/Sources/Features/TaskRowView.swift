import SwiftUI

struct TaskRowView: View {
    let item: ReminderItemSnapshot
    @Bindable var store: ReminderStore
    @Binding var editingTaskID: String?
    @Binding var lastTaskRowTapTime: Date

    @Environment(\.locale) private var locale
    @State private var title: String
    @State private var notes: String
    @State private var dueDate: Date
    @State private var dueDateText: String
    @State private var hasDueDate: Bool
    @State private var isDatePickerPresented = false
    @State private var calendarMonth: Date
    @State private var hoveredDateChoice: String?
    @State private var hoveredCalendarDate: Date?
    @State private var priority: ReminderPriority
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case notes
        case dueDate
    }

    private var isEditing: Bool {
        !item.isCompleted && editingTaskID == item.id
    }

    private var isReadOnly: Bool {
        item.isCompleted
    }

    init(
        item: ReminderItemSnapshot,
        store: ReminderStore,
        editingTaskID: Binding<String?>,
        lastTaskRowTapTime: Binding<Date>
    ) {
        self.item = item
        self.store = store
        _editingTaskID = editingTaskID
        _lastTaskRowTapTime = lastTaskRowTapTime
        _title = State(initialValue: item.title)
        _notes = State(initialValue: item.notes)
        _dueDate = State(initialValue: item.dueDate ?? Date())
        _dueDateText = State(initialValue: Self.formattedDateText(item.dueDate))
        _hasDueDate = State(initialValue: item.dueDate != nil)
        _calendarMonth = State(initialValue: item.dueDate ?? Date())
        _priority = State(initialValue: item.priority)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 10) {
                    Button {
                        Task { await store.toggleCompleted(id: item.id, isCompleted: !item.isCompleted) }
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14, weight: .regular))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(item.isCompleted ? Color.secondary.opacity(0.65) : Color.secondary.opacity(0.45))
                    .help(Text("action.toggleComplete"))

                    HStack(spacing: 3) {
                        if !priorityPrefix.isEmpty {
                            Text(priorityPrefix)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(item.isCompleted ? .secondary : priorityColor(for: priority))
                        }

                        TextField("task.title", text: $title)
                            .textFieldStyle(.plain)
                            .font(.callout.weight(.medium))
                            .strikethrough(item.isCompleted)
                            .foregroundStyle(item.isCompleted ? .tertiary : .primary)
                            .disabled(isReadOnly)
                            .focused($focusedField, equals: .title)
                            .onTapGesture {
                                beginEditing()
                            }
                            .onSubmit { saveTitle() }
                            .onChange(of: title) { _, newValue in
                                guard newValue != item.title else { return }
                            }
                    }

                    Spacer(minLength: 8)
                }

                if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEditing || focusedField == .notes {
                    TextField("task.notes", text: $notes)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(item.isCompleted ? .tertiary : .secondary)
                        .disabled(isReadOnly)
                        .focused($focusedField, equals: .notes)
                        .onSubmit { saveNotes() }
                        .padding(.leading, 28)
                }

                if item.dueDate != nil || isEditing {
                    HStack(spacing: 6) {
                        if let dueDate = item.dueDate, !isEditing {
                            Text(dueDate.formatted(.dateTime.year().month(.defaultDigits).day()))
                                .font(.caption)
                                .foregroundStyle(item.isCompleted ? .tertiary : .secondary)
                        }

                        if isEditing {
                            inlineDateEditor
                            priorityMenu {
                                Text(priorityControlSymbol)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(priorityColor(for: priority))
                                    .frame(minWidth: 16, minHeight: 16)
                            }
                            .menuStyle(.button)
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .fixedSize()

                            Button(role: .destructive) {
                                Task { await store.deleteTask(id: item.id) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .help(Text("action.delete"))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
                }
            }
        }
        .padding(.vertical, 7)
        .padding(.trailing, 2)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                beginEditing()
            }
        )
        .onChange(of: focusedField) { oldValue, newValue in
            if newValue == .title {
                beginEditing()
            }
            if oldValue == .title, newValue != .title {
                saveTitle()
            }
            if oldValue == .notes, newValue != .notes {
                saveNotes()
            }
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                finishEditing()
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator.opacity(0.45))
                .frame(height: 0.5)
                .padding(.leading, 28)
        }
        .onChange(of: item) { _, newValue in
            if newValue.isCompleted {
                editingTaskID = nil
                focusedField = nil
                isDatePickerPresented = false
            }
            title = newValue.title
            notes = newValue.notes
            dueDate = newValue.dueDate ?? Date()
            dueDateText = Self.formattedDateText(newValue.dueDate)
            hasDueDate = newValue.dueDate != nil
            calendarMonth = newValue.dueDate ?? calendarMonth
            priority = newValue.priority
        }
    }

    private var priorityPrefix: String {
        priorityPrefix(for: priority)
    }

    private var inlineDateEditor: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .imageScale(.small)
                .foregroundStyle(.secondary)

            TextField("task.date.add", text: $dueDateText)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .dueDate)
                .frame(width: 76)
                .onTapGesture {
                    beginEditing()
                    isDatePickerPresented = true
                }
                .onSubmit {
                    saveDueDateText()
                }
                .onChange(of: focusedField) { _, newValue in
                    if newValue == .dueDate {
                        beginEditing()
                        isDatePickerPresented = true
                    }
                }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(dueDateText.isEmpty ? .secondary : .primary)
        .background(.quaternary, in: Capsule())
        .fixedSize()
        .contentShape(Capsule())
        .onTapGesture {
            beginEditing()
            isDatePickerPresented = true
        }
        .popover(isPresented: $isDatePickerPresented, arrowEdge: .bottom) {
            inlineDatePickerPanel
                .environment(\.locale, locale)
        }
    }

    private var inlineDatePickerPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            dateChoiceButton(id: "today", titleKey: "task.date.today", date: Date())
            dateChoiceButton(id: "tomorrow", titleKey: "task.date.tomorrow", date: daysFromToday(1))
            dateChoiceButton(id: "weekend", titleKey: "task.date.weekend", date: weekendDate())
            dateChoiceButton(id: "nextWeek", titleKey: "task.date.nextWeek", date: daysFromToday(7))

            Divider()

            customCalendarPicker

            if hasDueDate {
                Divider()

                Button {
                    clearDueDate()
                } label: {
                    Text("task.noDueDate")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .background(hoveredDateChoice == "clear" ? Color.secondary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .onHover { isHovering in
                    hoveredDateChoice = isHovering ? "clear" : nil
                }
            }
        }
        .padding(8)
        .frame(width: 230)
        .presentationBackground(.regularMaterial)
    }

    private func dateChoiceButton(id: String, titleKey: String, date: Date) -> some View {
        Button {
            setDueDate(date)
        } label: {
            HStack {
                dateChoiceLabel(titleKey: titleKey, date: date)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .background(hoveredDateChoice == id ? Color.secondary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { isHovering in
            hoveredDateChoice = isHovering ? id : nil
        }
    }

    private var customCalendarPicker: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    moveCalendarMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(calendarMonth, format: .dateTime.year().month(.wide))
                    .font(.caption.weight(.semibold))

                Spacer()

                Button {
                    moveCalendarMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 2), count: 7), spacing: 2) {
                ForEach(shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 18)
                }

                ForEach(calendarDays, id: \.self) { date in
                    if let date {
                        Button {
                            setDueDate(date)
                        } label: {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption)
                                .frame(width: 28, height: 24)
                                .background(calendarDayBackground(for: date), in: Circle())
                                .background(calendarDayHoverBackground(for: date), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .onHover { isHovering in
                            hoveredCalendarDate = isHovering ? date : nil
                        }
                    } else {
                        Color.clear.frame(width: 28, height: 24)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func priorityMenu<LabelContent: View>(@ViewBuilder label: () -> LabelContent) -> some View {
        Menu {
            ForEach(ReminderPriority.allCases) { priority in
                Button {
                    setPriority(priority)
                } label: {
                    Text(priorityMenuSymbol(for: priority))
                        .foregroundStyle(priorityColor(for: priority))
                }
            }
        } label: {
            label()
        }
    }

    private var priorityControlSymbol: String {
        priority == .none ? "!" : priorityPrefix(for: priority)
    }

    private func saveTitle() {
        guard !isReadOnly else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, trimmedTitle != item.title else {
            title = item.title
            return
        }
        Task {
            await store.updateTask(id: item.id, mutation: ReminderMutation(title: trimmedTitle, notes: nil, dueDate: nil, priority: nil))
        }
    }

    private func beginEditing() {
        guard !isReadOnly else { return }
        lastTaskRowTapTime = Date()
        editingTaskID = item.id
    }

    private func finishEditing() {
        saveTitle()
        saveNotes()
        if focusedField == .dueDate {
            saveDueDateText()
        }
        focusedField = nil
        isDatePickerPresented = false
    }

    private func saveNotes() {
        guard !isReadOnly else { return }
        guard notes != item.notes else { return }
        Task {
            await store.updateTask(id: item.id, mutation: ReminderMutation(title: nil, notes: notes, dueDate: nil, priority: nil))
        }
    }

    private func saveDueDateText() {
        guard !isReadOnly else { return }
        let trimmedText = dueDateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            clearDueDate()
            return
        }
        guard let parsedDate = Self.parseDateText(trimmedText) else {
            dueDateText = Self.formattedDateText(item.dueDate)
            return
        }
        setDueDate(parsedDate)
    }

    private func setDueDate(_ date: Date) {
        guard !isReadOnly else { return }
        dueDate = date
        dueDateText = Self.formattedDateText(date)
        hasDueDate = true
        isDatePickerPresented = false
        Task {
            await store.updateTask(id: item.id, mutation: ReminderMutation(title: nil, notes: nil, dueDate: .some(date), priority: nil))
        }
    }

    private func clearDueDate() {
        guard !isReadOnly else { return }
        dueDateText = ""
        hasDueDate = false
        isDatePickerPresented = false
        Task {
            await store.updateTask(id: item.id, mutation: ReminderMutation(title: nil, notes: nil, dueDate: .some(nil), priority: nil))
        }
    }

    private func setPriority(_ newPriority: ReminderPriority) {
        guard !isReadOnly else { return }
        priority = newPriority
        Task {
            await store.updateTask(id: item.id, mutation: ReminderMutation(title: nil, notes: nil, dueDate: nil, priority: newPriority))
        }
    }

    private func dateChoiceLabel(titleKey: String, date: Date) -> some View {
        VStack(alignment: .leading) {
            Text(LocalizedStringKey(titleKey))
            Text(date, format: .dateTime.year().month(.defaultDigits).day())
                .foregroundStyle(.secondary)
        }
    }

    private func daysFromToday(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private func weekendDate() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let saturday = 7
        let daysUntilSaturday = (saturday - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysUntilSaturday == 0 ? 7 : daysUntilSaturday, to: today) ?? daysFromToday(3)
    }

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: calendarMonth),
              let daysRange = calendar.range(of: .day, in: .month, for: calendarMonth)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let leading = Array<Date?>(repeating: nil, count: leadingEmptyDays)
        let days = daysRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        return leading + days
    }

    private func calendarDayBackground(for date: Date) -> Color {
        if hasDueDate, Calendar.current.isDate(date, inSameDayAs: dueDate) {
            return Color.accentColor.opacity(0.25)
        }
        if Calendar.current.isDateInToday(date) {
            return Color.secondary.opacity(0.15)
        }
        return Color.clear
    }

    private func calendarDayHoverBackground(for date: Date) -> Color {
        guard let hoveredCalendarDate,
              Calendar.current.isDate(hoveredCalendarDate, inSameDayAs: date)
        else { return Color.clear }
        return Color.secondary.opacity(0.12)
    }

    private func moveCalendarMonth(by months: Int) {
        calendarMonth = Calendar.current.date(byAdding: .month, value: months, to: calendarMonth) ?? calendarMonth
    }

    private func priorityPrefix(for priority: ReminderPriority) -> String {
        switch priority {
        case .high: "!!!"
        case .medium: "!!"
        case .low: "!"
        case .none: ""
        }
    }

    private func priorityMenuSymbol(for priority: ReminderPriority) -> String {
        let prefix = priorityPrefix(for: priority)
        return prefix.isEmpty ? "-" : prefix
    }

    private func priorityColor(for priority: ReminderPriority) -> Color {
        switch priority {
        case .high: .red
        case .medium: .orange
        case .low: .blue
        case .none: .secondary
        }
    }

    private static func formattedDateText(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.year().month(.defaultDigits).day())
    }

    private var shortWeekdaySymbols: [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = locale.language.languageCode?.identifier == "en"
            ? formatter.shortWeekdaySymbols ?? []
            : formatter.veryShortWeekdaySymbols ?? []
        guard symbols.count == 7 else { return [] }
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private static func parseDateText(_ text: String) -> Date? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearlessSeparators = ["/", "-"]
        for separator in yearlessSeparators {
            let components = trimmedText.split(separator: Character(separator)).compactMap { Int($0) }
            if components.count == 2,
               let date = Calendar.current.date(from: DateComponents(year: currentYear, month: components[0], day: components[1]))
            {
                return Calendar.current.startOfDay(for: date)
            }
        }

        let formatters = ["yyyy/M/d", "yyyy-MM-dd"].map { format in
            let formatter = DateFormatter()
            formatter.calendar = .current
            formatter.locale = .current
            formatter.dateFormat = format
            return formatter
        }

        for formatter in formatters {
            if let date = formatter.date(from: trimmedText) {
                return Calendar.current.startOfDay(for: date)
            }
        }

        if let date = DateFormatter.localizedDateFormatter.date(from: trimmedText) {
            return Calendar.current.startOfDay(for: date)
        }

        return nil
    }
}

private extension DateFormatter {
    static let localizedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = .current
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}
