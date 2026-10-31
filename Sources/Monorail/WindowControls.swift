#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// What can be done to a window from a preview or the overview.
struct WindowCommands {
    var focus: (WindowID) -> Void = { _ in }
    var close: (WindowID) -> Void = { _ in }
    var minimize: (WindowID) -> Void = { _ in }
    var fullScreen: (WindowID) -> Void = { _ in }
    var ownSlide: (WindowID) -> Void = { _ in }
    var rename: (WindowID) -> Void = { _ in }
    var moveToWorkspace: (WindowID, Int) -> Void = { _, _ in }
    var workspaceNames: () -> [String] = { [] }
    var currentWorkspace: (WindowID) -> Int? = { _ in nil }
    /// nil arrangement means tabs.
    var setLayout: (WindowID, Arrangement?) -> Void = { _, _ in }
    /// The slide's layout (inner nil = tabs); outer nil if the window isn't tiled.
    var currentLayout: (WindowID) -> Arrangement?? = { _ in nil }
    /// The user's own layouts, and setting one on a slide.
    var customLayouts: () -> [CustomLayout] = { [] }
    var setCustomLayout: (WindowID, [Int]) -> Void = { _, _ in }
    var setZones: (WindowID, SplitTree) -> Void = { _, _ in }
    var currentRows: (WindowID) -> [Int]? = { _ in nil }
    /// Saves the slide's apps as an app pair.
    var saveAppPair: (WindowID) -> Void = { _ in }
    /// Windows that follow you to every workspace.
    var isSticky: (WindowID) -> Bool = { _ in false }
    var toggleSticky: (WindowID) -> Void = { _ in }
    /// A live picture of the window in a screen corner.
    var pictureInPicture: (WindowID) -> Void = { _ in }
    /// Name and lock the slide holding a window.
    var nameSlide: (WindowID) -> Void = { _ in }
    var isSlideLocked: (WindowID) -> Bool = { _ in false }
    var toggleLock: (WindowID) -> Void = { _ in }
    /// Stop managing the window's app altogether.
    var neverManage: (WindowID) -> Void = { _ in }
    /// Float the window at an exact size, centred.
    var setSize: (WindowID, CGSize) -> Void = { _, _ in }
}

/// Sizes for recordings and screenshots.
let standardSizes: [(String, CGSize)] = [
    ("1280 × 720 (720p)", CGSize(width: 1280, height: 720)),
    ("1440 × 900", CGSize(width: 1440, height: 900)),
    ("1920 × 1080 (1080p)", CGSize(width: 1920, height: 1080)),
    ("2560 × 1440", CGSize(width: 2560, height: 1440)),
    ("1080 × 1080 (square)", CGSize(width: 1080, height: 1080)),
]

/// "Slide Layout ▸" for the slide holding a window.
struct SlideLayoutMenu: View {
    let window: WindowID
    let commands: WindowCommands

    var body: some View {
        let current = commands.currentLayout(window)
        Menu("Slide Layout") {
            ForEach(Arrangement.standard, id: \.self) { arrangement in
                Button {
                    commands.setLayout(window, arrangement)
                } label: {
                    if current == .some(.some(arrangement)) {
                        Label(arrangement.title, systemImage: "checkmark")
                    } else {
                        Text(arrangement.title)
                    }
                }
            }
            Button {
                commands.setLayout(window, nil)
            } label: {
                if current == .some(.none) { Label("Tabs", systemImage: "checkmark") } else { Text("Tabs") }
            }
            let custom = commands.customLayouts()
            if !custom.isEmpty {
                Divider()
                let rows = current == .some(.some(.custom)) ? commands.currentRows(window) : nil
                ForEach(custom) { layout in
                    Button {
                        if let zones = layout.zones {
                            commands.setZones(window, zones)
                        } else {
                            commands.setCustomLayout(window, layout.rows)
                        }
                    } label: {
                        if rows == layout.rows { Label(layout.name, systemImage: "checkmark") } else { Text(layout.name) }
                    }
                }
            }
        }
    }
}

