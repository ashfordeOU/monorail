#if os(macOS)
import AppKit
import Combine
import MonorailCore
import SwiftUI

/// First-run tour: grant Accessibility, then learn the easy ways to get around.
/// Remembers which core moves the user has tried, for the practice pad.
final class PracticeTracker: ObservableObject {
    struct Task: Identifiable {
        var id: String { title }
        var title: String
        var actions: Set<Action>
        /// How to do it, shown in the coach card.
        var hint: String
    }

    static let tasks = [
        Task(title: "Slide to another window", actions: [.focusLeft, .focusRight],
             hint: "Tap the right ⌥ key, then press →   (or ⌃⌥→)"),
        Task(title: "Move a window along", actions: [.moveLeft, .moveRight],
             hint: "In slide mode press ⇧→   (or ⌃⌥⇧→)"),
        Task(title: "Change a window’s width", actions: [.cycleWidth, .cycleWidthBackward, .narrower, .wider],
             hint: "In slide mode press R   (or ⌃⌥R)"),
        Task(title: "Fill the screen", actions: [.toggleFullWidth],
             hint: "In slide mode press F   (or ⌃⌥F)"),
        Task(title: "Open the overview", actions: [.overview],
             hint: "In slide mode press O   (or ⌃⌥O)"),
        Task(title: "Dock a window onto another", actions: [.dockLeft, .dockRight, .dockUp, .dockDown],
             hint: "Drag a window by its title bar onto another window’s edge; the middle makes tabs"),
    ]

    /// The first task not done yet.
    var next: Task? { Self.tasks.first { !done.contains($0.id) } }

    @Published private(set) var done: Set<String> = []

    func record(_ action: Action) {
        for task in Self.tasks where task.actions.contains(action) && !done.contains(task.id) {
            done.insert(task.id)
        }
    }
}

