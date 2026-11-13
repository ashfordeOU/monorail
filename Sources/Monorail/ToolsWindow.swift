#if os(macOS)
import AppKit
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import MonorailCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers
import Vision

/// The Tools window: small jobs done on this Mac, nothing uploaded. Files, images, PDFs, text and
/// developer tools, with a search field. Monorail adds the ones the App Store's sandbox doesn't allow.
enum ToolKind: String, CaseIterable, Identifiable {
    case screenshotNames = "Screenshot Names", batchRename = "Batch Rename", images = "Convert Images", pdf = "PDF"
    case qr = "QR Code", wordCount = "Word Count", caseConvert = "Change Case", speak = "Read Aloud"
    case json = "JSON", base64 = "Base64", hash = "Hashes", timestamp = "Timestamps", jwt = "JWT", cleanLink = "Clean Link"
    case password = "Password", uuid = "UUID", deadPixel = "Dead Pixel Test", ejectAll = "Eject All", cleanKeyboard = "Clean Keyboard"

    var id: String { rawValue }

    var group: String {
        switch self {
        case .screenshotNames, .batchRename, .images, .pdf, .qr: return "Files"
        case .wordCount, .caseConvert, .speak: return "Text"
        case .json, .base64, .hash, .timestamp, .jwt, .cleanLink, .password, .uuid: return "Developer"
        case .deadPixel, .ejectAll, .cleanKeyboard: return "Mac"
        }
    }

    var symbol: String {
        switch self {
        case .screenshotNames: return "text.viewfinder"
        case .batchRename: return "pencil.and.list.clipboard"
        case .images: return "photo.on.rectangle.angled"
        case .pdf: return "doc.richtext"
        case .qr: return "qrcode"
        case .wordCount: return "textformat.123"
        case .caseConvert: return "textformat"
        case .speak: return "speaker.wave.2"
        case .json: return "curlybraces"
        case .base64: return "chevron.left.forwardslash.chevron.right"
        case .hash: return "number"
        case .timestamp: return "clock"
        case .jwt: return "key.horizontal"
        case .cleanLink: return "link"
        case .password: return "lock"
        case .uuid: return "barcode"
        case .deadPixel: return "square.grid.3x3.fill"
        case .ejectAll: return "eject"
        case .cleanKeyboard: return "keyboard"
        }
    }

    var about: String {
        switch self {
        case .screenshotNames: return "Names screenshots from the words in them, so \"Screenshot 2026-11-13 at 09.41.22\" becomes \"Quarterly revenue by region\"."
        case .batchRename: return "Rename many files at once with a pattern, numbers and dates, and find and replace."
        case .images: return "Convert, resize and compress images, and strip their location and camera details."
        case .pdf: return "Merge PDFs and images into one PDF, or split a PDF into pages."
        case .qr: return "Make a QR code from a link or any text."
        case .wordCount: return "Words, characters, sentences and reading time."
        case .caseConvert: return "UPPER, lower, Title, Sentence, camelCase, snake_case and kebab-case."
        case .speak: return "Hear any text read aloud."
        case .json: return "Tidy or minify JSON, and check it's valid."
        case .base64: return "Encode and decode Base64."
        case .hash: return "MD5, SHA-1, SHA-256 and SHA-512 of any text."
        case .timestamp: return "Unix time to a date and back."
        case .jwt: return "Read a JSON Web Token's header and claims."
        case .cleanLink: return "Remove tracking (utm_, fbclid, gclid…) from a link."
        case .password: return "Strong passwords without look-alike characters."
        case .uuid: return "New UUIDs."
        case .deadPixel: return "Full-screen colours to spot stuck or dead pixels."
        case .ejectAll: return "Eject every external drive and disk image at once."
        case .cleanKeyboard: return "Locks the keyboard for a minute so you can wipe it."
        }
    }

    /// Tools the App Store's sandbox can't do: ejecting other disks and holding the keyboard.
    static var available: [ToolKind] { Edition.isAppStore ? allCases.filter { ![.ejectAll, .cleanKeyboard].contains($0) } : allCases }
}

final class ToolsWindow {
    static let shared = ToolsWindow()
    private var window: NSWindow?