/// Close, minimise and full-screen buttons, like a window's title bar.
struct TrafficLights: View {
    let window: WindowID
    let commands: WindowCommands
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 6) {
            light(Color(red: 1, green: 0.37, blue: 0.34), symbol: "xmark", help: "Close") { commands.close(window) }
            light(Color(red: 1, green: 0.74, blue: 0.18), symbol: "minus", help: "Minimise") { commands.minimize(window) }
            light(Color(red: 0.16, green: 0.78, blue: 0.25), symbol: "arrow.up.left.and.arrow.down.right",
                  help: "Full screen") { commands.fullScreen(window) }
        }
        .padding(5)
        .background(Capsule().fill(Color.black.opacity(0.35)))
        .onHover { hovered = $0 }
    }

    private func light(_ color: Color, symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle().fill(color)
                Circle().strokeBorder(Color.black.opacity(0.2), lineWidth: 0.5)
                if hovered {
                    Image(systemName: symbol)
                        .font(.system(size: 6.5, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.6))
                }
            }
            .frame(width: 12, height: 12)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// The right-click menu for a window tile.
struct WindowContextMenu: View {
    let window: WindowID
    let commands: WindowCommands

    var body: some View {
        Button("Rename…") { commands.rename(window) }
        Divider()
        Button("Focus") { commands.focus(window) }
        Button("Give It Its Own Slide") { commands.ownSlide(window) }
        if commands.currentLayout(window) != nil {
            SlideLayoutMenu(window: window, commands: commands)
            Button("Save Slide as App Pair…") { commands.saveAppPair(window) }
            Button("Name Slide…") { commands.nameSlide(window) }
            Button(commands.isSlideLocked(window) ? "Unlock Slide" : "Lock Slide") { commands.toggleLock(window) }
        }
        let names = commands.workspaceNames()
        if names.count > 1 {
            Menu("Move to Workspace") {
                ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                    Button(name) { commands.moveToWorkspace(window, index) }
                        .disabled(commands.currentWorkspace(window) == index)
                }
            }
        }
        Button(commands.isSticky(window) ? "Keep in This Workspace Only" : "Show on Every Workspace") {
            commands.toggleSticky(window)
        }
        Button("Picture in Picture") { commands.pictureInPicture(window) }
        Menu("Size for Recording") {
            ForEach(Array(standardSizes.enumerated()), id: \.offset) { _, entry in
                Button(entry.0) { commands.setSize(window, entry.1) }
            }
        }
        Button("Never Manage This App") { commands.neverManage(window) }
        Divider()
        Button("Full Screen") { commands.fullScreen(window) }
        Button("Minimise") { commands.minimize(window) }
        Button("Close") { commands.close(window) }
    }
}

extension View {
    /// Adds the traffic lights (top-left) and the right-click menu to a window tile.
    func windowControls(_ window: WindowID, _ commands: WindowCommands, showLights: Bool = true) -> some View {
        overlay(alignment: .topLeading) {
            if showLights { TrafficLights(window: window, commands: commands).padding(6) }
        }
        .contextMenu { WindowContextMenu(window: window, commands: commands) }
    }
}

/// A small modal text prompt (renaming windows and workspaces).
enum TextPrompt {
    static func ask(
        title: String, message: String, initial: String, placeholder: String = "", button: String = "Rename"
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = initial
        field.placeholderString = placeholder
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }
}

/// One colour per workspace, used by the overview and the slider bar, from
/// the chosen theme.
enum WorkspaceColor {
    /// Set from Settings → Appearance.
    static var theme: Theme = .vivid