struct WelcomeView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var practice: PracticeTracker
    let onFinish: () -> Void
    /// Opens (true) or closes (false) three practice windows to try the moves on.
    var practiceWindows: (Bool) -> Void = { _ in }
    @State private var practising = false
    @State private var trusted = Accessibility.isTrusted(prompt: false)
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Scrolling strip or fit on screen, keeping the slider choice above.
    private var styleBinding: Binding<StartStyle> {
        Binding(
            get: { store.settings.fitByDefault ? .fit : .scrolling },
            set: { style in
                let bar = store.settings.sliderBar
                store.settings.apply(style)
                store.settings.sliderBar = bar
            })
    }

    /// An extra's checkbox, bound to the real setting.
    private func extra(_ item: StarterExtra) -> Binding<Bool> {
        Binding(get: { item.isOn(in: store.settings) }, set: { on in item.set(on, in: &store.settings) })
    }

    /// The extras offered: the ⌘Tab switcher needs the event tap, so not in the App Store edition.
    /// The usage counts aren't asked about here; they're switched off in Settings.
    private var extras: [StarterExtra] {
        StarterExtra.allCases.filter { !(Edition.isAppStore && $0 == .windowSwitcher) && $0 != .usageCounts }
    }

    /// "Pick your extras": one line each, ticked to suit the starter setup chosen above.
    private var extrasStep: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pick your extras").fontWeight(.medium)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: 4) {
                    ForEach(extras, id: \.self) { item in
                        Toggle(item.title, isOn: extra(item)).toggleStyle(.checkbox).font(.callout)
                    }
                }
                HStack(spacing: 12) {
                    Button("Open Trackpad settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .help("Set “Swipe between full-screen apps” to four fingers, so three belong to Monorail.")
                }
                .buttonStyle(.link).controlSize(.small)
                if extra(.swipe).wrappedValue {
                    Text("For the swipe: in Trackpad settings, set “Swipe between full-screen apps” to four fingers.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Change any of these later in Settings.").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
        // Usage counts aren't asked about (they're in Settings and the privacy policy); mark the old notice as done.
        .onAppear { if !store.settings.usageNoticeShown { store.settings.usageNoticeShown = true } }
    }

    private func shortcut(_ action: Action) -> String {
        store.settings.keymap.shortcuts(for: action).first?.displayString ?? "—"
    }

    private func tip(keys: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(keys)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.08)))
                .frame(width: 130, alignment: .leading)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Pages

    /// The tour as pages, one idea each, like a new Apple app: hello, how it works, the one
    /// permission, how you work, try it, and done. Pages slide with a spring; the dots stretch.
    @State private var page = 0
    @State private var forward = true
    @State private var appeared = false
    @State private var breathe = false
    @State private var finished = false
    /// The pages shown: Station (the App Store edition) has no window permission or practice to do.
    private static let pages: [Int] = Edition.isAppStore ? [0, 1, 5] : [0, 1, 2, 3, 4, 5]
    private static var pageCount: Int { pages.count }

    private func go(_ target: Int) {
        guard target != page, (0..<Self.pageCount).contains(target) else { return }
        forward = target > page
        // One turn of the run loop later, so the page leaving slides the right way.
        DispatchQueue.main.async { withAnimation(Motion.page) { page = target } }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                pageView(Self.pages[page])
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            footer
        }
        .padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 22)
        .frame(width: 560, height: 600)
        .onReceive(timer) { _ in trusted = Accessibility.isTrusted(prompt: false) }
    }

    @ViewBuilder private func pageView(_ index: Int) -> some View {
        switch index {
        case 0: hello
        case 1: howItWorks
        case 2: permissionSection
        case 3: ScrollView { VStack(alignment: .leading, spacing: 14) { startSection; extrasStep } }
        case 4: ScrollView { VStack(alignment: .leading, spacing: 14) { aroundSection; practiceSection; keeperSection } }
        default: done
        }
    }

    private var hello: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 24)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.54, blue: 0.36).opacity(0.38), Color(red: 0.91, green: 0.26, blue: 0.48).opacity(0.12), .clear],
                                         center: .center, startRadius: 20, endRadius: 120))
                    .frame(width: 240, height: 240)
                    .scaleEffect(breathe ? 1.06 : 0.94)
                    .opacity(appeared ? 1 : 0)
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 112, height: 112)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)
            }
            .frame(height: 200)
            .accessibilityHidden(true)
            Text("Welcome to \(Brand.name)").font(.system(size: 28, weight: .bold))
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
            Text(Edition.isAppStore
                 ? "Your Mac at a glance from the menu bar: battery, Stay Awake, Evening Mode and what's keeping it busy."
                 : "Your windows ride one strip that runs past the edges of your screen. Nothing you’re using ever shrinks.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(Motion.reduced ? .easeOut(duration: 0.1) : .spring(response: 0.7, dampingFraction: 0.68).delay(0.1)) { appeared = true }
            if !Motion.reduced {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true }
            }
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Here’s how it works").font(.system(size: 26, weight: .bold)).frame(maxWidth: .infinity).padding(.bottom, 6)
            if Edition.isAppStore {
                FeatureRow(symbol: "bolt.fill", tint: Tone.good, title: "Three battery rings",
                           text: "Charge, time left and drain against your usual, with a glow that follows the drain.", delay: 0)
                FeatureRow(symbol: "cup.and.saucer.fill", tint: Tone.warm, title: "Stay Awake",
                           text: "For an hour, until a time, or while something downloads.", delay: 0.08)
                FeatureRow(symbol: "moon.fill", tint: Color(nsColor: .systemIndigo), title: "Evening Mode",
                           text: "A warmer screen at night, on a schedule or by hand.", delay: 0.16)
                FeatureRow(symbol: "rectangle.split.3x1.fill", tint: Color(red: 0.91, green: 0.33, blue: 0.45), title: "Want your windows arranged too?",
                           text: "Monorail, Station’s free big sibling, puts them on one endless strip.", delay: 0.24)
            } else {
                FeatureRow(symbol: "rectangle.split.3x1", tint: Tone.blue, title: "One endless strip",
                           text: "New windows slide in beside you. \(shortcut(.focusLeft)) and \(shortcut(.focusRight)) glide along it.", delay: 0)
                FeatureRow(symbol: "square.grid.2x2.fill", tint: Color(red: 0.91, green: 0.33, blue: 0.45), title: "Everything in one panel",
                           text: "Click the menu bar icon for your windows, battery and switches.", delay: 0.08)
                FeatureRow(symbol: "bolt.fill", tint: Tone.good, title: "Knows your battery",
                           text: "Three rings, and the app to quit when it drains fast.", delay: 0.16)
                FeatureRow(symbol: "sparkles", tint: Color(nsColor: .systemPurple), title: "Just say it",
                           text: "“Slack and Mail side by side.” Press \(shortcut(.commandPalette)) and type.", delay: 0.24)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var done: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Image(systemName: "checkmark").font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Tone.good))
                .shadow(color: Tone.good.opacity(0.35), radius: 14, y: 8)
                .scaleEffect(finished ? 1 : 0.5).opacity(finished ? 1 : 0)
                .accessibilityHidden(true)
            Text("You’re all set").font(.system(size: 28, weight: .bold))
            Text(Edition.isAppStore
                 ? "Station lives in the menu bar. Click its icon for everything; it turns orange while your Mac stays awake."
                 : "Monorail lives in the menu bar. Click its icon for everything; it turns grey while paused and orange while your Mac stays awake.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 380)
            Spacer()
            Button { onFinish() } label: {
                Text(Edition.isAppStore ? "Start Using Station" : trusted ? "Start Using Monorail" : L("Continue without permission")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            finished = false
            withAnimation(Motion.reduced ? .easeOut(duration: 0.1) : .spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { finished = true }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            PageDots(count: Self.pageCount, current: page)
            Spacer()
            if page > 0, page < Self.pageCount - 1 {
                Button("Back") { go(page - 1) }.controlSize(.large)
            }
            if page < Self.pageCount - 1 {
                Button(Self.pages[page] == 2 && !trusted ? L("Continue without permission") : "Continue") { go(page + 1) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(height: 32)
        .padding(.top, 12)
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: trusted ? "checkmark.seal.fill" : "lock.shield")
                        .font(.title2)
                        .foregroundStyle(trusted ? Color.green : Color.orange)
                        .scaleEffect(trusted ? 1 : 0.92)
                        .animation(Motion.pop, value: trusted)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("1. Allow Accessibility")).fontWeight(.medium)
                        Text(
                            trusted
                                ? "Done. Monorail can now arrange your windows."
                                : "macOS needs your permission before any app can move other apps’ windows. Monorail asks for nothing else."
                        )
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        if !trusted {
                            Button(L("Open Accessibility Settings")) {
                                _ = Accessibility.isTrusted(prompt: true)
                                if let url = Accessibility.settingsURL { NSWorkspace.shared.open(url) }
                            }
                            // Switched on but still refused: the entry belongs to an earlier copy.
                            Button("Switched on but still not working? Reset and ask again") {
                                Accessibility.resetAndAsk()
                            }
                            .buttonStyle(.link).font(.callout)
                            Text("A work Mac where only IT can allow it? Carry on without it: Stay Awake, Keep me Available, Evening Mode, the display controls and arranging scriptable apps work straight away. Monorail won’t keep asking.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

        }
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("2. Choose how you see your slides")).fontWeight(.medium)
                    HStack(spacing: 12) {
                        ViewChoice(
                            title: "Slider bar + menu bar icon",
                            detail: "A bar of your slides along the bottom of the screen.",
                            withBar: true,
                            selected: store.settings.sliderBar != .off
                        ) { store.settings.sliderBar = .always }
                        ViewChoice(
                            title: "Menu bar icon only",
                            detail: "Windows reach right down to the Dock. Click the icon for your slides.",
                            withBar: false,
                            selected: store.settings.sliderBar == .off
                        ) { store.settings.sliderBar = .off }
                    }
                    Text("How do you want to start?").fontWeight(.medium).padding(.top, 4)
                    HStack(spacing: 8) {
                        ForEach(StarterSetup.allCases, id: \.self) { setup in
                            Button(setup.title) {
                                let bar = store.settings.sliderBar
                                store.settings.apply(setup)
                                store.settings.applyExtras(for: setup)
                                store.settings.sliderBar = bar
                                if setup == .switching { Importer.run(store: store) }
                            }
                            .help(setup.detail)
                        }
                    }
                    Text(LocalizedStringKey(store.settings.showAllSettings
                         ? "Every setting shows in Settings. Turn off **Show all settings** at the bottom of its sidebar for just the essentials."
                         : "Settings shows the essentials. Turn on **Show all settings** at the bottom of its sidebar for everything."))
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("You can switch any time in Settings → Appearance.")
                        .font(.callout).foregroundStyle(.secondary)
                    Picker("Style", selection: styleBinding) {
                        ForEach([StartStyle.scrolling, .fit], id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(store.settings.fitByDefault ? StartStyle.fit.detail : StartStyle.scrolling.detail)
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

        }
    }

    private var aroundSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("3. Get around")).fontWeight(.medium)
                    tip(
                        keys: store.settings.slideTrigger == .off ? "—" : "tap \(store.settings.slideTrigger.title)",
                        text: "Slide mode. Then just press ← → to slide between windows, ⇧← ⇧→ to move one, R for width, F to fill. Esc when done.")
                    tip(
                        keys: "\(store.settings.scrollModifier.symbols) + scroll",
                        text: "Hold \(store.settings.scrollModifier.symbols) and use the mouse wheel or trackpad. Each wheel notch moves one window.")
                    tip(keys: "menu bar", text: "Scroll over the menu bar, or click ‹ › next to the Monorail icon. No keys needed.")
                    tip(keys: "click", text: "Click any window, even the thin edge of one off-screen, to bring it into view.")
                    tip(keys: shortcut(.overview), text: "Overview: see every slide at once, click one to jump there, drag to rearrange.")
                    Text("Prefer shortcuts? \(shortcut(.focusLeft)) \(shortcut(.focusRight)) focus, \(shortcut(.cycleWidth)) width, \(shortcut(.toggleFullWidth)) fill. All of them can be changed in Settings.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

        }
    }

    private var keeperSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if Companions.keeperDownloadable,
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: Companions.keeper) == nil
            {
                GroupBox {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "square.stack.3d.up").font(.title2).foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Also from Ashforde: Keeper").fontWeight(.medium)
                            Text(Companions.keeperTagline).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("It works with Monorail: one Stay Awake, and its panels are never tiled.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Get Keeper…") {
                            if let url = URL(string: Companions.keeperDownloads) { NSWorkspace.shared.open(url) }
                        }
                    }
                    .padding(6)
                }
            }

        }
    }

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L("4. Practice")).fontWeight(.medium)
                        Spacer()
                        Text("\(practice.done.count) of \(PracticeTracker.tasks.count)")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Text("Open two or three windows, then try each move. They tick off as you go.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button(practising ? L("Close demo windows") : L("Practice with demo windows")) {
                        practising.toggle()
                        practiceWindows(practising)
                    }
                    .help("Three of Monorail’s own windows to practise on, so your real work stays put")
                    ForEach(PracticeTracker.tasks) { task in
                        HStack(spacing: 8) {
                            Image(systemName: practice.done.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(practice.done.contains(task.id) ? Color.green : Color.secondary)
                            Text(task.title)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

        }
    }

}

