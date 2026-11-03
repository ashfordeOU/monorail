#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// The hold-and-release window switcher: hold ⌘ (or ⌥) and press Tab for a grid of live
/// thumbnails of every window, most recent first; Tab and the arrows move, W closes, M minimises,
/// Q quits the app, and letting go switches. Keys come from the event tap (InputMonitor), so the
/// panel never takes focus from the app you're in.
final class WindowSwitcherGrid {
    var windows: () -> [Engine.WindowSummary] = { [] }
    var choose: (WindowID) -> Void = { _ in }
    var closeWindow: (WindowID) -> Void = { _ in }
    var minimizeWindow: (WindowID) -> Void = { _ in }
    var quitApp: (WindowID) -> Void = { _ in }
    /// The panel went away by itself (a click): the keys stop being the switcher's.
    var onDismiss: () -> Void = {}

    private let model = SwitcherGridModel()
    private var panel: NSPanel?
    private var showTimer: Timer?

    /// What the event tap saw.
    func handle(_ event: HoldSwitcherEvent) {
        switch event {
        case .open(let backward):
            open(backward: backward)
        case .step(let delta):
            model.selection = HoldSwitcher.step(model.selection, by: delta, count: model.windows.count)
        case .row(let delta):
            model.selection = HoldSwitcher.row(model.selection, by: delta, count: model.windows.count, columns: model.columns)
        case .commit:
            let chosen = model.selected?.id
            hide()
            if let chosen { choose(chosen) }
        case .cancel:
            hide()
        case .closeWindow, .minimizeWindow, .quitApp:
            guard let chosen = model.selected else { return }
            switch event {
            case .closeWindow: closeWindow(chosen.id)
            case .minimizeWindow: minimizeWindow(chosen.id)
            default: quitApp(chosen.id)
            }
            // Take it out of the grid (quitting takes every window of the app).
            let gone: (Engine.WindowSummary) -> Bool = event == .quitApp
                ? { $0.appName == chosen.appName } : { $0.id == chosen.id }
            model.windows.removeAll(where: gone)
            if model.windows.isEmpty {
                hide()
                onDismiss()
                return
            }
            model.selection = min(model.selection, model.windows.count - 1)
            model.columns = HoldSwitcher.columns(for: model.windows.count)
            if panel?.isVisible == true { show() }
        }
    }

    private func open(backward: Bool) {
        let list = windows()
        model.windows = list
        model.columns = HoldSwitcher.columns(for: list.count)
        model.selection = HoldSwitcher.initialSelection(count: list.count, backward: backward)
        model.thumbnails = [:]
        // A quick ⌘Tab-and-let-go switches without the panel flashing up.
        showTimer?.invalidate()
        showTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in self?.show() }
    }

    private func show() {
        guard !model.windows.isEmpty else { return }
        if model.thumbnails.isEmpty, WindowThumbnails.isAllowed {
            // Only once the grid shows (a quick switch never needs them). Private windows show their icon.
            let ids = model.windows.filter { !$0.isPrivate }.prefix(36).map(\.id)
            WindowThumbnails.capture(Array(ids)) { [weak self] images in self?.model.thumbnails = images }
        }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        model.tile = SwitcherGridModel.tileSize(columns: model.columns, maxWidth: visible.width * 0.9)
        let size = model.panelSize
        panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }

    private func hide() {
        showTimer?.invalidate()
        showTimer = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: SwitcherGridView(model: model) { [weak self] id in
            self?.hide()
            self?.onDismiss()
            self?.choose(id)
        })
        return panel
    }
}

final class SwitcherGridModel: ObservableObject {
    @Published var windows: [Engine.WindowSummary] = []
    @Published var selection = 0
    @Published var thumbnails: [WindowID: NSImage] = [:]
    @Published var columns = 1
    @Published var tile = CGSize(width: 220, height: 170)

    static let padding: CGFloat = 18
    static let spacing: CGFloat = 10

    var selected: Engine.WindowSummary? { windows.indices.contains(selection) ? windows[selection] : nil }

    var rows: Int { max(1, Int((Double(windows.count) / Double(max(columns, 1))).rounded(.up))) }