    func show(_ tool: ToolKind? = nil) {
        if let tool { UserDefaults.standard.set(tool.rawValue, forKey: "ToolsChoice") }
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "\(Brand.name) Tools"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 520)
        window.contentView = NSHostingView(rootView: ToolsRoot())
        window.center()
        window.setFrameAutosaveName("MonorailTools")
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ToolsRoot: View {
    @AppStorage("ToolsChoice") private var choice = ToolKind.screenshotNames.rawValue
    @State private var search = ""

    private var tool: ToolKind { ToolKind(rawValue: choice).flatMap { ToolKind.available.contains($0) ? $0 : nil } ?? .screenshotNames }

    private var shown: [ToolKind] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return ToolKind.available }
        return ToolKind.available.filter { $0.rawValue.lowercased().contains(q) || $0.about.lowercased().contains(q) || $0.group.lowercased().contains(q) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Search tools", text: $search).textFieldStyle(.roundedBorder).padding(.top, 34)
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(["Files", "Text", "Developer", "Mac"], id: \.self) { group in
                            let items = shown.filter { $0.group == group }
                            if !items.isEmpty {
                                Text(group.uppercased()).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary).padding(.top, 10).padding(.leading, 8)
                                ForEach(items) { item in row(item) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(width: 220)
            .background(.regularMaterial)
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: tool.symbol).font(.system(size: 22)).foregroundStyle(Color(nsColor: .systemOrange)).frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.rawValue).font(.system(size: 22, weight: .bold))
                        Text(tool.about).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                ToolBody(tool: tool).id(tool)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24).padding(.top, 34).padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func row(_ item: ToolKind) -> some View {
        Button { choice = item.rawValue } label: {
            HStack(spacing: 9) {
                Image(systemName: item.symbol).frame(width: 18)
                Text(item.rawValue)
                Spacer()
            }
            .font(.system(size: 13, weight: tool == item ? .semibold : .regular))
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tool == item ? Color.accentColor.opacity(0.18) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tool == item ? .isSelected : [])
    }
}

private struct ToolBody: View {
    let tool: ToolKind

    var body: some View {
        switch tool {
        case .screenshotNames: ScreenshotNamesTool()
        case .batchRename: BatchRenameTool()
        case .images: ImagesTool()
        case .pdf: PDFTool()
        case .qr: QRTool()
        case .wordCount: WordCountTool()
        case .caseConvert: CaseTool()
        case .speak: SpeakTool()
        case .json: TextTransformTool(actions: [("Tidy", DevTools.prettyJSON), ("Minify", DevTools.minifyJSON)], failure: "That isn't valid JSON.")
        case .base64: TextTransformTool(actions: [("Encode", { DevTools.base64Encode($0) }), ("Decode", DevTools.base64Decode)], failure: "That isn't Base64 text.")
        case .hash: HashTool()
        case .timestamp: TextTransformTool(actions: [("Convert", DevTools.timestamp), ("Now", { _ in String(Int(Date().timeIntervalSince1970)) })],
                                           failure: "Enter seconds or milliseconds since 1970, or a date like 2026-11-13T09:00:00Z.")
        case .jwt: TextTransformTool(actions: [("Read", { DevTools.decodeJWT($0).map { "Header\n\($0.header)\n\nClaims\n\($0.payload)" } })],
                                     failure: "That doesn't look like a token (three parts separated by dots).")
        case .cleanLink: TextTransformTool(actions: [("Clean", DevTools.cleanLink)], failure: "That isn't a web link.")
        case .password: GeneratorTool(title: "New Password") { DevTools.password(length: 24) }
        case .uuid: GeneratorTool(title: "New UUID") { UUID().uuidString }
        case .deadPixel: Button("Start the Test") { DeadPixelTest.start() }.controlSize(.large)
        case .ejectAll: EjectTool()
        case .cleanKeyboard: CleanKeyboardTool()
        }
    }
}

// MARK: - Shared pieces

private func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

private func chooseFolder(_ message: String) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.message = message
    panel.prompt = "Choose"
    return panel.runModal() == .OK ? panel.url : nil
}

private func chooseFiles(_ types: [UTType]) -> [URL] {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = types
    return panel.runModal() == .OK ? panel.urls : []
}

private struct Editor: View {
    @Binding var text: String
    var placeholder = "Paste or type here"

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 12.5, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(alignment: .topLeading) {
                if text.isEmpty { Text(placeholder).foregroundStyle(.tertiary).padding(11).allowsHitTesting(false) }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
    }
}

