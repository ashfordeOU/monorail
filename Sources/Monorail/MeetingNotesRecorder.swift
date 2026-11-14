#if os(macOS)
import AppKit
import AVFoundation
import MonorailCore
import ScreenCaptureKit
import Speech
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Meeting Notes: records what's said in a meeting and writes it down on this Mac. Your microphone
/// is "You"; the Mac's sound (the call) is "Others". Speech is turned into text on the Mac, and on
/// macOS 26 Apple's on-device model writes a summary. Nothing is uploaded and no audio is kept.
final class MeetingRecorder: NSObject, ObservableObject, SCStreamOutput, SCStreamDelegate {
    static let shared = MeetingRecorder()

    @Published private(set) var recording = false
    @Published private(set) var transcript = MeetingTranscript(title: "", started: Date())
    @Published private(set) var partial: [String: String] = [:]
    @Published private(set) var saved: [MeetingTranscript] = []
    @Published private(set) var summarising: Set<String> = []
    @Published var problem: String?

    var store: SettingsStore?
    private var started = Date()
    private let engine = AVAudioEngine()
    private var micRequest: SFSpeechAudioBufferRecognitionRequest?
    private var micTask: SFSpeechRecognitionTask?
    private var callRequest: SFSpeechAudioBufferRecognitionRequest?
    private var callTask: SFSpeechRecognitionTask?
    private var stream: SCStream?
    private var restartTimer: Timer?
    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private let audioQueue = DispatchQueue(label: "org.ashforde.monorail.meeting-audio")

    static var folder: URL { SettingsStore.directory.appendingPathComponent("Meeting Notes") }

    override init() {
        super.init()
        load()
    }

    var elapsed: TimeInterval { recording ? Date().timeIntervalSince(started) : transcript.duration }

    // MARK: Start and stop

