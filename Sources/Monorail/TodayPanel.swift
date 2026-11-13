#if os(macOS)
import AppKit
import EventKit
import MonorailCore
import SwiftUI
import UserNotifications

/// Today's calendar, timers and clocks for the Today page. Reads the calendar only after you allow it.
final class TodayWatch: ObservableObject {
    static let shared = TodayWatch()

    struct Meeting: Identifiable, Equatable {
        var id: String
        var title: String
        var start: Date
        var end: Date
        var colour: NSColor
        var join: URL?
    }

    struct Countdown: Identifiable, Equatable {
        let id = UUID()
        var title: String
        var ends: Date
    }

    @Published private(set) var meetings: [Meeting] = []
    @Published private(set) var access = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var timers: [Countdown] = []
    @Published private(set) var now = Date()

    let store = EKEventStore()
    private var clock: Timer?

    var next: Meeting? { meetings.first { $0.end > now } }

    func start() {
        guard clock == nil else { return }
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in self?.reload() }
        clock = Timer.every(15) { [weak self] _ in self?.tick() }
        reload()
    }

    func requestAccess() {
        // Already answered "Don't Allow": macOS won't ask again, so take them to the switch.
        if access == .denied || access == .restricted || access.rawValue == 4 {
            PrivacyAccess.openSettings(.event)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let done: (Bool, Error?) -> Void = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.access = EKEventStore.authorizationStatus(for: .event)
                self?.reload()
            }
        }
        if #available(macOS 14.0, *) { store.requestFullAccessToEvents(completion: done) } else { store.requestAccess(to: .event, completion: done) }
    }

    var hasAccess: Bool {
        access == .authorized || (access.rawValue == 3)
    }

    private func tick() {
        now = Date()
        let finished = timers.filter { $0.ends <= now }
        if !finished.isEmpty {
            timers.removeAll { $0.ends <= now }
            for timer in finished { notify(title: timer.title, body: "Time's up.") }
        }
    }

    func reload() {
        now = Date()
        access = EKEventStore.authorizationStatus(for: .event)
        guard hasAccess else { meetings = []; return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        meetings = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                Meeting(id: event.eventIdentifier ?? UUID().uuidString, title: event.title ?? "Untitled",
                        start: event.startDate, end: event.endDate, colour: event.calendar?.color ?? .systemBlue,
                        join: TimeModel.joinLink(url: event.url?.absoluteString, location: event.location, notes: event.notes))
            }
    }

    func addTimer(minutes: Int, title: String? = nil) {
        timers.append(Countdown(title: title ?? "\(minutes)-minute timer", ends: Date().addingTimeInterval(Double(minutes) * 60)))
        timers.sort { $0.ends < $1.ends }
        now = Date()
        // Ticks faster while a timer runs, so the countdown reads smoothly.
        clock?.invalidate()
        clock = Timer.every(1) { [weak self] _ in
            guard let self else { return }
            self.tick()
            if self.timers.isEmpty {
                self.clock?.invalidate()
                self.clock = Timer.every(15) { [weak self] _ in self?.tick() }
            }
        }
    }

    func cancel(_ timer: Countdown) { timers.removeAll { $0.id == timer.id } }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