/// Text in, a choice of actions, text out.
private struct TextTransformTool: View {
    let actions: [(String, (String) -> String?)]
    let failure: String
    @State private var input = ""
    @State private var output = ""
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Editor(text: $input).frame(minHeight: 130)
            HStack {
                ForEach(actions.indices, id: \.self) { i in
                    Button(actions[i].0) {
                        if let result = actions[i].1(input) { output = result; failed = false } else { output = ""; failed = true }
                    }
                }
                if failed { Text(failure).font(.system(size: 12)).foregroundStyle(Color(nsColor: .systemRed)) }
                Spacer()
                Button("Copy Result") { copy(output) }.disabled(output.isEmpty)
            }
            Editor(text: $output, placeholder: "The result appears here").frame(minHeight: 130)
        }
    }
}

private struct GeneratorTool: View {
    let title: String
    let make: () -> String
    @State private var values: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(title) { values.insert(make(), at: 0) }.keyboardShortcut(.defaultAction)
                Button("Clear") { values = [] }.disabled(values.isEmpty)
            }
            ForEach(values.prefix(10), id: \.self) { value in
                HStack {
                    Text(value).font(.system(size: 14, design: .monospaced)).textSelection(.enabled)
                    Spacer()
                    Button { copy(value) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).help("Copy")
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            }
        }
        .onAppear { if values.isEmpty { values = [make()] } }
    }
}

// MARK: - Text

private struct WordCountTool: View {
    @State private var text = ""

    var body: some View {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let sentences = text.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 24) {
                stat("Words", "\(words)")
                stat("Characters", "\(text.count)")
                stat("Without spaces", "\(text.filter { !$0.isWhitespace }.count)")
                stat("Sentences", "\(sentences)")
                stat("Paragraphs", "\(paragraphs)")
                stat("Reading", "\(max(words > 0 ? 1 : 0, Int((Double(words) / 238).rounded()))) min")
            }
            Editor(text: $text)
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 20, weight: .semibold)).monospacedDigit()
        }
    }
}

private struct CaseTool: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Editor(text: $text).frame(minHeight: 160)
            HStack {
                ForEach(DevTools.Case.allCases, id: \.self) { style in
                    Button(style.rawValue) { text = DevTools.convert(text, to: style) }
                }
                Spacer()
                Button("Copy") { copy(text) }.disabled(text.isEmpty)
            }
        }
    }
}

private final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    let synth = AVSpeechSynthesizer()
    @Published var speaking = false
    override init() { super.init(); synth.delegate = self }
    func say(_ text: String, rate: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        synth.speak(utterance)
        speaking = true
    }
    func stop() { synth.stopSpeaking(at: .immediate); speaking = false }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { DispatchQueue.main.async { self.speaking = false } }
}

private struct SpeakTool: View {
    @StateObject private var speaker = Speaker()
    @State private var text = ""
    @State private var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Editor(text: $text, placeholder: "Paste text to hear it")
            HStack {
                Button(speaker.speaking ? "Stop" : "Read Aloud") { speaker.speaking ? speaker.stop() : speaker.say(text, rate: rate) }
                    .keyboardShortcut(.defaultAction).disabled(text.isEmpty && !speaker.speaking)
                Text("Speed")
                Slider(value: $rate, in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate).frame(width: 180)
            }
        }
    }
}

private struct HashTool: View {
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Editor(text: $text).frame(minHeight: 120)
            ForEach(DevTools.hashes(text), id: \.name) { item in
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name).font(.system(size: 12, weight: .semibold)).frame(width: 70, alignment: .leading)
                    Text(item.hex).font(.system(size: 11.5, design: .monospaced)).textSelection(.enabled).lineLimit(2)
                    Spacer()
                    Button { copy(item.hex) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).help("Copy")
                }
            }
        }
    }
}

// MARK: - Files

/// Rename files in one folder with a preview first; nothing changes until Rename.
private struct RenamePreview: View {
    let pairs: [(from: URL, to: String)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(pairs.indices, id: \.self) { i in
                    HStack {
                        Text(pairs[i].from.lastPathComponent).foregroundStyle(.secondary).lineLimit(1)
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                        Text(pairs[i].to).lineLimit(1)
                        Spacer()
                    }
                    .font(.system(size: 12))
                }
            }
        }
        .frame(minHeight: 160)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.07)))
    }
}

