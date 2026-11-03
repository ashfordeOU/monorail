#if os(macOS)
import AppKit
import CoreGraphics
import MonorailCore

/// A display's resolutions and refresh rates, through the public Core Graphics display mode calls.
enum DisplayModes {
    /// Every mode the display offers for the desktop, including the sharp (HiDPI) scaled ones.
    static func all(_ display: CGDirectDisplayID) -> [(info: DisplayModeInfo, mode: CGDisplayMode)] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
        guard let modes = CGDisplayCopyAllDisplayModes(display, options) as? [CGDisplayMode] else { return [] }
        return modes.filter { $0.isUsableForDesktopGUI() }.map { (info($0), $0) }
    }

    static func current(_ display: CGDirectDisplayID) -> DisplayModeInfo? {
        CGDisplayCopyDisplayMode(display).map(info)
    }

    static func info(_ mode: CGDisplayMode) -> DisplayModeInfo {
        DisplayModeInfo(width: mode.width, height: mode.height, pixelWidth: mode.pixelWidth,
                        pixelHeight: mode.pixelHeight, refreshRate: mode.refreshRate)
    }

    /// Switches the display to `wanted` (an exact match from `all`). Returns false if it isn't offered.
    @discardableResult
    static func set(_ display: CGDirectDisplayID, to wanted: DisplayModeInfo) -> Bool {
        guard let mode = all(display).first(where: { $0.info == wanted })?.mode else { return false }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return false }
        CGConfigureDisplayWithDisplayMode(config, display, mode, nil)
        return CGCompleteDisplayConfiguration(config, .permanently) == .success
    }

    /// The display's own default mode (what System Settings calls "Default for display").
    static func defaultMode(_ display: CGDirectDisplayID) -> DisplayModeInfo? {
        // macOS marks it with the "native/default" flag (kDisplayModeDefaultFlag, 0x4) in ioFlags.
        all(display).first { $0.mode.ioFlags & 0x4 != 0 }?.info
    }
}

/// The Displays menu in the menu bar: a brightness slider per display (down below the display's
/// own lowest setting), and its resolution and refresh rate.
final class DisplayMenu: NSObject {
    var brightness: (String) -> Double = { _ in 1 }
    var setBrightness: (String, Double) -> Void = { _, _ in }
    var notice: (String) -> Void = { _ in }

    struct Screen {
        let id: CGDirectDisplayID
        let uuid: String
        let name: String
    }

