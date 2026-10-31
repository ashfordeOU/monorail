#if os(macOS)
import AVFoundation
import AppKit
import CoreImage
import CoreMIDI
import GameController
import MonorailCore
import MultipeerConnectivity
import Network
import Speech
import Vision

/// A MIDI controller (pads, keys, a Launchpad…) runs actions: each note is mapped to one.
final class MIDIControl {
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private(set) var isOn = false
    /// Called with each note pressed (on the main thread).
    var onNote: (Int) -> Void = { _ in }

    func setEnabled(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        if on { start() } else { stop() }
    }

    private func start() {
        MIDIClientCreateWithBlock("Monorail" as CFString, &client) { _ in }
        MIDIInputPortCreateWithProtocol(client, "Monorail input" as CFString, ._1_0, &port) { [weak self] list, _ in
            self?.handle(list)
        }
        for index in 0..<MIDIGetNumberOfSources() {
            MIDIPortConnectSource(port, MIDIGetSource(index), nil)
        }
    }

    private func stop() {
        if port != 0 { MIDIPortDispose(port) }
        if client != 0 { MIDIClientDispose(client) }
        port = 0
        client = 0
    }

    private func handle(_ list: UnsafePointer<MIDIEventList>) {
        var notes: [Int] = []
        for packet in list.unsafeSequence() {
            let count = Int(packet.pointee.wordCount)
            withUnsafeBytes(of: packet.pointee.words) { raw in
                let words = raw.bindMemory(to: UInt32.self)
                for index in 0..<min(count, words.count) {
                    // A MIDI 1.0 voice message in a UMP word: status in bits 16–23, note 8–15, velocity 0–7.
                    let word = words[index]
                    let status = (word >> 16) & 0xF0
                    let note = Int((word >> 8) & 0x7F)
                    if status == 0x90, word & 0x7F > 0 { notes.append(note) }
                }
            }
        }
        guard !notes.isEmpty else { return }
        DispatchQueue.main.async { notes.forEach(self.onNote) }
    }
}

/// A game controller: d-pad slides, shoulders switch workspace, buttons for the overview and undo.
final class GameControllerInput {
    var perform: (Action) -> Void = { _ in }
    private var observers: [NSObjectProtocol] = []
    private(set) var isOn = false

    func setEnabled(_ on: Bool) {
        guard on != isOn else { return }
        isOn = on
        if on {
            GCController.shouldMonitorBackgroundEvents = true
            observers.append(NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) {
                [weak self] note in
                if let controller = note.object as? GCController { self?.bind(controller) }
            })
            GCController.controllers().forEach(bind)
            GCController.startWirelessControllerDiscovery {}
        } else {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers.removeAll()
            GCController.controllers().forEach { $0.extendedGamepad?.valueChangedHandler = nil }
        }
    }

    private func bind(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }
        func press(_ button: GCControllerButtonInput, _ action: Action) {
            button.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.perform(action) } }
        }
        press(pad.dpad.left, .focusLeft)
        press(pad.dpad.right, .focusRight)
        press(pad.dpad.up, .focusUp)
        press(pad.dpad.down, .focusDown)
        press(pad.leftShoulder, .previousWorkspace)
        press(pad.rightShoulder, .nextWorkspace)
        press(pad.buttonA, .overview)
        press(pad.buttonB, .undo)
        press(pad.buttonX, .cycleWidth)
        press(pad.buttonY, .toggleFullWidth)
        press(pad.buttonMenu, .commandPalette)
    }
}

/// Say what you want ("Slack and Mail side by side"); recognised on this Mac.
final class VoiceCommands {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var stopTimer: Timer?
    private(set) var isListening = false
    var onText: (String) -> Void = { _ in }
    var onState: (String) -> Void = { _ in }

    func toggle() {
        isListening ? finish() : begin()
    }

    private func begin() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self?.onState("Voice commands need Speech Recognition · System Settings → Privacy & Security")
                    return
                }
                self?.listen()
            }
        }
    }

    private func listen() {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            onState("Speech recognition isn’t available right now")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        request.shouldReportPartialResults = false
        self.request = request
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            onState("Couldn’t start the microphone")
            return
        }
        isListening = true
        onState("Listening… say what you want, e.g. “Safari two thirds”")
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result, result.isFinal {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.onText(text) }
            }
            if error != nil || result?.isFinal == true { DispatchQueue.main.async { self.cleanUp() } }
        }
        stopTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in self?.finish() }
    }

    private func finish() {
        stopTimer?.invalidate()
        request?.endAudio()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isListening = false
    }

    private func cleanUp() {
        finish()
        task = nil
        request = nil
    }
}

/// Experimental: turn your head towards a display and it gets focus.
final class HeadFocus: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureSession?
    private let queue = DispatchQueue(label: "org.ashforde.monorail.head")
    private var lastSide = 0
    private var since = Date()
    var onTurn: (_ right: Bool) -> Void = { _ in }

    func setEnabled(_ on: Bool) {
        if on, session == nil {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async { self?.start() }
            }
        } else if !on {
            session?.stopRunning()
            session = nil
        }
    }

    private func start() {
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device) else { return }
        let session = AVCaptureSession()
        session.sessionPreset = .low
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        self.session = session
        queue.async { session.startRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cvPixelBuffer: buffer, options: [:]).perform([request])
        guard let face = request.results?.first, let yaw = face.yaw?.doubleValue else { return }
        // About 25° either way counts as looking at the display on that side.
        let side = yaw > 0.45 ? 1 : yaw < -0.45 ? -1 : 0
        if side != lastSide {
            lastSide = side
            since = Date()
        } else if side != 0, Date().timeIntervalSince(since) > 0.6 {
            since = .distantFuture
            DispatchQueue.main.async { self.onTurn(side < 0) }  // the image is mirrored
        }
    }
}

