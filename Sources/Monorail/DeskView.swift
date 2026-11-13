#if os(macOS)
import AppKit
import SwiftUI

/// Your desk as it really is: each display drawn as what it is (the MacBook's own screen as a laptop,
/// others as monitors, placed as arranged in System Settings), with every window where it sits and its
/// app's icon. Monorail can focus a window and save the arrangement; Signalbox shows it.
enum DeskContext {
    static var focus: (CGWindowID) -> Void = { _ in }
    static var save: () -> Void = {}
}

struct DeskModel {
    struct Screen: Identifiable { let id: CGDirectDisplayID; let frame: CGRect; let name: String; let builtIn: Bool }
    struct Window: Identifiable { let id: CGWindowID; let frame: CGRect; let app: String; let pid: pid_t; let title: String }

    var screens: [Screen] = []
    var windows: [Window] = []

    /// Reads the displays and the on-screen windows, in one coordinate space (top-left origin, like the window list).
    static func now() -> DeskModel {
        var model = DeskModel()
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let id = CGDirectDisplayID(number.uint32Value)
            let f = screen.frame
            let flipped = CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height)
            model.screens.append(Screen(id: id, frame: flipped, name: screen.localizedName, builtIn: CGDisplayIsBuiltin(id) != 0))
        }
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let mine = getpid()
        for info in list.reversed() {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != mine,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let id = info[kCGWindowNumber as String] as? CGWindowID else { continue }
            let frame = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            guard frame.width > 120, frame.height > 80 else { continue }
            model.windows.append(Window(id: id, frame: frame, app: info[kCGWindowOwnerName as String] as? String ?? "",
                                        pid: pid, title: info[kCGWindowName as String] as? String ?? ""))
        }
        return model
    }

    var appCount: Int { Set(windows.map(\.pid)).count }
}

struct DeskView: View {
    @State private var desk = DeskModel.now()
    @State private var hovered: CGWindowID?
    private let tick = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            GeometryReader { geo in
                let bounds = desk.screens.reduce(CGRect.null) { $0.union($1.frame) }
                let scale = bounds.isNull ? 1 : min((geo.size.width - 40) / bounds.width, (geo.size.height - 70) / bounds.height)
                let origin = CGPoint(x: (geo.size.width - bounds.width * scale) / 2, y: 10)
                ZStack(alignment: .topLeading) {
                    ForEach(desk.screens) { screen in
                        device(screen, scale: scale, origin: origin, bounds: bounds)
                    }
                }
            }
            .frame(minHeight: 320)
            HStack(spacing: 14) {
                Label("\(desk.windows.count) windows", systemImage: "macwindow")
                Label("\(desk.appCount) apps", systemImage: "square.grid.2x2")
                Label("\(desk.screens.count) display\(desk.screens.count == 1 ? "" : "s")", systemImage: "display.2")
                if !Edition.isAppStore {
                    Divider().frame(height: 16)
                    Button("Save This Arrangement") { DeskContext.save() }.buttonStyle(.borderedProminent)
                }
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .onReceive(tick) { _ in desk = DeskModel.now() }
    }

    @ViewBuilder
    private func device(_ screen: DeskModel.Screen, scale: CGFloat, origin: CGPoint, bounds: CGRect) -> some View {
        let rect = CGRect(x: origin.x + (screen.frame.minX - bounds.minX) * scale, y: origin.y + (screen.frame.minY - bounds.minY) * scale,
                          width: screen.frame.width * scale, height: screen.frame.height * scale)
        let bezel: CGFloat = 6
        ZStack(alignment: .topLeading) {
            // The hardware: a laptop's base, or a monitor's stand.
            if screen.builtIn {
                Path { p in
                    p.move(to: CGPoint(x: rect.minX - rect.width * 0.08, y: rect.maxY + bezel + 10))
                    p.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.08, y: rect.maxY + bezel + 10))
                    p.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.03, y: rect.maxY + bezel + 2))
                    p.addLine(to: CGPoint(x: rect.minX - rect.width * 0.03, y: rect.maxY + bezel + 2))
                    p.closeSubpath()
                }
                .fill(Color(white: 0.72))
            } else {
                Rectangle().fill(Color(white: 0.6)).frame(width: 10, height: 28).position(x: rect.midX, y: rect.maxY + bezel + 14)
                Capsule().fill(Color(white: 0.6)).frame(width: max(40, rect.width * 0.22), height: 6).position(x: rect.midX, y: rect.maxY + bezel + 30)
            }
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(white: 0.1))
                .frame(width: rect.width + bezel * 2, height: rect.height + bezel * 2)
                .offset(x: rect.minX - bezel, y: rect.minY - bezel)
            // The screen and its windows.
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 0.2, green: 0.25, blue: 0.45), Color(red: 0.45, green: 0.25, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach(desk.windows.filter { screen.frame.intersects($0.frame) }) { window in
                    let w = window.frame.intersection(screen.frame)
                    let local = CGRect(x: (w.minX - screen.frame.minX) * scale, y: (w.minY - screen.frame.minY) * scale, width: w.width * scale, height: w.height * scale)
                    windowTile(window, size: local.size)
                        .offset(x: local.minX, y: local.minY)
                }
                Text(screen.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                    .padding(5)
            }
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .offset(x: rect.minX, y: rect.minY)
        }
    }

    private func windowTile(_ window: DeskModel.Window, size: CGSize) -> some View {
        let icon = NSRunningApplication(processIdentifier: window.pid)?.icon
        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(hovered == window.id ? 0.95 : 0.85))
            VStack(spacing: 0) {
                Rectangle().fill(Color.black.opacity(0.08)).frame(height: min(10, size.height * 0.12))
                Spacer()
            }
            if let icon { Image(nsImage: icon).resizable().frame(width: min(28, size.width * 0.4), height: min(28, size.width * 0.4)) }
        }
        .frame(width: max(size.width - 1, 2), height: max(size.height - 1, 2))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .help(window.title.isEmpty ? window.app : "\(window.app): \(window.title)")
        .onHover { hovered = $0 ? window.id : nil }
        .onTapGesture { if !Edition.isAppStore { DeskContext.focus(window.id) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(window.title.isEmpty ? window.app : "\(window.app): \(window.title)"))
    }
}
#endif
