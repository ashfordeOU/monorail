#if os(macOS)
import AppKit
import AVFoundation
import CoreLocation
import EventKit
import Speech
import SwiftUI
import UserNotifications

/// Every permission the app can use, whether it's allowed, what uses it, and one button to put it right.
/// Nothing here asks for anything by itself: it only reads, and opens the right page of System Settings.
struct PermissionsSection: View {
    enum State: Equatable { case allowed, denied, notAsked, unknown }

    struct Permission: Identifiable {
        var id: String
        var name: String
        var symbol: String
        var uses: String
        var pane: String
        var state: State
    }

    @SwiftUI.State private var list: [Permission] = []
    @SwiftUI.State private var notifications: State = .unknown
    private let tick = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        Section {
            ForEach(list) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.symbol).font(.system(size: 13)).foregroundStyle(.white)
                        .frame(width: 26, height: 26).background(RoundedRectangle(cornerRadius: 6).fill(colour(item.state)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name).font(.system(size: 13, weight: .medium))
                        Text(item.uses).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Text(word(item.state)).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(colour(item.state))
                    if item.state != .allowed {
                        Button(item.state == .notAsked ? "Set Up" : "Fix") { open(item.pane) }.controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("\(Brand.name) asks for a permission only when you turn on something that needs it. Fix opens the right page of System Settings.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .onAppear(perform: refresh)
        .onReceive(tick) { _ in refresh() }
    }

    private func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let state: State = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional ? .allowed
                : settings.authorizationStatus == .denied ? .denied : .notAsked
            DispatchQueue.main.async { notifications = state; list = Self.read(notifications: state) }
        }
        list = Self.read(notifications: notifications)
    }

    static func read(notifications: State) -> [Permission] {
        func av(_ type: AVMediaType) -> State {
            switch AVCaptureDevice.authorizationStatus(for: type) {
            case .authorized: return .allowed
            case .denied, .restricted: return .denied
            case .notDetermined: return .notAsked
            @unknown default: return .unknown
            }
        }
        func ek(_ type: EKEntityType) -> State {
            let status = EKEventStore.authorizationStatus(for: type)
            if status == .authorized { return .allowed }
            if #available(macOS 14, *), status == .fullAccess || status == .writeOnly { return .allowed }
            if status == .notDetermined { return .notAsked }
            return .denied
        }
        let speech: State = {
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: return .allowed
            case .denied, .restricted: return .denied
            case .notDetermined: return .notAsked
            @unknown default: return .unknown
            }
        }()
        let location: State = {
            switch CLLocationManager().authorizationStatus {
            case .authorizedAlways: return .allowed
            case .denied, .restricted: return .denied
            case .notDetermined: return .notAsked
            @unknown default: return .unknown
            }
        }()
        let home = StorageWatch.realHome
        let fullDisk: State = (try? FileManager.default.contentsOfDirectory(atPath: home.appendingPathComponent("Library/Safari").path)) != nil ? .allowed : .notAsked
        var list: [Permission] = []
        if !Edition.isAppStore {
            list.append(Permission(id: "ax", name: "Accessibility", symbol: "figure.wave", uses: "Arranging windows: the strip, docking, the overview and everything that moves windows.",
                                   pane: "Privacy_Accessibility", state: AXIsProcessTrusted() ? .allowed : .notAsked))
        }
        list += [
            Permission(id: "screen", name: "Screen Recording", symbol: "rectangle.dashed.badge.record",
                       uses: "Live window previews, sharing one slide, reading text in screenshots, and hearing others in Meeting Notes.",
                       pane: "Privacy_ScreenCapture", state: CGPreflightScreenCaptureAccess() ? .allowed : .notAsked),
            Permission(id: "calendar", name: "Calendars", symbol: "calendar", uses: "Today's meetings with Join, and the calendar on Home.", pane: "Privacy_Calendars", state: ek(.event)),
            Permission(id: "reminders", name: "Reminders", symbol: "checklist", uses: "Reminders on the Today page.", pane: "Privacy_Reminders", state: ek(.reminder)),
            Permission(id: "mic", name: "Microphone", symbol: "mic.fill", uses: "Meeting Notes and voice commands, recognised on this Mac.", pane: "Privacy_Microphone", state: av(.audio)),
            Permission(id: "speech", name: "Speech Recognition", symbol: "waveform", uses: "Turning speech into text for Meeting Notes, on this Mac.", pane: "Privacy_SpeechRecognition", state: speech),
            Permission(id: "camera", name: "Camera", symbol: "camera.fill", uses: "The camera tile, to check how you look before a call.", pane: "Privacy_Camera", state: av(.video)),
            Permission(id: "location", name: "Location", symbol: "location.fill", uses: "Optional: rules that change with where you are. Weather never needs it.", pane: "Privacy_LocationServices", state: location),
            Permission(id: "notifications", name: "Notifications", symbol: "bell.badge.fill", uses: "Battery, AI limit, disk and reminder notices.", pane: "notifications", state: notifications),
        ]
        if !Edition.isAppStore {
            list.append(Permission(id: "disk", name: "Full Disk Access", symbol: "internaldrive.fill",
                                   uses: "Optional: measuring Mail, Messages and the Trash on the Storage page.", pane: "Privacy_AllFiles", state: fullDisk))
        }
        return list
    }

    private func open(_ pane: String) {
        let link = pane == "notifications" ? "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
            : "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
    }

    private func word(_ state: State) -> String {
        switch state {
        case .allowed: return "Allowed"
        case .denied: return "Turned off"
        case .notAsked: return "Not set up"
        case .unknown: return "–"
        }
    }

    private func colour(_ state: State) -> Color {
        switch state {
        case .allowed: return Color(nsColor: .systemGreen)
        case .denied: return Color(nsColor: .systemOrange)
        case .notAsked, .unknown: return Color(nsColor: .systemGray)
        }
    }
}
#endif

#if os(macOS)
/// Which screen is which: a big number and the display's name on every screen for a few seconds.
enum IdentifyDisplays {
    private static var windows: [NSWindow] = []

    static func show() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.enumerated().map { index, screen in
            let size = NSSize(width: 360, height: 240)
            let frame = NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.midY - size.height / 2, width: size.width, height: size.height)
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            let scale = screen.backingScaleFactor
            window.contentView = NSHostingView(rootView: VStack(spacing: 6) {
                Text("\(index + 1)").font(.system(size: 110, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(screen.localizedName).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                Text("\(Int(screen.frame.width * scale)) × \(Int(screen.frame.height * scale))\(screen == NSScreen.main ? " · main" : "")")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: size.width, height: size.height)
            .background(RoundedRectangle(cornerRadius: 34, style: .continuous).fill(.black.opacity(0.72))))
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.2; window.animator().alphaValue = 1 }
            return window
        }
        let shown = windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; shown.forEach { $0.animator().alphaValue = 0 } }) {
                shown.forEach { $0.orderOut(nil) }
            }
        }
    }
}
#endif