private func rename(_ pairs: [(from: URL, to: String)]) -> (done: Int, failed: Int) {
    var done = 0, failed = 0
    let finalNames = BatchRename.unique(pairs.map(\.to))
    for (i, pair) in pairs.enumerated() {
        let target = pair.from.deletingLastPathComponent().appendingPathComponent(finalNames[i])
        if target.path == pair.from.path { continue }
        if FileManager.default.fileExists(atPath: target.path) { failed += 1; continue }
        do { try FileManager.default.moveItem(at: pair.from, to: target); done += 1 } catch { failed += 1 }
    }
    return (done, failed)
}

private func contents(of folder: URL, images: Bool) -> [URL] {
    let list = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
    let files = list.filter { !$0.hasDirectoryPath }
    let chosen = images ? files.filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) ?? false } : files
    return chosen.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

private struct ScreenshotNamesTool: View {
    @State private var folder: URL?
    @State private var pairs: [(from: URL, to: String)] = []
    @State private var working = false
    @State private var note = ""
    @State private var onlyScreenshots = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Choose Folder…") {
                    folder = chooseFolder("Choose the folder with your screenshots (usually Desktop)")
                    read()
                }
                Toggle("Only files named \"Screenshot…\"", isOn: $onlyScreenshots).onChange(of: onlyScreenshots) { _ in read() }
                if working { ProgressView().controlSize(.small) }
                Spacer()
                Button("Rename \(pairs.count)") {
                    let result = rename(pairs)
                    note = "Renamed \(result.done)." + (result.failed > 0 ? " \(result.failed) couldn't be renamed." : "")
                    read()
                }
                .disabled(pairs.isEmpty || working).keyboardShortcut(.defaultAction)
            }
            if let folder { Text(folder.path).font(.system(size: 11)).foregroundStyle(.secondary) }
            RenamePreview(pairs: pairs)
            if !note.isEmpty { Text(note).font(.system(size: 12)).foregroundStyle(.secondary) }
            Text("Text is read on this Mac with Apple's Vision; nothing is uploaded.").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }

    private func read() {
        guard let folder else { return }
        let files = contents(of: folder, images: true).filter { !onlyScreenshots || $0.lastPathComponent.lowercased().hasPrefix("screenshot") || $0.lastPathComponent.lowercased().hasPrefix("screen shot") }
        working = true
        pairs = []
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [(from: URL, to: String)] = []
            for file in files.prefix(200) {
                guard let image = NSImage(contentsOf: file)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                try? VNImageRequestHandler(cgImage: image).perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                if let name = ScreenshotName.suggest(from: lines) { found.append((file, name + "." + file.pathExtension)) }
            }
            DispatchQueue.main.async { pairs = found; working = false; note = found.isEmpty ? "No readable text found." : "" }
        }
    }
}

private struct BatchRenameTool: View {
    @State private var files: [URL] = []
    @State private var pattern = "{name}"
    @State private var find = ""
    @State private var replace = ""
    @State private var start = 1
    @State private var note = ""

