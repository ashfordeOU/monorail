#if os(macOS)
import AppKit
import EventKit
import MonorailCore
import SwiftUI

/// Calendar and Reminders permission: asked once by macOS; after a "Don't Allow" only System
/// Settings can change it, so the button goes there instead.
enum PrivacyAccess {
    enum State { case notAsked, allowed, denied }

    static func state(_ type: EKEntityType) -> State {
        let status = EKEventStore.authorizationStatus(for: type)
        switch status.rawValue {
        case 0: return .notAsked
        case 3: return .allowed   // .authorized / .fullAccess
        default: return .denied   // denied, restricted, or write-only
        }
    }

    static func openSettings(_ type: EKEntityType) {
        let pane = type == .event ? "Privacy_Calendars" : "Privacy_Reminders"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
}

// MARK: - Calendar

extension TodayWatch {
    func events(on day: Date) -> [EKEvent] {
        guard hasAccess else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
    }

    func busyDays(in month: Date) -> Set<Int> {
        guard hasAccess else { return [] }
        let calendar = Calendar.current
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let end = calendar.date(byAdding: .month, value: 1, to: first) else { return [] }
        let events = store.events(matching: store.predicateForEvents(withStart: first, end: end, calendars: nil))
        return Organiser.busyDays(events.map(\.startDate), ends: events.map(\.endDate), month: month)
    }

    /// Adds an event to the default calendar.
    @discardableResult
    func addEvent(title: String, start: Date, minutes: Int) -> Bool {
        guard hasAccess, let calendar = store.defaultCalendarForNewEvents else { return false }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(Double(minutes) * 60)
        event.calendar = calendar
        guard (try? store.save(event, span: .thisEvent)) != nil else { return false }
        reload()
        return true
    }
}

// MARK: - Reminders

final class RemindersWatch: ObservableObject {
    static let shared = RemindersWatch()

    @Published private(set) var access = PrivacyAccess.state(.reminder)
    @Published private(set) var reminders: [EKReminder] = []
    @Published private(set) var lists: [EKCalendar] = []
    private let store = TodayWatch.shared.store
    private var observing = false

    func start() {
        access = PrivacyAccess.state(.reminder)
        if !observing {
            observing = true
            NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in self?.reload() }
        }
        reload()
    }

    func requestAccess() {
        if access == .denied { return PrivacyAccess.openSettings(.reminder) }
        NSApp.activate(ignoringOtherApps: true)
        let done: (Bool, Error?) -> Void = { [weak self] _, _ in DispatchQueue.main.async { self?.start() } }
        if #available(macOS 14.0, *) { store.requestFullAccessToReminders(completion: done) } else { store.requestAccess(to: .reminder, completion: done) }
    }

    func reload() {
        access = PrivacyAccess.state(.reminder)
        guard access == .allowed else { reminders = []; return }
        lists = store.calendars(for: .reminder)
        store.fetchReminders(matching: store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)) { [weak self] found in
            DispatchQueue.main.async { self?.reminders = found ?? [] }
        }
    }

    func dueDate(_ reminder: EKReminder) -> Date? { reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) } }
    func hasTime(_ reminder: EKReminder) -> Bool { reminder.dueDateComponents?.hour != nil }

    func bucket(_ reminder: EKReminder) -> Organiser.Bucket {
        Organiser.bucket(due: dueDate(reminder), hasTime: hasTime(reminder))
    }

    func complete(_ reminder: EKReminder) {
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
        withAnimation(Motion.pop) { reminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier } }
    }

    func add(_ title: String, today: Bool) {
        let text = title.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let list = store.defaultCalendarForNewReminders() else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = text
        reminder.calendar = list
        if today { reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date()) }
        try? store.save(reminder, commit: true)
        reload()
    }
}

// MARK: - Apple Notes (Monorail: through the Notes app's scripting; Signalbox can't reach it)

final class AppleNotes: ObservableObject {
    static let shared = AppleNotes()

    @Published private(set) var notes: [Organiser.NoteLine] = []
    @Published private(set) var loading = false
    @Published private(set) var problem: String?
    private let queue = DispatchQueue(label: "monorail.notes")

    static var available: Bool { !Edition.isAppStore }

    private func run(_ source: String, then: @escaping (String?, String?) -> Void) {
        queue.async {
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            let message = error?[NSAppleScript.errorMessage] as? String
            DispatchQueue.main.async { then(result?.stringValue, message) }
        }
    }

