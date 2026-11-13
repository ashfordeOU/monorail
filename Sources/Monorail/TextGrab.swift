#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Vision

/// Text and QR codes from a picture: what's on the clipboard, a file you choose, or (Monorail)
/// an area of the screen you select. Recognised on this Mac with Apple's Vision; nothing is sent.
final class TextGrab: ObservableObject {
    static let shared = TextGrab()

    @Published private(set) var text = ""
    @Published private(set) var links: [String] = []
    @Published private(set) var message: String?
    @Published private(set) var working = false

    /// Monorail: select an area with macOS's own screenshot tool, then read it.
    /// Signalbox reads screenshots you copy (⌃⇧⌘4) instead; the App Store keeps screen capture for recording.
    var canSelectArea: Bool { !Edition.isAppStore }

    func fromScreen() {
        guard canSelectArea else { return fromClipboard() }
        NSApp.windows.filter { $0 is MenuBarPanel }.forEach { $0.orderOut(nil) }
        let before = NSPasteboard.general.changeCount
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-i", "-c", "-x"]
            try? task.run()
            task.waitUntilExit()
            DispatchQueue.main.async {
                guard NSPasteboard.general.changeCount != before else { return }
                self.fromClipboard()
            }
        }
    }

    func fromClipboard() {
        guard let image = NSImage(pasteboard: NSPasteboard.general) else {
            message = "No picture on the clipboard. Press ⌃⇧⌘4 and select an area, then try again."
            return
        }
        read(image)
    }

    func fromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.prompt = "Read Text"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        read(image)
    }

    func read(_ image: NSImage) {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            message = "That picture couldn't be read."
            return
        }
        working = true
        message = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            textRequest.automaticallyDetectsLanguage = true
            let codeRequest = VNDetectBarcodesRequest()
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([textRequest, codeRequest])
            let lines = (textRequest.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            let codes = (codeRequest.results ?? []).compactMap(\.payloadStringValue)
            DispatchQueue.main.async {
                self.working = false
                self.text = lines.joined(separator: "\n")
                self.links = codes
                if lines.isEmpty && codes.isEmpty {
                    self.message = "No text or code found in that picture."
                } else {
                    // The text goes straight to the clipboard, ready to paste.
                    let out = self.text.isEmpty ? codes.joined(separator: "\n") : self.text
                    ClipboardWatch.shared.copy(out)
                    self.message = codes.isEmpty ? "Copied \(lines.count) line\(lines.count == 1 ? "" : "s")." : "Found \(codes.count) code\(codes.count == 1 ? "" : "s"); copied."
                }
            }
        }
    }
}

/// The Text page: read text and QR codes from a picture.
struct TextGrabPage: View {
    let onBack: () -> Void
    @ObservedObject private var grab = TextGrab.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PageHeader(back: Brand.name, title: "Text and Codes", onBack: onBack)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if grab.canSelectArea {
                        Button("Select on Screen") { grab.fromScreen() }.buttonStyle(.borderedProminent)
                    }
                    Button("From Clipboard") { grab.fromClipboard() }
                    Button("Choose Picture…") { grab.fromFile() }
                    if grab.working { ProgressView().controlSize(.small) }
                }
                .controlSize(.small)
                Text(grab.canSelectArea ? "Select any part of the screen; the text is copied, ready to paste."
                     : "Press ⌃⇧⌘4 and select an area to copy a screenshot, then click From Clipboard. The text is copied, ready to paste.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let message = grab.message {
                    Text(message).font(.system(size: 11.5, weight: .medium))
                }
            }
            .tile()
            ForEach(grab.links, id: \.self) { code in
                HStack(spacing: 8) {
                    Image(systemName: "qrcode").foregroundStyle(.secondary)
                    Text(code).font(.system(size: 12)).lineLimit(2).truncationMode(.middle)
                    Spacer()
                    if let url = URL(string: code), url.scheme?.hasPrefix("http") == true {
                        Button("Open") { NSWorkspace.shared.open(url) }.controlSize(.small)
                    }
                    Button("Copy") { ClipboardWatch.shared.copy(code) }.controlSize(.small)
                }
                .tile()
            }
            if !grab.text.isEmpty {
                ScrollView {
                    Text(grab.text).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .tile()
            }
        }
        .padding(12)
    }
}
#endif