    private var pairs: [(from: URL, to: String)] {
        let info = files.map { url -> (name: String, ext: String, date: Date) in
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            return (url.deletingPathExtension().lastPathComponent, url.pathExtension, date)
        }
        let names = BatchRename.names(info, pattern: pattern, find: find, replace: replace, start: start)
        return Array(zip(files, names)).map { (from: $0.0, to: $0.1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Choose Folder…") { if let folder = chooseFolder("Choose the folder whose files you want to rename") { files = contents(of: folder, images: false) } }
                Text("\(files.count) files").foregroundStyle(.secondary)
            }
            Form {
                TextField("Pattern", text: $pattern, prompt: Text("Trip {n} {date}"))
                Text("{name} the old name · {n} a number · {date} the file's date").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    TextField("Find", text: $find)
                    TextField("Replace with", text: $replace)
                }
                Stepper("Numbers start at \(start)", value: $start, in: 0...9999)
            }
            RenamePreview(pairs: pairs)
            HStack {
                if !note.isEmpty { Text(note).font(.system(size: 12)).foregroundStyle(.secondary) }
                Spacer()
                Button("Rename \(files.count)") {
                    let result = rename(pairs)
                    note = "Renamed \(result.done)." + (result.failed > 0 ? " \(result.failed) couldn't be renamed." : "")
                    if let folder = files.first?.deletingLastPathComponent() { files = contents(of: folder, images: false) }
                }
                .disabled(files.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
    }
}

private struct ImagesTool: View {
    enum Format: String, CaseIterable { case jpeg = "JPEG", png = "PNG", heic = "HEIC", tiff = "TIFF" }
    @State private var files: [URL] = []
    @State private var format = Format.jpeg
    @State private var maxSide = 0.0
    @State private var quality = 0.8
    @State private var strip = true
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Choose Images…") { files = chooseFiles([.image]) }
                Text(files.isEmpty ? "None chosen" : "\(files.count) images").foregroundStyle(.secondary)
            }
            Form {
                Picker("Save as", selection: $format) { ForEach(Format.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                HStack {
                    Text("Longest side")
                    Slider(value: $maxSide, in: 0...6000, step: 100)
                    Text(maxSide == 0 ? "Original" : "\(Int(maxSide)) px").monospacedDigit().frame(width: 70, alignment: .trailing)
                }
                if format == .jpeg || format == .heic {
                    HStack {
                        Text("Quality")
                        Slider(value: $quality, in: 0.3...1)
                        Text("\(Int(quality * 100))%").monospacedDigit().frame(width: 70, alignment: .trailing)
                    }
                }
                Toggle("Remove location, camera and other details", isOn: $strip)
            }
            HStack {
                if !note.isEmpty { Text(note).font(.system(size: 12)).foregroundStyle(.secondary) }
                Spacer()
                Button("Save \(files.count)…") { save() }.disabled(files.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
    }

    private func save() {
        guard let folder = chooseFolder("Choose where to save the new images") else { return }
        let type: UTType
        switch format {
        case .jpeg: type = .jpeg
        case .png: type = .png
        case .heic: type = .heic
        case .tiff: type = .tiff
        }
        var saved = 0, before: Int64 = 0, after: Int64 = 0
        for file in files {
            guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { continue }
            var options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true]
            if maxSide > 0 { options[kCGImageSourceThumbnailMaxPixelSize] = Int(maxSide) }
            else if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                options[kCGImageSourceThumbnailMaxPixelSize] = max(props[kCGImagePropertyPixelWidth] as? Int ?? 0, props[kCGImagePropertyPixelHeight] as? Int ?? 0)
            }
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { continue }
            let target = folder.appendingPathComponent(file.deletingPathExtension().lastPathComponent).appendingPathExtension(type.preferredFilenameExtension ?? "img")
            guard let destination = CGImageDestinationCreateWithURL(target as CFURL, type.identifier as CFString, 1, nil) else { continue }
            var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
            if !strip, let original = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                for (key, value) in original where key != kCGImagePropertyOrientation { properties[key] = value }
            }
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
            if CGImageDestinationFinalize(destination) {
                saved += 1
                before += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                after += Int64((try? target.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            }
        }
        let size = { (n: Int64) in ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }
        note = "Saved \(saved) images: \(size(before)) → \(size(after))."
    }
}

private struct PDFTool: View {
    @State private var files: [URL] = []
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Choose PDFs and Images…") { files = chooseFiles([.pdf, .image]) }
                Text(files.isEmpty ? "None chosen" : "\(files.count) files, in this order").foregroundStyle(.secondary)
            }
            List {
                ForEach(files, id: \.self) { Text($0.lastPathComponent) }
                    .onMove { files.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(minHeight: 160)
            HStack {
                if !note.isEmpty { Text(note).font(.system(size: 12)).foregroundStyle(.secondary) }
                Spacer()
                Button("Split into Pages…") { split() }.disabled(files.count != 1 || files.first?.pathExtension.lowercased() != "pdf")
                Button("Combine into One PDF…") { merge() }.disabled(files.isEmpty).keyboardShortcut(.defaultAction)
            }
        }
    }

    private func merge() {
        let out = PDFDocument()
        for file in files {
            if file.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: file) {
                for i in 0..<doc.pageCount { if let page = doc.page(at: i) { out.insert(page, at: out.pageCount) } }
            } else if let image = NSImage(contentsOf: file), let page = PDFPage(image: image) {
                out.insert(page, at: out.pageCount)
            }
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Combined.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        note = out.write(to: url) ? "Saved \(out.pageCount) pages." : "Couldn't save the PDF."
    }

    private func split() {
        guard let file = files.first, let doc = PDFDocument(url: file), let folder = chooseFolder("Choose where to save the pages") else { return }
        var saved = 0
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let single = PDFDocument()
            single.insert(page, at: 0)
            if single.write(to: folder.appendingPathComponent("\(file.deletingPathExtension().lastPathComponent) – page \(i + 1).pdf")) { saved += 1 }
        }
        note = "Saved \(saved) pages."
    }
}

private struct QRTool: View {
    @State private var text = ""