    static func palette(_ theme: Theme) -> [Color] {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch theme {
        case .vivid:
            return [rgb(0.36, 0.56, 1.0), rgb(0.69, 0.42, 1.0), rgb(1.0, 0.38, 0.62), rgb(1.0, 0.58, 0.27),
                    rgb(0.27, 0.82, 0.55), rgb(0.2, 0.8, 0.86), rgb(1.0, 0.8, 0.25), rgb(1.0, 0.36, 0.36),
                    rgb(0.45, 0.45, 0.95)]
        case .ocean:
            return [rgb(0.2, 0.62, 1.0), rgb(0.16, 0.82, 0.86), rgb(0.35, 0.45, 0.98), rgb(0.3, 0.9, 0.72),
                    rgb(0.55, 0.75, 1.0), rgb(0.12, 0.55, 0.75), rgb(0.6, 0.9, 0.95), rgb(0.4, 0.35, 0.85),
                    rgb(0.25, 0.7, 0.6)]
        case .sunset:
            return [rgb(1.0, 0.55, 0.3), rgb(1.0, 0.36, 0.5), rgb(0.85, 0.35, 0.85), rgb(1.0, 0.78, 0.3),
                    rgb(0.95, 0.45, 0.35), rgb(0.6, 0.35, 0.9), rgb(1.0, 0.65, 0.55), rgb(0.9, 0.25, 0.4),
                    rgb(1.0, 0.85, 0.55)]
        case .forest:
            return [rgb(0.3, 0.75, 0.45), rgb(0.6, 0.8, 0.3), rgb(0.85, 0.7, 0.35), rgb(0.25, 0.6, 0.55),
                    rgb(0.7, 0.55, 0.35), rgb(0.45, 0.85, 0.6), rgb(0.9, 0.8, 0.45), rgb(0.55, 0.65, 0.4),
                    rgb(0.35, 0.5, 0.35)]
        case .mono:
            return [0.92, 0.78, 0.64, 0.86, 0.7, 0.56, 0.96, 0.6, 0.74].map { Color(white: $0) }
        case .ashforde:
            return [rgb(0.85, 0.68, 0.32), rgb(0.33, 0.47, 0.86), rgb(0.94, 0.8, 0.5), rgb(0.45, 0.62, 0.95),
                    rgb(0.78, 0.55, 0.28), rgb(0.6, 0.7, 0.92), rgb(0.98, 0.88, 0.62), rgb(0.26, 0.36, 0.7),
                    rgb(0.9, 0.74, 0.45)]
        case .aurora:
            return [rgb(0.180, 0.902, 0.651), rgb(0.239, 0.722, 1.000), rgb(0.608, 0.486, 1.000), rgb(0.361, 0.949, 0.839), rgb(0.478, 0.655, 1.000), rgb(0.753, 0.518, 0.988), rgb(0.204, 0.827, 0.600), rgb(0.376, 0.647, 0.980), rgb(0.655, 0.545, 0.980)]
        case .nord:
            return [rgb(0.533, 0.753, 0.816), rgb(0.506, 0.631, 0.757), rgb(0.369, 0.506, 0.675), rgb(0.561, 0.737, 0.733), rgb(0.639, 0.745, 0.549), rgb(0.922, 0.796, 0.545), rgb(0.816, 0.529, 0.439), rgb(0.749, 0.380, 0.416), rgb(0.706, 0.557, 0.678)]
        case .dracula:
            return [rgb(0.741, 0.576, 0.976), rgb(1.000, 0.475, 0.776), rgb(0.545, 0.914, 0.992), rgb(0.314, 0.980, 0.482), rgb(1.000, 0.722, 0.424), rgb(0.945, 0.980, 0.549), rgb(1.000, 0.333, 0.333), rgb(0.384, 0.447, 0.643), rgb(1.000, 0.573, 0.875)]
        case .solarized:
            return [rgb(0.149, 0.545, 0.824), rgb(0.165, 0.631, 0.596), rgb(0.522, 0.600, 0.000), rgb(0.710, 0.537, 0.000), rgb(0.796, 0.294, 0.086), rgb(0.863, 0.196, 0.184), rgb(0.827, 0.212, 0.510), rgb(0.424, 0.443, 0.769), rgb(0.576, 0.631, 0.631)]
        case .rosePine:
            return [rgb(0.922, 0.737, 0.729), rgb(0.769, 0.655, 0.906), rgb(0.612, 0.812, 0.847), rgb(0.192, 0.455, 0.561), rgb(0.965, 0.757, 0.467), rgb(0.922, 0.435, 0.573), rgb(0.878, 0.871, 0.957), rgb(0.565, 0.549, 0.667), rgb(0.322, 0.310, 0.404)]
        case .mint:
            return [rgb(0.243, 0.706, 0.537), rgb(0.400, 0.851, 0.659), rgb(0.596, 0.961, 0.769), rgb(0.165, 0.616, 0.561), rgb(0.498, 0.847, 0.745), rgb(0.659, 0.902, 0.812), rgb(0.322, 0.718, 0.533), rgb(0.251, 0.569, 0.424), rgb(0.718, 0.894, 0.780)]
        case .lavender:
            return [rgb(0.706, 0.592, 0.941), rgb(0.831, 0.702, 1.000), rgb(0.604, 0.478, 0.902), rgb(0.886, 0.776, 1.000), rgb(0.557, 0.435, 0.847), rgb(0.780, 0.651, 0.969), rgb(0.941, 0.851, 1.000), rgb(0.494, 0.361, 0.788), rgb(0.651, 0.545, 0.890)]
        case .ember:
            return [rgb(1.000, 0.420, 0.208), rgb(0.969, 0.576, 0.118), rgb(1.000, 0.757, 0.369), rgb(0.894, 0.341, 0.180), rgb(1.000, 0.549, 0.259), rgb(0.843, 0.149, 0.239), rgb(1.000, 0.702, 0.278), rgb(0.757, 0.267, 0.055), rgb(1.000, 0.624, 0.110)]
        case .glacier:
            return [rgb(0.659, 0.855, 0.863), rgb(0.498, 0.784, 0.973), rgb(0.804, 0.937, 1.000), rgb(0.373, 0.659, 0.827), rgb(0.741, 0.878, 0.996), rgb(0.565, 0.878, 0.937), rgb(0.282, 0.792, 0.894), rgb(0.792, 0.941, 0.973), rgb(0.678, 0.910, 0.957)]
        case .sand:
            return [rgb(0.914, 0.769, 0.416), rgb(0.957, 0.635, 0.380), rgb(0.906, 0.435, 0.318), rgb(0.831, 0.639, 0.451), rgb(0.800, 0.835, 0.682), rgb(0.980, 0.929, 0.804), rgb(0.737, 0.424, 0.145), rgb(0.867, 0.631, 0.369), rgb(0.996, 0.980, 0.878)]
        case .spring:
            return [rgb(1.000, 0.718, 0.773), rgb(0.710, 0.894, 0.549), rgb(1.000, 0.839, 0.878), rgb(0.600, 0.851, 0.549), rgb(1.000, 0.898, 0.925), rgb(0.463, 0.784, 0.576), rgb(0.976, 0.776, 0.827), rgb(0.780, 0.976, 0.800), rgb(1.000, 0.784, 0.867)]
        case .summer:
            return [rgb(1.000, 0.820, 0.400), rgb(0.024, 0.839, 0.627), rgb(0.067, 0.541, 0.698), rgb(0.937, 0.278, 0.435), rgb(1.000, 0.718, 0.012), rgb(0.149, 0.776, 0.855), rgb(0.984, 0.522, 0.000), rgb(0.557, 0.792, 0.902), rgb(0.957, 0.827, 0.369)]
        case .autumn:
            return [rgb(0.851, 0.282, 0.059), rgb(0.902, 0.467, 0.000), rgb(0.961, 0.624, 0.000), rgb(0.627, 0.322, 0.176), rgb(0.761, 0.255, 0.047), rgb(0.706, 0.325, 0.035), rgb(0.918, 0.702, 0.031), rgb(0.486, 0.176, 0.071), rgb(0.976, 0.451, 0.086)]
        case .winter:
            return [rgb(0.890, 0.949, 0.992), rgb(0.733, 0.871, 0.984), rgb(0.565, 0.792, 0.976), rgb(0.812, 0.847, 0.863), rgb(0.702, 0.898, 0.988), rgb(0.925, 0.937, 0.945), rgb(0.506, 0.831, 0.980), rgb(0.690, 0.745, 0.773), rgb(0.882, 0.961, 0.996)]
        case .festive:
            return [rgb(0.839, 0.157, 0.157), rgb(0.165, 0.616, 0.561), rgb(0.957, 0.827, 0.369), rgb(0.757, 0.071, 0.122), rgb(0.000, 0.427, 0.467), rgb(1.000, 0.820, 0.400), rgb(0.902, 0.224, 0.275), rgb(0.106, 0.263, 0.196), rgb(0.988, 0.749, 0.286)]
        case .synthwave:
            return [rgb(1.000, 0.180, 0.592), rgb(0.000, 0.941, 1.000), rgb(1.000, 0.722, 0.000), rgb(0.616, 0.306, 0.867), rgb(1.000, 0.431, 0.780), rgb(0.227, 0.525, 1.000), rgb(0.969, 0.145, 0.522), rgb(0.447, 0.035, 0.718), rgb(0.298, 0.788, 0.941)]
        case .phosphor:
            return [rgb(0.200, 1.000, 0.400), rgb(0.133, 0.800, 0.333), rgb(0.400, 1.000, 0.600), rgb(0.098, 0.639, 0.278), rgb(0.600, 1.000, 0.733), rgb(0.180, 0.902, 0.353), rgb(0.059, 0.478, 0.200), rgb(0.333, 0.933, 0.533), rgb(0.702, 1.000, 0.800)]
        case .paper:
            return [rgb(0.122, 0.122, 0.122), rgb(0.361, 0.361, 0.361), rgb(0.549, 0.110, 0.075), rgb(0.180, 0.251, 0.341), rgb(0.420, 0.306, 0.180), rgb(0.239, 0.239, 0.239), rgb(0.639, 0.231, 0.125), rgb(0.290, 0.365, 0.137), rgb(0.467, 0.467, 0.467)]
        case .nebula:
            return [rgb(0.482, 0.184, 0.969), rgb(0.945, 0.027, 0.639), rgb(0.000, 0.761, 1.000), rgb(1.000, 0.478, 0.961), rgb(0.302, 0.588, 1.000), rgb(0.710, 0.090, 0.620), rgb(0.227, 0.047, 0.639), rgb(0.969, 0.145, 0.522), rgb(0.298, 0.788, 0.941)]
        case .holographic:
            return [rgb(1.000, 0.604, 0.635), rgb(1.000, 0.855, 0.757), rgb(0.886, 0.941, 0.796), rgb(0.710, 0.918, 0.843), rgb(0.780, 0.808, 0.918), rgb(0.627, 0.906, 0.898), rgb(0.984, 0.769, 0.671), rgb(0.973, 0.710, 0.898), rgb(0.706, 0.973, 0.784)]
        case .seasons:
            return palette(theme.resolved())
        }
    }