/// One of the two ways to see your slides, drawn as a little screen.
private struct ViewChoice: View {
    let title: String
    let detail: String
    let withBar: Bool
    let selected: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 8) {
                MiniScreen(withBar: withBar).frame(height: 92)
                HStack(spacing: 6) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    Text(title).fontWeight(.medium)
                }
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(selected ? 0.08 : 0.03)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A sketch of a Mac screen: menu bar, two windows side by side, the Dock,
/// and either the slider bar above the Dock or the menu bar icon's panel.
private struct MiniScreen: View {
    let withBar: Bool

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width, h = geometry.size.height
            let menu: CGFloat = 9, dock: CGFloat = 12, bar: CGFloat = withBar ? 13 : 0, gap: CGFloat = 4
            let windowsTop = menu + gap
            let windowsBottom = h - dock - gap - (withBar ? bar + gap : 0)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.2, green: 0.25, blue: 0.5), Color(red: 0.45, green: 0.2, blue: 0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Rectangle().fill(Color.white.opacity(0.25)).frame(width: w, height: menu)
                // The Monorail icon in the menu bar.
                RoundedRectangle(cornerRadius: 1.5).fill(Color.white)
                    .frame(width: 10, height: 5).offset(x: w * 0.68, y: 2)
                ForEach(0..<2, id: \.self) { i in
                    let width = (w - gap * 3) / 2
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(i == 0 ? 0.9 : 0.75))
                        .frame(width: width, height: windowsBottom - windowsTop)
                        .offset(x: gap + CGFloat(i) * (width + gap), y: windowsTop)
                }
                if withBar {
                    Capsule().fill(Color.black.opacity(0.45))
                        .overlay(HStack(spacing: 3) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(i == 1 ? Color.accentColor : Color.white.opacity(0.5))
                                    .frame(width: 12, height: 6)
                            }
                        })
                        .frame(width: w * 0.62, height: bar)
                        .offset(x: w * 0.19, y: windowsBottom + gap)
                } else {
                    // The slider panel hanging from the icon.
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.6))
                        .overlay(HStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(i == 1 ? Color.accentColor : Color.white.opacity(0.5))
                                    .frame(width: 10, height: 7)
                            }
                        })
                        .frame(width: 62, height: 20)
                        .offset(x: w * 0.68 + 5 - 31, y: menu + 2)
                        .shadow(radius: 3)
                }
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.35))
                    .frame(width: w * 0.5, height: dock - 4).offset(x: w * 0.25, y: h - dock + 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

/// Coach tips: while the welcome tour is open, a card at the bottom of the
/// screen shows the next practice step and how to do it, live.
final class CoachTips {
    private var panel: NSPanel?
    private var subscription: AnyCancellable?

    func start(_ practice: PracticeTracker) {
        let panel = self.panel ?? makePanel(practice)
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
        subscription = practice.$done.receive(on: DispatchQueue.main).sink { [weak self] done in
            guard done.count == PracticeTracker.tasks.count else { return }
            // All done: let the card say so, then go.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self?.stop() }
        }
    }

    func stop() {
        subscription = nil
        panel?.orderOut(nil)
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let size = NSSize(width: 560, height: 92)
        panel.setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.minY + 90, width: size.width, height: size.height), display: true)
    }

    private func makePanel(_ practice: PracticeTracker) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 92),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: CoachView(practice: practice))
        return panel
    }

    private struct CoachView: View {
        @ObservedObject var practice: PracticeTracker

        var body: some View {
            let total = PracticeTracker.tasks.count
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color(red: 0.96, green: 0.38, blue: 0.44))
                    if let next = practice.next, let index = PracticeTracker.tasks.firstIndex(where: { $0.id == next.id }) {
                        Text("\(index + 1)/\(total)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    } else {
                        Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    if let next = practice.next {
                        Text("Try it: \(next.title.lowercased())").font(.system(size: 15, weight: .semibold))
                        Text(next.hint).font(.system(size: 13)).foregroundStyle(.secondary)
                    } else {
                        Text("All done. You’re ready to slide!").font(.system(size: 15, weight: .semibold))
                        Text("Every shortcut is in the menu bar under Keyboard Shortcuts.").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(width: 560, height: 92)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .animation(.easeOut(duration: 0.2), value: practice.done)
        }
    }
}
#endif