    func reload() {
        guard Self.available, !loading else { return }
        loading = true
        let script = """
        tell application "Notes"
            set out to ""
            set c to count of notes
            if c > 40 then set c to 40
            repeat with i from 1 to c
                set n to note i
                set d to modification date of n
                set iso to (year of d as string) & "-" & text -2 thru -1 of ("0" & ((month of d) as integer)) & "-" & text -2 thru -1 of ("0" & day of d) & "T" & text -2 thru -1 of ("0" & hours of d) & ":" & text -2 thru -1 of ("0" & minutes of d) & ":00"
                set p to plaintext of n
                if length of p > 160 then set p to text 1 thru 160 of p
                set out to out & (id of n) & tab & (name of n) & tab & iso & tab & p & linefeed
            end repeat
            return out
        end tell
        """
        run(script) { [weak self] output, error in
            self?.loading = false
            if let output {
                self?.notes = Organiser.parseNotes(output.replacingOccurrences(of: "\r", with: " "))
                self?.problem = nil
            } else {
                self?.problem = error?.contains("-1743") == true || error?.lowercased().contains("not allowed") == true
                    ? "Allow Monorail to use Notes in System Settings → Privacy & Security → Automation."
                    : "Notes didn't answer. Open Notes once, then try again."
            }
        }
    }

    func open(_ id: String) {
        run("tell application \"Notes\"\nshow note id \"\(id)\"\nactivate\nend tell") { _, _ in }
    }

    /// A new note with this text (the first line becomes its title).
    func create(_ text: String, then: @escaping () -> Void = {}) {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let html = escaped.components(separatedBy: .newlines).map { "<div>\($0.isEmpty ? "<br>" : $0)</div>" }.joined()
        run("tell application \"Notes\" to make new note with properties {body:\"\(html)\"}") { [weak self] _, _ in
            self?.reload()
            then()
        }
    }
}

// MARK: - The page

/// Calendar, Reminders and Notes, one tab each: a clean look at your day without opening three apps.
struct OrganiserPage: View {
    enum Tab: String, CaseIterable { case calendar = "Calendar", reminders = "Reminders", notes = "Notes" }

    let onBack: () -> Void
    @ObservedObject var store: SettingsStore
    @State var tab: Tab = .calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageHeader(back: Brand.name, title: tab.rawValue, onBack: onBack)
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()
            switch tab {
            case .calendar: CalendarTab(store: store)
            case .reminders: RemindersTab()
            case .notes: NotesTab()
            }
        }
        .padding(12)
    }
}

private func accessCard(_ title: String, _ text: String, denied: Bool, allow: @escaping () -> Void) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.system(size: 12.5, weight: .semibold))
        Text(denied ? "It's switched off for \(Brand.name). Turn it on in System Settings, then come back." : text)
            .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        Button(denied ? "Open Privacy Settings" : "Allow…", action: allow).controlSize(.small)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .tile()
}