    private var image: NSImage? {
        guard !text.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: output.extent.width / 2, height: output.extent.height / 2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("A link or any text", text: $text).textFieldStyle(.roundedBorder)
            if let image {
                Image(nsImage: image).interpolation(.none).resizable().frame(width: 220, height: 220)
                    .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(.white))
                HStack {
                    Button("Copy Image") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([image])
                    }
                    Button("Save…") {
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.png]
                        panel.nameFieldStringValue = "QR Code.png"
                        if panel.runModal() == .OK, let url = panel.url, let tiff = image.tiffRepresentation,
                           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) { try? png.write(to: url) }
                    }
                }
            }
        }
    }
}

// MARK: - Mac

enum DeadPixelTest {
    private static var window: NSWindow?

    static func start() {
        guard let screen = NSScreen.main else { return }
        let w = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.level = .screenSaver
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: Colours(close: { window?.orderOut(nil); window = nil }))
        w.setFrame(screen.frame, display: true)
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private struct Colours: View {
        let close: () -> Void
        @State private var index = 0
        private let colours: [Color] = [.red, .green, .blue, .white, .black, Color(white: 0.5)]

        var body: some View {
            colours[index]
                .ignoresSafeArea()
                .overlay(alignment: .bottom) {
                    Text(index == 0 ? "Click for the next colour; after grey it closes" : "").font(.system(size: 13)).foregroundStyle(.white.opacity(0.8)).padding(30)
                }
                .onTapGesture { if index == colours.count - 1 { close() } else { index += 1 } }
                .onExitCommand(perform: close)
        }
    }
}

private struct EjectTool: View {
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Eject All") {
                var done = 0, busy: [String] = []
                let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsInternalKey, .volumeNameKey]
                for url in FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? [] {
                    guard let v = try? url.resourceValues(forKeys: Set(keys)), v.volumeIsEjectable == true || v.volumeIsRemovable == true || v.volumeIsInternal == false,
                          url.path != "/" else { continue }
                    do { try NSWorkspace.shared.unmountAndEjectDevice(at: url); done += 1 } catch { busy.append(v.volumeName ?? url.lastPathComponent) }
                }
                note = done == 0 && busy.isEmpty ? "Nothing to eject." : "Ejected \(done)." + (busy.isEmpty ? "" : " In use: " + busy.joined(separator: ", ") + ".")
            }
            .controlSize(.large)
            if !note.isEmpty { Text(note).foregroundStyle(.secondary) }
        }
    }
}

/// Swallows key presses for a minute while you wipe the keyboard; the trackpad still works.
private struct CleanKeyboardTool: View {
    @State private var secondsLeft = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if secondsLeft > 0 {
                Text("Keyboard locked · \(secondsLeft)s").font(.system(size: 28, weight: .bold)).monospacedDigit()
                Button("Unlock Now") { stop() }.controlSize(.large)
            } else {
                Button("Lock the Keyboard for a Minute") { startLock() }.controlSize(.large)
                Text("Click Unlock Now with the trackpad or mouse to finish early. Needs Accessibility, which \(Brand.name) already has.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .onDisappear { stop() }
    }

    private func startLock() {
        guard KeyboardLock.start() else { return }
        secondsLeft = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            secondsLeft -= 1
            if secondsLeft <= 0 { stop() }
        }
    }

    private func stop() {
        timer?.invalidate(); timer = nil
        secondsLeft = 0
        KeyboardLock.stop()
    }
}

enum KeyboardLock {
    private static var tap: CFMachPort?
    private static var source: CFRunLoopSource?

    static func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue) | (1 << 14) // system-defined: media keys
        guard let made = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask),
                                           callback: { _, type, event, _ in
                                               if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                                                   if let tap = KeyboardLock.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                                                   return Unmanaged.passUnretained(event)
                                               }
                                               return nil
                                           }, userInfo: nil) else { return false }
        tap = made
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, made, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: made, enable: true)
        return true
    }

    static func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }
}
#endif