    static func screens() -> [Screen] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let id = CGDirectDisplayID(number.uint32Value)
            return Screen(id: id, uuid: Display.uuidString(for: id), name: screen.localizedName)
        }
    }

    func menuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: L("Displays"), action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "display", accessibilityDescription: nil)
        let menu = NSMenu()
        let screens = Self.screens()
        for (index, screen) in screens.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            let header = NSMenuItem(title: screens.count > 1 ? "\(index + 1). \(screen.name)" : screen.name, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(sliderItem(for: screen))
            if let resolution = resolutionItem(for: screen) { menu.addItem(resolution) }
            if let refresh = refreshItem(for: screen) { menu.addItem(refresh) }
        }
        parent.submenu = menu
        return parent
    }

    // MARK: Brightness

    private func sliderItem(for screen: Screen) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 28))
        let low = NSImageView(frame: NSRect(x: 18, y: 6, width: 16, height: 16))
        low.image = NSImage(systemSymbolName: "sun.min", accessibilityDescription: L("Dimmer"))
        let slider = NSSlider(value: brightness(screen.uuid), minValue: EveningMode.minimumBrightness, maxValue: 1,
                              target: self, action: #selector(brightnessChanged(_:)))
        slider.frame = NSRect(x: 38, y: 4, width: 174, height: 20)
        slider.identifier = NSUserInterfaceItemIdentifier(screen.uuid)
        slider.isContinuous = true
        slider.setAccessibilityLabel("\(screen.name) brightness")
        let high = NSImageView(frame: NSRect(x: 216, y: 6, width: 16, height: 16))
        high.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: L("Brighter"))
        view.addSubview(low)
        view.addSubview(slider)
        view.addSubview(high)
        item.view = view
        item.toolTip = "Dims the display in software, on top of its own brightness, so it can go darker than its lowest setting."
        return item
    }

    @objc private func brightnessChanged(_ sender: NSSlider) {
        guard let uuid = sender.identifier?.rawValue else { return }
        setBrightness(uuid, sender.doubleValue)
    }

    /// The display with focus one step brighter or dimmer (10% at a time).
    func step(_ uuid: String, name: String, brighter: Bool) {
        let now = brightness(uuid)
        let next = min(max((now + (brighter ? 0.1 : -0.1)) * 10, EveningMode.minimumBrightness * 10), 10).rounded() / 10
        setBrightness(uuid, next)
        notice("\(name) · \(Int((next * 100).rounded()))% brightness")
    }

    // MARK: Resolution and refresh rate

    private func resolutionItem(for screen: Screen) -> NSMenuItem? {
        let modes = DisplayModes.all(screen.id).map(\.info)
        guard let current = DisplayModes.current(screen.id) else { return nil }
        let sizes = DisplayModeChoice.sizes(modes, current: current)
        guard sizes.count > 1 else { return nil }
        let parent = NSMenuItem(title: "\(L("Resolution")): \(current.sizeTitle)", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        let defaultMode = DisplayModes.defaultMode(screen.id)
        for mode in sizes.reversed() {
            var title = mode.sizeTitle
            if mode.isHiDPI != current.isHiDPI { title += mode.isHiDPI ? " (sharp)" : " (low resolution)" }
            if let defaultMode, defaultMode.width == mode.width, defaultMode.height == mode.height { title += " — Default" }
            let entry = NSMenuItem(title: title, action: #selector(chooseMode(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = Choice(display: screen.id, mode: mode)
            entry.state = mode.width == current.width && mode.height == current.height ? .on : .off
            menu.addItem(entry)
        }
        parent.submenu = menu
        return parent
    }

    private func refreshItem(for screen: Screen) -> NSMenuItem? {
        guard let current = DisplayModes.current(screen.id) else { return nil }
        let rates = DisplayModeChoice.refreshRates(DisplayModes.all(screen.id).map(\.info), current: current)
        guard rates.count > 1 else { return nil }
        let parent = NSMenuItem(title: "\(L("Refresh Rate")): \(current.refreshTitle)", action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for mode in rates {
            let entry = NSMenuItem(title: mode.refreshTitle, action: #selector(chooseMode(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = Choice(display: screen.id, mode: mode)
            entry.state = Int(mode.refreshRate.rounded()) == Int(current.refreshRate.rounded()) ? .on : .off
            menu.addItem(entry)
        }
        parent.submenu = menu
        return parent
    }

    private final class Choice: NSObject {
        let display: CGDirectDisplayID
        let mode: DisplayModeInfo
        init(display: CGDirectDisplayID, mode: DisplayModeInfo) {
            self.display = display
            self.mode = mode
        }
    }

    @objc private func chooseMode(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? Choice else { return }
        if !DisplayModes.set(choice.display, to: choice.mode) { notice("That display mode isn’t available right now") }
    }

    /// "More space", "larger text" or the default, for a display.
    func changeResolution(_ id: CGDirectDisplayID, name: String, action: Action) {
        guard let current = DisplayModes.current(id) else { return }
        let modes = DisplayModes.all(id).map(\.info)
        let target: DisplayModeInfo?
        switch action {
        case .displayMoreSpace: target = DisplayModeChoice.step(from: current, in: modes, moreSpace: true)
        case .displayLargerText: target = DisplayModeChoice.step(from: current, in: modes, moreSpace: false)
        default: target = DisplayModes.defaultMode(id)
        }
        guard let target else {
            notice(action == .displayMoreSpace ? "\(name) is already at its most space" : action == .displayLargerText
                ? "\(name) already has its largest text" : "No default mode for \(name)")
            return
        }
        if target == current { return notice("\(name) is already at \(current.sizeTitle)") }
        if DisplayModes.set(id, to: target) { notice("\(name) · looks like \(target.sizeTitle)") }
    }
}
#endif