struct CalendarTab: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject private var today = TodayWatch.shared
    @State private var selected = Date()
    @State private var month = Date()
    @State private var newTitle = ""
    @State private var newTime = Date().addingTimeInterval(3600)
    @State private var newMinutes = 30
    @State private var adding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 6) {
                HStack {
                    Text(month.formatted(.dateTime.month(.wide).year())).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button { shift(-1) } label: { Image(systemName: "chevron.left").accessibilityLabel("Previous month") }.buttonStyle(.plain)
                    Button("Today") { month = Date(); selected = Date() }.buttonStyle(.plain).font(.system(size: 11.5)).foregroundStyle(Tone.blue)
                    Button { shift(1) } label: { Image(systemName: "chevron.right").accessibilityLabel("Next month") }.buttonStyle(.plain)
                }
                PickMonth(month: month, selected: $selected, busy: today.busyDays(in: month))
            }
            .tile()
            if today.hasAccess {
                agenda
            } else {
                accessCard("See your days here", "Meetings with a Join button, every day at a glance, and new events in a line.",
                           denied: today.access != .notDetermined) { today.requestAccess() }
            }
            ClocksAndTimers(store: store)
        }
        .onAppear { today.start(); today.reload() }
    }

    private func shift(_ months: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: months, to: month) { month = next }
    }

    private var agenda: some View {
        let events = today.events(on: selected)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Calendar.current.isDateInToday(selected) ? "TODAY" : selected.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(.label).foregroundStyle(.secondary)
                Spacer()
                Button(adding ? "Cancel" : "New Event") { adding.toggle(); newTitle = "" }.buttonStyle(.link).font(.system(size: 11))
            }
            if adding {
                TextField("Title", text: $newTitle).textFieldStyle(.roundedBorder)
                HStack {
                    DatePicker("", selection: $newTime, displayedComponents: [.hourAndMinute]).labelsHidden()
                    Picker("", selection: $newMinutes) {
                        ForEach([15, 30, 45, 60, 90, 120], id: \.self) { Text($0 < 60 ? "\($0) min" : "\($0 / 60) h\($0 % 60 == 0 ? "" : " 30")").tag($0) }
                    }
                    .labelsHidden().frame(width: 90)
                    Spacer()
                    Button("Add") {
                        let calendar = Calendar.current
                        let time = calendar.dateComponents([.hour, .minute], from: newTime)
                        let start = calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: selected) ?? newTime
                        if today.addEvent(title: newTitle, start: start, minutes: newMinutes) { adding = false }
                    }
                    .buttonStyle(.borderedProminent).disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .controlSize(.small)
            }
            if events.isEmpty && !adding {
                Text("Nothing on.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ForEach(events, id: \.eventIdentifier) { event in
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(nsColor: event.calendar?.color ?? .systemBlue)).frame(width: 3, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title ?? "Untitled").font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(event.isAllDay ? "All day" : "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))"
                             + (event.location.map { $0.isEmpty ? "" : " · \($0)" } ?? ""))
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if let link = TimeModel.joinLink(url: event.url?.absoluteString, location: event.location, notes: event.notes), event.endDate > Date() {
                        Button("Join") { NSWorkspace.shared.open(link) }.buttonStyle(.borderedProminent).controlSize(.small)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    // Opens Calendar at that day.
                    if let url = URL(string: "ical://") { NSWorkspace.shared.open(url) }
                }
            }
        }
        .tile()
    }
}

/// A month you can click through: today circled, the chosen day filled, dots under busy days.
struct PickMonth: View {
    let month: Date
    @Binding var selected: Date
    let busy: Set<Int>

    var body: some View {
        let calendar = Calendar.current
        let days = TimeModel.monthGrid(for: month)
        let isThisMonth = calendar.isDate(month, equalTo: Date(), toGranularity: .month)
        let todayNumber = calendar.component(.day, from: Date())
        let chosen = calendar.isDate(selected, equalTo: month, toGranularity: .month) ? calendar.component(.day, from: selected) : nil
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, letter in
                    Text(letter).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 1) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let isToday = isThisMonth && day == todayNumber, isChosen = day == chosen
                        Button {
                            var parts = calendar.dateComponents([.year, .month], from: month)
                            parts.day = day
                            if let date = calendar.date(from: parts) { selected = date }
                        } label: {
                            VStack(spacing: 1) {
                                Text("\(day)").font(.system(size: 11.5, weight: isToday || isChosen ? .bold : .regular))
                                    .foregroundStyle(isChosen ? Color.white : isToday ? Tone.high : Color.primary)
                                    .frame(width: 24, height: 22)
                                    .background(Circle().fill(isChosen ? (isToday ? Tone.high : Tone.blue) : Color.clear))
                                Circle().fill(busy.contains(day) ? Color.secondary : Color.clear).frame(width: 3.5, height: 3.5)
                            }
                            .frame(maxWidth: .infinity).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("\(day)\(busy.contains(day) ? ", has events" : "")"))
                    } else {
                        Color.clear.frame(height: 26)
                    }
                }
            }
        }
    }
}

