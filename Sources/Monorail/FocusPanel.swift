#if os(macOS)
import AppKit
import AVFoundation
import MonorailCore
import SwiftUI
import UserNotifications

/// Focus sessions with a countdown, an optional background sound, a streak and a daily review;
/// and 20-20-20 eye breaks. In Monorail a session can also hide your distracting apps.
final class FocusWatch: ObservableObject {
    static let shared = FocusWatch()

    @Published private(set) var log = FocusLog()
    @Published private(set) var endsAt: Date?
    @Published private(set) var started: Date?
    @Published private(set) var now = Date()

    var settings: () -> AppSettings = { AppSettings() }
    /// Monorail hides distracting apps while a session runs.
    var onRunningChange: (Bool) -> Void = { _ in }

    private var tick: Timer?
    private var eyeTimer: Timer?
    private var activeSince = Date()
    private let noise = NoisePlayer()
    private var file: URL { SettingsStore.directory.appendingPathComponent("focus.json") }

    var isRunning: Bool { endsAt != nil }
    var remaining: TimeInterval { max((endsAt ?? now).timeIntervalSince(now), 0) }
    var progress: Double {
        guard let started, let endsAt else { return 0 }
        return min(max(now.timeIntervalSince(started) / endsAt.timeIntervalSince(started), 0), 1)
    }

    init() {
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(FocusLog.self, from: data) { log = saved }
    }

    func apply(_ settings: AppSettings) {
        if settings.eyeBreaks, eyeTimer == nil {
            activeSince = Date()
            eyeTimer = Timer.every(30) { [weak self] _ in self?.checkEyes() }
        } else if !settings.eyeBreaks {
            eyeTimer?.invalidate()
            eyeTimer = nil
        }
        if isRunning { noise.play(settings.focusSound) }
    }

    func start(minutes: Int? = nil) {
        guard !isRunning else { return }
        let length = minutes ?? settings().sessionMinutes
        started = Date()
        endsAt = Date().addingTimeInterval(Double(length) * 60)
        now = Date()
        tick = Timer.every(1) { [weak self] _ in self?.step() }
        noise.play(settings().focusSound)
        onRunningChange(true)
    }

    func stop(finished: Bool = false) {
        guard let started, isRunning else { return }
        let minutes = Int(Date().timeIntervalSince(started) / 60)
        log.record(.init(start: started, minutes: minutes, finished: finished))
        save()
        self.started = nil
        endsAt = nil
        tick?.invalidate()
        tick = nil
        noise.stop()
        onRunningChange(false)
        if finished { notify("Focus session done", "\(minutes) minutes. Stand up and look away for a moment.") }
    }

    func setSound(_ sound: String) { if isRunning { noise.play(sound) } }

    private func step() {
        now = Date()
        if let endsAt, now >= endsAt { stop(finished: true) }
    }

    private func checkEyes() {
        guard !SuiteRole.shared.pauses(.eyeBreaks) else { return }
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        if idle >= 60 { activeSince = Date(); return }
        if EyeBreaks.isDue(activeSeconds: Date().timeIntervalSince(activeSince), idleSeconds: idle) {
            activeSince = Date()
            notify("Rest your eyes", "Look at something 20 feet (6 metres) away for 20 seconds.")
        }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: SettingsStore.directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(log) { try? data.write(to: file, options: .atomic) }
    }