    var panelSize: CGSize {
        let c = CGFloat(columns), r = CGFloat(rows)
        return CGSize(width: Self.padding * 2 + c * tile.width + (c - 1) * Self.spacing,
                      height: Self.padding * 2 + r * tile.height + (r - 1) * Self.spacing + 26)
    }

    /// Tiles shrink to fit a row on the screen.
    static func tileSize(columns: Int, maxWidth: CGFloat) -> CGSize {
        let c = CGFloat(max(columns, 1))
        let width = min(220, (maxWidth - padding * 2 - (c - 1) * spacing) / c)
        return CGSize(width: max(width, 120), height: max(width, 120) * 0.77)
    }
}

struct SwitcherGridView: View {
    @ObservedObject var model: SwitcherGridModel
    let choose: (WindowID) -> Void

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(model.tile.width), spacing: SwitcherGridModel.spacing),
                                     count: max(model.columns, 1)),
                      spacing: SwitcherGridModel.spacing) {
                ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                    tile(window, selected: index == model.selection)
                        .onTapGesture { choose(window.id) }
                }
            }
            KeyHints(hints: [("tab", "next"), ("W", "close"), ("M", "minimise"), ("Q", "quit"), ("esc", "cancel")])
        }
        .padding(SwitcherGridModel.padding)
        .frame(width: model.panelSize.width, height: model.panelSize.height)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.12)))
    }

    private func tile(_ window: Engine.WindowSummary, selected: Bool) -> some View {
        let imageHeight = model.tile.height - 34
        return VStack(spacing: 5) {
            ZStack {
                if let image = model.thumbnails[window.id], !window.isPrivate {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                } else if let icon = window.icon {
                    Image(nsImage: icon).resizable().frame(width: 64, height: 64)
                }
            }
            .frame(width: model.tile.width - 16, height: imageHeight)
            .overlay(alignment: .bottomLeading) {
                if model.thumbnails[window.id] != nil, let icon = window.icon {
                    Image(nsImage: icon).resizable().frame(width: 26, height: 26).offset(x: -4, y: 6)
                }
            }
            HStack(spacing: 4) {
                Text(window.title.isEmpty ? window.appName : window.title)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                WindowBadges(window: window)
            }
            .frame(width: model.tile.width - 16)
        }
        .padding(8)
        .frame(width: model.tile.width, height: model.tile.height)
        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.35) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(window.accessibilityDescription)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Turns the macOS app switcher (⌘Tab) off while Monorail's switcher has it, and back on.
/// macOS handles ⌘Tab before any event tap sees it, so this is the only way to take it over
/// (AltTab does the same). The call is private, so it's loaded at run time and the App Store
/// edition never uses it; if it can't be found, ⌘Tab simply stays the app switcher.
enum NativeCommandTab {
    private typealias SetEnabledFn = @convention(c) (Int32, Bool) -> Int32
    /// macOS's symbolic hot keys for ⌘Tab and ⌘⇧Tab.
    private static let hotKeys: [Int32] = [1, 2]

    private static let setEnabledFunction: SetEnabledFn? = {
        #if APPSTORE
        return nil
        #else
        for path in ["/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
                     "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"] {
            if let handle = dlopen(path, RTLD_LAZY), let symbol = dlsym(handle, "CGSSetSymbolicHotKeyEnabled") {
                return unsafeBitCast(symbol, to: SetEnabledFn.self)
            }
        }
        return nil
        #endif
    }()

    /// Whether Monorail can take ⌘Tab over on this Mac.
    static var isAvailable: Bool { setEnabledFunction != nil }

    private static let takenKey = "nativeCommandTabTakenOver"

    /// ⌘Tab (and ⌘⇧Tab) back to the app switcher, or not. ⌘` stays with macOS either way.
    static func setEnabled(_ enabled: Bool) {
        guard let set = setEnabledFunction else { return }
        for key in hotKeys { _ = set(key, enabled) }
        UserDefaults.standard.set(!enabled, forKey: takenKey)
    }

    /// True if Monorail last left ⌘Tab turned off (it quit unexpectedly while holding it).
    static var wasLeftOff: Bool { UserDefaults.standard.bool(forKey: takenKey) }
}
#endif