/// World clocks and timers, at the foot of the Calendar tab.
struct ClocksAndTimers: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject private var today = TodayWatch.shared
    @State private var addingCity = false
    @State private var cityQuery = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            clocksCard
            timersCard
        }
    }

    private var clocksCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("WORLD CLOCKS").font(.label).foregroundStyle(.secondary)
                Spacer()
                Button(addingCity ? "Done" : "Add City") { addingCity.toggle(); cityQuery = "" }.buttonStyle(.link).font(.system(size: 11))
            }
            if addingCity {
                TextField("Search cities", text: $cityQuery).textFieldStyle(.roundedBorder).font(.system(size: 12))
                let matches = TimeZone.knownTimeZoneIdentifiers.filter {
                    !cityQuery.isEmpty && TimeModel.city($0).localizedCaseInsensitiveContains(cityQuery) && !store.settings.worldClocks.contains($0)
                }.prefix(5)
                ForEach(Array(matches), id: \.self) { zone in
                    Button { store.settings.worldClocks.append(zone); cityQuery = "" } label: {
                        HStack { Text(TimeModel.city(zone)); Spacer(); Text(zone).foregroundStyle(.tertiary) }.font(.system(size: 12)).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if store.settings.worldClocks.isEmpty && !addingCity {
                Text("Add the cities your team works in.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ForEach(store.settings.worldClocks, id: \.self) { id in
                if let zone = TimeZone(identifier: id) {
                    HStack {
                        Text(TimeModel.city(id)).font(.system(size: 12))
                        if TimeModel.isNight(in: zone, at: today.now) {
                            Image(systemName: "moon.fill").font(.system(size: 9)).foregroundStyle(.secondary).help("Night there").accessibilityLabel("Night there")
                        }
                        Spacer()
                        Text(TimeModel.offset(zone, from: .current, at: today.now)).font(.system(size: 11)).foregroundStyle(.tertiary)
                        Text(today.now.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))).font(.figure(13, weight: .semibold))
                    }
                    .contextMenu { Button("Remove \(TimeModel.city(id))") { store.settings.worldClocks.removeAll { $0 == id } } }
                }
            }
        }
        .tile()
    }

    private var timersCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TIMERS").font(.label).foregroundStyle(.secondary)
            ForEach(today.timers) { timer in
                HStack {
                    Text(timer.title).font(.system(size: 12))
                    Spacer()
                    Text(TimeModel.countdown(timer.ends.timeIntervalSince(today.now))).font(.figure(15))
                    Button { today.cancel(timer) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary).accessibilityLabel("Cancel timer") }
                        .buttonStyle(.plain)
                }
            }
            HStack(spacing: 6) {
                ForEach([5, 10, 25, 45], id: \.self) { minutes in
                    Button("\(minutes) min") { today.addTimer(minutes: minutes) }.controlSize(.small)
                }
            }
        }
        .tile()
    }
}

/// A small month calendar, Monday first, today circled.
struct MonthView: View {
    let date: Date

    var body: some View {
        let days = TimeModel.monthGrid(for: date)
        let todayNumber = Calendar.current.component(.day, from: date)
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i]).font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary).frame(width: 22)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day.map(String.init) ?? "")
                        .font(.system(size: 10.5, weight: day == todayNumber ? .bold : .regular))
                        .foregroundStyle(day == todayNumber ? Color.white : Color.primary)
                        .frame(width: 20, height: 18)
                        .background(Circle().fill(day == todayNumber ? Tone.high : Color.clear))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date.formatted(date: .complete, time: .omitted)))
    }
}

/// The Today widget on Home: the next meeting, with Join; opens the Today page.
struct TodayWidget: View {
    let open: () -> Void
    @ObservedObject private var today = TodayWatch.shared
    @ObservedObject private var reminders = RemindersWatch.shared

    /// "2 reminders due today", when Reminders is allowed and something is due or overdue.
    private var dueLine: String? {
        let due = reminders.reminders.filter { [.overdue, .today].contains(reminders.bucket($0)) }.count
        return due == 0 ? nil : "\(due) reminder\(due == 1 ? "" : "s") due today"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: open) {
                HStack(spacing: 10) {
                    VStack(spacing: 0) {
                        Text(today.now.formatted(.dateTime.weekday(.abbreviated))).font(.system(size: 9, weight: .semibold)).foregroundStyle(Tone.high)
                        Text(today.now.formatted(.dateTime.day())).font(.figure(18, weight: .bold))
                    }
                    .frame(width: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        if let next = today.next {
                            Text(next.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            Text("\(next.start.formatted(date: .omitted, time: .shortened)) · \(TimeModel.until(next.start, end: next.end, now: today.now))")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        } else {
                            Text("Today").font(.system(size: 13, weight: .semibold))
                            Text(today.timers.first.map { "\($0.title) · \(TimeModel.countdown($0.ends.timeIntervalSince(today.now)))" }
                                 ?? dueLine ?? "Calendar, reminders and notes")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            if let link = today.next?.join, TimeModel.isImminent(today.next!.start, end: today.next!.end, now: today.now) || today.next!.start <= today.now {
                Button("Join") { NSWorkspace.shared.open(link) }.buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .tile()
        .onAppear {
            TodayWatch.shared.start()
            if PrivacyAccess.state(.reminder) == .allowed { RemindersWatch.shared.start() }
        }
    }
}
#endif