    /// The overview's backdrop: a gradient and three soft glows.
    static func backdrop(_ theme: Theme) -> (gradient: [Color], glows: [Color]) {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch theme {
        case .vivid:
            return ([rgb(0.13, 0.09, 0.36), rgb(0.36, 0.13, 0.5), rgb(0.05, 0.3, 0.46)],
                    [rgb(1, 0.38, 0.62), rgb(0.2, 0.8, 0.86), rgb(1, 0.58, 0.27)])
        case .ocean:
            return ([rgb(0.03, 0.12, 0.3), rgb(0.04, 0.25, 0.42), rgb(0.02, 0.35, 0.4)],
                    [rgb(0.2, 0.62, 1), rgb(0.16, 0.82, 0.86), rgb(0.35, 0.45, 0.98)])
        case .sunset:
            return ([rgb(0.3, 0.08, 0.2), rgb(0.45, 0.14, 0.24), rgb(0.35, 0.12, 0.4)],
                    [rgb(1, 0.55, 0.3), rgb(0.85, 0.35, 0.85), rgb(1, 0.78, 0.3)])
        case .forest:
            return ([rgb(0.05, 0.18, 0.12), rgb(0.1, 0.25, 0.15), rgb(0.12, 0.2, 0.1)],
                    [rgb(0.3, 0.75, 0.45), rgb(0.85, 0.7, 0.35), rgb(0.45, 0.85, 0.6)])
        case .mono:
            return ([Color(white: 0.1), Color(white: 0.16), Color(white: 0.12)],
                    [Color(white: 0.5), Color(white: 0.35), Color(white: 0.6)])
        case .ashforde:
            return ([rgb(0.04, 0.07, 0.18), rgb(0.07, 0.12, 0.28), rgb(0.05, 0.09, 0.22)],
                    [rgb(0.85, 0.68, 0.32), rgb(0.33, 0.47, 0.86), rgb(0.94, 0.8, 0.5)])
        case .aurora:
            return ([rgb(0.024, 0.102, 0.169), rgb(0.043, 0.180, 0.247), rgb(0.102, 0.078, 0.275)],
                    [rgb(0.180, 0.902, 0.651), rgb(0.608, 0.486, 1.000), rgb(0.239, 0.722, 1.000)])
        case .nord:
            return ([rgb(0.180, 0.204, 0.251), rgb(0.231, 0.259, 0.322), rgb(0.263, 0.298, 0.369)],
                    [rgb(0.533, 0.753, 0.816), rgb(0.369, 0.506, 0.675), rgb(0.706, 0.557, 0.678)])
        case .dracula:
            return ([rgb(0.129, 0.133, 0.173), rgb(0.157, 0.165, 0.212), rgb(0.204, 0.216, 0.275)],
                    [rgb(0.741, 0.576, 0.976), rgb(1.000, 0.475, 0.776), rgb(0.545, 0.914, 0.992)])
        case .solarized:
            return ([rgb(0.000, 0.169, 0.212), rgb(0.027, 0.212, 0.259), rgb(0.039, 0.247, 0.298)],
                    [rgb(0.149, 0.545, 0.824), rgb(0.165, 0.631, 0.596), rgb(0.710, 0.537, 0.000)])
        case .rosePine:
            return ([rgb(0.098, 0.090, 0.141), rgb(0.122, 0.114, 0.180), rgb(0.149, 0.137, 0.227)],
                    [rgb(0.922, 0.737, 0.729), rgb(0.769, 0.655, 0.906), rgb(0.612, 0.812, 0.847)])
        case .mint:
            return ([rgb(0.043, 0.165, 0.133), rgb(0.059, 0.227, 0.180), rgb(0.071, 0.247, 0.208)],
                    [rgb(0.400, 0.851, 0.659), rgb(0.165, 0.616, 0.561), rgb(0.659, 0.902, 0.812)])
        case .lavender:
            return ([rgb(0.118, 0.082, 0.188), rgb(0.165, 0.114, 0.271), rgb(0.141, 0.102, 0.227)],
                    [rgb(0.706, 0.592, 0.941), rgb(0.886, 0.776, 1.000), rgb(0.557, 0.435, 0.847)])
        case .ember:
            return ([rgb(0.122, 0.039, 0.020), rgb(0.227, 0.071, 0.031), rgb(0.169, 0.051, 0.024)],
                    [rgb(1.000, 0.420, 0.208), rgb(1.000, 0.757, 0.369), rgb(0.843, 0.149, 0.239)])
        case .glacier:
            return ([rgb(0.039, 0.102, 0.165), rgb(0.063, 0.157, 0.243), rgb(0.051, 0.133, 0.212)],
                    [rgb(0.659, 0.855, 0.863), rgb(0.498, 0.784, 0.973), rgb(0.792, 0.941, 0.973)])
        case .sand:
            return ([rgb(0.165, 0.122, 0.078), rgb(0.231, 0.169, 0.102), rgb(0.200, 0.145, 0.102)],
                    [rgb(0.914, 0.769, 0.416), rgb(0.957, 0.635, 0.380), rgb(0.906, 0.435, 0.318)])
        case .spring:
            return ([rgb(0.122, 0.165, 0.110), rgb(0.165, 0.227, 0.149), rgb(0.227, 0.165, 0.200)],
                    [rgb(1.000, 0.718, 0.773), rgb(0.710, 0.894, 0.549), rgb(1.000, 0.898, 0.925)])
        case .summer:
            return ([rgb(0.024, 0.157, 0.239), rgb(0.039, 0.239, 0.361), rgb(0.055, 0.290, 0.420)],
                    [rgb(1.000, 0.820, 0.400), rgb(0.024, 0.839, 0.627), rgb(0.937, 0.278, 0.435)])
        case .autumn:
            return ([rgb(0.165, 0.078, 0.031), rgb(0.227, 0.110, 0.047), rgb(0.200, 0.094, 0.039)],
                    [rgb(0.902, 0.467, 0.000), rgb(0.851, 0.282, 0.059), rgb(0.961, 0.624, 0.000)])
        case .winter:
            return ([rgb(0.051, 0.106, 0.165), rgb(0.106, 0.149, 0.231), rgb(0.082, 0.125, 0.184)],
                    [rgb(0.733, 0.871, 0.984), rgb(0.925, 0.937, 0.945), rgb(0.506, 0.831, 0.980)])
        case .festive:
            return ([rgb(0.102, 0.043, 0.043), rgb(0.059, 0.165, 0.122), rgb(0.165, 0.059, 0.071)],
                    [rgb(0.839, 0.157, 0.157), rgb(0.165, 0.616, 0.561), rgb(0.957, 0.827, 0.369)])
        case .synthwave:
            return ([rgb(0.071, 0.000, 0.169), rgb(0.176, 0.043, 0.306), rgb(0.102, 0.024, 0.220)],
                    [rgb(1.000, 0.180, 0.592), rgb(0.000, 0.941, 1.000), rgb(0.616, 0.306, 0.867)])
        case .phosphor:
            return ([rgb(0.004, 0.039, 0.012), rgb(0.012, 0.078, 0.039), rgb(0.008, 0.059, 0.024)],
                    [rgb(0.200, 1.000, 0.400), rgb(0.098, 0.639, 0.278), rgb(0.400, 1.000, 0.600)])
        case .paper:
            return ([rgb(0.937, 0.914, 0.867), rgb(0.961, 0.941, 0.902), rgb(0.910, 0.878, 0.816)],
                    [rgb(0.788, 0.749, 0.682), rgb(0.867, 0.827, 0.761), rgb(0.722, 0.675, 0.596)])
        case .nebula:
            return ([rgb(0.027, 0.008, 0.078), rgb(0.078, 0.020, 0.200), rgb(0.043, 0.039, 0.180)],
                    [rgb(0.945, 0.027, 0.639), rgb(0.482, 0.184, 0.969), rgb(0.000, 0.761, 1.000)])
        case .holographic:
            return ([rgb(0.110, 0.106, 0.180), rgb(0.165, 0.141, 0.251), rgb(0.122, 0.165, 0.227)],
                    [rgb(1.000, 0.604, 0.635), rgb(0.627, 0.906, 0.898), rgb(0.780, 0.808, 0.918)])
        case .seasons:
            return backdrop(theme.resolved())
        }
    }

    static var all: [Color] { palette(theme) }

    /// Per-workspace colours chosen in Settings → Workspaces (hex, keyed by index).
    static var overrides: [Int: String] = [:]

    static func color(_ index: Int) -> Color {
        if let hex = overrides[index], let color = Color(hex: hex) { return color }
        let colors = all
        return colors[((index % colors.count) + colors.count) % colors.count]
    }
}
extension Color {
    /// A colour from "#RRGGBB" or "RRGGBB".
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

/// The average colour of an app's icon, for borders that match the app.
enum IconColor {
    private static var cache: [pid_t: String] = [:]

    static func hex(for pid: pid_t) -> String? {
        if let cached = cache[pid] { return cached }
        guard let icon = NSRunningApplication(processIdentifier: pid)?.icon,
            let cg = icon.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let alpha = max(Double(pixel[3]) / 255, 0.01)
        func channel(_ v: UInt8) -> Int { min(255, Int(Double(v) / alpha)) }
        let hex = String(format: "#%02X%02X%02X", channel(pixel[0]), channel(pixel[1]), channel(pixel[2]))
        cache[pid] = hex
        return hex
    }
}
#endif