    func start(title: String? = nil) {
        guard !recording else { return }
        problem = nil
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.problem = "Allow Speech Recognition for \(Brand.name) in System Settings → Privacy & Security."
                    return
                }
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.problem = "Allow the microphone for \(Brand.name) in System Settings → Privacy & Security."
                            return
                        }
                        self.begin(title: title)
                    }
                }
            }
        }
    }

    private func begin(title: String?) {
        let name = title ?? TodayWatch.shared.meetings.first { $0.start <= Date().addingTimeInterval(600) && $0.end > Date() }?.title
            ?? "Meeting " + Date().formatted(date: .omitted, time: .shortened)
        started = Date()
        transcript = MeetingTranscript(title: name, started: started)
        partial = [:]
        recording = true
        startMicrophone()
        if store?.settings.meetingNotesSystemAudio ?? true { startCallAudio() }
        // Speech tasks are kept short and renewed, so long meetings keep going.
        restartTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: true) { [weak self] _ in self?.renewTasks() }
        RecordingPill.shared.show()
    }

    func stop() {
        guard recording else { return }
        recording = false
        restartTimer?.invalidate()
        restartTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        micRequest?.endAudio()
        callRequest?.endAudio()
        if let stream { stream.stopCapture { _ in } }
        stream = nil
        RecordingPill.shared.hide()
        // Give the last phrases a moment to arrive, then save.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.micTask?.finish()
            self.callTask?.finish()
            for (speaker, text) in self.partial where !text.isEmpty { self.transcript.add(.init(speaker: speaker, at: Date().timeIntervalSince(self.started), text: text)) }
            self.partial = [:]
            self.transcript.duration = Date().timeIntervalSince(self.started)
            self.transcript.actionItems = MeetingNotes.actionItems(self.transcript)
            guard !self.transcript.lines.isEmpty else { return }
            let finished = self.transcript
            self.saved.insert(finished, at: 0)
            self.write(finished)
            self.summarise(finished)
        }
    }

    // MARK: Microphone ("You")

    private func startMicrophone() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        micRequest = newRequest()
        micTask = task(micRequest, speaker: "You")
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in self?.micRequest?.append(buffer) }
        do { try engine.start() } catch { problem = "The microphone couldn't start: \(error.localizedDescription)" }
    }

    // MARK: The Mac's sound ("Others"), through ScreenCaptureKit

    private func startCallAudio() {
        callRequest = newRequest()
        callTask = task(callRequest, speaker: "Others")
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { return }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.capturesAudio = true
                config.excludesCurrentProcessAudio = true
                config.sampleRate = 16000
                config.channelCount = 1
                config.width = 2
                config.height = 2
                config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
                try await stream.startCapture()
                await MainActor.run { self.stream = stream }
            } catch {
                await MainActor.run {
                    self.problem = "Only your microphone is being written down. To hear the others too, allow Screen Recording for \(Brand.name) in System Settings → Privacy & Security."
                }
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        callRequest?.appendAudioSampleBuffer(sampleBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.stream = nil }
    }

    // MARK: Speech

    private func newRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer?.supportsOnDeviceRecognition == true { request.requiresOnDeviceRecognition = true }
        request.addsPunctuation = true
        return request
    }

    private func task(_ request: SFSpeechAudioBufferRecognitionRequest?, speaker: String) -> SFSpeechRecognitionTask? {
        guard let request, let recognizer else { return nil }
        let at = Date().timeIntervalSince(started)
        return recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            let text = result.bestTranscription.formattedString
            DispatchQueue.main.async {
                if result.isFinal {
                    self.transcript.add(.init(speaker: speaker, at: at + (result.bestTranscription.segments.first?.timestamp ?? 0), text: text))
                    self.partial[speaker] = ""
                } else {
                    self.partial[speaker] = text
                }
            }
        }
    }

    /// Ends the current speech tasks (keeping what they heard) and starts fresh ones.
    private func renewTasks() {
        guard recording else { return }
        let oldMic = micRequest, oldCall = callRequest
        micRequest = newRequest()
        micTask = task(micRequest, speaker: "You")
        if oldCall != nil {
            callRequest = newRequest()
            callTask = task(callRequest, speaker: "Others")
        }
        oldMic?.endAudio()
        oldCall?.endAudio()
    }

    // MARK: Summary

    /// Apple's on-device model (macOS 26 and later) summarises each part of the meeting, then the whole.
    func summarise(_ meeting: MeetingTranscript) {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *), case .available = SystemLanguageModel.default.availability else { return }
        summarising.insert(meeting.id)
        Task {
            var notes: [String] = []
            for piece in MeetingNotes.chunks(meeting) {
                let session = LanguageModelSession(instructions: "You write short, plain meeting notes in British English. List decisions and who agreed to do what. Don't invent anything.")
                if let reply = try? await session.respond(to: "Summarise this part of a meeting in a few bullet points:\n\n" + piece) { notes.append(reply.content) }
            }
            var summary = notes.joined(separator: "\n")
            if notes.count > 1 {
                let session = LanguageModelSession(instructions: "You write short, plain meeting notes in British English.")
                if let reply = try? await session.respond(to: "Combine these notes from one meeting into one short summary with bullet points, without repeating yourself:\n\n" + String(summary.prefix(9000))) {
                    summary = reply.content
                }
            }
            await MainActor.run {
                self.summarising.remove(meeting.id)
                guard !summary.isEmpty, let index = self.saved.firstIndex(where: { $0.id == meeting.id }) else { return }
                self.saved[index].summary = summary
                self.write(self.saved[index])
            }
        }
        #endif
    }

    static var canSummarise: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), case .available = SystemLanguageModel.default.availability { return true }
        #endif
        return false
    }

    // MARK: Saved notes

    private func write(_ meeting: MeetingTranscript) {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(meeting) { try? data.write(to: Self.folder.appendingPathComponent(meeting.id + ".json"), options: .atomic) }
        try? meeting.markdown().write(to: Self.folder.appendingPathComponent(MeetingNotes.fileName(meeting)), atomically: true, encoding: .utf8)
    }

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? []
        saved = files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(MeetingTranscript.self, from: Data(contentsOf: $0)) }
            .sorted { $0.started > $1.started }
    }

    func delete(_ meeting: MeetingTranscript) {
        saved.removeAll { $0.id == meeting.id }
        try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(meeting.id + ".json"))
        try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(MeetingNotes.fileName(meeting)))
    }

    func rename(_ meeting: MeetingTranscript, to title: String) {
        guard let index = saved.firstIndex(where: { $0.id == meeting.id }) else { return }
        try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(MeetingNotes.fileName(meeting)))
        saved[index].title = title
        write(saved[index])
    }

    // MARK: Offer on calls

    func callChanged(_ started: Bool) {
        if started, !recording, store?.settings.meetingNotesOffer ?? false, !SuiteRole.shared.rests(.meetingNotes) { NotesOffer.shared.show() }
        if !started { NotesOffer.shared.hide() }
    }
}