/// A remote control page for your phone: big buttons on the local network,
/// protected by a secret in its link.
final class WebRemote {
    private var listener: NWListener?
    private(set) var port: UInt16 = 0
    var token = ""
    var perform: (String) -> Void = { _ in }
    var status: () -> String = { "" }

    var url: URL? {
        guard port != 0, let host = Self.localAddress() else { return nil }
        return URL(string: "http://\(host):\(port)/?t=\(token)")
    }

    func setEnabled(_ on: Bool, port wanted: UInt16) {
        if !on {
            listener?.cancel()
            listener = nil
            port = 0
            return
        }
        guard listener == nil, let nwPort = NWEndpoint.Port(rawValue: wanted) else { return }
        guard let listener = try? NWListener(using: .tcp, on: nwPort) else { return }
        listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
        listener.start(queue: .main)
        self.listener = listener
        port = wanted
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8),
                let line = request.split(separator: "\r\n").first
            else { connection.cancel(); return }
            let parts = line.split(separator: " ")
            let target = parts.count > 1 ? String(parts[1]) : "/"
            let components = URLComponents(string: "http://x" + target)
            let token = components?.queryItems?.first { $0.name == "t" }?.value ?? ""
            var body = "Forbidden"
            var type = "text/plain"
            var code = "403 Forbidden"
            if !self.token.isEmpty, token == self.token {
                code = "200 OK"
                if components?.path == "/do", let action = components?.queryItems?.first(where: { $0.name == "a" })?.value {
                    self.perform(action)
                    body = self.status()
                } else {
                    body = Self.page(token: self.token)
                    type = "text/html; charset=utf-8"
                }
            }
            let bytes = Data(body.utf8)
            let head = "HTTP/1.1 \(code)\r\nContent-Type: \(type)\r\nContent-Length: \(bytes.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(head.utf8) + bytes, completion: .contentProcessed { _ in connection.cancel() })
        }
    }

    /// A QR code of the remote's link, to scan with the phone.
    func qrCode() -> NSImage? {
        guard let text = url?.absoluteString, let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        let rep = NSCIImageRep(ciImage: image)
        let result = NSImage(size: rep.size)
        result.addRepresentation(rep)
        return result
    }

    static func localAddress() -> String? {
        var address: String?
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = entry.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            address = String(cString: host)
            if name == "en0" { break }
        }
        return address
    }

    private static func page(token: String) -> String {
        let buttons: [(String, String)] = [
            ("‹ Slide", "focus-left"), ("Slide ›", "focus-right"), ("Overview", "overview"), ("Full width", "full-width"),
            ("‹ Workspace", "previous-workspace"), ("Workspace ›", "next-workspace"), ("Focus mode", "focus-mode"),
            ("Show desktop", "show-desktop"), ("Undo", "undo"), ("Centre", "center"),
        ]
        let html = buttons.map { "<button onclick=\"go('\($0.1)')\">\($0.0)</button>" }.joined()
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Monorail remote</title><style>
        body{margin:0;font-family:-apple-system,system-ui;background:#0b1020;color:#fff;padding:16px}
        h1{font-size:18px;font-weight:700;margin:4px 0 14px}small{opacity:.6}
        .grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}
        button{font:600 17px -apple-system,system-ui;padding:22px 8px;border:0;border-radius:16px;color:#fff;
        background:linear-gradient(135deg,#3b5bdb,#9c36b5)}button:active{transform:scale(.97);opacity:.8}
        #s{margin-top:14px;opacity:.7;font-size:14px}</style></head><body>
        <h1>Monorail <small>by Ashforde®</small></h1><div class="grid">\(html)</div><div id="s"></div>
        <script>function go(a){fetch('/do?t=\(token)&a='+a).then(r=>r.text()).then(t=>document.getElementById('s').textContent=t)}</script>
        </body></html>
        """
    }
}

/// Keeps two nearby Macs' layouts in step, for pair programming and demos.
final class PairSync: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    private static let service = "monorail-sync"
    private let peer = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var lastSent = ""
    private var quietUntil = Date.distantPast
    var onLayout: (String) -> Void = { _ in }
    var onStatus: (String) -> Void = { _ in }
    private(set) var isOn = false

    func toggle() {
        isOn ? stop() : start()
    }

    private func start() {
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
        let advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: Self.service)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.service)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.advertiser = advertiser
        self.browser = browser
        isOn = true
        onStatus("Looking for a nearby Mac with layout sync on…")
    }

    private func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        session = nil
        isOn = false
        onStatus("Layout sync off")
    }

    /// Sends this Mac's layout (JSON) when it changed.
    func send(_ layout: String) {
        guard let session, !session.connectedPeers.isEmpty, layout != lastSent, Date() > quietUntil else { return }
        lastSent = layout
        try? session.send(Data(layout.utf8), toPeers: session.connectedPeers, with: .reliable)
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            if state == .connected { self.onStatus("Layout sync connected to \(peerID.displayName)") }
            if state == .notConnected, self.isOn { self.onStatus("Layout sync: \(peerID.displayName) left") }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async {
            // Don't bounce the change straight back.
            self.quietUntil = Date().addingTimeInterval(2)
            self.lastSent = text
            self.onLayout(text)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Sync layouts with \(peerID.displayName)?"
            alert.informativeText = "Your workspace layout will follow theirs, and theirs yours, until you turn sync off."
            alert.addButton(withTitle: "Sync")
            alert.addButton(withTitle: "Not Now")
            NSApp.activate(ignoringOtherApps: true)
            invitationHandler(alert.runModal() == .alertFirstButtonReturn, self.session)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // The Mac with the "larger" name invites, so the two don't invite each other at once.
        guard let session, peerID.displayName < peer.displayName else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
#endif