    private func notify(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

/// Soft background noise made on the fly (no recordings): brown, pink, or rain-like.
final class NoisePlayer {
    private var engine: AVAudioEngine?
    private var current = "none"

    func play(_ kind: String) {
        guard kind != current || engine == nil else { return }
        stop()
        guard kind != "none" else { return }
        current = kind
        let engine = AVAudioEngine()
        let format = engine.outputNode.inputFormat(forBus: 0)
        var brown: Float = 0
        var pink = [Float](repeating: 0, count: 7)
        var drop: Float = 0
        let source = AVAudioSourceNode(format: format) { _, _, frames, buffers -> OSStatus in
            let list = UnsafeMutableAudioBufferListPointer(buffers)
            for frame in 0..<Int(frames) {
                let white = Float.random(in: -1...1)
                var sample: Float
                switch kind {
                case "pink":
                    pink[0] = 0.99886 * pink[0] + white * 0.0555179
                    pink[1] = 0.99332 * pink[1] + white * 0.0750759
                    pink[2] = 0.96900 * pink[2] + white * 0.1538520
                    pink[3] = 0.86650 * pink[3] + white * 0.3104856
                    pink[4] = 0.55000 * pink[4] + white * 0.5329522
                    pink[5] = -0.7616 * pink[5] - white * 0.0168980
                    sample = (pink[0] + pink[1] + pink[2] + pink[3] + pink[4] + pink[5] + pink[6] + white * 0.5362) * 0.05
                    pink[6] = white * 0.115926
                case "rain":
                    brown = (brown + 0.02 * white) / 1.02
                    if Float.random(in: 0...1) > 0.9993 { drop = Float.random(in: 0.2...0.5) }
                    drop *= 0.993
                    sample = brown * 2.2 + white * drop * 0.25
                default:
                    brown = (brown + 0.02 * white) / 1.02
                    sample = brown * 3
                }
                for buffer in list { buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample * 0.5 }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.35
        try? engine.start()
        self.engine = engine
    }

    func stop() {
        engine?.stop()
        engine = nil
        current = "none"
    }
}

/// The Focus page: a ring counting down, lengths, a sound, eye breaks, the streak and the week.
struct FocusPage: View {
    let onBack: () -> Void
    @ObservedObject var store: SettingsStore
    @ObservedObject private var focus = FocusWatch.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageHeader(back: Brand.name, title: "Focus", onBack: onBack)
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 10)
                    Circle().trim(from: 0, to: focus.isRunning ? 1 - focus.progress : 1)
                        .stroke(Color(nsColor: .systemIndigo), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: focus.progress)
                    VStack(spacing: 0) {
                        Text(focus.isRunning ? TimeModel.countdown(focus.remaining) : "\(store.settings.sessionMinutes):00").font(.figure(30, weight: .semibold))
                        Text(focus.isRunning ? "focusing" : "ready").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 130, height: 130)
                .accessibilityElement(children: .combine)
                Picker("Length", selection: $store.settings.sessionMinutes) {
                    ForEach([15, 25, 50, 90], id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().disabled(focus.isRunning)
                Button(focus.isRunning ? "End Session" : "Start Focus") { focus.isRunning ? focus.stop() : focus.start() }
                    .buttonStyle(.borderedProminent).tint(Color(nsColor: .systemIndigo)).controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .tile()
            VStack(alignment: .leading, spacing: 6) {
                Picker("Sound", selection: $store.settings.focusSound) {
                    Text("None").tag("none"); Text("Brown noise").tag("brown"); Text("Pink noise").tag("pink"); Text("Rain").tag("rain")
                }
                .onChange(of: store.settings.focusSound) { focus.setSound($0) }
                if !Edition.isAppStore {
                    Toggle("Hide distracting apps while focusing", isOn: $store.settings.focusHidesApps)
                }
                Toggle("Eye breaks every 20 minutes", isOn: $store.settings.eyeBreaks)
            }
            .font(.system(size: 12)).tile()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("THIS WEEK").font(.label).foregroundStyle(.secondary)
                    Spacer()
                    let streak = focus.log.streak()
                    if streak > 0 { Label("\(streak)-day streak", systemImage: "flame.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(Tone.warm) }
                }
                let week = focus.log.week()
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(week.enumerated()), id: \.offset) { index, minutes in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .systemIndigo).opacity(index == 6 ? 1 : 0.55))
                                .frame(height: max(3, CGFloat(minutes) / CGFloat(max(week.max() ?? 1, 60)) * 44))
                            Text(Calendar.current.date(byAdding: .day, value: index - 6, to: Date())!.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .help("\(minutes) min")
                    }
                }
                .frame(height: 58, alignment: .bottom)
                Text(focus.log.review()).font(.system(size: 11.5)).foregroundStyle(.secondary)
                if let hour = focus.log.bestHour() {
                    Text("You focus best around \(Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!.formatted(date: .omitted, time: .shortened)).")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }
            .tile()
        }
        .padding(12)
    }
}
#endif