/// While recording: a small red pill at the top of the screen, so it's always clear notes are being taken.
final class RecordingPill {
    static let shared = RecordingPill()
    private var panel: NSPanel?

    func show() {
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 250, height: 36)
        let panel = self.panel ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: Pill())
        panel.setFrame(NSRect(x: screen.visibleFrame.maxX - size.width - 16, y: screen.visibleFrame.maxY - size.height - 10, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() { panel?.orderOut(nil) }

    private struct Pill: View {
        @ObservedObject private var recorder = MeetingRecorder.shared
        @State private var now = Date()
        private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        var body: some View {
            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 9, height: 9)
                Text("Taking notes · " + MeetingNotes.clock(recorder.elapsed)).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                Spacer()
                Button("Stop") { recorder.stop() }.controlSize(.small)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Capsule().fill(.regularMaterial))
            .overlay(Capsule().strokeBorder(Color.red.opacity(0.5)))
            .onReceive(tick) { now = $0 }
            .help("Meeting Notes is listening. Let everyone in the meeting know.")
        }
    }
}

/// When a call starts: "Take notes for this call?"
final class NotesOffer {
    static let shared = NotesOffer()
    private var panel: NSPanel?
    private var timer: Timer?

    func show() {
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 320, height: 96)
        let panel = self.panel ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: Card(close: { [weak self] in self?.hide() }))
        panel.setFrame(NSRect(x: screen.visibleFrame.maxX - size.width - 16, y: screen.visibleFrame.maxY - size.height - 10, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { [weak self] _ in self?.hide() }
    }

    func hide() {
        timer?.invalidate()
        panel?.orderOut(nil)
    }

    private struct Card: View {
        let close: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.badge.mic").foregroundStyle(Color(nsColor: .systemOrange))
                    Text("Take notes for this call?").font(.system(size: 13, weight: .semibold))
                }
                Text("Written down on this Mac; nothing is uploaded. Let everyone know first.").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Not Now", action: close)
                    Button("Take Notes") { close(); MeetingRecorder.shared.start() }.keyboardShortcut(.defaultAction)
                }
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        }
    }
}