struct RemindersTab: View {
    @ObservedObject private var watch = RemindersWatch.shared
    @State private var newTitle = ""
    @State private var forToday = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if watch.access != .allowed {
                accessCard("Your reminders, from the menu bar", "Tick them off and add new ones without opening Reminders.",
                           denied: watch.access == .denied) { watch.requestAccess() }
            } else {
                HStack(spacing: 6) {
                    TextField("New reminder", text: $newTitle).textFieldStyle(.roundedBorder)
                        .onSubmit { add() }
                    Toggle("Today", isOn: $forToday).toggleStyle(.checkbox).font(.system(size: 11.5))
                    Button("Add") { add() }.controlSize(.small).disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Organiser.Bucket.allCases, id: \.self) { bucket in
                            let items = watch.reminders.filter { watch.bucket($0) == bucket }
                                .sorted { (watch.dueDate($0) ?? .distantFuture) < (watch.dueDate($1) ?? .distantFuture) }
                            if !items.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bucket.title.uppercased()).font(.label).foregroundStyle(bucket == .overdue ? Tone.high : .secondary)
                                    ForEach(items.prefix(12), id: \.calendarItemIdentifier) { reminder in row(reminder) }
                                }
                                .tile()
                            }
                        }
                        if watch.reminders.isEmpty {
                            Text("All done.").font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 20)
                        }
                    }
                }
                .frame(maxHeight: 380)
            }
        }
        .onAppear { watch.start() }
    }

    private func add() {
        watch.add(newTitle, today: forToday)
        newTitle = ""
    }

    private func row(_ reminder: EKReminder) -> some View {
        HStack(spacing: 8) {
            Button { watch.complete(reminder) } label: {
                Image(systemName: "circle").font(.system(size: 15)).foregroundStyle(Color(nsColor: reminder.calendar?.color ?? .systemOrange))
                    .accessibilityLabel("Complete \(reminder.title ?? "reminder")")
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title ?? "").font(.system(size: 12)).lineLimit(2)
                let detail = [watch.dueDate(reminder).map { watch.hasTime(reminder) ? $0.formatted(date: .abbreviated, time: .shortened) : $0.formatted(date: .abbreviated, time: .omitted) },
                              reminder.calendar?.title].compactMap { $0 }.joined(separator: " · ")
                if !detail.isEmpty { Text(detail).font(.system(size: 10.5)).foregroundStyle(.tertiary) }
            }
            Spacer(minLength: 0)
        }
    }
}

struct NotesTab: View {
    @ObservedObject private var notes = AppleNotes.shared
    @ObservedObject private var clips = ClipboardWatch.shared
    @State private var query = ""
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            quickNote
            if AppleNotes.available { appleNotes }
        }
        .onAppear { if AppleNotes.available && notes.notes.isEmpty { notes.reload() } }
    }

    /// The scratch note (both editions), with a way into Apple Notes.
    private var quickNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("QUICK NOTE").font(.label).foregroundStyle(.secondary)
                Spacer()
                Text("\(PlainText.counts(clips.note).words) words").font(.system(size: 10.5)).foregroundStyle(.tertiary)
            }
            TextEditor(text: $clips.note)
                .font(.system(size: 12.5)).scrollContentBackground(.hidden)
                .frame(height: AppleNotes.available ? 90 : 200)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
            HStack {
                Button("Copy") { clips.copy(clips.note) }
                Spacer()
                if AppleNotes.available {
                    Button("Save to Notes") { notes.create(clips.note) { clips.note = "" } }
                } else {
                    // Signalbox: macOS's own Share to Notes, which the App Store allows.
                    Button("Send to Notes…") {
                        NSSharingService(named: NSSharingService.Name("com.apple.Notes.SharingExtension"))?.perform(withItems: [clips.note])
                    }
                }
            }
            .controlSize(.small).disabled(clips.note.isEmpty)
        }
        .tile()
    }

    private var appleNotes: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("APPLE NOTES").font(.label).foregroundStyle(.secondary)
                Spacer()
                if notes.loading { ProgressView().controlSize(.small) }
                Button { notes.reload() } label: { Image(systemName: "arrow.clockwise").accessibilityLabel("Refresh") }.buttonStyle(.plain)
            }
            TextField("Search notes", text: $query).textFieldStyle(.roundedBorder).font(.system(size: 12))
            if let problem = notes.problem {
                Text(problem).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            let shown = notes.notes.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.snippet.localizedCaseInsensitiveContains(query) }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(shown.prefix(25), id: \.id) { note in
                        Button { notes.open(note.id) } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(note.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    Spacer()
                                    if let date = note.modified { Text(date.formatted(.relative(presentation: .named))).font(.system(size: 10)).foregroundStyle(.tertiary) }
                                }
                                if !note.snippet.isEmpty { Text(note.snippet).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
                            }
                            .padding(.vertical, 5).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .tile()
    }
}
#endif