/// The Dashboard's Meeting Notes page.
struct MeetingNotesSection: View {
    @ObservedObject private var recorder = MeetingRecorder.shared
    @State private var chosen: String?
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let store = DashboardContext.store
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meeting Notes").font(.system(size: 22, weight: .bold))
                    Text("What's said, written down on this Mac, with action items" + (MeetingRecorder.canSummarise ? " and a summary" : "")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                if recorder.recording {
                    Button { recorder.stop() } label: { Label("Stop · " + MeetingNotes.clock(recorder.elapsed), systemImage: "stop.fill") }
                        .buttonStyle(.borderedProminent).tint(.red)
                } else {
                    Button { recorder.start() } label: { Label("Take Notes", systemImage: "record.circle") }.buttonStyle(.borderedProminent)
                }
            }
            if let problem = recorder.problem {
                Label(problem, systemImage: "exclamationmark.triangle").font(.system(size: 12)).foregroundStyle(Color(nsColor: .systemOrange))
            }
            if recorder.recording { live }
            if let store {
                DashCard(title: "Settings") {
                    Toggle("Offer to take notes when a call starts", isOn: Binding(get: { store.settings.meetingNotesOffer }, set: { store.settings.meetingNotesOffer = $0 }))
                    Toggle("Hear the other people too, from the Mac's sound (needs Screen Recording)", isOn: Binding(get: { store.settings.meetingNotesSystemAudio }, set: { store.settings.meetingNotesSystemAudio = $0 }))
                    Text(MeetingRecorder.canSummarise ? "Summaries are written by Apple's on-device model." : "Summaries need macOS 26 with Apple Intelligence; action items are found without it.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("Recording people may need their agreement where you are. Tell everyone before you start.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .font(.system(size: 12.5))
            }
            if !recorder.saved.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    DashCard(title: "Notes") {
                        ForEach(recorder.saved, id: \.id) { meeting in
                            Button { chosen = meeting.id } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(meeting.title).font(.system(size: 12.5, weight: chosen == meeting.id ? .semibold : .regular)).lineLimit(1)
                                    Text(meeting.started.formatted(date: .abbreviated, time: .shortened) + " · " + MeetingNotes.clock(meeting.duration))
                                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 260)
                    if let meeting = recorder.saved.first(where: { $0.id == (chosen ?? recorder.saved.first?.id) }) { detail(meeting) }
                }
            }
        }
        .sectionScroll()
        .onReceive(tick) { now = $0 }
        .onAppear { recorder.store = store }
    }

    private var live: some View {
        DashCard(title: "Listening", trailing: "\(recorder.transcript.wordCount) words") {
            ForEach(Array(recorder.transcript.lines.suffix(8).enumerated()), id: \.offset) { _, line in
                Text("**\(line.speaker)** \(line.text)").font(.system(size: 12.5))
            }
            ForEach(recorder.partial.keys.sorted(), id: \.self) { speaker in
                if let text = recorder.partial[speaker], !text.isEmpty {
                    Text("**\(speaker)** \(text)").font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func detail(_ m: MeetingTranscript) -> some View {
        DashCard(title: m.title, trailing: "\(m.wordCount) words") {
            HStack {
                Button("Copy as Markdown") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(m.markdown(), forType: .string)
                }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([MeetingRecorder.folder.appendingPathComponent(MeetingNotes.fileName(m))]) }
                Button("Rename…") { if let name = ClipPrompt.ask("Rename notes", "Title", initial: m.title) { recorder.rename(m, to: name) } }
                if MeetingRecorder.canSummarise && m.summary == nil {
                    Button(recorder.summarising.contains(m.id) ? "Summarising…" : "Summarise") { recorder.summarise(m) }.disabled(recorder.summarising.contains(m.id))
                }
                Spacer()
                Button("Delete", role: .destructive) { recorder.delete(m) }
            }
            .controlSize(.small)
            if let summary = m.summary {
                Text("SUMMARY").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
                Text(summary).font(.system(size: 12.5)).textSelection(.enabled)
            }
            if !m.actionItems.isEmpty {
                Text("ACTION ITEMS").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(m.actionItems, id: \.self) { item in Label(item, systemImage: "square").font(.system(size: 12.5)) }
            }
            Text("TRANSCRIPT").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(Array(m.lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(MeetingNotes.clock(line.at)).font(.system(size: 10.5)).foregroundStyle(.tertiary).monospacedDigit().frame(width: 40, alignment: .trailing)
                    Text(line.speaker).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(line.speaker == "You" ? Color(nsColor: .systemOrange) : Color(nsColor: .systemTeal)).frame(width: 50, alignment: .leading)
                    Text(line.text).font(.system(size: 12.5)).textSelection(.enabled)
                }
            }
        }
    }
}
#endif
