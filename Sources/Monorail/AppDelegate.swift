#if os(macOS)
import AppKit
import Combine
import MonorailCore
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = SettingsStore()
    private lazy var engine = Engine(settings: store.settings)
    /// Keeper (or another Ashforde app) that said hello through the local API.
    private var peer: PeerHello? {
        didSet {
            guard peer != oldValue else { return }
            if let peer, Companions.isKeeper(peer.bundleID) { SuiteRole.shared.setKeeper(peer) }
        }
    }
    /// The peer, while it's still running.
    private var activePeer: PeerHello? {
        guard let peer, let app = NSRunningApplication(processIdentifier: peer.pid), !app.isTerminated,
            app.bundleIdentifier == peer.bundleID
        else { return nil }
        return peer
    }
    private let input = InputMonitor()
    private let trackpad = TrackpadSwipe.shared
    private let switcher = SwitcherController()
    private let switcherGrid = WindowSwitcherGrid()
    private let displayMenu = DisplayMenu()
    /// True while Monorail's switcher has ⌘Tab (the macOS app switcher is off).
    private var commandTabTaken = false
    private lazy var overview = OverviewController(engine: engine)
    private let updater = Updater()
    private var subscriptions: [AnyCancellable] = []
    private let practice = PracticeTracker()
    private let sliderBar = SliderBarController()
    private let resizeAssist = ResizeAssist()
    private let toast = Toast()
    private let hotEdges = HotEdges()
    private let coach = CoachTips()
    private let popover = SliderPopover()
    private let snapPicker = SnapPicker()
    private let palette = CommandPalette()
    private let stats = UsageStats()
    private let autoRules = AutoRules()
    private let pictureInPicture = PictureInPicture()
    private let radial = RadialMenu()
    private let resizeHUD = ResizeHUD()
    private let integrations = Integrations()
    private let hints = WindowHints()
    private let stripZoom = StripZoom()
    private let meetings = MeetingHelper()
    private let api = LocalAPI()
    private let scripts = ScriptHost()
    private var resizeModeTimer: Timer?
    private let cheatSheet = CheatSheet()
    private let workspaceHUD = WorkspaceHUD()
    private var demoWindows: [NSWindow] = []
    private var statsTimer: Timer?
    private var apiStarted = false
    private var capsLockOn = false
    private let whatsNew = WhatsNew()
    private let weekly = WeeklySummary()
    private let pomodoro = Pomodoro()
    private let breakReminder = BreakReminder()
    private let focusFlash = FocusFlash()
    private let pointerLocator = PointerLocator()
    private let hotCorners = HotCorners()
    private let remoteCommands = RemoteCommands()
    private var pomodoroText: String?
    private var focusMinuteTimer: Timer?
    private let deepWork = DeepWork()
    private let shareWatch = ScreenShareWatch()
    private let workspaceClipboard = WorkspaceClipboard()
    private let drift = WallpaperDrift()
    private let notchHUD = NotchHUD()
    private let crashReporter = CrashReporter()
    private let calendarFocus = CalendarFocus()
    private let midi = MIDIControl()
    private let gamepad = GameControllerInput()
    // Made the first time they're used (most people never touch them), so launch stays light.
    private lazy var voice: VoiceCommands = {
        let voice = VoiceCommands()
        voice.onState = { [weak self] text in self?.toast.show(text) }
        voice.onText = { [weak self] text in self?.say(text) }
        return voice
    }()
    private var headFocusMade = false
    private lazy var headFocus: HeadFocus = {
        self.headFocusMade = true
        let head = HeadFocus()
        head.onTurn = { [weak self] _ in self?.engine.perform(.focusNextDisplay) }
        return head
    }()
    private var webRemoteMade = false
    private lazy var webRemote: WebRemote = {
        self.webRemoteMade = true
        let remote = WebRemote()
        remote.perform = { [weak self] name in if let action = Action(rawValue: name) { self?.engine.perform(action) } }
        remote.status = { [weak self] in
            guard let status = self?.engine.status() else { return "" }
            return "Workspace \(status.workspace) · slide \(status.focusedColumn) of \(status.columnCount)"
        }
        return remote
    }()
    private var pairSyncMade = false
    private lazy var pairSync: PairSync = {
        self.pairSyncMade = true
        let sync = PairSync()
        sync.onStatus = { [weak self] text in self?.toast.show(text) }
        sync.onLayout = { [weak self] json in _ = self?.engine.applyLayoutJSON(json) }
        return sync
    }()
    private lazy var slideShare = ScreenMirror()
    private lazy var windowMirror = ScreenMirror()
    private lazy var demoLens = ScreenMirror()
    private let annotation = AnnotationOverlay()
    private let keystrokes = KeystrokeOverlay()
    private let presenterNotesPanel = PresenterNotes()
    private lazy var cameraTile = CameraTile()
    private var timelineWindow: NSWindow?
    private var safeMode = false
    private var guestOn = false
    private var vimText: String?
    private var midiLearn: ((Int) -> Void)?
    private var budgetWarned: Set<String> = []
    private var budgetTimer: Timer?
    private var lastSyncSent = Date.distantPast
    private var lastStatusSignature = ""
    private var seenHandoffs: Set<String> = []
    private var notesSave: DispatchWorkItem?
    private var dimMonitor: Any?
    private let awake = StayAwake()
    private let scriptable = ScriptableArranger()
    private let evening = EveningLight()
    let usage = UsageLog()
    private let telemetry = Telemetry()
    private let dockPreview = DockPreview()
    private let gapHandles = GapHandles()
    private var awakeTicker: Timer?
    /// Every 4 s while you're at the Mac, every 16 s while you're away.
    private var barAsidePoller = RestingPoller(every: 4)
    private var barAsideTimer: Timer?
    private var scriptsOn = false
    private let statusMenu = NSMenu()
    private let navigation = SettingsNavigation()
    private var statusItem: NSStatusItem!
    private var arrowItems: [NSStatusItem] = []
    private let slideHUD = SlideHUD()
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var permissionTimer: Timer?
    private var mouseMonitor: Any?
    private var signalSources: [DispatchSourceSignal] = []

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1
        {
            // Another copy is running; let it handle things.
            NSApp.terminate(nil)
            return
        }
        BundleIDs.migrateIfNeeded()

        // The main thread never waits long on a busy app; window moves run in
        // the background with their own, longer allowance (see WindowWriter).
        Accessibility.setGlobalTimeout(0.25)
        // Hold ⌥ while Monorail starts for safe mode.
        safeMode = NSEvent.modifierFlags.contains(.option)
        setUpStatusItem()
        wireUp()
        handleTerminationSignals()

        // Everything that doesn't move other apps' windows starts now, with or without Accessibility.
        startEssentials()
        if Edition.isAppStore {
            // Signalbox: the App Store's sandbox doesn't let apps move other apps' windows, so no
            // window engine and no Accessibility request. Everything else starts as usual.
        } else if Accessibility.isTrusted(prompt: false) {
            startEngine()
        } else {
            waitForPermission()
        }
        if UITest.isRequested {
            runUITest()
            return
        }
        // The tour opens on a first run only: without Accessibility, the menu says what's
        // needed instead of asking again at every launch.
        if !store.settings.hasCompletedOnboarding {
            showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stats.save()
        // Nothing stays frozen after Monorail quits.
        PowerWatch.shared.resumeAll()
        // Give Caps Lock back to macOS while Monorail isn't running.
        if store.settings.capsLockKey { CapsLockKey.set(false) }
        sliderBar.hideAll(animated: false)
        input.stop()
        trackpad.stop()
        engine.shutdown()
        usage.awake(false)
        awake.shutdown()
        evening.restore()
        if commandTabTaken { NativeCommandTab.setEnabled(true) }
        usage.save()
        EventStream.shared.stop()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.isFileURL {
            openSharedFile(url)
        }
        for url in urls where !url.isFileURL {
            // monorail://layout/Coding, pair/…, snapshot/…, profile/…, workspace/2, launch/t
            let argument = url.pathComponents.dropFirst().joined(separator: "/").removingPercentEncoding ?? ""
            switch url.host?.lowercased() {
            case "settings": showSettings()
            case "welcome": showWelcome()
            case "palette": palette.show()
            case "panel":
                // monorail://panel opens (or closes) the menu bar panel; monorail://panel/battery opens a page of it.
                if let button = statusItem?.button {
                    let pages: [String: PanelPage] = ["battery": .battery, "clipboard": .clipboard, "system": .system, "storage": .storage,
                                                      "today": .today, "network": .network, "focus": .focus, "awake": .awake, "evening": .evening, "film": .film]
                    popover.toggle(relativeTo: button, page: pages[argument.lowercased()] ?? .home)
                }
            case "dashboard":
                // monorail://dashboard opens the Dashboard; monorail://dashboard/ai-usage (or time, switches…) opens that page.
                let wanted = argument.lowercased().replacingOccurrences(of: "-", with: " ")
                if let section = DashboardSection.allCases.first(where: { $0.rawValue.lowercased() == wanted || "\($0)".lowercased() == wanted }) {
                    UserDefaults.standard.set(section.rawValue, forKey: "DashboardSection")
                }
                DashboardWindow.shared.show()
            case "layout": engine.applyLayout(named: argument)
            case "snapshot": engine.restoreSnapshot(named: argument)
            case "save-snapshot": engine.saveSnapshot(named: argument.isEmpty ? Self.snapshotName() : argument)
            case "pair":
                if let pair = store.settings.appPairs.first(where: { $0.name.caseInsensitiveCompare(argument) == .orderedSame }) {
                    engine.openPair(pair)
                }
            case "profile":
                if let index = store.settings.profiles.firstIndex(where: { $0.caseInsensitiveCompare(argument) == .orderedSame })
                    ?? Int(argument).map({ $0 - 1 })
                {
                    engine.switchProfile(to: index)
                }
            case "workspace":
                if let n = Int(argument) { engine.switchWorkspace(to: n - 1) }
            case "launch": engine.quickLaunch(argument)
            case "template":
                if let template = store.settings.templates.first(where: { $0.name.caseInsensitiveCompare(argument) == .orderedSame }) {
                    engine.runTemplate(template)
                }
            case "presentation-mode" where argument == "on" || argument == "off":
                engine.setPresenting(argument == "on", byPeer: PeerHello.isFromKeeper(url))
            case "focus-mode" where argument == "on" || argument == "off":
                engine.setFocusMode(argument == "on", byPeer: PeerHello.isFromKeeper(url))
            case "focus-app":
                // monorail://focus-app/Safari: the app's most recent window.
                if let window = engine.allWindowSummaries().first(where: {
                    $0.appName.caseInsensitiveCompare(argument) == .orderedSame
                }) {
                    engine.focusAndReveal(window.id)
                } else if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: argument) {
                    NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
                }
            case "notify": toast.show(argument)
            case "import": importLink(url.pathComponents.dropFirst().joined(separator: "/"))
            case "awake":
                // monorail://awake (toggle), awake/on, awake/off, awake/90 (minutes), awake/downloading
                let fromKeeper = PeerHello.isFromKeeper(url)
                switch argument.lowercased() {
                case "", "toggle": awake.toggle()
                case "on": awake.start(minutes: store.settings.awakeDefaultMinutes, fromPeer: fromKeeper)
                case "off": awake.end()
                case "downloading": awake.start(.whileDownloading)
                default: if let minutes = Int(argument) { awake.start(minutes: minutes, fromPeer: fromKeeper) }
                }
            case "pomodoro": performAppAction(.pomodoro)
            default:
                if let action = Action(url: url.absoluteString) {
                    engine.perform(action)
                } else {
                    log.error("Unknown URL: \(url.absoluteString)")
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func wireUp() {
        store.onChange = { [weak self] settings in self?.apply(settings) }
        store.onRecordingChange = { [weak self] recording in self?.input.isSuspended = recording }

        engine.onStateChange = { [weak self] in
            guard let self else { return }
            if let status = self.engine.status() { self.usage.noteFocus(workspace: status.workspace, column: status.focusedColumn) }
            self.integrations.update({ [weak self] in self?.currentState() }, settings: self.store.settings)
            self.updateStatusItem()
            self.sliderBar.update()
            self.popover.refresh()
        }
        popover.mapProvider = { [weak self] in
            guard let maps = self?.engine.miniMaps(), !maps.isEmpty else { return nil }
            let mouse = NSEvent.mouseLocation
            return maps.first { map in
                map.screenFrame.minX <= mouse.x && mouse.x < map.screenFrame.maxX
            } ?? maps.first
        }
        popover.controls = SliderPopover.Controls(
            isPaused: { [weak self] in self?.engine.isPaused ?? false },
            resetPairs: { [weak self] in self?.engine.perform(.regroup) },
            togglePause: { [weak self] in self?.engine.togglePause() },
            openSettings: { [weak self] in self?.showSettings() },
            isEveningOn: { [weak self] in self?.evening.isOn ?? false },
            openEveningSettings: { [weak self] in self?.showEveningSettingsFromMenu() },
            awake: SliderPopover.AwakeControls(
                isOn: { [weak self] in self?.awake.isOn ?? false },
                status: { [weak self] in self?.awake.statusText ?? "Off" },
                start: { [weak self] minutes in self?.awake.start(minutes: minutes) },
                startWhileDownloading: { [weak self] in self?.awake.start(.whileDownloading) },
                end: { [weak self] in self?.awake.end() },
                toggleKeepAvailable: { [weak self] in self?.toggleKeepAvailableFromMenu() },
                toggleClosedLid: { [weak self] in self?.toggleAwakeLidFromMenu() },
                refresh: { [weak self] in self?.awake.refresh() },
                openSettings: { [weak self] in self?.showAwakeSettingsFromMenu() }),
            more: SliderPopover.MoreControls(
                layouts: { [weak self] in self?.engine.layouts.map(\.name) ?? [] },
                snapshots: { [weak self] in self?.engine.snapshots.map(\.name) ?? [] },
                applyLayout: { [weak self] name in self?.engine.applyLayout(named: name) },
                restoreSnapshot: { [weak self] name in self?.engine.restoreSnapshot(named: name) },
                takeSnapshot: { [weak self] in self?.engine.perform(.takeSnapshot) },
                isFocusOn: { [weak self] in self?.engine.isFocusMode ?? false },
                toggleFocus: { [weak self] in self?.engine.perform(.toggleFocusMode) },
                clashCount: { [weak self] in
                    guard let self else { return 0 }
                    let hotkeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
                    return self.store.settings.keymap.clashes(with: SystemShortcuts.parse(hotkeys)).count
                },
                openShortcuts: { [weak self] in
                    self?.navigation.tab = .shortcuts
                    self?.showSettings()
                },
                pausedForStageManager: { [weak self] in self?.pausedForStageManager ?? false },
                openPowerSettings: { [weak self] in
                    self?.navigation.tab = .apps
                    self?.showSettings()
                },
                showOverview: { [weak self] in self?.overview.show() },
                openPalette: { [weak self] in self?.palette.show() },
                statusExtra: { [weak self] in self?.statusExtra })
        )
        popover.store = store
        sliderBar.stepAside = { [weak self] frame in
            guard let self, self.store.settings.sliderBarStepsAside else { return false }
            return BarAside.shouldHide(frame)
        }
        // Check again when apps change, and now and then while a bar is always shown (videos start and stop).
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.sliderBar.update() }
        }
        barAsideTimer = Timer.every(4) { [weak self] _ in
            guard let self, self.store.settings.sliderBarStepsAside, self.store.settings.sliderBar == .always,
                !self.barAsidePoller.shouldSkip()
            else { return }
            self.sliderBar.update()
        }
        sliderBar.mapsProvider = { [weak self] in
            guard let self, !self.engine.isPresenting else { return [] }
            return self.engine.miniMaps()
        }
        sliderBar.actions = SliderBarController.Actions(
            slide: { [weak self] x, uuid in self?.engine.slide(to: x, displayUUID: uuid) },
            endSlide: { [weak self] in self?.engine.endSlide() },
            focus: { [weak self] id in
                self?.engine.endPeek(keep: true)
                self?.engine.focusAndReveal(id)
            },
            switchWorkspace: { [weak self] index in self?.engine.switchWorkspace(to: index) },
            showOverview: { [weak self] in self?.overview.show() }
        )
        let commands = windowCommands()
        sliderBar.actions.commands = commands
        sliderBar.actions.renameWorkspace = { [weak self] index in self?.overview.showRenaming(index) }
        sliderBar.actions.peek = { [weak self] column, uuid in self?.engine.peek(column: column, displayUUID: uuid) }
        sliderBar.actions.endPeek = { [weak self] in self?.engine.endPeek() }
        sliderBar.actions.park = { [weak self] index in self?.engine.parkWorkspace(index) }
        sliderBar.actions.unpark = { [weak self] index in self?.engine.unparkWorkspace(index) }
        overview.commands = commands
        overview.setWorkspaceName = { [weak self] index, name in
            self?.store.settings.setWorkspaceName(name, at: index)
        }
        overview.setWorkspaceNote = { [weak self] index, note in
            let trimmed = note.trimmingCharacters(in: .whitespaces)
            self?.store.settings.workspaceNotes[String(index)] = trimmed.isEmpty ? nil : trimmed
        }
        overview.toggleFit = { [weak self] key in
            guard let self else { return }
            self.store.settings.setFit(!self.store.settings.isFit(key.workspace), for: key.workspace)
        }
        popover.actions = sliderBar.actions
        updater.$available
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &subscriptions)
        popover.updater = updater
        updater.showUpdate = { [weak self] in
            guard let self, let button = self.statusItem?.button else { return }
            self.popover.toggle(relativeTo: button, page: .whatsNew)
        }
        engine.onShowSwitcher = { [weak self] in self?.switcher.toggle() }
        engine.onShowOverview = { [weak self] in self?.overview.toggle() }
        engine.onNotice = { [weak self] text in
            guard let self, !self.engine.isPresenting, !self.store.settings.quietMode, !MomentsWatch.shared.film else { return }
            self.toast.show(text)
        }
        engine.onAdjustSettings = { [weak self] change in
            guard let self else { return }
            var settings = self.store.settings
            change(&settings)
            self.store.settings = settings
        }
        engine.onWorkspaceShown = { [weak self] name, index, count in
            guard let self, self.store.settings.workspaceHUD, !self.engine.isPresenting else { return }
            self.workspaceHUD.show(name: name, note: self.engine.workspaceNote(index), index: index, count: count)
        }
        engine.onAskForSlideName = { [weak self] id, current in self?.askForSlideName(id, current: current) }
        engine.onCheatSheet = { [weak self] in self?.cheatSheet.toggle() }
        engine.onAnnounce = { [weak self] text in
            guard self?.store.settings.announceChanges == true else { return }
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                                 userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
        cheatSheet.keymap = { [weak self] in self?.store.settings.keymap ?? .default }
        input.onKeyActivity = { [weak self] in self?.cheatSheet.keyWasPressed() }
        NotificationCenter.default.addObserver(forName: .monorailCopyDiagnostics, object: nil, queue: .main) { [weak self] _ in
            self?.copyDiagnostics()
        }
        NotificationCenter.default.addObserver(forName: .monorailForgetWholeSlideApp, object: nil, queue: .main) { [weak self] note in
            if let app = note.object as? String { self?.engine.forgetWholeSlideApp(app) }
        }
        WholeSlideApps.list = { [weak self] in self?.engine.wholeSlideApps ?? [] }
        engine.onWindowHints = { [weak self] in self?.showHints() }
        engine.onResizeMode = { [weak self] on in self?.setResizeMode(on) }
        engine.onStripZoom = { [weak self] in self?.stripZoom.toggle() }
        engine.onWindowOpened = { [weak self] id, app, title in
            self?.usage.windowManaged()
            self?.scripts.emit("windowOpened", ["id": Int(id), "app": app, "title": title])
        }
        stripZoom.mapProvider = { [weak self] in
            guard let maps = self?.engine.miniMaps(), !maps.isEmpty else { return nil }
            let mouse = NSEvent.mouseLocation
            return maps.first { $0.screenFrame.minX <= mouse.x && mouse.x < $0.screenFrame.maxX } ?? maps.first
        }
        stripZoom.focus = { [weak self] id in self?.engine.focusAndReveal(id) }
        input.onPinchProgress = { [weak self] total, ended in self?.stripZoom.pinch(total, ended: ended) }
        trackpad.onVerticalSwipe = { [weak self] up in self?.engine.switchWorkspaceVertically(next: up) }
        meetings.onMeeting = { [weak self] title, link in self?.joinMeeting(title, link) }
        api.handler = { [weak self] method, path, body in self?.handleAPI(method, path, body) }
        api.allowAgentChange = { [weak self] path, body in self?.agentMayChange(path, body) ?? false }
        scripts.bridge = scriptBridge()
        NotificationCenter.default.addObserver(forName: .monorailReloadScripts, object: nil, queue: .main) { [weak self] _ in
            self?.reloadScripts()
        }
        NotificationCenter.default.addObserver(forName: .monorailRunTemplate, object: nil, queue: .main) { [weak self] note in
            guard let self, let id = note.object as? String,
                let template = self.store.settings.templates.first(where: { $0.id == id })
            else { return }
            self.engine.runTemplate(template)
        }
        engine.onAskForLetter = { [weak self] action in self?.readMarkLetter(for: action) }
        engine.onShowPalette = { [weak self] in self?.palette.toggle() }
        engine.onAskForSnapshotName = { [weak self] in self?.takeSnapshot() }
        engine.onUsage = { [weak self] event in self?.stats.record(event) }
        engine.onLayoutsSaved = { [weak self] in
            if self?.store.settings.syncThroughICloud == true { self?.store.pushToCloud() }
        }
        engine.onPictureInPicture = { [weak self] id in self?.showPictureInPicture(id) }
        store.onLayoutsChanged = { [weak self] in self?.engine.reloadLayouts() }
        palette.commands = { [weak self] in self?.paletteCommands() ?? [] }
        stats.onSuggestion = { [weak self] pair in
            let names = pair.split(separator: "|").map { UsageStats.appName(String($0)) }.joined(separator: " + ")
            self?.toast.show("You often use \(names) together · save them as an app pair in Settings → Insights")
        }
        autoRules.fire = { [weak self] rule in self?.run(rule) }
        pictureInPicture.focus = { [weak self] id in self?.engine.focusAndReveal(id) }
        pictureInPicture.onNeedsPermission = { [weak self] in
            self?.toast.show("Picture in picture needs Screen Recording · turn on live previews in the overview")
        }
        trackpad.onThreeFingerTap = { [weak self] in self?.overview.toggle() }
        radial.preview = { [weak self] position in self?.engine.snapPreview(position) }
        radial.apply = { [weak self] position in self?.engine.snapFocused(position) }
        engine.onRadialMenu = { [weak self] in self?.radial.toggle() }
        engine.onResizeHUD = { [weak self] frame in self?.resizeHUD.show(frame) }
        engine.onShowAppOverview = { [weak self] app in
            let name = self?.engine.allWindowSummaries().first { $0.id == self?.engine.focusedWindowID() }?.appName
            self?.overview.show(onlyApp: app, appName: name)
        }
        input.onFlagsChanged = { [weak self] modifiers in
            guard let self else { return }
            self.radial.modifiersChanged(modifiers)
            self.cheatSheet.modifiersChanged(modifiers, enabled: self.store.settings.cheatSheetOnHold && !self.radial.isShown)
        }
        input.onDragBegin = { [weak self] point, resize in self?.engine.beginModifierDrag(at: point, resize: resize) ?? false }
        input.onDragMove = { [weak self] point in self?.engine.continueModifierDrag(to: point) }
        input.onDragEnd = { [weak self] in self?.engine.endModifierDrag() }
        input.titleBarWindow = { [weak self] point in self?.engine.titleBarWindow(at: point) }
        input.onTitleBarSwipe = { [weak self] swipe, id in self?.engine.titleBarSwipe(swipe, on: id) }
        engine.onWindowDrag = { [weak self] id in self?.snapPicker.windowDragStarted(id) }
        snapPicker.snap = { [weak self] id, position, point in self?.engine.snapWindow(id, to: position, at: point) }
        snapPicker.isFloating = { [weak self] id in self?.engine.isFloating(id) ?? false }
        snapPicker.gap = { [weak self] in self?.store.settings.layout.gap ?? 8 }
        engine.onResized = { [weak self] id, frame, name, hasOthers in
            self?.resizeAssist.show(for: id, frame: frame, appName: name, hasOthers: hasOthers)
        }
        resizeAssist.actions = ResizeAssist.Actions(
            ownSlide: { [weak self] id in self?.engine.giveOwnSlide(id) },
            othersOut: { [weak self] id in self?.engine.moveOthersOut(keeping: id) },
            undo: { [weak self] in self?.engine.undo() }
        )

        input.isPaused = { [weak self] in self?.engine.isPaused ?? false }
        input.onAction = { [weak self] action in
            self?.practice.record(action)
            self?.engine.perform(action)
        }
        input.onScroll = { [weak self] delta in self?.engine.swipe(by: delta) }
        input.onScrollEnd = { [weak self] in self?.engine.endSwipe() }
        input.onStep = { [weak self] forward in self?.engine.step(forward: forward) }
        input.isOverMenuBar = { [weak self] point in
            // Scrolling over the menu bar or a visible slider bar slides the strip.
            guard !Self.isOverMenuBar(point) else { return true }
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            return self?.sliderBar.contains(CGPoint(x: point.x, y: primaryHeight - point.y)) ?? false
        }
        input.onPinch = { [weak self] open in
            if open { self?.overview.show() } else { self?.overview.close() }
        }
        input.onSlideModeChange = { [weak self] on in
            if on { self?.slideHUD.show() } else { self?.slideHUD.hide() }
        }

        trackpad.onScroll = { [weak self] fraction in
            guard let self else { return }
            // Map trackpad-width fractions to roughly a screen's width per full swipe.
            let width = Double(NSScreen.main?.visibleFrame.width ?? 1440)
            self.engine.swipe(by: -fraction * width * 1.5)
        }
        trackpad.onEnd = { [weak self] in self?.engine.endSwipe() }

        switcher.windows = { [weak self] in self?.engine.allWindowSummaries() ?? [] }
        switcher.choose = { [weak self] id in self?.engine.focusAndReveal(id) }
        wireUpDesktopTools()
        wireUpV11()
        wireUpV12()
    }

    // MARK: - 1.2

    private func wireUpV12() {
        engine.onAgentWaiting = { [weak self] id, app in
            guard let self else { return }
            self.tipOnce("agent", "you can turn agent alerts off, or have the agent's slide come into view, in Settings → Smart")
            self.toast.show("\(app): an agent is waiting for you · ⌃⌥/ then “agent”")
            NSSound(named: "Glass")?.play()
            self.postWebhook("agent_waiting", ["id": Int(id), "app": app])
        }
        engine.onDocked = { [weak self] in self?.practice.record(.dockRight) }
        engine.onDockPreview = { [weak self] rect, edge in self?.dockPreview.show(rect, edge: edge) }
        gapHandles.handles = { [weak self] in self?.engine.gapHandles() ?? [] }
        gapHandles.drag = { [weak self] handle, delta, ended in self?.engine.dragGap(handle, by: delta, ended: ended) }
        engine.onOverlaysUpdated = { [weak self] in self?.gapHandles.refresh() }
        engine.onRuleSuggestion = { [weak self] name, bundle, width in
            guard let self else { return }
            var settings = self.store.settings
            settings.suggestedRules[bundle] = width
            self.store.settings = settings
            self.toast.show("You keep giving \(name) \(Self.widthName(width)) · make it a rule in Settings → Smart")
        }
        engine.onFloatSuggestion = { [weak self] name, bundle in self?.suggestFloat(name, bundle) }
        SmartBridge.showUsagePayload = { [weak self] in self?.showUsagePayload() }
        engine.onDistraction = { [weak self] count in
            self?.toast.show("\(count) switches in five minutes · try focus mode (⌃⌥B) or deep work")
        }
        engine.onRunShortcut = { name in ShortcutRunner.run(name) }
        let previousStateChange = engine.onStateChange
        engine.onStateChange = { [weak self] in
            previousStateChange()
            self?.stateChangedV12()
        }
        palette.dynamic = { [weak self] query in self?.dynamicCommands(query) ?? [] }
        SmartBridge.remoteURL = { [weak self] in self?.webRemoteMade == true ? self?.webRemote.url : nil }
        SmartBridge.remoteQR = { [weak self] in self?.webRemoteMade == true ? self?.webRemote.qrCode() : nil }
        SmartBridge.learnMIDINote = { [weak self] handler in
            self?.midiLearn = handler
            self?.toast.show("Press a pad or key on your MIDI controller")
        }
        SmartBridge.acceptSuggestion = { [weak self] bundle in self?.acceptSuggestion(bundle) }
        deepWork.apps = { [weak self] in self?.store.settings.deepWorkApps ?? [] }
        deepWork.onChange = { [weak self] on in
            guard let self else { return }
            if on != self.engine.isFocusMode { self.engine.setFocusMode(on) }
            self.toast.show(on ? "Deep work · distracting apps stay hidden until it ends" : "Deep work over · welcome back")
            self.postWebhook(on ? "deep_work_on" : "deep_work_off", [:])
            self.updateStatusItem()
        }
        deepWork.onBlocked = { [weak self] app in self?.toast.show("\(app) waits until deep work ends") }
        shareWatch.onChange = { [weak self] sharing in
            guard let self else { return }
            Switchboard.shared.sharingChanged()
            guard self.store.settings.safeScreenShare else { return }
            self.engine.setPrivateHidden(sharing)
            if sharing { self.toast.show("You’re sharing your screen · private windows are out of sight") }
            self.postWebhook(sharing ? "screen_share_on" : "screen_share_off", [:])
        }
        workspaceClipboard.currentWorkspace = { [weak self] in self?.engine.status().map { $0.workspace - 1 } }
        calendarFocus.onFocusEvent = { [weak self] until in self?.deepWork.start(until: until) }
        midi.onNote = { [weak self] note in
            guard let self else { return }
            if let learn = self.midiLearn {
                self.midiLearn = nil
                learn(note)
                return
            }
            if let name = self.store.settings.midiMap[String(note)], let action = Action(rawValue: name) { self.engine.perform(action) }
        }
        gamepad.perform = { [weak self] action in self?.engine.perform(action) }
        presenterNotesPanel.text = { [weak self] in self?.store.settings.presenterNotes ?? "" }
        presenterNotesPanel.save = { [weak self] text in
            self?.notesSave?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                var settings = self.store.settings
                settings.presenterNotes = text
                self.store.settings = settings
            }
            self?.notesSave = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
        }
        input.onKeyEcho = { [weak self] key in self?.keystrokes.show(key: key) }
        input.onVimChange = { [weak self] on, pending in self?.vimChanged(on, pending) }
        input.onMouseGesture = { [weak self] dx, dy in self?.mouseGesture(dx, dy) }
        NotificationCenter.default.addObserver(forName: .monorailNeedsScreenRecording, object: nil, queue: .main) { [weak self] _ in
            self?.toast.show("Sharing, mirroring and zoom need Screen Recording · turn on live previews in the overview")
        }
        store.onLayoutsChanged = { [weak self] in
            self?.engine.reloadLayouts()
            self?.checkHandoff()
        }
        budgetTimer = Timer.every(60) { [weak self] _ in self?.checkBudgets() }
        if safeMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.toast.show("Safe mode · rules, scripts and automations are off until Monorail restarts")
            }
        }
        if StageManagerCheck.isOn && !store.settings.pauseForStageManager {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.toast.show("Stage Manager is on as well · turn it off in Control Centre so Monorail can arrange windows")
            }
        }
        watchStageManager()
        PowerWatch.shared.onNotice = { [weak self] text in self?.toast.show(text) }
        PowerWatch.shared.onChange = { [weak self] in self?.sliderBar.update() }
        PowerWatch.shared.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.checkNotch() }
        watchDormancy()
        wireUpAwake()
    }

    // MARK: Battery in the menu bar

    private var batteryItem: NSStatusItem?
    private var batteryWatch: AnyCancellable?

    private func updateBatteryItem(_ on: Bool) {
        guard on else {
            if let item = batteryItem { NSStatusBar.system.removeStatusItem(item) }
            batteryItem = nil
            batteryWatch = nil
            return
        }
        guard batteryItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggleBatteryPanel)
        item.button?.toolTip = "Battery: charge, time left and which apps use it"
        batteryItem = item
        refreshBatteryItem()
        batteryWatch = PowerWatch.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshBatteryItem() }
        }
    }

    private func refreshBatteryItem() {
        guard let button = batteryItem?.button else { return }
        let power = PowerWatch.shared
        let hot = !power.hungry.isEmpty
        button.image = NSImage(systemSymbolName: hot ? "bolt.fill" : (power.battery.isCharging ? "battery.100.bolt" : "bolt"),
                               accessibilityDescription: "Battery")
        button.imagePosition = .imageLeading
        var title = " \(power.battery.percent)%"
        if power.battery.onBattery, let minutes = power.battery.minutesAtCurrentRate { title += " · \(BatteryState.duration(minutes))" }
        button.title = title
        button.contentTintColor = hot ? .systemOrange : nil
    }

    /// ⚡ opens the same Monorail panel, straight at its Battery page: one panel, never two.
    @objc private func toggleBatteryPanel() {
        guard let button = batteryItem?.button else { return }
        popover.toggle(relativeTo: button, page: .battery)
    }

    // MARK: Stage Manager

    private var stageManagerTimer: Timer?
    private var pausedForStageManager = false

    /// While Stage Manager is on, Monorail pauses (windows stay where they are) and
    /// carries on by itself when it's turned off. Checked every few seconds.
    private func watchStageManager() {
        stageManagerTimer?.invalidate()
        stageManagerTimer = nil
        guard store.settings.pauseForStageManager else {
            if pausedForStageManager {
                pausedForStageManager = false
                engine.setPaused(false)
            }
            return
        }
        checkStageManager()
        let timer = Timer.every(4) { [weak self] _ in self?.checkStageManager() }
        timer.tolerance = 1
        stageManagerTimer = timer
    }

    private func checkStageManager() {
        let on = StageManagerCheck.isOn
        if on, !pausedForStageManager, !engine.isPaused {
            pausedForStageManager = true
            engine.setPaused(true)
            toast.show("Stage Manager is on · Monorail is paused until you turn it off")
        } else if !on, pausedForStageManager {
            pausedForStageManager = false
            engine.setPaused(false)
            toast.show("Stage Manager is off · Monorail is arranging windows again")
        }
    }

    // MARK: Stay Awake

    private func wireUpAwake() {
        engine.onActionPerformed = { [weak self] action in
            guard let self else { return }
            EventStream.shared.send("action", ["action": action.rawValue])
            self.usage.action(action)
            let steps = (self.usage.stored.actions["focus-left"] ?? 0) + (self.usage.stored.actions["focus-right"] ?? 0)
            if steps == 30 { self.tipOnce("slide-mode", "tap the right ⌥ key on its own for slide mode, then just use the arrow keys") }
            if action == .overview, (self.usage.stored.actions["overview"] ?? 0) == 1 {
                self.tipOnce("overview", "drag a window onto another to pair them, or between slides to give it its own")
            }
            if action == .commandPalette, (self.usage.stored.actions["command-palette"] ?? 0) == 3 {
                self.tipOnce("sentences", "the palette understands sentences: try “Safari two thirds” or “how do I keep my Mac awake?”")
            }
        }
        whatsNew.store = store
        whatsNew.tryAction = { [weak self] action in
            if action == .commandPalette { self?.palette.show() } else { self?.engine.perform(action) }
        }
        UsageBridge.log = usage
        awake.settings = { [weak self] in self?.store.settings ?? AppSettings() }
        evening.settings = { [weak self] in self?.store.settings ?? AppSettings() }
        evening.start()
        // Keeper owns staying awake while it runs and says so: a session started here goes to it.
        awake.forwardToPeer = { [weak self] session in
            guard let self else { return false }
            // Signalbox resting: Monorail keeps the Mac awake instead.
            if Edition.isAppStore, SuiteRole.shared.isResting {
                var args = ["for": "0"]  // 0: until turned off
                if case .until(let end) = session, let minutes = SuiteRoles.handoffMinutes(endsAt: end) { args["for"] = "\(minutes)m" }
                self.askMonorail("awake.on", args)
                return true
            }
            guard let peer = self.activePeer else { return false }
            let closedLid = self.store.settings.awakeClosedLid
            let id = String(UUID().uuidString.prefix(8)).lowercased()
            guard let link = peer.awakeHandoffLink(for: session, closedLid: closedLid, handoffID: id),
                let url = URL(string: link)
            else { return false }
            NSWorkspace.shared.open(url)
            self.toast.show("\(peer.app) keeps your Mac awake")
            if closedLid { self.awaitAwakeHandoff(id, session: session) }
            return true
        }
        engine.peerOverlays = { [weak self] in self?.activePeer?.overlays ?? [] }
        awake.onNotice = { [weak self] message in self?.toast.show(message) }
        awake.turnOffKeepAvailable = { [weak self] in self?.store.settings.keepAvailable = false }
        scriptable.notice = { [weak self] text in self?.toast.show(text) }
        scriptable.gap = { [weak self] in Double(self?.store.settings.layout.gap ?? 8) }
        awake.onChange = { [weak self] on, why in
            guard let self else { return }
            if self.store.settings.awakeNotify { self.toast.show(why) }
            if self.store.settings.awakeSound { NSSound(named: on ? "Purr" : "Pop")?.play() }
            self.postWebhook(on ? "stay_awake_on" : "stay_awake_off", ["status": self.awake.statusText])
            self.usage.awake(on)
            if on { self.tipOnce("awake", "Stay Awake ends by itself at 10% battery, and can start on its own: Settings → Stay Awake → triggers") }
            self.integrations.update({ [weak self] in self?.currentState() }, settings: self.store.settings)
            self.awakeTicker?.invalidate()
            self.awakeTicker = on ? Timer.every(20) { [weak self] _ in self?.updateStatusItem() } : nil
            self.publishSuiteHello()
            self.updateStatusItem()
        }
        // The shared channel needs no Accessibility: Keeper can hand Stay Awake over before it's granted.
        DispatchQueue.main.async { [weak self] in self?.startSuiteChannel() }
        if store.settings.awakeOnLaunch { awake.start(minutes: store.settings.awakeDefaultMinutes) }
    }

    private func performAwake(_ action: Action) {
        switch action {
        case .toggleAwake: awake.toggle()
        case .awake30: awake.start(minutes: 30)
        case .awake60: awake.start(minutes: 60)
        case .awake120: awake.start(minutes: 120)
        case .awakeWhileDownloading: awake.start(.whileDownloading)
        case .toggleAwakeDisplay:
            var settings = store.settings
            settings.awakeKeepDisplayOn.toggle()
            store.settings = settings
            toast.show(settings.awakeKeepDisplayOn ? "Stay Awake keeps the display on" : "Stay Awake lets the display sleep (the Mac stays awake)")
        default: break
        }
    }

    private func awakeMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: awake.isOn ? L("Stay Awake") + " · \(awake.statusText)" : L("Stay Awake"), action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: awake.isOn ? "cup.and.saucer.fill" : "cup.and.saucer", accessibilityDescription: nil)
        let menu = NSMenu()
        if awake.isOn {
            menu.addItem(item(L("End Stay Awake"), #selector(endAwakeFromMenu), action: .toggleAwake))
            menu.addItem(.separator())
        }
        let header = NSMenuItem(title: "Keep this Mac awake…", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let indefinitely = item(L("Until I end it"), #selector(awakeForMinutesFromMenu(_:)))
        indefinitely.tag = 0
        menu.addItem(indefinitely)
        for (title, minutes) in [("For 15 minutes", 15), ("For 30 minutes", 30), ("For 1 hour", 60), ("For 2 hours", 120),
                                 ("For 4 hours", 240), ("For 8 hours", 480), ("For 12 hours", 720)] {
            let entry = item(title, #selector(awakeForMinutesFromMenu(_:)))
            entry.tag = minutes
            menu.addItem(entry)
        }
        menu.addItem(item("Until a Time…", #selector(awakeUntilFromMenu)))
        let apps = NSMenuItem(title: "While an App Is Open", action: nil, keyEquivalent: "")
        let appsMenu = NSMenu()
        for app in NSWorkspace.shared.runningApplications.filter({ $0.activationPolicy == .regular && $0.bundleIdentifier != nil })
            .sorted(by: { ($0.localizedName ?? "") < ($1.localizedName ?? "") })
        {
            let entry = item(app.localizedName ?? app.bundleIdentifier!, #selector(awakeWhileAppFromMenu(_:)))
            entry.representedObject = app.bundleIdentifier
            entry.image = app.icon.map { icon in
                let copy = icon.copy() as! NSImage
                copy.size = NSSize(width: 16, height: 16)
                return copy
            }
            appsMenu.addItem(entry)
        }
        apps.submenu = appsMenu
        menu.addItem(apps)
        menu.addItem(item("While Downloading", #selector(awakeDownloadingFromMenu)))
        menu.addItem(.separator())
        let settings = store.settings
        for (title, on, selector) in [
            ("Keep the Display On", settings.awakeKeepDisplayOn, #selector(toggleAwakeDisplayFromMenu)),
            ("Allow the Screen Saver", settings.awakeAllowScreenSaver, #selector(toggleAwakeScreenSaverFromMenu)),
            ("Move the Pointer Now and Then", settings.awakeMoveCursor, #selector(toggleAwakeCursorFromMenu)),
            ("Keep External Drives Awake", settings.awakeDriveAlive, #selector(toggleAwakeDrivesFromMenu)),
            ("Automatic Triggers", settings.awakeTriggersOn, #selector(toggleAwakeTriggersFromMenu)),
        ] + (Edition.isAppStore ? [] : [("Stay Awake with the Lid Closed", settings.awakeClosedLid, #selector(toggleAwakeLidFromMenu))]) {
            let entry = item(title, selector)
            entry.state = on ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(item(L("Stay Awake Settings…"), #selector(showAwakeSettingsFromMenu)))
        parent.submenu = menu
        return parent
    }

    @objc private func toggleAnimationsFromMenu() {
        var settings = store.settings
        settings.animate.toggle()
        store.settings = settings
        toast.show(settings.animate ? "Animations on" : "Animations off · windows move instantly")
    }

    @objc private func showWhatsNewFromMenu() {
        whatsNew.show(version: Bundle.main.shortVersion)
    }

    @objc private func endAwakeFromMenu() { awake.end() }
    @objc private func awakeForMinutesFromMenu(_ sender: NSMenuItem) { awake.start(minutes: sender.tag) }
    @objc private func awakeDownloadingFromMenu() { awake.start(.whileDownloading) }
    @objc private func awakeWhileAppFromMenu(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { awake.start(.whileApp(id)) }
    }
    @objc private func awakeUntilFromMenu() {
        afterMenu { delegate in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            guard let text = TextPrompt.ask(title: "Stay awake until…", message: "A time today (or tomorrow, if it has passed), like 18:30.",
                                            initial: formatter.string(from: Date().addingTimeInterval(3600)), placeholder: "18:30", button: "Start"),
                let time = formatter.date(from: text.trimmingCharacters(in: .whitespaces))
            else { return }
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            var date = Calendar.current.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: Date()) ?? Date()
            if date <= Date() { date = date.addingTimeInterval(86400) }
            delegate.awake.start(.until(date))
        }
    }
    private func toggleAwakeSetting(_ change: (inout AppSettings) -> Void) {
        var settings = store.settings
        change(&settings)
        store.settings = settings
        awake.refresh()
    }
    @objc private func toggleAwakeDisplayFromMenu() { toggleAwakeSetting { $0.awakeKeepDisplayOn.toggle() } }
    @objc private func toggleAwakeScreenSaverFromMenu() { toggleAwakeSetting { $0.awakeAllowScreenSaver.toggle() } }
    @objc private func toggleAwakeCursorFromMenu() { toggleAwakeSetting { $0.awakeMoveCursor.toggle() } }
    @objc private func toggleAwakeDrivesFromMenu() { toggleAwakeSetting { $0.awakeDriveAlive.toggle() } }
    @objc private func toggleAwakeLidFromMenu() {
        if !store.settings.awakeClosedLid {
            let alert = NSAlert()
            alert.messageText = "Stay awake with the lid closed?"
            alert.informativeText = "During Stay Awake your MacBook keeps running when you close it, even without an external display. macOS asks for your password when it starts. It works only while plugged in (change that in Settings), and it turns off by itself if your Mac gets hot. Still, don't put a running Mac in a bag."
            alert.addButton(withTitle: "Turn On")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        toggleAwakeSetting { $0.awakeClosedLid.toggle() }
    }
    @objc private func toggleAwakeTriggersFromMenu() { toggleAwakeSetting { $0.awakeTriggersOn.toggle() } }
    /// A lid-closed session handed to Keeper: Keeper answers in its next hello within 10 s. If it
    /// says no or doesn't answer, Monorail keeps the session itself (agreed with Keeper).
    private func awaitAwakeHandoff(_ id: String, session: AwakeSession, tries: Int = 0) {
        if let answer = activePeer?.awakeHandoff, answer.id == id {
            if answer.ok { return }
            awake.start(session, fromPeer: true)
            toast.show("Keeper couldn't keep your Mac running closed (\(answer.reason ?? "failed")), so Monorail does")
            return
        }
        guard tries < 10 else {
            awake.start(session, fromPeer: true)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.awaitAwakeHandoff(id, session: session, tries: tries + 1)
        }
    }

    /// "Also from Ashforde": Keeper's state and a way to open it, or to get it once it's released.
    private func addAshfordeSection(to menu: NSMenu) {
        let state: Companions.KeeperState
        if let peer = activePeer, Companions.isKeeper(peer.bundleID) {
            state = .running(awake: peer.isAwake)
        } else if NSWorkspace.shared.urlForApplication(withBundleIdentifier: Companions.keeper) != nil {
            state = .installed
        } else {
            state = .notInstalled
        }
        let rows = Companions.keeperMenu(state)
        guard !rows.isEmpty else { return }
        menu.addItem(.separator())
        let header = NSMenuItem(title: L("Also from Ashforde"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for row in rows {
            let item = NSMenuItem(title: row.title, action: row.link == nil ? nil : #selector(openAshfordeLink(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = row.link
            item.isEnabled = row.link != nil
            menu.addItem(item)
        }
    }

    @objc private func openAshfordeLink(_ sender: NSMenuItem) {
        guard let link = sender.representedObject as? String, let url = URL(string: link) else { return }
        NSWorkspace.shared.open(url)
    }

    /// Evening Mode in the menu bar menu: on or off, how warm, the schedule.
    private func eveningMenu() -> NSMenuItem {
        let settings = store.settings
        let parent = NSMenuItem(title: L("Evening Mode"), action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: evening.isOn ? "moon.fill" : "moon", accessibilityDescription: nil)
        let menu = NSMenu()
        let toggle = item(settings.eveningOn ? L("Turn Off") : L("Turn On Now"), #selector(toggleEveningFromMenu))
        menu.addItem(toggle)
        menu.addItem(.separator())
        for percent in [25, 50, 75, 100] {
            let entry = item("\(percent)% warmer", #selector(setEveningStrengthFromMenu(_:)))
            entry.tag = percent
            entry.state = Int((settings.eveningStrength * 100).rounded()) == percent ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        let scheduled = item(L("Every Evening on a Schedule"), #selector(toggleEveningScheduleFromMenu))
        scheduled.state = settings.eveningSchedule == .scheduled ? .on : .off
        menu.addItem(scheduled)
        let sun = item(L("Sunset to Sunrise"), #selector(toggleEveningSunFromMenu))
        sun.state = settings.eveningSchedule == .sun ? .on : .off
        if case .normal(let sunrise, let sunset) = evening.todaysSun() {
            sun.toolTip = String(format: "Today %02d:%02d–%02d:%02d, worked out from your time zone", sunset / 60, sunset % 60, sunrise / 60, sunrise % 60)
        }
        menu.addItem(sun)
        let red = item(L("Deep Red"), #selector(toggleEveningRedFromMenu))
        red.state = settings.eveningRed ? .on : .off
        red.toolTip = "Green and blue fade out as well: at full strength only red light is left, for late at night."
        menu.addItem(red)
        if evening.isPausedForApp {
            let paused = NSMenuItem(title: L("Resting while this app is in front"), action: nil, keyEquivalent: "")
            paused.isEnabled = false
            menu.addItem(paused)
        }
        menu.addItem(item(L("Evening Mode Settings…"), #selector(showEveningSettingsFromMenu)))
        parent.submenu = menu
        return parent
    }

    /// "Keep me Available": the Mac stays awake and Teams, Slack and other chat apps keep showing
    /// you as available. Works without any permission.
    private func keepAvailableItem() -> NSMenuItem {
        let entry = item(L("Keep me Available"), #selector(toggleKeepAvailableFromMenu), action: .keepAvailable)
        entry.state = store.settings.keepAvailable ? .on : .off
        entry.image = NSImage(systemSymbolName: "person.crop.circle.badge.checkmark", accessibilityDescription: nil)
        entry.toolTip = "Keeps your Mac awake and Teams, Slack and other chat apps showing you as Available. No permission needed."
        return entry
    }

    @objc private func toggleKeepAvailableFromMenu() {
        var settings = store.settings
        settings.keepAvailable.toggle()
        store.settings = settings
        awake.reconsider()
        toast.show(settings.keepAvailable
                   ? "Keep me Available on · your Mac stays awake and Teams and Slack show you as Available"
                   : "Keep me Available off")
    }

    // MARK: Without Accessibility

    /// Arranging scriptable apps with Apple Events: only until Accessibility is allowed, and not
    /// in the App Store edition.
    private var usesScriptableArranging: Bool {
        ScriptableArranger.isAvailable && store.settings.arrangeScriptableApps && !engine.isRunning
    }

    private func scriptableMenu() -> NSMenuItem {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let name = scriptable.frontApp?.name
        let header = NSMenuItem(
            title: name.map { "Front window of \($0)" } ?? "Safari, Chrome, Finder, Terminal, Notes, Mail…",
            action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for placement in ScriptPlacement.allCases {
            let entry = item(placement.title, #selector(placeScriptableFromMenu(_:)))
            entry.representedObject = placement.rawValue
            entry.isEnabled = name != nil
            menu.addItem(entry)
        }
        menu.addItem(item("Side by Side with the App Before", #selector(scriptableSideBySideFromMenu)))
        menu.addItem(.separator())
        let next = item("Next Window of This App", #selector(scriptableNextWindowFromMenu))
        next.isEnabled = name != nil
        menu.addItem(next)
        let previous = item("Previous Window of This App", #selector(scriptablePreviousWindowFromMenu))
        previous.isEnabled = name != nil
        menu.addItem(previous)
        menu.addItem(.separator())
        menu.addItem(item("Automation Settings…", #selector(openAutomationSettings)))
        let parent = NSMenuItem(title: "Arrange Scriptable Apps", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil)
        parent.toolTip = "Moves the windows of apps that can be scripted, without Accessibility. macOS asks once for each app."
        parent.submenu = menu
        return parent
    }

    private func scriptablePaletteCommands() -> [PaletteCommand] {
        guard usesScriptableArranging else { return [] }
        let app = scriptable.frontApp?.name ?? "the front app"
        var list = ScriptPlacement.allCases.map { placement -> PaletteCommand in
            PaletteCommand(
                id: "scriptable-\(placement.rawValue)", title: "\(placement.title): \(app)",
                subtitle: "Arrange a scriptable app · no Accessibility needed", symbol: "rectangle.split.2x1",
                keywords: "arrange move window half left right fill full centre center scriptable"
            ) { [weak self] in self?.scriptable.place(placement) }
        }
        list.append(PaletteCommand(
            id: "scriptable-side-by-side", title: "Side by side: the last two scriptable apps",
            subtitle: "Arrange scriptable apps · no Accessibility needed", symbol: "rectangle.split.2x1",
            keywords: "pair split arrange scriptable two apps"
        ) { [weak self] in self?.scriptable.sideBySide() })
        list.append(PaletteCommand(
            id: "scriptable-next-window", title: "Next window of \(app)", subtitle: "No Accessibility needed",
            symbol: "macwindow.on.rectangle", keywords: "next window cycle switch scriptable"
        ) { [weak self] in self?.scriptable.cycleWindows(forward: true) })
        list.append(PaletteCommand(
            id: "scriptable-previous-window", title: "Previous window of \(app)", subtitle: "No Accessibility needed",
            symbol: "macwindow.on.rectangle", keywords: "previous window cycle switch scriptable"
        ) { [weak self] in self?.scriptable.cycleWindows(forward: false) })
        return list
    }

    @objc private func placeScriptableFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let placement = ScriptPlacement(rawValue: raw) else { return }
        afterMenu { $0.scriptable.place(placement) }
    }

    @objc private func scriptableSideBySideFromMenu() { afterMenu { $0.scriptable.sideBySide() } }
    @objc private func scriptableNextWindowFromMenu() { afterMenu { $0.scriptable.cycleWindows(forward: true) } }
    @objc private func scriptablePreviousWindowFromMenu() { afterMenu { $0.scriptable.cycleWindows(forward: false) } }

    @objc private func openAutomationSettings() {
        if let url = URL(string: ScriptErrors.automationSettingsURL) { NSWorkspace.shared.open(url) }
    }

    /// Asks macOS once (the person chose to), and opens the Accessibility list.
    @objc private func grantAccessibilityFromMenu() {
        _ = Accessibility.isTrusted(prompt: true)
        if let url = Accessibility.settingsURL { NSWorkspace.shared.open(url) }
    }

    /// What works without Accessibility, and how IT can allow it.
    @objc private func explainWithoutAccessibility() {
        afterMenu { _ in
            let alert = NSAlert()
            alert.messageText = "Using Monorail without Accessibility"
            alert.informativeText = """
                Moving other apps’ windows needs Accessibility. On a Mac your organisation manages, only an \
                administrator can allow it, and IT can do that for Monorail in one step.

                \(PermissionStatus.useWithout) Monorail won’t keep asking: choose Grant Accessibility Access \
                in this menu whenever you’re ready.
                """
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Guide for IT…")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertSecondButtonReturn,
                let url = URL(string: "https://monorail.ashforde.org/docs/it/")
            {
                NSWorkspace.shared.open(url)
            }
        }
    }


    @objc private func toggleEveningFromMenu() {
        var settings = store.settings
        settings.eveningOn.toggle()
        store.settings = settings
        toast.show(settings.eveningOn ? "Evening Mode on · \(Int((settings.eveningStrength * 100).rounded()))% warmer" : "Evening Mode off")
    }

    @objc private func setEveningStrengthFromMenu(_ sender: NSMenuItem) {
        var settings = store.settings
        settings.eveningStrength = Double(sender.tag) / 100
        if settings.eveningSchedule == .manual { settings.eveningOn = true }
        store.settings = settings
    }

    @objc private func toggleEveningScheduleFromMenu() {
        var settings = store.settings
        settings.eveningSchedule = settings.eveningSchedule == .scheduled ? .manual : .scheduled
        store.settings = settings
        if settings.eveningSchedule == .scheduled {
            toast.show(String(format: "Evening Mode every day %02d:%02d–%02d:%02d", settings.eveningStart / 60, settings.eveningStart % 60, settings.eveningEnd / 60, settings.eveningEnd % 60))
        }
    }

    @objc private func toggleEveningSunFromMenu() {
        var settings = store.settings
        settings.eveningSchedule = settings.eveningSchedule == .sun ? .manual : .sun
        store.settings = settings
        if settings.eveningSchedule == .sun, case .normal(let sunrise, let sunset) = evening.todaysSun() {
            toast.show(String(format: "Evening Mode from sunset (%02d:%02d) to sunrise (%02d:%02d)", sunset / 60, sunset % 60, sunrise / 60, sunrise % 60))
        }
    }

    @objc private func toggleEveningRedFromMenu() {
        var settings = store.settings
        settings.eveningRed.toggle()
        store.settings = settings
    }

    @objc private func showEveningSettingsFromMenu() {
        navigation.tab = .evening
        showSettings()
    }

    @objc private func showAwakeSettingsFromMenu() {
        navigation.tab = .awake
        showSettings()
    }

    /// Pollers rest while the screen sleeps, is locked or shows the screen saver.
    private func watchDormancy() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { _ in Dormancy.isDormant = true }
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { _ in Dormancy.isDormant = false }
        }
        // A display unplugged or rearranged: Monorail's own windows come back into view.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                               queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.refitOwnWindows() }
        }
        let distributed = DistributedNotificationCenter.default()
        for (name, dormant) in [("com.apple.screenIsLocked", true), ("com.apple.screensaver.didstart", true),
                                ("com.apple.screenIsUnlocked", false), ("com.apple.screensaver.didstop", false)] {
            distributed.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { _ in
                Dormancy.isDormant = dormant
            }
        }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) {
            [weak self] _ in self?.updateThrift()
        }
        updateThrift()
    }

    private func updateThrift() {
        Dormancy.isThrifty = ProcessInfo.processInfo.isLowPowerModeEnabled || (store.settings.energySaver && Power.onBattery)
    }

    /// Settings as the engine should see them: managed values, safe mode, battery and sound packs.
    private func adjustedV12(_ original: AppSettings) -> AppSettings {
        var settings = ManagedSettings.apply(to: original)
        if safeMode {
            settings.appRules = []
            settings.autoRules = []
            settings.scripts = false
            settings.pathRules = []
        }
        if settings.energySaver, Power.onBattery { settings.animationFPS = 30 }
        switch settings.soundPack {
        case .classic: break
        case .silent: settings.slideSound = false
        default: if let sound = settings.soundPack.sounds.slide { settings.clickSound = sound }
        }
        return settings
    }

    private func applyV12(_ settings: AppSettings) {
        if CapsLockKey.source != settings.monorailKeySource.usage {
            CapsLockKey.source = settings.monorailKeySource.usage
            if settings.capsLockKey { CapsLockKey.set(true) }
        }
        input.mouseGestures = settings.mouseGestures
        midi.setEnabled(settings.midiControl)
        gamepad.setEnabled(settings.gameController)
        if settings.headFocus || headFocusMade { headFocus.setEnabled(settings.headFocus) }
        if settings.webRemote, settings.webRemoteToken.isEmpty {
            var changed = settings
            changed.webRemoteToken = Self.randomToken()
            DispatchQueue.main.async { [weak self] in self?.store.settings = changed }
        }
        if settings.webRemote || webRemoteMade {
            webRemote.token = settings.webRemoteToken
            webRemote.setEnabled(settings.webRemote && !settings.webRemoteToken.isEmpty, port: UInt16(clamping: settings.apiPort + 1))
        }
        shareWatch.setEnabled(settings.safeScreenShare || settings.modes.contains { $0.enabled && $0.triggers.contains(.screenShare) })
        workspaceClipboard.setEnabled(settings.workspaceClipboard)
        calendarFocus.setEnabled(settings.deepWorkFromCalendar)
        crashReporter.setEnabled(settings.crashReports)
        OverviewStyle.blurPrivate = settings.privacyBlur
        OverviewStyle.live = !(settings.energySaver && Power.onBattery)
        updateThrift()
        awake.refresh()
        if settings.dimFollowsPointer, dimMonitor == nil {
            dimMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                let location = NSEvent.mouseLocation
                let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
                self?.engine.dimAnchor = self?.engine.window(at: CGPoint(x: location.x, y: primaryHeight - location.y))
            }
        } else if !settings.dimFollowsPointer, let monitor = dimMonitor {
            NSEvent.removeMonitor(monitor)
            dimMonitor = nil
            engine.dimAnchor = nil
        }
        stateChangedV12()
    }

    private static func randomToken() -> String {
        let letters = Array("abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<24).map { _ in letters.randomElement()! })
    }

    static func widthName(_ width: Double) -> String {
        switch width {
        case ..<0.3: return "a quarter of the screen"
        case ..<0.4: return "a third of the screen"
        case ..<0.6: return "half the screen"
        case ..<0.7: return "two thirds of the screen"
        case ..<0.9: return "three quarters of the screen"
        default: return "the full width"
        }
    }

    private func stateChangedV12() {
        guard engine.isRunning else { return }
        let maps = engine.miniMaps()
        drift.update(path: store.settings.driftWallpaper, positions: maps.compactMap { map in
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: map.screenFrame.midX, y: map.screenFrame.midY)) })
            else { return nil }
            let fraction = map.viewportX / max(map.totalWidth - map.viewportWidth, 1)
            return (screen, map.displayUUID, fraction)
        })
        if let status = engine.status() {
            let signature = "\(status.workspace)-\(status.focusedColumn)-\(status.columnCount)"
            if signature != lastStatusSignature {
                lastStatusSignature = signature
                EventStream.shared.send("state", ["workspace": status.workspace, "slide": status.focusedColumn,
                                                  "slides": status.columnCount])
                if store.settings.notchHUD {
                    notchHUD.show(slide: status.focusedColumn, slides: status.columnCount, workspace: status.workspace,
                                  workspaces: engine.workspaceCount)
                }
            }
        }
        if pairSyncMade, pairSync.isOn, Date().timeIntervalSince(lastSyncSent) > 1, let json = engine.layoutJSON() {
            lastSyncSent = Date()
            pairSync.send(json)
        }
    }

    private func vimChanged(_ on: Bool, _ pending: String) {
        let wasOn = vimText != nil
        vimText = on ? "NORMAL" + (pending.isEmpty ? "" : " " + pending) : nil
        if on && !wasOn { toast.show("Vim mode · h j k l, 3l, gg, G, dd, w b, u, / · i or Esc to leave") }
        if !on && wasOn { toast.show("Vim mode off") }
        updateStatusItem()
    }

    /// Text after the menu bar icon for timers and modes.
    private var statusExtra: String? {
        let parts = [awake.menuBarText, pomodoroText, vimText, deepWork.isOn ? "◆ Deep work" : nil, guestOn ? "Guest" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func mouseGesture(_ dx: Double, _ dy: Double) {
        guard max(abs(dx), abs(dy)) > 60 else { return }
        if abs(dx) > abs(dy) {
            engine.perform(dx > 0 ? .nextWorkspace : .previousWorkspace)
        } else if dy < 0 {
            overview.show()
        } else {
            engine.perform(.showDesktop)
        }
    }

    // MARK: Sentences and intents

    private func runningAppNames() -> [String] {
        let windows = engine.allWindowSummaries().map(\.appName)
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.compactMap(\.localizedName)
        return Array(Set(windows + apps)).sorted { $0.count > $1.count }
    }

    /// Carries out a sentence; false when nothing was understood.
    @discardableResult
    private func say(_ text: String) -> Bool {
        if let command = CommandParser.parse(text, apps: runningAppNames()) {
            run(command)
            return true
        }
        if let (candidate, score) = IntentMatcher.best(for: text, in: intentCandidates()), score >= 0.2 {
            start(candidate)
            return true
        }
        if Assistant.isReady(store.settings) {
            askAssistant(text)
            return true
        }
        toast.show("Didn’t catch that · try “Safari two thirds” or “Slack and Mail side by side on 2”")
        return false
    }

    /// Asks Claude (with the person's own key) to turn the sentence into known commands, then confirms.
    private func askAssistant(_ text: String) {
        let name = store.settings.assistantProvider.shortName
        toast.show("Asking \(name)…")
        let apps = runningAppNames()
        Assistant.plan(for: text, apps: apps, actions: Action.allCases.map(\.title), settings: store.settings) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.toast.show(error.localizedDescription)
            case .success(let plan):
                let commands = plan.commands.compactMap { sentence in
                    CommandParser.parse(sentence, apps: apps).map { (sentence, $0) }
                }
                guard !commands.isEmpty else {
                    self.toast.show(plan.explanation.isEmpty ? "\(name) couldn’t turn that into window commands" : plan.explanation)
                    return
                }
                let alert = NSAlert()
                alert.messageText = "Do this?"
                alert.informativeText = commands.enumerated().map { "\($0.offset + 1). \(self.describe($0.element.1))" }
                    .joined(separator: "\n") + (plan.explanation.isEmpty ? "" : "\n\n" + plan.explanation)
                alert.addButton(withTitle: "Do It")
                alert.addButton(withTitle: "Cancel")
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                for (index, command) in commands.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.45) { [weak self] in self?.run(command.1) }
                }
            }
        }
    }

    private func describe(_ command: NaturalCommand) -> String {
        switch command {
        case .pair(let apps, let arrangement, let workspace):
            return apps.joined(separator: " and ") + " " + arrangement.title.lowercased() + (workspace.map { " on workspace \($0 + 1)" } ?? "")
        case .width(let app, let share): return "\(app ?? "This window") at \(Int((share * 100).rounded()))% width"
        case .moveTo(let app, let workspace): return "Move \(app ?? "this window") to workspace \(workspace + 1)"
        case .switchTo(let workspace): return "Go to workspace \(workspace + 1)"
        case .open(let app): return "Open \(app)"
        case .focusMode(let on): return "Focus mode \(on ? "on" : "off")"
        case .action(let action): return action.title
        }
    }

    private func run(_ command: NaturalCommand) {
        let summaries = engine.allWindowSummaries()
        func window(of app: String) -> WindowID? {
            summaries.first { $0.appName.caseInsensitiveCompare(app) == .orderedSame }?.id
                ?? summaries.first { $0.appName.lowercased().hasPrefix(app.lowercased()) }?.id
        }
        switch command {
        case .pair(let apps, let arrangement, let workspace):
            let ids = apps.compactMap(window(of:))
            guard ids.count >= 2 else {
                toast.show("Open \(apps.joined(separator: " and ")) first, then try again")
                return
            }
            engine.pairWindows(ids, arrangement: arrangement)
            if let workspace {
                for id in ids { engine.moveWindow(id, toWorkspace: workspace) }
                engine.switchWorkspace(to: workspace)
            }
        case .width(let app, let share):
            if let app, let id = window(of: app) { engine.focusAndReveal(id) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                if let action = Action.allCases.first(where: { abs(($0.directWidth ?? -1) - share) < 0.02 }) {
                    self?.engine.perform(action)
                } else {
                    self?.engine.perform(.toggleFullWidth)
                }
            }
        case .moveTo(let app, let workspace):
            if let id = app.flatMap(window(of:)) ?? engine.focusedWindowID() { engine.moveWindow(id, toWorkspace: workspace) }
        case .switchTo(let workspace):
            engine.switchWorkspace(to: workspace)
        case .open(let app):
            if let id = window(of: app) {
                engine.focusAndReveal(id)
            } else {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-a", app]
                try? process.run()
            }
        case .focusMode(let on):
            engine.setFocusMode(on)
        case .action(let action):
            engine.perform(action)
        }
    }

    private func intentCandidates() -> [IntentCandidate] {
        let settings = store.settings
        var list: [IntentCandidate] = settings.templates.map {
            IntentCandidate(kind: .template, name: $0.name, keywords: $0.items.map { UsageStats.appName($0.bundleID) })
        }
        list += engine.layouts.filter { $0.isSnapshot != true }.map { IntentCandidate(kind: .layout, name: $0.name) }
        list += settings.appPairs.map { IntentCandidate(kind: .pair, name: $0.name, keywords: $0.bundleIDs.map(UsageStats.appName)) }
        list += (0..<engine.workspaceCount).map { IntentCandidate(kind: .workspace, name: settings.workspaceName($0)) }
        return list
    }

    private func start(_ candidate: IntentCandidate) {
        let settings = store.settings
        switch candidate.kind {
        case .template:
            if let template = settings.templates.first(where: { $0.name == candidate.name }) { engine.runTemplate(template) }
        case .layout:
            engine.applyLayout(named: candidate.name)
        case .pair:
            if let pair = settings.appPairs.first(where: { $0.name == candidate.name }) { engine.openPair(pair) }
        case .workspace:
            if let index = (0..<engine.workspaceCount).first(where: { settings.workspaceName($0) == candidate.name }) {
                engine.switchWorkspace(to: index)
            }
        case .project:
            break
        }
        toast.show("Starting “\(candidate.name)”")
    }

    private func dynamicCommands(_ query: String) -> [PaletteCommand] {
        var list: [PaletteCommand] = []
        // What you copied, today's meetings, reminders and notes that match.
        let q = query.trimmingCharacters(in: .whitespaces)
        if let value = QuickCalc.evaluate(q) {
            let answer = QuickCalc.format(value)
            list.append(PaletteCommand(id: "calc", title: "= \(answer)", subtitle: "Copy the answer", symbol: "equal.circle", keywords: q) { ClipboardWatch.shared.copy(answer) })
        }
        // "5 km in miles", "72 F to C".
        if let converted = UnitConversion.answer(q) {
            let result = converted.components(separatedBy: " = ").last ?? converted
            list.append(PaletteCommand(id: "convert", title: converted, subtitle: "Copy \(result)", symbol: "arrow.left.arrow.right", keywords: q) { ClipboardWatch.shared.copy(result) })
        }
        if q.count >= 2 {
            for clip in ClipboardWatch.shared.history.shown(matching: q).prefix(4) {
                list.append(PaletteCommand(id: "clip-\(clip.id)", title: clip.preview(60), subtitle: "Clipboard · paste it", symbol: clip.kind.symbol,
                                           keywords: q) { ClipboardWatch.shared.use(clip) })
            }
            for event in TodayWatch.shared.meetings where event.title.localizedCaseInsensitiveContains(q) {
                list.append(PaletteCommand(id: "event-\(event.id)", title: event.title,
                                           subtitle: "Calendar · \(event.start.formatted(date: .omitted, time: .shortened))" + (event.join == nil ? "" : " · Join"),
                                           symbol: "calendar", keywords: q) {
                    if let link = event.join { NSWorkspace.shared.open(link) }
                })
            }
            for reminder in RemindersWatch.shared.reminders where (reminder.title ?? "").localizedCaseInsensitiveContains(q) {
                list.append(PaletteCommand(id: "reminder-\(reminder.calendarItemIdentifier)", title: reminder.title ?? "",
                                           subtitle: "Reminder · mark as done", symbol: "checkmark.circle", keywords: q) {
                    RemindersWatch.shared.complete(reminder)
                })
            }
            for note in AppleNotes.shared.notes where note.title.localizedCaseInsensitiveContains(q) || note.snippet.localizedCaseInsensitiveContains(q) {
                list.append(PaletteCommand(id: "note-\(note.id)", title: note.title, subtitle: "Notes · open", symbol: "note.text", keywords: q) {
                    AppleNotes.shared.open(note.id)
                })
            }
        }
        // Ask Monorail: "how do I keep my Mac awake?"
        if HelpIndex.isQuestion(query) {
            for (n, answer) in HelpIndex.answers(for: query).enumerated() {
                list.append(PaletteCommand(id: "help-\(n)", title: answer.question, subtitle: answer.answer,
                                           symbol: "questionmark.circle", keywords: query) { [weak self] in
                    self?.openHelpTarget(answer.target)
                })
            }
        }
        guard query.split(separator: " ").count >= 2 else { return list }
        if let command = CommandParser.parse(query, apps: runningAppNames()) {
            list.append(PaletteCommand(id: "say", title: "Do it: \(describe(command))", subtitle: "From what you typed",
                                       symbol: "sparkles", keywords: query) { [weak self] in self?.run(command) })
        }
        if let (candidate, score) = IntentMatcher.best(for: query, in: intentCandidates()), score >= 0.2 {
            list.append(PaletteCommand(id: "intent", title: "Start “\(candidate.name)”",
                                       subtitle: "Your \(candidate.kind.rawValue) that matches what you’re doing",
                                       symbol: "wand.and.stars", keywords: query) { [weak self] in self?.start(candidate) })
        }
        return list
    }

    private func openHelpTarget(_ target: HelpIndex.Target) {
        switch target {
        case .action(let action):
            if action == .commandPalette { palette.show() } else { engine.perform(action) }
        case .settings(let id):
            if let tab = SettingsTab(rawValue: id) { navigation.tab = tab }
            showSettings()
        }
    }

    private func v12PaletteCommands() -> [PaletteCommand] {
        var list: [PaletteCommand] = []
        if engine.snapshots.contains(where: { $0.name == Self.beforeMeeting }) {
            list.append(PaletteCommand(id: "after-meeting", title: "After the meeting: put things back",
                                       subtitle: "The layout from before your call", symbol: "arrow.uturn.backward",
                                       keywords: "meeting call after restore back") { [weak self] in
                self?.engine.restoreSnapshot(named: Self.beforeMeeting)
            })
        }
        for id in engine.waitingAgents {
            let name = engine.allWindowSummaries().first { $0.id == id }?.appName ?? "Agent"
            list.append(PaletteCommand(id: "agent-\(id)", title: "Go to the waiting agent (\(name))", subtitle: "Needs your approval",
                                       symbol: "exclamationmark.bubble", keywords: "agent claude codex waiting approve") { [weak self] in
                self?.engine.focusAndReveal(id)
            })
        }
        if let next = engine.predictedNext {
            list.append(PaletteCommand(id: "predicted", title: "Next: \(UsageStats.appName(next))", subtitle: "Where you usually go from here",
                                       symbol: "arrow.forward.circle", keywords: "next predicted usual") { [weak self] in
                self?.engine.perform(.goToPredicted)
            })
        }
        if let index = engine.status().map({ $0.workspace - 1 }) {
            for (n, text) in workspaceClipboard.items(for: index).enumerated() {
                let short = text.count > 60 ? String(text.prefix(59)) + "…" : text
                list.append(PaletteCommand(id: "clip-\(n)", title: "Clipboard: \(short)", subtitle: "Copied in this workspace",
                                           symbol: "doc.on.clipboard", keywords: "clip clipboard paste copy") { [weak self] in
                    self?.workspaceClipboard.use(text)
                    self?.toast.show("On the clipboard · ⌘V to paste")
                })
            }
        }
        for layout in engine.layouts where layout.name.hasPrefix("Archive · ") {
            list.append(PaletteCommand(id: "archive-\(layout.name)", title: "Bring back \(layout.name.dropFirst(10))",
                                       subtitle: "Archived workspace", symbol: "archivebox", keywords: "archive restore") { [weak self] in
                self?.engine.restoreArchive(named: layout.name)
            })
        }
        let host = Host.current().localizedName ?? "Mac"
        for layout in engine.layouts where layout.name.hasPrefix("Handoff · ") && layout.name != "Handoff · \(host)" {
            list.append(PaletteCommand(id: "handoff-\(layout.name)", title: "Continue from \(layout.name.dropFirst(10))",
                                       subtitle: "Your other Mac’s workspaces", symbol: "laptopcomputer.and.arrow.down",
                                       keywords: "handoff continue other mac") { [weak self] in
                self?.engine.applyLayout(named: layout.name)
            })
        }
        for command in scripts.commands {
            let title = command.title
            list.append(PaletteCommand(id: "script-\(title)", title: title, subtitle: "From your scripts", symbol: "curlybraces") {
                [weak self] in self?.scripts.runCommand(title)
            })
        }
        for (bundle, width) in store.settings.suggestedRules where store.settings.rule(for: bundle) == nil {
            list.append(PaletteCommand(id: "suggest-\(bundle)", title: "Always give \(UsageStats.appName(bundle)) \(Self.widthName(width))",
                                       subtitle: "Suggested from how you work", symbol: "lightbulb", keywords: "rule suggestion width") {
                [weak self] in self?.acceptSuggestion(bundle)
            })
        }
        return list
    }

    /// 1.7.3: mouse buttons 4 and 5 go back to the apps (they're Back and Forward in browsers
    /// and Finder). Done once; people who want them to step slides can turn it on again.
    private func migrateMouseButtons() {
        let key = "MonorailMouseButtonsReturned"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard store.settings.mouseButtonsStep, store.settings.hasCompletedOnboarding else { return }
        var settings = store.settings
        settings.mouseButtonsStep = false
        store.settings = settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.toast.show("Your mouse's Back and Forward buttons work in apps again · stepping slides with them is in Settings → Motion & Input")
        }
    }

    private func startTelemetry() {
        telemetry.settings = { [weak self] in self?.store.settings ?? AppSettings() }
        telemetry.usage = { [weak self] in self?.usage.stored }
        // No prompt: the counts are anonymous and on by default, explained in the privacy policy, and
        // switched off in Settings → Devices & Sharing → Trust (where "What's Sent…" shows them in full).
        telemetry.start()
    }

    /// Shows exactly what the daily usage counts contain.
    func showUsagePayload() {
        let alert = NSAlert()
        alert.messageText = "What Monorail sends once a day"
        alert.informativeText = store.settings.shareUsageStats
            ? "Anonymous counts, exactly as below. Nothing else."
            : "Sharing is off, so nothing is sent. This is what would be sent."
        let scroll = NSTextView.scrollableTextView()
        scroll.frame = NSRect(x: 0, y: 0, width: 460, height: 300)
        if let text = scroll.documentView as? NSTextView {
            text.string = telemetry.payloadText
            text.isEditable = false
            text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        }
        alert.accessoryView = scroll
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: store.settings.shareUsageStats ? "Turn Off" : "Turn On")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn {
            var settings = store.settings
            settings.shareUsageStats.toggle()
            settings.usageNoticeShown = true
            store.settings = settings
        }
    }

    /// Someone floated this app's windows by hand three times: offer a rule.
    private func suggestFloat(_ name: String, _ bundle: String) {
        var settings = store.settings
        settings.seenTips.append("float:" + bundle)
        store.settings = settings
        let alert = NSAlert()
        alert.messageText = "Always float \(name)?"
        alert.informativeText = "You keep taking \(name) windows off the strip. Monorail can leave them floating from now on. You can change this in Settings → Apps."
        alert.addButton(withTitle: "Always Float")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        settings = store.settings
        settings.appRules.append(AppRule(bundleID: bundle, name: name, float: true))
        store.settings = settings
        toast.show("\(name) windows now float")
    }

    func acceptSuggestion(_ bundle: String) {
        var settings = store.settings
        guard let width = settings.suggestedRules.removeValue(forKey: bundle) else { return }
        var rule = AppRule(bundleID: bundle, name: UsageStats.appName(bundle))
        rule.width = width
        settings.appRules.append(rule)
        store.settings = settings
        toast.show("Rule added · \(UsageStats.appName(bundle)) opens at \(Self.widthName(width))")
    }

    private func checkHandoff() {
        let host = Host.current().localizedName ?? "Mac"
        for layout in engine.layouts where layout.name.hasPrefix("Handoff · ") && layout.name != "Handoff · \(host)"
            && !seenHandoffs.contains(layout.name + "\(layout.savedAt?.timeIntervalSince1970 ?? 0)")
        {
            seenHandoffs.insert(layout.name + "\(layout.savedAt?.timeIntervalSince1970 ?? 0)")
            toast.show("\(layout.name.dropFirst(10)) sent you its workspaces · ⌃⌥/ then “continue”")
        }
    }

    private func checkBudgets() {
        let settings = store.settings
        let today = stats.today
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        for (key, config) in settings.workspaceConfigs {
            guard let budget = config.budgetMinutes, let index = Int(key) else { continue }
            let name = settings.workspaceName(index)
            let used = today.workspaceMinutes[name] ?? 0
            let warning = "\(day)-\(key)"
            if let over = TimeBudget.over(used: used, budget: budget), !budgetWarned.contains(warning) {
                budgetWarned.insert(warning)
                toast.show("\(name) has had its \(InsightsPane.duration(budget)) today\(over > 0 ? " (+\(over) min)" : "") · time for something else?")
            }
        }
    }

    /// With a crowded menu bar on a notched MacBook, Monorail's icon can hide behind the notch.
    private func checkNotch() {
        guard let window = statusItem?.button?.window, !window.occlusionState.contains(.visible) else { return }
        toast.show("Monorail’s menu bar icon is hidden by the notch · ⌘-drag it to the right, or use ⌃⌥/")
    }

    private func performAppActionV12(_ action: Action) {
        switch action {
        case .startIntent:
            guard let text = TextPrompt.ask(
                title: "What are you working on?",
                message: "Monorail opens the template, layout, app pair or workspace that fits, or does what you say (“Slack and Mail side by side”).",
                initial: "", placeholder: "Write the Q3 report", button: "Start")
            else { return }
            say(text)
        case .showTimeline:
            showTimeline()
        case .shareWorkspace:
            exportSetup()
        case .toggleVimMode:
            input.setVim(!input.vimActive)
        case .searchWindowText:
            guard WindowThumbnails.isAllowed else {
                toast.show("Finding windows by their contents needs Screen Recording · turn on live previews in the overview")
                return
            }
            guard let query = TextPrompt.ask(title: "Find a window by what’s in it", message: "Words you can see in the window.",
                                             initial: "", placeholder: "invoice 4471", button: "Find")
            else { return }
            toast.show("Reading your windows…")
            WindowTextSearch.search(query, in: engine.allWindowSummaries().map(\.id)) { [weak self] id in
                if let id { self?.engine.focusAndReveal(id) } else { self?.toast.show("No window shows “\(query)”") }
            }
        case .voiceCommand:
            voice.toggle()
        case .toggleDeepWork:
            deepWork.toggle()
        case .shareSlide:
            if slideShare.isRunning {
                slideShare.stop()
                return
            }
            guard let frame = engine.focusedSlideFrame() else { return }
            let size = NSSize(width: max(frame.width * 0.5, 480), height: max(frame.height * 0.5, 300))
            slideShare.start(.region(frame), title: "Monorail · Shared slide", frame: NSRect(origin: NSPoint(x: 60, y: 60), size: size),
                             floating: false)
            toast.show("Share the window “Monorail · Shared slide” in your call · it shows only this slide")
        case .demoZoom:
            if demoLens.isRunning { demoLens.stop() } else {
                demoLens.start(.pointer(zoom: 2.2), title: "Monorail · Zoom", frame: NSRect(x: 0, y: 0, width: 520, height: 340), floating: true)
            }
        case .toggleKeystrokes:
            keystrokes.toggle()
            input.echoKeys = keystrokes.isOn
            toast.show(keystrokes.isOn ? "Showing keystrokes and clicks" : "Keystrokes hidden")
        case .toggleAnnotate:
            annotation.toggle(color: accentColor())
            if annotation.isShown { toast.show("Draw with the mouse · C clears · Esc finishes") }
        case .presenterNotes:
            presenterNotesPanel.toggle()
        case .mirrorWindow:
            if windowMirror.isRunning {
                windowMirror.stop()
                return
            }
            guard let id = engine.focusedWindowID() else { return }
            let screen = NSScreen.screens.first { $0 != NSScreen.main } ?? NSScreen.main
            let area = (screen?.visibleFrame ?? .zero).insetBy(dx: 40, dy: 40)
            windowMirror.start(.window(id), title: "Monorail · Mirror", frame: area, floating: false)
        case .guestMode:
            if guestOn {
                guestOn = false
                engine.setPaused(false)
                engine.restoreSnapshot(named: "Before guest mode")
                toast.show("Guest mode off · your layout is back")
            } else {
                engine.saveSnapshot(named: "Before guest mode", quiet: true)
                engine.setPaused(true)
                guestOn = true
                toast.show("Guest mode · Monorail steps aside and keeps your layout safe")
            }
            updateStatusItem()
        case .cameraTile:
            cameraTile.toggle()
        case .pairSync:
            pairSync.toggle()
        case .handoff:
            let host = Host.current().localizedName ?? "Mac"
            engine.saveLayout(named: "Handoff · \(host)")
            toast.show(store.settings.syncThroughICloud
                       ? "Sent · on your other Mac, ⌃⌥/ then “continue from \(host)”"
                       : "Saved · turn on iCloud sync (Settings → General) on both Macs to continue there")
        case .clipboardHistory:
            palette.show(query: "clipboard")
        case .toggleAwake, .awake30, .awake60, .awake120, .awakeWhileDownloading, .toggleAwakeDisplay:
            performAwake(action)
        default:
            break
        }
    }

    private func showTimeline() {
        let view = TimelineView(changes: engine.undoHistory(30)) { [weak self] steps in
            self?.engine.undo(steps: steps)
            self?.timelineWindow?.close()
        }
        let window = timelineWindow ?? NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Layout timeline"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.setContentSize(window.contentView?.fittingSize ?? NSSize(width: 440, height: 360))
        window.center()
        timelineWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func exportSetup() {
        let list = engine.windowList()
        let workspaces = (0..<engine.workspaceCount).map { index -> (name: String, apps: [String]) in
            let apps = list.filter { ($0["workspace"] as? Int) == index + 1 }.compactMap { $0["app"] as? String }
            return (store.settings.workspaceName(index), Array(Set(apps)).sorted())
        }
        let html = SetupExporter.html(settings: store.settings, workspaces: workspaces)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "My Monorail setup.html"
        panel.allowedContentTypes = [.html]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? html.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)
    }


    // MARK: - 1.1

    private func wireUpV11() {
        engine.onAppAction = { [weak self] action in self?.performAppAction(action) }
        engine.onWindowClosed = { [weak self] id, app in
            guard let self else { return }
            self.scripts.emit("windowClosed", ["id": Int(id), "app": app])
            self.postWebhook("window_closed", ["id": Int(id), "app": app])
        }
        engine.onDropCheck = { [weak self] id, _ in
            guard let self, let hit = self.sliderBar.slide(at: NSEvent.mouseLocation) else { return false }
            self.engine.moveWindow(id, intoSlide: hit.column, displayUUID: hit.displayUUID)
            return true
        }
        input.onMiddleClickZoom = { [weak self] point in self?.engine.zoomWindow(at: point) }
        input.onScrollResize = { [weak self] point, delta in self?.engine.resizeSlide(at: point, by: delta) }
        input.onWorkspaceScroll = { [weak self] next in self?.engine.perform(next ? .nextWorkspace : .previousWorkspace) }
        hotCorners.onTrigger = { [weak self] corner in self?.runHotCorner(corner) }
        remoteCommands.onPerform = { [weak self] name in
            guard let self else { return }
            if let action = Action(rawValue: name) {
                self.engine.perform(action)
            } else {
                log.info("Remote command not recognised: \(name, privacy: .public)")
            }
        }
        pomodoro.onTick = { [weak self] text in
            self?.pomodoroText = text
            self?.updateStatusItem()
        }
        pomodoro.onPhase = { [weak self] focusing in
            guard let self else { return }
            self.toast.show(focusing ? "Focus for \(self.pomodoro.focusMinutes) minutes · Monorail keeps the rest out of sight"
                            : "Break time · stand up, look away for \(self.pomodoro.breakMinutes) minutes")
            if focusing != self.engine.isFocusMode { self.engine.setFocusMode(focusing) }
            self.postWebhook(focusing ? "pomodoro_focus" : "pomodoro_break", [:])
        }
        pomodoro.onFocusMinute = { [weak self] in self?.stats.addFocusMinute() }
        breakReminder.onRemind = { [weak self] in
            self?.toast.show("Time for a short break · look 20 feet away for 20 seconds")
        }
        // Focus mode counts towards the daily focus goal.
        focusMinuteTimer = Timer.every(60) { [weak self] _ in
            guard let self, self.engine.isFocusMode, !self.pomodoro.isRunning else { return }
            self.stats.addFocusMinute()
            let goal = self.store.settings.dailyFocusGoal
            if goal > 0, self.stats.today.focusMinutes == goal {
                self.toast.show("Daily focus goal reached · \(InsightsPane.duration(goal)) today")
            }
        }
        integrations.onEvent = { [weak self] event, state in
            guard let self else { return }
            let payload: [String: Any] = event == "workspaceChanged"
                ? ["index": state.workspace, "name": state.workspaceName, "profile": state.profile]
                : ["app": state.app ?? "", "title": state.title ?? ""]
            self.scripts.emit(event, payload)
            if event == "focusChanged" { self.scripts.emit("slideChanged", ["slide": state.slide, "slides": state.slides]) }
            self.postWebhook(event == "workspaceChanged" ? "workspace_changed" : "focus_changed", payload)
        }
    }

    private func postWebhook(_ event: String, _ payload: [String: Any]) {
        EventStream.shared.send(event, payload)
        let url = store.settings.webhookURL.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        Webhook.post(url, event: event, payload: payload)
    }

    private func runHotCorner(_ corner: HotCorner) {
        guard engine.isRunning, !engine.isPaused else { return }
        switch corner {
        case .none: break
        case .overview: overview.toggle()
        case .showDesktop: engine.perform(.showDesktop)
        case .palette: palette.toggle()
        case .focusMode: engine.setFocusMode(!engine.isFocusMode)
        case .cheatSheet: cheatSheet.toggle()
        case .stripZoom: stripZoom.toggle()
        }
    }

    private func accentColor() -> NSColor {
        NSColor(hex: store.settings.focusBorderColor) ?? .controlAccentColor
    }

    /// Actions the engine hands to the app: prompts, the clipboard, timers and flashes.
    // MARK: - Window switcher and displays

    private func wireUpDesktopTools() {
        switcherGrid.windows = { [weak self] in self?.engine.recentWindowSummaries() ?? [] }
        switcherGrid.choose = { [weak self] id in self?.engine.focusAndReveal(id) }
        switcherGrid.closeWindow = { [weak self] id in self?.engine.closeWindow(id) }
        switcherGrid.minimizeWindow = { [weak self] id in self?.engine.minimizeWindow(id) }
        switcherGrid.quitApp = { [weak self] id in
            guard let pid = self?.engine.pid(of: id) else { return }
            NSRunningApplication(processIdentifier: pid)?.terminate()
        }
        switcherGrid.onDismiss = { [weak self] in self?.input.holdSwitcher.reset() }
        input.onHoldSwitcher = { [weak self] event in self?.switcherGrid.handle(event) }
        displayMenu.brightness = { [weak self] uuid in self?.store.settings.displayBrightness[uuid] ?? 1 }
        displayMenu.setBrightness = { [weak self] uuid, value in
            guard let self else { return }
            var settings = self.store.settings
            let clamped = min(max(value, EveningMode.minimumBrightness), 1)
            settings.displayBrightness[uuid] = clamped >= 0.995 ? nil : clamped
            self.store.settings = settings
        }
        displayMenu.notice = { [weak self] text in self?.toast.show(text) }
    }

    /// The macOS app switcher is off exactly while Monorail's switcher has ⌘Tab and its keys work.
    private func updateCommandTab() {
        let take = input.holdSwitcher.shortcut == .commandTab && input.isActive && NativeCommandTab.isAvailable
        if take != commandTabTaken || (!take && NativeCommandTab.wasLeftOff) {
            commandTabTaken = take
            NativeCommandTab.setEnabled(!take)
        }
    }

    private func performAppAction(_ action: Action) {
        switch action {
        case .renameWorkspace:
            guard let status = engine.status() else { return }
            let index = status.workspace - 1
            guard let name = TextPrompt.ask(
                title: "Rename this workspace", message: "Shown in the slider, the overview and the menu bar.",
                initial: store.settings.workspaceName(index), placeholder: "Mail, Code, Design…")
            else { return }
            var settings = store.settings
            settings.setWorkspaceName(name, at: index)
            store.settings = settings
            engine.onStateChange()
        case .noteWindow:
            guard let id = engine.focusedWindowID(), let note = TextPrompt.ask(
                title: "Note on this window",
                message: "A reminder of what this window is for. Shown in the overview and found by the command palette.",
                initial: engine.note(of: id) ?? "", placeholder: "Reply to Sam by 3 pm", button: "Save")
            else { return }
            engine.setNote(note, for: id)
        case .quickLaunchBeside:
            toast.show("Open beside: type an app’s letter")
            let beside = engine.focusedWindowID()
            input.captureNextKey = { [weak self] letter in
                guard let self, let letter else { return }
                self.engine.quickLaunch(letter)
                self.pairWhenFocusChanges(from: beside)
            }
        case .openLinkBeside:
            guard let text = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
                let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? "")
            else {
                toast.show("Copy a link first · then open it beside this window")
                return
            }
            let beside = engine.focusedWindowID()
            NSWorkspace.shared.open(url)
            pairWhenFocusChanges(from: beside)
        case .copyLayout:
            guard let json = engine.layoutJSON() else {
                toast.show("Nothing to copy in this workspace")
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
            toast.show("Layout copied · paste it on another workspace or Mac")
        case .pasteLayout:
            let text = NSPasteboard.general.string(forType: .string) ?? ""
            toast.show(engine.applyLayoutJSON(text) ? "Layout pasted" : "The clipboard has no Monorail layout with open windows")
        case .locatePointer:
            pointerLocator.show(color: accentColor())
        case .flashFocus:
            if let frame = engine.focusedFrame() { focusFlash.flash(frame, color: accentColor()) }
        case .pomodoro:
            pomodoro.focusMinutes = store.settings.pomodoroFocus
            pomodoro.breakMinutes = store.settings.pomodoroBreak
            if pomodoro.isRunning {
                pomodoro.stop()
                if engine.isFocusMode { engine.setFocusMode(false) }
                toast.show("Pomodoro stopped")
            } else {
                pomodoro.start(.focus)
            }
        case .restart:
            WindowThumbnails.relaunch()
        case .openSettings:
            showSettings()
        case .checkForUpdates:
            updater.check(userInitiated: true)
        case .toggleEvening:
            toggleEveningFromMenu()
        case .keepAvailable:
            toggleKeepAvailableFromMenu()
        case .displayBrighter, .displayDimmer:
            guard let display = actionDisplay() else { return }
            displayMenu.step(display.uuid, name: display.name, brighter: action == .displayBrighter)
        case .displayMoreSpace, .displayLargerText, .displayDefaultResolution:
            guard let display = actionDisplay() else { return }
            displayMenu.changeResolution(display.id, name: display.name, action: action)
        default:
            performAppActionV12(action)
        }
    }

    /// The display a display action applies to: the engine's choice, or (before it runs, without
    /// Accessibility) the one under the pointer.
    private func actionDisplay() -> (id: CGDirectDisplayID, uuid: String, name: String)? {
        if let display = engine.activeDisplay() { return display }
        let mouse = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let point = CGPoint(x: mouse.x, y: primaryHeight - mouse.y)
        let all = Display.all()
        guard let display = all.first(where: { $0.frame.contains(point) }) ?? all.first else { return nil }
        return (display.id, display.uuid, display.name)
    }

    /// After launching something "beside", pairs its window with the one you were in.
    private func pairWhenFocusChanges(from beside: WindowID?, attempts: Int = 0) {
        guard let beside, attempts < 20 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            guard let now = self.engine.focusedWindowID(), now != beside else {
                self.pairWhenFocusChanges(from: beside, attempts: attempts + 1)
                return
            }
            self.engine.pairWindows([beside, now], arrangement: .columns)
        }
    }

    private func startEngine() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        input.start()
        updateCommandTab()
        engine.start()
        startSuiteChannel()
        if engine.crashedLastRun {
            // After the windows are rescued and things have settled.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                guard let self else { return }
                ProblemReport.askAfterCrash(store: self.store)
            }
        }
        apply(store.settings)
        updateStatusItem()
        autoRules.start()
        migrateMouseButtons()
        EventStream.shared.start()
        weekly.stats = stats
        weekly.workspaceTitle = { [weak self] index in self?.engine.workspaceTitle(index) ?? "" }
        weekly.isEnabled = { [weak self] in self?.store.settings.weeklySummary ?? false }
        weekly.start()
        // Once a minute, note which apps share slides (for Insights).
        statsTimer = Timer.every(60) { [weak self] _ in
            guard let self, self.engine.isRunning, !self.engine.isPaused else { return }
            self.stats.sample(slides: self.engine.slideApps(), slideCount: self.engine.slideCount)
            if let state = self.currentState() {
                self.stats.addMinute(workspace: state.workspaceName, app: state.app)
            }
        }
    }

    /// What needs no Accessibility: settings, sync, usage counts and What's New. Stay Awake,
    /// Evening Mode and the display controls are wired up in `wireUp`. Runs once, at launch.
    private func startEssentials() {
        apply(store.settings)
        // Calls, films and heat (works in Signalbox's sandbox too).
        MomentsWatch.shared.settings = { [weak self] in self?.store.settings ?? AppSettings() }
        MomentsWatch.shared.onFilmChange = { [weak self] on in self?.evening.pauseForFilm(on) }
        MomentsWatch.shared.start()
        BatteryLog.shared.start()
        StorageWatch.shared.start()
        MonorailNudgeWatch.shared.start()
        SuiteRole.shared.settings = { [weak self] in self?.store.settings ?? AppSettings() }
        SuiteRole.shared.onChange = { [weak self] role in self?.roleChanged(role) }
        SuiteRole.shared.onAreasChange = { [weak self] fresh in self?.areasChanged(fresh) }
        SuiteRole.shared.$asking.receive(on: DispatchQueue.main).sink { [weak self] asking in
            guard let self, asking.contains(.island), !self.islandAskedThisRun else { return }
            self.islandAskedThisRun = true
            IslandChoice.show { [weak self] app in self?.choose(.island, app) }
        }.store(in: &subscriptions)
        SuiteRole.shared.start()
        DashboardContext.store = store
        DashboardContext.openSettings = { [weak self] in self?.showSettings() }
        DeskContext.focus = { [weak self] id in self?.engine.focusAndReveal(WindowID(id)) }
        DeskContext.save = { [weak self] in self?.engine.perform(.takeSnapshot) }
        SystemAlerts.shared.enabled = { [weak self] in self?.store.settings.systemAlerts ?? true }
        SystemRecorder.shared.start()
        AIUsageWatch.shared.store = store
        AIUsageWatch.shared.start()
        SwitchContext.store = store
        SwitchContext.awakeIsOn = { [weak self] in self?.awake.isOn ?? false }
        SwitchContext.awakeSet = { [weak self] on in
            guard let self else { return }
            if on { self.awake.start(minutes: self.store.settings.awakeDefaultMinutes) } else { self.awake.end() }
        }
        SwitchContext.sharingScreen = { [weak self] in self?.shareWatch.isSharing ?? false }
        Switchboard.shared.start()
        MeetingRecorder.shared.store = store
        MomentsWatch.shared.onCallChange = { started in MeetingRecorder.shared.callChanged(started) }
        NowPlaying.shared.start()
        NotchLive.shared.open = { [weak self] in
            guard let self, let button = self.statusItem?.button, !self.popover.isShown else { return }
            self.popover.toggle(relativeTo: button)
        }
        NotchLive.shared.activities = { [weak self] in
            guard let self else { return [] }
            var list: [NotchActivity] = []
            let now = Date()
            if self.shareWatch.isSharing { list.append(NotchActivity(.sharing, symbol: "rectangle.inset.filled.and.person.filled", text: "Sharing", tint: "red")) }
            if let meeting = TodayWatch.shared.meetings.first(where: { $0.start <= now && $0.end > now }) {
                list.append(NotchActivity(.call, symbol: "video.fill", text: NotchActivity.countdown(meeting.end.timeIntervalSince(now)), tint: "green"))
            }
            if MeetingRecorder.shared.recording {
                list.append(NotchActivity(.recording, symbol: "waveform", text: MeetingNotes.clock(MeetingRecorder.shared.elapsed), tint: "red"))
            } else if Switchboard.shared.activeModes.contains("recording") {
                list.append(NotchActivity(.recording, symbol: "record.circle", text: "Rec", tint: "red"))
            } else if let id = Switchboard.shared.activeModes.first, let mode = self.store.settings.modes.first(where: { $0.id == id }) {
                list.append(NotchActivity(.mode, symbol: mode.symbol, text: mode.name, tint: "purple"))
            }
            if FocusWatch.shared.endsAt != nil, FocusWatch.shared.remaining > 0 {
                list.append(NotchActivity(.timer, symbol: "timer", text: NotchActivity.countdown(FocusWatch.shared.remaining), tint: "orange"))
            }
            if PowerWatch.hasBattery {
                let b = PowerWatch.shared.battery
                if b.onBattery && b.percent <= 15 { list.append(NotchActivity(.batteryLow, symbol: "battery.25", text: "\(b.percent)%", tint: "red")) }
                else if b.isCharging { list.append(NotchActivity(.charging, symbol: "bolt.fill", text: "\(b.percent)%", tint: "green")) }
            }
            if let top = AIUsageWatch.shared.headline, top.window.usedPercent >= 90 {
                list.append(NotchActivity(.aiLimit, symbol: "brain", text: "\(Int(top.window.usedPercent))%", tint: "orange"))
            }
            if self.awake.isOn { list.append(NotchActivity(.awake, symbol: "cup.and.saucer.fill", text: "Awake", tint: "blue")) }
            // Only once the Storage page has looked in Downloads (so macOS has already asked, in context).
            if !Edition.isAppStore, UserDefaults.standard.bool(forKey: "DownloadsReadable") {
                let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path
                let names = (try? FileManager.default.contentsOfDirectory(atPath: downloads)) ?? []
                if let label = Downloading.label(Downloading.inProgress(names)) {
                    list.append(NotchActivity(.download, symbol: "arrow.down.circle.fill", text: label, tint: "blue"))
                }
            }
            if let music = NowPlaying.shared.activity { list.append(music) }
            return list
        }
        NotchOpener.shared.open = { [weak self] in
            guard let self, let button = self.statusItem?.button, !self.popover.isShown else { return }
            self.popover.toggle(relativeTo: button, page: .clipboard)
        }
        // Shortcuts and Spotlight actions.
        ShortcutsBridge.stayAwake = { [weak self] minutes in self?.awake.start(minutes: minutes) }
        ShortcutsBridge.endStayAwake = { [weak self] in self?.awake.end() }
        ShortcutsBridge.setEvening = { [weak self] on in self?.store.settings.eveningOn = on }
        ShortcutsBridge.arrange = { [weak self] text in
            guard let self, !Edition.isAppStore else { return false }
            if self.engine.layouts.contains(where: { $0.name.caseInsensitiveCompare(text) == .orderedSame }) {
                self.engine.applyLayout(named: text)
                return true
            }
            return self.say(text)
        }
        FocusWatch.shared.settings = { [weak self] in self?.store.settings ?? AppSettings() }
        FocusWatch.shared.onRunningChange = { [weak self] on in
            guard let self, !Edition.isAppStore, self.store.settings.focusHidesApps else { return }
            on ? self.deepWork.start() : self.deepWork.stop()
        }
        store.startCloudSync()
        store.watchFile()
        startTelemetry()
        // After an update: what changed. (Not on a first install.)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if store.settings.hasCompletedOnboarding, !version.isEmpty, store.settings.lastSeenVersion != version {
            // One notice, then What's New only for a release with something new to show.
            toast.show("Updated to Monorail \(version)")
            whatsNew.store = store
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.whatsNew.showIfNotable(version: version) }
        }
        if store.settings.lastSeenVersion != version { store.settings.lastSeenVersion = version }
        updateStatusItem()
    }

    /// Waits quietly for Accessibility (never asks again by itself), then starts. macOS posts a
    /// notification when the list changes; the slow timer is a fallback.
    private func waitForPermission() {
        let check: () -> Void = { [weak self] in
            guard let self, self.permissionTimer != nil, Accessibility.isTrusted(prompt: false) else { return }
            self.startEngine()
            self.updateStatusItem()
            self.toast.show("Accessibility allowed · Monorail now arranges your windows")
        }
        permissionTimer = Timer.every(5) { _ in check() }
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { _ in
            // The answer is stored a moment after the notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { check() }
        }
    }

    private var chosenAppearance: NSAppearance?
    private var appearanceObservers: [NSObjectProtocol] = []

    /// Every window of ours takes the chosen theme, except the menu bar's, which follows the menu bar.
    private func applyChosenAppearance() {
        for window in NSApp.windows where !window.className.contains("StatusBar") && !window.className.contains("NSMenu") {
            if window.appearance?.name != chosenAppearance?.name { window.appearance = chosenAppearance }
        }
        statusItem?.button?.appearance = nil
        guard appearanceObservers.isEmpty else { return }
        // New windows and panels pick it up as they appear.
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didChangeOcclusionStateNotification] {
            appearanceObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let self, let window = note.object as? NSWindow,
                    !window.className.contains("StatusBar"), !window.className.contains("NSMenu"),
                    window.appearance?.name != self.chosenAppearance?.name else { return }
                window.appearance = self.chosenAppearance
            })
        }
    }

    private func apply(_ original: AppSettings) {
        let settings = Edition.restrict(adjustedV12(original))
        let syncWasOn = engine.settings.syncThroughICloud
        let liveReloadWasOn = engine.settings.liveReloadSettings
        engine.settings = settings
        ClipboardWatch.shared.apply(settings)
        let islandHere = settings.notchLive && !SuiteRole.shared.pauses(.notch) && !SuiteRole.shared.rests(.island)
        NotchLive.shared.set(islandHere)
        VolumeWatch.shared.enabled = islandHere && settings.volumeHUD
        MenuBarReadings.shared.apply(SuiteRole.shared.rests(.menuBarReadings) ? [] : settings.menuBarReadings)
        FocusWatch.shared.apply(settings)
        // The theme goes on Monorail's own windows only. Set on the whole app, it also reached the
        // menu bar icon, which then came out black on a dark menu bar (or white on a light one).
        chosenAppearance = {
            switch settings.appAppearance {
            case .system: return nil
            case .light: return NSAppearance(named: .aqua)
            case .dark: return NSAppearance(named: .darkAqua)
            }
        }()
        NSApp.appearance = nil
        applyChosenAppearance()
        if settings.pauseForStageManager != (stageManagerTimer != nil) { watchStageManager() }
        PowerWatch.shared.parkOnBattery = settings.parkPowerHogs
        PowerWatch.shared.showMarkers = settings.powerMarkers
        PowerWatch.shared.isEnabled = true
        updateBatteryItem(settings.batteryMenuBar)
        updateStatusItem()
        evening.update()
        // Settings that change what Monorail has on change what Keeper hears (once per real change).
        SuiteRole.shared.evaluateAreas()
        if suite != nil, suiteAnnouncement != lastSuiteAnnouncement { publishSuiteHello() }
        WorkspaceColor.theme = settings.theme
        stats.isEnabled = settings.collectStats
        autoRules.rules = settings.autoRules
        if settings.syncThroughICloud != syncWasOn { store.startCloudSync() }
        input.keymap = settings.keymap
        input.modifierSwipe = settings.modifierSwipe
        input.scrollModifier = settings.scrollModifier
        input.scrollOverMenuBar = settings.scrollOverMenuBar
        input.slideTrigger = settings.slideTrigger
        input.pinchForOverview = settings.pinchForOverview
        input.modifierDrag = settings.modifierDrag
        if settings.capsLockKey != capsLockOn {
            capsLockOn = settings.capsLockKey
            CapsLockKey.set(settings.capsLockKey)
            input.capsLockKey = settings.capsLockKey
        }
        updater.betaChannel = settings.betaUpdates
        input.pinchZoomsStrip = settings.pinchZoomsStrip
        trackpad.detectsVertical = settings.verticalWorkspaceSwipes
        meetings.isEnabled = settings.meetingHelper
        Localization.choose(settings.language)
        if settings.localAPI != engine.settings.localAPI || settings.apiPort != engine.settings.apiPort || !apiStarted {
            apiStarted = true
            if settings.localAPI { api.start(port: settings.apiPort) } else { api.stop() }
        }
        if settings.scripts != scriptsOn {
            scriptsOn = settings.scripts
            if settings.scripts { scripts.load() } else { scripts.unload() }
        }
        input.titleBarSwipes = settings.titleBarSwipes
        if settings.liveReloadSettings != liveReloadWasOn { store.watchFile() }
        snapPicker.isEnabled = settings.snapPicker
        snapPicker.edgeSnapping = settings.edgeSnapping
        snapPicker.defersToMacOS = settings.edgeSnappingDefersToMacOS
        input.holdSwitcher.shortcut = settings.windowSwitcherShortcut
        updateCommandTab()
        updateArrowItems(visible: settings.showNavigationArrows)
        updater.setAutomatic(settings.checkForUpdates)
        updater.installAutomatically = settings.installUpdatesAutomatically
        hotEdges.onSlide = { [weak self] right in self?.engine.step(forward: right, honourReverse: false, visual: true) }
        hotEdges.setEnabled(settings.hotEdges && engine.isRunning)
        sliderBar.compact = settings.compactSlider
        sliderBar.showTitles = settings.sliderTitles
        sliderBar.iconsOnly = settings.sliderIconsOnly
        sliderBar.peekEnabled = settings.peekWithOption
        popover.peekEnabled = settings.peekWithOption
        sliderBar.edge = settings.sliderBarEdge
        sliderBar.opacity = settings.sliderOpacity
        sliderBar.scale = settings.sliderScale
        sliderBar.update()
        toast.position = settings.noticePosition
        toast.duration = settings.noticeDuration
        OverviewStyle.plain = settings.plainOverview
        OverviewStyle.iconsOnly = settings.overviewIconsOnly
        WorkspaceColor.overrides = settings.workspaceConfigs.reduce(into: [:]) { result, entry in
            if let index = Int(entry.key), let color = entry.value.color, !color.isEmpty { result[index] = color }
        }
        input.mouseButtonsStep = settings.mouseButtonsStep
        input.thumbWheelSlides = settings.thumbWheelSlides
        input.middleClickZoom = settings.middleClickZoom
        input.scrollResizes = settings.scrollResizes
        input.shiftScrollSwitchesWorkspace = settings.shiftScrollSwitchesWorkspace
        hotCorners.corners = settings.hotCorners
        hotCorners.setEnabled(settings.hotCorners.contains { $0 != .none })
        remoteCommands.setEnabled(settings.remoteCommands)
        breakReminder.set(minutes: settings.breakReminderMinutes)
        pomodoro.focusMinutes = settings.pomodoroFocus
        pomodoro.breakMinutes = settings.pomodoroBreak
        applyV12(settings)

        trackpad.fingers = settings.swipeFingers.rawValue
        trackpad.detectsTap = settings.threeFingerTapOverview
        if settings.swipeFingers == .off && !settings.threeFingerTapOverview {
            trackpad.stop()
        } else if engine.isRunning {
            trackpad.start()
        }

        if settings.focusFollowsMouse, mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                let location = NSEvent.mouseLocation
                let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
                self?.engine.mouseMoved(to: CGPoint(x: location.x, y: primaryHeight - location.y))
            }
        } else if !settings.focusFollowsMouse, let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        updateStatusItem()
    }

    /// Quitting from the terminal (or a logout) still puts windows back.
    private func handleTerminationSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }

    // MARK: - Menu bar

    /// Left-click opens the slider popover; right-click or ⌃-click opens the menu.
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu || !store.settings.iconOpensSlider || !engine.isRunning {
            // Pop the menu up directly: this returns only after the user picks an
            // item (or dismisses it), so the chosen action is always delivered.
            menuNeedsUpdate(statusMenu)
            statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
        } else {
            popover.toggle(relativeTo: sender)
        }
    }

    /// True for points (Accessibility coordinates) on any display's menu bar.
    private static func isOverMenuBar(_ point: CGPoint) -> Bool {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return false }
        let cocoa = CGPoint(x: point.x, y: primaryHeight - point.y)
        return NSScreen.screens.contains { screen in
            let frame = screen.frame
            let menuBarHeight = max(frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
            return cocoa.x >= frame.minX && cocoa.x < frame.maxX
                && cocoa.y <= frame.maxY && cocoa.y >= frame.maxY - menuBarHeight
        }
    }

    /// The ‹ › buttons next to the menu bar icon. Created after the main item,
    /// so they sit to its left.
    private func updateArrowItems(visible: Bool) {
        if !visible {
            arrowItems.forEach { NSStatusBar.system.removeStatusItem($0) }
            arrowItems.removeAll()
            return
        }
        guard arrowItems.isEmpty else { return }
        // One narrow item for both directions: its left half goes back, its right half forward.
        let item = NSStatusBar.system.statusItem(withLength: 24)
        item.button?.image = StatusIcon.arrows()
        item.button?.toolTip = "Previous / next window (scroll over the menu bar works too)"
        item.button?.target = self
        item.button?.action = #selector(arrowClicked(_:))
        arrowItems.append(item)
    }

    @objc private func arrowClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let x = sender.convert(event.locationInWindow, from: nil).x
        if x < sender.bounds.midX { stepLeft() } else { stepRight() }
    }

    /// Window commands shared by the slider-bar previews, popover and overview.
    private func windowCommands() -> WindowCommands {
        var commands = WindowCommands()
        commands.focus = { [weak self] id in self?.engine.focusAndReveal(id) }
        commands.close = { [weak self] id in self?.engine.closeWindow(id) }
        commands.minimize = { [weak self] id in self?.engine.minimizeWindow(id) }
        commands.fullScreen = { [weak self] id in self?.engine.toggleFullScreen(id) }
        commands.ownSlide = { [weak self] id in self?.engine.giveOwnSlide(id) }
        commands.rename = { [weak self] id in self?.renameWindow(id) }
        commands.moveToWorkspace = { [weak self] id, index in self?.engine.moveWindow(id, toWorkspace: index) }
        commands.workspaceNames = { [weak self] in
            guard let self else { return [] }
            return (0..<self.engine.workspaceCount).map(self.store.settings.workspaceName)
        }
        commands.currentWorkspace = { [weak self] id in self?.engine.workspaceIndex(of: id) }
        commands.setLayout = { [weak self] id, arrangement in self?.engine.setSlideLayout(of: id, to: arrangement) }
        commands.currentLayout = { [weak self] id in self?.engine.slideLayout(of: id) ?? nil }
        commands.customLayouts = { [weak self] in self?.store.settings.customLayouts ?? [] }
        commands.appBundleID = { [weak self] id in self?.engine.bundleID(of: id) }
        commands.setCustomLayout = { [weak self] id, rows in self?.engine.setSlideLayout(of: id, to: .custom, rows: rows) }
        commands.setZones = { [weak self] id, zones in self?.engine.setSlideZones(of: id, to: zones) }
        commands.currentRows = { [weak self] id in self?.engine.slideRows(of: id) }
        commands.saveAppPair = { [weak self] id in self?.saveAppPair(from: id) }
        commands.isSticky = { [weak self] id in self?.engine.isSticky(id) ?? false }
        commands.toggleSticky = { [weak self] id in self?.engine.toggleSticky(id) }
        commands.pictureInPicture = { [weak self] id in self?.showPictureInPicture(id) }
        commands.nameSlide = { [weak self] id in self?.askForSlideName(id, current: self?.engine.slideName(of: id) ?? "") }
        commands.isSlideLocked = { [weak self] id in self?.engine.isSlideLocked(id) ?? false }
        commands.toggleLock = { [weak self] id in self?.engine.toggleLock(id) }
        commands.neverManage = { [weak self] id in self?.neverManage(id) }
        commands.setSize = { [weak self] id, size in self?.engine.setFloatingSize(id, size) }
        return commands
    }

    /// Marks: after the shortcut, the next key typed is the mark's letter.
    /// Marks and quick launch: after the shortcut, the next key typed is the letter.
    private func readMarkLetter(for action: Action) {
        switch action {
        case .setMark: toast.show("Mark this window: type a letter")
        case .quickLaunch: toast.show("Quick launch: type an app’s letter")
        default: toast.show("Jump to mark: type its letter")
        }
        input.captureNextKey = { [weak self] letter in
            guard let self, let letter else { return }
            switch action {
            case .setMark: self.engine.setMark(letter)
            case .quickLaunch: self.engine.quickLaunch(letter)
            default: self.engine.jumpToMark(letter)
            }
        }
    }

    private func showPictureInPicture(_ id: WindowID) {
        let title = engine.allWindowSummaries().first { $0.id == id }.map { $0.title.isEmpty ? $0.appName : $0.title } ?? ""
        pictureInPicture.toggle(id, title: title)
    }

    static func snapshotName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    private func takeSnapshot() {
        guard let name = TextPrompt.ask(
            title: "Take a session snapshot",
            message: "Saves every workspace of every profile and which apps are open. Restore it from Snapshots in the menu bar, even after a restart: Monorail reopens the apps and puts their windows back.",
            initial: Self.snapshotName(), placeholder: "Before the weekend", button: "Save")
        else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        engine.saveSnapshot(named: trimmed.isEmpty ? Self.snapshotName() : trimmed)
    }

    // MARK: - 0.8: hints, resize mode, templates, meetings, sharing, API, scripts, practice

    @objc private func redoLayout() { afterMenu { $0.engine.redo() } }
    @objc private func undoToStep(_ sender: NSMenuItem) {
        let steps = sender.tag
        afterMenu { $0.engine.undo(steps: steps) }
    }
    @objc private func toggleFitFromMenu() { afterMenu { $0.engine.perform(.toggleFitMode) } }
    @objc private func rescueFromMenu() { afterMenu { $0.engine.rescueWindows() } }

    private func askForSlideName(_ id: WindowID, current: String) {
        guard let name = TextPrompt.ask(
            title: "Name this slide",
            message: "Shown in the slider, the overview and the command palette. Leave empty for no name.",
            initial: current, placeholder: "Writing, Review, Call…", button: "Name")
        else { return }
        engine.nameSlide(id, name)
    }

    /// Floats the window's app from now on (a rule in Settings → Apps).
    private func neverManage(_ id: WindowID) {
        guard let window = engine.allWindowSummaries().first(where: { $0.id == id }),
            let bundleID = engine.windowList().first(where: { ($0["id"] as? Int) == Int(id) })?["bundleID"] as? String
        else { return }
        engine.release(id)
        if let index = store.settings.appRules.firstIndex(where: { $0.bundleID == bundleID && !$0.isTitleRule }) {
            store.settings.appRules[index].float = true
        } else {
            store.settings.appRules.append(AppRule(bundleID: bundleID, name: window.appName, float: true))
        }
        toast.show("Monorail leaves \(window.appName) alone now · change it in Settings → Apps")
    }

    private func copyDiagnostics() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        var text = "\(Brand.full) \(version) on macOS \(os)\n"
        text += "Accessibility: \(Accessibility.isTrusted(prompt: false) ? "allowed" : "not allowed"), "
        text += "Screen Recording: \(WindowThumbnails.isAllowed ? "allowed" : "not allowed")\n"
        text += engine.diagnostics()
        text += "\nSettings: grouping \(store.settings.groupByApp), \(store.settings.tilesPerSlide) per slide, "
        text += "\(store.settings.workspaceCount) workspaces, slider bar \(store.settings.sliderBar.rawValue), "
        text += "gaps \(Int(store.settings.layout.gap))/\(Int(store.settings.layout.edgeGap))"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        toast.show("Diagnostics copied · paste them into a bug report")
    }

    // MARK: AppleScript

    func scriptPerform(_ name: String) -> Bool {
        guard let action = Action(rawValue: name) else { return false }
        engine.perform(action)
        return true
    }

    func scriptOpen(_ kind: String, _ name: String) -> Bool {
        switch kind {
        case "layout": engine.applyLayout(named: name)
        case "pair":
            guard let pair = store.settings.appPairs.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return false }
            engine.openPair(pair)
        case "template":
            guard let template = store.settings.templates.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return false }
            engine.runTemplate(template)
        case "snapshot": engine.restoreSnapshot(named: name)
        default: return false
        }
        return true
    }

    func scriptState() -> String {
        guard let state = currentState(), let data = try? JSONEncoder().encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func scriptWindows() -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: engine.windowList(), options: [.sortedKeys]) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    @objc private func togglePresentation() { afterMenu { $0.engine.setPresenting(!$0.engine.isPresenting) } }
    @objc private func stopRecording() { afterMenu { $0.engine.perform(.recordSlide) } }

    private func showHints() {
        let map = hints.show(engine.visibleWindowFrames())
        guard !map.isEmpty else {
            toast.show("No windows on screen")
            return
        }
        input.captureNextKey = { [weak self] letter in
            self?.hints.hide()
            guard let letter, let id = map[letter] else { return }
            self?.engine.focusAndReveal(id)
        }
    }

    /// Resize mode: ← → width, ↑ ↓ the main share, 1–9 tenths, 0 full width; esc or return ends it.
    private func setResizeMode(_ on: Bool) {
        resizeModeTimer?.invalidate()
        guard on else {
            input.keyInterceptor = nil
            return
        }
        toast.show("Resize mode · ← → width · ↑ ↓ split · 1–9 tenths · 0 full · esc when done")
        let restart = { [weak self] in
            self?.resizeModeTimer?.invalidate()
            self?.resizeModeTimer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { _ in self?.setResizeMode(false) }
        }
        restart()
        input.keyInterceptor = { [weak self] keyCode, modifiers in
            guard let self else { return false }
            if keyCode == KeyCode.escape || keyCode == KeyCode.returnKey {
                DispatchQueue.main.async { self.setResizeMode(false) }
                return true
            }
            guard modifiers.isEmpty || modifiers == [.shift] else { return false }
            // The event tap runs on the main thread, so the engine can be asked directly.
            let handled = self.engine.resizeKey(keyCode)
            DispatchQueue.main.async { if handled { restart() } else { self.setResizeMode(false) } }
            return handled
        }
    }

    /// Templates ▸ each template to start.
    private func templatesMenu() -> NSMenuItem {
        let menu = NSMenu()
        for template in store.settings.templates {
            let entry = item(template.name, #selector(runTemplateFromMenu(_:)))
            entry.representedObject = template.id
            menu.addItem(entry)
        }
        let parent = NSMenuItem(title: L("Templates"), action: nil, keyEquivalent: "")
        parent.submenu = menu
        return parent
    }

    @objc private func runTemplateFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
            let template = store.settings.templates.first(where: { $0.id == id })
        else { return }
        afterMenu { $0.engine.runTemplate(template) }
    }

    private func joinMeeting(_ title: String, _ link: URL) {
        if let profile = store.settings.meetingProfile { engine.switchProfile(to: profile) }
        guard store.settings.meetingLayout,
            let notes = NSWorkspace.shared.urlForApplication(withBundleIdentifier: store.settings.meetingNotesApp)
        else {
            NSWorkspace.shared.open(link)
            toast.show("Joining “\(title)”")
            return
        }
        // Keep the layout to come back to, open the notes app, then the call beside it.
        engine.saveSnapshot(named: Self.beforeMeeting, quiet: true)
        NSWorkspace.shared.openApplication(at: notes, configuration: NSWorkspace.OpenConfiguration())
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            let notesWindow = self.engine.focusedWindowID()
            NSWorkspace.shared.open(link)
            self.pairWhenFocusChanges(from: notesWindow)
            self.toast.show("Joining “\(title)” with your notes beside it · ⌃⌥/ then “after the meeting” puts things back")
        }
    }

    static let beforeMeeting = "Before the meeting"

    /// A tip, once ever.
    private func tipOnce(_ id: String, _ text: String) {
        guard !store.settings.seenTips.contains(id) else { return }
        var settings = store.settings
        settings.seenTips.append(id)
        store.settings = settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.toast.show("Tip · " + text) }
    }

    // MARK: Sharing layouts

    /// A shared layout or template file (.monorail).
    struct SharedFile: Codable {
        var kind: String
        var layout: SavedLayout?
        var template: WorkspaceTemplate?
        var appPair: AppPair?
    }

    @objc private func shareLayout(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, let layout = engine.layouts.first(where: { $0.name == name })
        else { return }
        export(SharedFile(kind: "layout", layout: layout), suggested: name)
    }

    func shareTemplate(_ template: WorkspaceTemplate) {
        export(SharedFile(kind: "template", template: template), suggested: template.name)
    }

    private func export(_ file: SharedFile, suggested: String) {
        afterMenu { _ in
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "\(suggested).monorail"
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try? encoder.encode(file).write(to: url, options: .atomic)
        }
    }

    /// Double-clicking a .monorail file: a layout is saved and applied, a template added and started.
    private func openSharedFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url), let file = try? JSONDecoder().decode(SharedFile.self, from: data) else {
            toast.show("That isn’t a Monorail layout file")
            return
        }
        importShared(file)
    }

    static let shareBase = "https://ashfordeou.github.io/monorail/share/#"

    @objc private func copyShareLink(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, let layout = engine.layouts.first(where: { $0.name == name })?.forSharing()
        else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(SharedFile(kind: "layout", layout: layout)) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.shareBase + Self.base64URL(data), forType: .string)
        toast.show("Link to “\(name)” copied · anyone with Monorail can open it")
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func fromBase64URL(_ text: String) -> Data? {
        var s = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }

    /// monorail://import/<data> from a share link: asks first, since it came from the web.
    private func importLink(_ encoded: String) {
        guard let data = Self.fromBase64URL(encoded), let file = try? JSONDecoder().decode(SharedFile.self, from: data) else {
            toast.show("That share link is incomplete or damaged")
            return
        }
        let name = file.layout?.name ?? file.template?.name ?? file.appPair?.name ?? "Shared"
        let what = file.layout != nil ? "layout" : file.template != nil ? "workspace template" : "app pair"
        let alert = NSAlert()
        alert.messageText = "Add the \(what) “\(name)”?"
        alert.informativeText = file.template != nil
            ? "It came from a link. Starting it may open apps and web pages it lists."
            : "It came from a link. It only arranges windows you have open."
        alert.addButton(withTitle: "Add and Use")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        importShared(file)
    }

    private func importShared(_ file: SharedFile) {
        if let layout = file.layout {
            engine.importLayout(layout)
            engine.applyLayout(named: layout.name)
        } else if let template = file.template {
            store.settings.templates.removeAll { $0.name == template.name }
            store.settings.templates.append(template)
            engine.runTemplate(template)
        } else if let pair = file.appPair {
            store.settings.appPairs.removeAll { $0.name == pair.name }
            store.settings.appPairs.append(pair)
            engine.openPair(pair)
        }
    }

    // MARK: Ashforde suite channel (App Group + doorbell; works inside the sandbox)

    private var suite: SuiteChannel?
    /// This app's name on the shared channel.
    private static var suiteName: String { Edition.isAppStore ? "station" : "monorail" }

    /// Signalbox, resting: asks Monorail to do something (Stay Awake), through the shared channel.
    private func askMonorail(_ op: String, _ args: [String: String] = [:]) {
        guard let suite else { return }
        suite.send(to: "monorail", from: Self.suiteName, op: op, args: args)
        ringSuiteDoorbell()
    }

    /// Signalbox steps back while Monorail runs and takes over again when it quits (SuiteRoles).
    private func roleChanged(_ role: SuiteRoles.Role) {
        guard Edition.isAppStore else { return }
        if role == .resting {
            // A Stay Awake session carries on in Monorail rather than stopping.
            if let session = awake.session {
                var args = ["for": "0"]  // 0: until turned off
                if case .until(let end) = session, let minutes = SuiteRoles.handoffMinutes(endsAt: end) { args["for"] = "\(minutes)m" }
                askMonorail("awake.on", args)
                awake.end()
            }
            statusItem?.isVisible = false
        } else {
            statusItem?.isVisible = true
        }
        // Each job looks at the role again: colours, clipboard, eye breaks, notifications.
        evening.update()
        apply(store.settings)
        publishSuiteHello()
    }

    private func startSuiteChannel() {
        guard suite == nil,
            let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SuiteChannel.appGroup)
        else { return }
        suite = SuiteChannel(container: container)
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(SuiteChannel.doorbell), object: nil, queue: .main
        ) { [weak self] _ in self?.suiteDoorbell() }
        publishSuiteHello()
        suiteDoorbell()
    }

    /// Monorail's hello, in the shape Keeper's PeerHello reads.
    private var suiteHello: [String: Any] {
        [
            "app": Brand.name, "bundleID": Bundle.main.bundleIdentifier ?? BundleIDs.current,
            "version": Bundle.main.shortVersion, "pid": Int(ProcessInfo.processInfo.processIdentifier),
            "owns": suiteOwns,
            "prefer": store.settings.suitePrefer,
            "preferAt": store.settings.suitePreferAt,
            "role": SuiteRole.shared.role.rawValue,
            "caps": ["closedLid": !Edition.isAppStore, "closedLidReady": false],
            "state": ["awake": awake.isOn, "awakeStatus": awake.statusText, "paused": engine.isPaused, "focusMode": engine.isFocusMode, "presenting": engine.isPresenting,
                      "live": suiteLive.map(\.json)] as [String: Any],
            "links": ["monorail://settings", "monorail://awake", "monorail://awake/off"],
        ]
    }

    private func publishSuiteHello() {
        guard let suite else { return }
        suite.writeHello(Self.suiteName, suiteHello)
        suite.writeState(Self.suiteName, ["live": suiteLive.map(\.json), "at": Date().timeIntervalSince1970 * 1000])
        lastSuiteAnnouncement = suiteAnnouncement
        ringSuiteDoorbell()
    }

    /// What the hello says Monorail has on (SuiteArea), in the agreed shape. Stay Awake, focus and
    /// presentation stay false: Monorail hands those to Keeper (PeerHello), as before.
    private var suiteOwns: [String: Any] {
        var owns = SuiteArea.ownsObject(SuiteRole.areasOn(store.settings, role: SuiteRole.shared.role))
        owns["awake"] = false
        owns["focus"] = false
        owns["stage"] = false
        owns["alarms"] = false  // each app rings only its own timers, so nothing rings twice
        return owns
    }

    /// Things happening here, for the island owner (Keeper's Island when the person chose it).
    private var suiteLive: [SuiteLive] {
        NotchLive.shared.activities().map { SuiteLive(kind: $0.kind.name, title: $0.text, symbol: $0.symbol) }
    }

    /// The parts of the hello other apps act on, to publish again only when they change.
    private var suiteAnnouncement: String {
        let areas = SuiteRole.areasOn(store.settings, role: SuiteRole.shared.role).map(\.rawValue).sorted()
        let prefer = store.settings.suitePrefer.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
        return (areas + ["|"] + prefer).joined(separator: ",")
    }
    private var lastSuiteAnnouncement = ""
    private var islandAskedThisRun = false
    private var lastLive: [SuiteLive] = []
    private var lastLiveWrite = Date.distantPast
    private var liveTimer: Timer?

    /// Keeper's Island shows Monorail's live items while it's the island: refresh them every few seconds.
    private func keepLiveFresh() {
        let needed = suite != nil && SuiteRole.shared.rests(.island)
        if !needed { liveTimer?.invalidate(); liveTimer = nil; return }
        guard liveTimer == nil else { return }
        liveTimer = Timer.every(3) { [weak self] _ in
            guard let self, let suite = self.suite else { return }
            let live = self.suiteLive
            // Keeper treats a state file older than 30 s as stale, so it's rewritten at least every 10 s.
            guard live != self.lastLive || Date().timeIntervalSince(self.lastLiveWrite) >= 10 else { return }
            self.lastLive = live
            self.lastLiveWrite = Date()
            suite.writeState(Self.suiteName, ["live": live.map(\.json), "at": Date().timeIntervalSince1970 * 1000])
            self.ringSuiteDoorbell()
        }
    }

    /// The person chose who looks after an area (nil: back to the agreed list).
    private func choose(_ area: SuiteArea, _ app: SuiteRules.App?) {
        if let app {
            store.settings.suitePrefer[area.rawValue] = app.rawValue
            store.settings.suitePreferAt[area.rawValue] = Date().timeIntervalSince1970 * 1000
        } else {
            store.settings.suitePrefer[area.rawValue] = nil
            store.settings.suitePreferAt[area.rawValue] = nil
        }
        SuiteRole.shared.evaluateAreas()
        publishSuiteHello()
    }

    /// Keeper took over (or gave back) some areas: everything looks again, and the first time an
    /// area goes to Keeper a note says so, with a way to choose otherwise.
    private func areasChanged(_ fresh: Set<SuiteArea>) {
        evening.update()
        apply(store.settings)
        keepLiveFresh()
        publishSuiteHello()
        let unseen = fresh.filter { !store.settings.suiteNotesShown.contains($0.rawValue) }
        guard !unseen.isEmpty else { return }
        store.settings.suiteNotesShown += unseen.map(\.rawValue)
        DispatchQueue.main.async { [weak self] in
            SuiteNote.show(unseen) { self?.navigation.tab = .general; self?.showSettings() }
        }
    }

    private func ringSuiteDoorbell() {
        // No payload: the sandbox strips it. Whoever hears it reads the folders.
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(SuiteChannel.doorbell), object: nil, userInfo: nil, deliverImmediately: true)
    }

    /// Someone changed something: read Keeper's hello, and answer requests left for Monorail.
    private func suiteDoorbell() {
        guard let suite else { return }
        if let body = suite.hello(of: "keeper"), let hello = PeerHello.decode(body),
            NSRunningApplication(processIdentifier: hello.pid)?.bundleIdentifier == hello.bundleID
        {
            peer = hello
        }
        let requests = suite.takeRequests(for: Self.suiteName)
        for request in requests {
            switch request.op {
            case "awake.on":
                let minutes = request.args["for"].flatMap { Int($0.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)) }
                awake.start(minutes: minutes ?? store.settings.awakeDefaultMinutes, fromPeer: true)
                suite.respond(to: request, ok: true, result: ["awake": awake.isOn])
            case "awake.off":
                awake.end()
                suite.respond(to: request, ok: true, result: ["awake": awake.isOn])
            case "peer":
                suite.respond(to: request, ok: true, result: suiteHello)
            default:
                suite.respond(to: request, ok: false, reason: "unsupported")
            }
        }
        if !requests.isEmpty { ringSuiteDoorbell() }
    }

    // MARK: Local API

    /// AI agents read freely; the first change they ask for waits for the person: this time, always, or no.
    private var agentsAllowedThisSession = false
    private func agentMayChange(_ path: [String], _ body: [String: Any]) -> Bool {
        if store.settings.agentsCanChange || agentsAllowedThisSession { return true }
        let what = (body["action"] as? String).map { "run “\($0)”" } ?? (body["text"] as? String).map { "do “\($0)”" } ?? "change “\(path.joined(separator: "/"))”"
        let alert = NSAlert()
        alert.messageText = "Let an AI agent change your Mac?"
        alert.informativeText = "An agent connected to \(Brand.name) through MCP wants to \(what). Reading what's on screen never needs asking. You can change this any time in Settings ▸ Automation."
        alert.addButton(withTitle: "Allow This Time")
        alert.addButton(withTitle: "Always Allow")
        alert.addButton(withTitle: "Don't Allow")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: agentsAllowedThisSession = true; return true
        case .alertSecondButtonReturn: store.settings.agentsCanChange = true; return true
        default: return false
        }
    }

    private func handleAPI(_ method: String, _ path: [String], _ body: [String: Any]) -> Any? {
        func int(_ key: String) -> Int? { (body[key] as? Int) ?? (body[key] as? String).flatMap { Int($0) } }
        func text(_ key: String) -> String? { body[key] as? String }
        switch (method, path.first ?? "") {
        case ("GET", "hello"):
            // Who's here, for Keeper (and any other Ashforde app) to find out on start-up.
            var hello: [String: Any] = [
                "app": "Monorail", "bundleID": Bundle.main.bundleIdentifier ?? BundleIDs.current,
                "version": Bundle.main.shortVersion, "api": 1,
                "focusMode": engine.isFocusMode, "presenting": engine.isPresenting, "awake": awake.isOn,
                "paused": engine.isPaused, "peer": NSNull(),
            ]
            if let peer = activePeer { hello["peer"] = ["app": peer.app, "bundleID": peer.bundleID, "version": peer.version] }
            return hello
        case ("POST", "peer"):
            guard let hello = PeerHello.decode(body),
                NSRunningApplication(processIdentifier: hello.pid)?.bundleIdentifier == hello.bundleID
            else { return ["error": "Not an Ashforde app that is running"] }
            peer = hello
            return ["ok": true]
        case ("GET", "state"):
            guard let state = currentState(), let data = try? JSONEncoder().encode(state),
                let object = try? JSONSerialization.jsonObject(with: data)
            else { return [String: Any]() }
            return object
        case ("GET", "windows"):
            return engine.windowList()
        case ("POST", "clipboard"):
            // For AI apps over MCP: what you copied, newest first. Secrets stay hidden.
            let kind = text("kind").flatMap { ClipKind(rawValue: $0) }
            let found = ClipboardWatch.shared.history.shown(matching: text("query") ?? "", kind: kind).prefix(min(int("limit") ?? 20, 100))
            return found.map { clip -> [String: Any] in
                var item: [String: Any] = ["id": clip.id.uuidString, "kind": clip.kind.rawValue, "copied": ISO8601DateFormatter().string(from: clip.copied),
                                           "pinned": clip.pinned, "boards": clip.boards, "tags": clip.tags]
                if let sensitive = clip.sensitive { item["text"] = "(hidden: \(sensitive))" }
                else if clip.kind == .image { item["text"] = clip.imageText ?? ""; item["image"] = ClipboardWatch.shared.imageURL(clip)?.path ?? "" }
                else { item["text"] = String(clip.text.prefix(5000)) }
                if let app = clip.app { item["app"] = app }
                if let files = clip.files { item["files"] = files }
                return item
            }
        case ("GET", "workspaces"):
            let windows = engine.windowList()
            return (0..<engine.workspaceCount).map { index -> [String: Any] in
                ["number": index + 1, "name": store.settings.workspaceName(index),
                 "windows": windows.filter { ($0["workspace"] as? Int) == index + 1 }.count]
            }
        case ("GET", "layouts"):
            return engine.layouts.map(\.name)
        case ("GET", "pairs"):
            return store.settings.appPairs.map(\.name)
        case ("GET", "templates"):
            return store.settings.templates.map(\.name)
        case ("GET", "snapshots"):
            return engine.snapshots.map(\.name)
        case ("GET", "actions"):
            return Action.allCases.map { ["name": $0.rawValue, "title": $0.title] }
        case ("POST", "action"):
            guard let name = text("action") ?? path.dropFirst().first, let action = Action(rawValue: name) else {
                return ["error": "Unknown action"]
            }
            engine.perform(action)
            return ["ok": true]
        case ("POST", "focus"):
            guard let id = int("id") else { return ["error": "Needs id"] }
            engine.focusAndReveal(WindowID(id))
            return ["ok": true]
        case ("POST", "move"):
            guard let id = int("id"), let workspace = int("workspace") else { return ["error": "Needs id and workspace"] }
            engine.moveWindow(WindowID(id), toWorkspace: workspace - 1)
            return ["ok": true]
        case ("POST", "pair"):
            let ids = (body["ids"] as? [Int] ?? []).map { WindowID($0) }
            let arrangement = text("layout").flatMap(Arrangement.init(rawValue:)) ?? .columns
            return ["ok": engine.pairWindows(ids, arrangement: arrangement)]
        case ("POST", "workspace"):
            guard let number = int("number") else { return ["error": "Needs number"] }
            engine.switchWorkspace(to: number - 1)
            return ["ok": true]
        case ("POST", "layout"):
            engine.applyLayout(named: text("name") ?? "")
            return ["ok": true]
        case ("POST", "pair-name"):
            guard let pair = store.settings.appPairs.first(where: { $0.name.caseInsensitiveCompare(text("name") ?? "") == .orderedSame })
            else { return ["error": "No such app pair"] }
            engine.openPair(pair)
            return ["ok": true]
        case ("POST", "template"):
            guard let template = store.settings.templates.first(where: { $0.name.caseInsensitiveCompare(text("name") ?? "") == .orderedSame })
            else { return ["error": "No such template"] }
            engine.runTemplate(template)
            return ["ok": true]
        case ("POST", "snapshot"):
            engine.restoreSnapshot(named: text("name") ?? "")
            return ["ok": true]
        case ("POST", "undo"):
            engine.undo(steps: max(int("steps") ?? 1, 1))
            return ["ok": true]
        case ("POST", "redo"):
            engine.redo()
            return ["ok": true]
        case ("GET", "history"):
            let format = ISO8601DateFormatter()
            return engine.undoHistory().map { ["label": $0.label, "date": format.string(from: $0.date)] }
        case ("POST", "name-slide"):
            guard let id = int("id") else { return ["error": "Needs id"] }
            engine.nameSlide(WindowID(id), text("name") ?? "")
            return ["ok": true]
        case ("POST", "slide-layout"):
            let name = text("layout") ?? ""
            guard let action = Action.allCases.first(where: { action in
                guard let layout = action.directLayout else { return false }
                return (layout?.rawValue ?? "tabs") == name
            }) else { return ["error": "Unknown layout"] }
            if let id = int("id") { engine.focusAndReveal(WindowID(id)) }
            engine.perform(action)
            return ["ok": true]
        case ("POST", "close"):
            guard let id = int("id") else { return ["error": "Needs id"] }
            if store.settings.confirmDestructiveAPI {
                let name = engine.allWindowSummaries().first { $0.id == WindowID(id) }.map { $0.title.isEmpty ? $0.appName : $0.title } ?? "a window"
                let alert = NSAlert()
                alert.messageText = "Close “\(name)”?"
                alert.informativeText = "A script or AI assistant asked Monorail to close this window."
                alert.addButton(withTitle: "Close")
                alert.addButton(withTitle: "Keep It")
                NSApp.activate(ignoringOtherApps: true)
                guard alert.runModal() == .alertFirstButtonReturn else { return ["ok": false, "error": "Declined"] }
            }
            engine.closeWindow(WindowID(id))
            return ["ok": true]
        case ("POST", "note"):
            guard let id = int("id") else { return ["error": "Needs id"] }
            engine.setNote(text("text") ?? "", for: WindowID(id))
            return ["ok": true]
        case ("POST", "notify"):
            toast.show(text("text") ?? "")
            return ["ok": true]
        case ("GET", "insights"):
            let today = stats.today
            return ["switches": today.switches, "windowsOpened": today.windowsOpened, "focusSessions": today.focusSessions,
                    "focusMinutes": today.focusMinutes, "focusGoal": store.settings.dailyFocusGoal,
                    "workspaceMinutes": today.workspaceMinutes, "appMinutes": today.appMinutes]
        case ("GET", "layout"):
            return ["json": engine.layoutJSON() ?? ""]
        case ("POST", "say"):
            return ["ok": say(text("text") ?? "")]
        case ("GET", "battery"):
            PowerWatch.shared.refreshIfStale()
            return PowerWatch.shared.report()
        case ("POST", "battery"):
            guard let app = text("app") else { return ["error": "Needs app (a bundle ID or name)"] }
            let power = PowerWatch.shared
            let id = power.apps.first { $0.id == app || $0.use.appName.caseInsensitiveCompare(app) == .orderedSame }?.id ?? app
            switch text("do") ?? "" {
            case "hide": power.hide(id)
            case "pause":
                guard power.canPause(id) else { return ["ok": false, "error": "That app can't be paused"] }
                power.pause(id)
            case "resume": power.resume(id)
            case "quit":
                let alert = NSAlert()
                alert.messageText = "Quit \(PowerWatch.appName(id) ?? id)?"
                alert.informativeText = "An assistant asked to quit it to save battery. It can still ask you to save your work."
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return ["ok": false, "error": "Declined"] }
                power.quit(id)
            default: return ["error": "do: hide, pause, resume or quit"]
            }
            return ["ok": true]
        case ("GET", "awake"):
            return ["on": awake.isOn, "status": awake.statusText]
        case ("POST", "awake"):
            if text("state") == "off" { awake.end() } else if let minutes = int("minutes") {
                awake.start(minutes: minutes, fromPeer: text("from")?.lowercased() == "keeper")
            } else {
                awake.toggle()
            }
            return ["on": awake.isOn, "status": awake.statusText]
        case ("GET", "agents"):
            return engine.waitingAgents.map { ["id": Int($0)] }
        case ("GET", "predict"):
            return ["next": engine.predictedNext.map { $0 as Any } ?? NSNull()]
        case ("POST", "context"):
            // Editors and browsers can report what you're on: {"project": "...", "file": "..."}.
            if let project = text("project"), !project.isEmpty, let status = engine.status(), store.settings.autoNameWorkspaces {
                var settings = store.settings
                settings.setWorkspaceName(project, at: status.workspace - 1)
                store.settings = settings
            }
            return ["ok": true]
        default:
            return nil
        }
    }

    // MARK: Scripts

    private func scriptBridge() -> ScriptHost.Bridge {
        ScriptHost.Bridge(
            perform: { [weak self] name in if let action = Action(rawValue: name) { self?.engine.perform(action) } },
            focus: { [weak self] id in self?.engine.focusAndReveal(id) },
            moveToWorkspace: { [weak self] id, index in self?.engine.moveWindow(id, toWorkspace: index) },
            park: { [weak self] index in self?.engine.parkWorkspace(index) },
            openPair: { [weak self] name in
                guard let self, let pair = self.store.settings.appPairs.first(where: { $0.name == name }) else { return }
                self.engine.openPair(pair)
            },
            applyLayout: { [weak self] name in self?.engine.applyLayout(named: name) },
            notify: { [weak self] text in self?.toast.show(text) },
            windows: { [weak self] in self?.engine.windowList() ?? [] },
            state: { [weak self] in
                guard let state = self?.currentState(), let data = try? JSONEncoder().encode(state),
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return [:] }
                return object
            },
            setWidths: { [weak self] widths in self?.engine.setSlideWidths(widths) },
            say: { [weak self] text in self?.say(text) })
    }

    func reloadScripts() {
        guard store.settings.scripts else { return }
        scripts.load()
        toast.show("Scripts reloaded")
    }

    // MARK: Practice windows

    /// Three of Monorail's own windows to try the moves on, tiled like real ones.
    func openDemoWindows() {
        closeDemoWindows()
        let colours: [NSColor] = [.systemBlue, .systemPink, .systemOrange]
        for (index, colour) in colours.enumerated() {
            let window = NSWindow(
                contentRect: NSRect(x: 200 + index * 40, y: 200, width: 640, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Practice window \(index + 1)"
            window.isReleasedWhenClosed = false
            let label = NSTextField(labelWithString: "Practice window \(index + 1)\n\nTry ⌃⌥← ⌃⌥→ to move between windows,\n⌃⌥R for width, ⌃⌥O for the overview.")
            label.alignment = .center
            label.font = .systemFont(ofSize: 18, weight: .semibold)
            label.textColor = .white
            let view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = colour.withAlphaComponent(0.85).cgColor
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            demoWindows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            for window in self?.demoWindows ?? [] { self?.engine.adoptDemoWindow(window.windowNumber) }
        }
    }

    func closeDemoWindows() {
        engine.forgetDemoWindows()
        demoWindows.forEach { $0.close() }
        demoWindows.removeAll()
    }

    /// What status bars and scripts see (state.json, the event script).
    private func currentState() -> Integrations.State? {
        guard let status = engine.status() else { return nil }
        let focused = engine.focusedWindowID().flatMap { id in engine.allWindowSummaries().first { $0.id == id } }
        return Integrations.State(
            workspace: status.workspace, workspaceName: store.settings.workspaceName(status.workspace - 1),
            workspaceCount: engine.workspaceCount, profile: engine.profileName,
            slide: status.focusedColumn, slides: status.columnCount,
            app: focused?.appName, title: focused?.title, focusMode: engine.isFocusMode,
            presenting: engine.isPresenting, awake: awake.isOn, paused: engine.isPaused)
    }

    /// Runs an auto rule: its profile, then its layout.
    private func run(_ rule: AutoRule) {
        if let profile = rule.profile { engine.switchProfile(to: profile) }
        if let layout = rule.layout, !layout.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.engine.applyLayout(named: layout) }
        }
        toast.show("Auto rule · \(rule.name)")
    }

    /// Everything the command palette offers, built fresh each time it opens.
    private func paletteCommands() -> [PaletteCommand] {
        var list: [PaletteCommand] = []
        let settings = store.settings
        for window in engine.allWindowSummaries() {
            list.append(PaletteCommand(
                id: "window-\(window.id)", title: window.title.isEmpty ? window.appName : window.title,
                subtitle: "Go to window · \(window.appName)" + (window.note.map { " · \($0)" } ?? ""), symbol: "macwindow",
                keywords: "focus go window \(window.appName) \(window.note ?? "")"
            ) { [weak self] in self?.engine.focusAndReveal(window.id) })
        }
        for index in 0..<engine.workspaceCount {
            let name = settings.workspaceName(index)
            list.append(PaletteCommand(
                id: "ws-\(index)", title: "Go to \(name)", subtitle: "Workspace \(index + 1)", symbol: "square.stack",
                keywords: "workspace switch"
            ) { [weak self] in self?.engine.switchWorkspace(to: index) })
            list.append(PaletteCommand(
                id: "move-ws-\(index)", title: "Move window to \(name)", subtitle: "Workspace \(index + 1)",
                symbol: "arrow.right.square", keywords: "workspace send"
            ) { [weak self] in
                if let id = self?.engine.focusedWindowID() { self?.engine.moveWindow(id, toWorkspace: index) }
            })
            let parked = engine.isParked(index)
            list.append(PaletteCommand(
                id: "park-\(index)", title: "\(parked ? "Bring back" : "Park") \(name)",
                subtitle: parked ? "Restore its windows from the Dock" : "Minimise its windows to the Dock",
                symbol: "parkingsign.circle", keywords: "park unpark dock"
            ) { [weak self] in
                if parked { self?.engine.unparkWorkspace(index) } else { self?.engine.parkWorkspace(index) }
            })
        }
        for pair in settings.appPairs {
            list.append(PaletteCommand(
                id: "pair-\(pair.id)", title: "Open pair \(pair.name)", subtitle: "App pair", symbol: "rectangle.split.2x1",
                keywords: "pair apps \(pair.bundleIDs.map(UsageStats.appName).joined(separator: " "))"
            ) { [weak self] in self?.engine.openPair(pair) })
        }
        for layout in engine.layouts {
            list.append(PaletteCommand(
                id: "layout-\(layout.name)", title: "Apply layout \(layout.name)", subtitle: "Saved layout",
                symbol: "square.grid.2x2", keywords: "layout"
            ) { [weak self] in self?.engine.applyLayout(named: layout.name) })
        }
        for (title, size) in standardSizes {
            list.append(PaletteCommand(
                id: "size-\(title)", title: "Size window to \(title)", subtitle: "Floats it, centred · for recordings",
                symbol: "rectangle.dashed", keywords: "size resize record screenshot"
            ) { [weak self] in
                if let id = self?.engine.focusedWindowID() { self?.engine.setFloatingSize(id, size) }
            })
        }
        for template in settings.templates {
            list.append(PaletteCommand(
                id: "template-\(template.id)", title: "Start template \(template.name)", subtitle: "Workspace template",
                symbol: "square.on.square", keywords: "template start"
            ) { [weak self] in self?.engine.runTemplate(template) })
        }
        for slide in engine.recentSlides().dropFirst() {
            list.append(PaletteCommand(
                id: "recent-\(slide.window)", title: "Back to \(slide.title)", subtitle: "Recent slide",
                symbol: "clock.arrow.circlepath", keywords: "recent slide back"
            ) { [weak self] in self?.engine.focusAndReveal(slide.window) })
        }
        for snapshot in engine.snapshots {
            list.append(PaletteCommand(
                id: "snapshot-\(snapshot.name)", title: "Restore snapshot \(snapshot.name)", subtitle: "Session snapshot",
                symbol: "camera.viewfinder", keywords: "snapshot session restore"
            ) { [weak self] in self?.engine.restoreSnapshot(named: snapshot.name) })
        }
        for (index, profile) in settings.profiles.enumerated() where settings.profiles.count > 1 {
            list.append(PaletteCommand(
                id: "profile-\(index)", title: "Switch to profile \(profile)", subtitle: "Profile",
                symbol: "person.crop.rectangle.stack", keywords: "profile"
            ) { [weak self] in self?.engine.switchProfile(to: index) })
        }
        for (letter, bundleID) in settings.launchSlots.sorted(by: { $0.key < $1.key }) {
            list.append(PaletteCommand(
                id: "launch-\(letter)", title: "Open \(UsageStats.appName(bundleID))", subtitle: "Quick launch · \(letter.uppercased())",
                symbol: "app.badge", keywords: "launch app"
            ) { [weak self] in self?.engine.quickLaunch(letter) })
        }
        for action in Action.allCases where action.columnNumber == nil && action.workspaceNumber == nil
            && action.moveToWorkspaceNumber == nil && action != .commandPalette
        {
            let keys = settings.keymap.shortcuts(for: action).first?.displayString ?? ""
            list.append(PaletteCommand(
                id: "action-\(action.rawValue)", title: action.title, subtitle: keys, symbol: "keyboard",
                keywords: action.rawValue.replacingOccurrences(of: "-", with: " ")
            ) { [weak self] in self?.engine.perform(action) })
        }
        list.append(PaletteCommand(id: "settings", title: "Open Settings", symbol: "gearshape") { [weak self] in
            self?.showSettings()
        })
        return scriptablePaletteCommands() + v12PaletteCommands() + list + everywhereCommands()
    }

    /// One search for everything: each page of the panel, every setting, and every menu item, so
    /// nothing is only reachable by knowing where it lives.
    private func everywhereCommands() -> [PaletteCommand] {
        var list: [PaletteCommand] = []
        let pages: [(String, PanelPage, String, String)] = [
            ("Battery", .battery, "bolt.fill", "charge health cycles drain apps report accessories airpods mouse keyboard"),
            ("System", .system, "cpu", "processor cpu memory ram heat network speed test ip vpn uptime chip cores"),
            ("Storage", .storage, "internaldrive.fill", "disk space free clean up largest files trash"),
            ("Calendar", .today, "calendar", "today meetings events join month world clocks timers"),
            ("Reminders", .reminders, "checklist", "todo tasks due overdue"),
            ("Notes", .note, "note.text", "quick note apple notes"),
            ("Clipboard", .clipboard, "doc.on.clipboard.fill", "copy paste history pins plain text colours"),
            ("Text and Codes", .text, "text.viewfinder", "ocr qr scan read text picture screenshot"),
            ("Focus Session", .focus, "timer", "pomodoro sounds rain brown noise streak eye breaks"),
            ("Film Mode", .film, "film.fill", "movie video sleep timer"),
            ("Stay Awake", .awake, "cup.and.saucer.fill", "caffeine keep awake amphetamine"),
            ("Evening Mode", .evening, "moon.fill", "night shift warm screen blue light"),
        ]
        for (title, page, symbol, keywords) in pages {
            list.append(PaletteCommand(id: "page-\(title)", title: title, subtitle: "Open in the \(Brand.name) panel", symbol: symbol,
                                       keywords: keywords) { [weak self] in
                guard let self, let button = self.statusItem?.button else { return }
                self.popover.toggle(relativeTo: button, page: page)
            })
        }
        do {
            list.append(PaletteCommand(id: "identify-displays", title: "Identify Displays", subtitle: "A big number and the name on every screen, for a moment",
                                       symbol: "display.2", keywords: "screens monitors which display number name") { IdentifyDisplays.show() })
            list.append(PaletteCommand(id: "dashboard", title: "Dashboard", subtitle: "System, battery, storage and today, full size", symbol: "gauge.with.dots.needle.67percent",
                                       keywords: "system monitor activity apps cpu memory gpu disk network battery sound ports agents trends history") { DashboardWindow.shared.show() })
            list.append(PaletteCommand(id: "ai-usage", title: "AI Usage", subtitle: "Claude, Codex, Gemini, OpenClaw, Hermes, Ollama, LM Studio and API keys", symbol: "brain",
                                       keywords: "ai usage limits tokens context codexbar claude codex gemini openclaw hermes ollama lm studio openrouter api spend credits") {
                UserDefaults.standard.set(DashboardSection.ai.rawValue, forKey: "DashboardSection")
                DashboardWindow.shared.show()
            })
            list.append(PaletteCommand(id: "clipboard-window", title: "Clipboard", subtitle: "Everything you copied: text, images, files, boards and tags", symbol: "doc.on.clipboard",
                                       keywords: "clipboard history copied paste boards tags moodboard images") { ClipboardWindow.shared.show() })
            list.append(PaletteCommand(id: "meeting-notes", title: MeetingRecorder.shared.recording ? "Stop Taking Notes" : "Take Meeting Notes",
                                       subtitle: "Write down what's said, on this Mac", symbol: "waveform.badge.mic",
                                       keywords: "meeting notes transcript record call minutes action items summary") {
                MeetingRecorder.shared.recording ? MeetingRecorder.shared.stop() : MeetingRecorder.shared.start()
            })
            list.append(PaletteCommand(id: "tools", title: "Tools", subtitle: "Screenshot names, images, PDFs, text and developer tools", symbol: "wrench.and.screwdriver",
                                       keywords: "tools utilities toolbox convert rename") { ToolsWindow.shared.show() })
            list.append(PaletteCommand(id: "switches", title: "Switches", subtitle: "System settings and actions in one click, and modes", symbol: "switch.2",
                                       keywords: "switches toggles levers modes dark mode dock desktop icons hidden files trash dns recording") {
                UserDefaults.standard.set(DashboardSection.switches.rawValue, forKey: "DashboardSection")
                DashboardWindow.shared.show()
            })
            for item in Switchboard.shared.catalogue {
                let state = Switchboard.shared.states[item.id]
                list.append(PaletteCommand(id: "switch-" + item.id, title: item.isAction ? item.title : "\(item.title): \(state == true ? "Turn Off" : "Turn On")",
                                           subtitle: item.about, symbol: item.symbol, keywords: "switch toggle " + item.group.rawValue.lowercased()) { Switchboard.shared.toggle(item.id) })
            }
            for mode in store.settings.modes {
                let active = Switchboard.shared.isActive(mode)
                list.append(PaletteCommand(id: "mode-" + mode.id, title: "\(active ? "Stop" : "Start") \(mode.name) Mode", subtitle: "Mode", symbol: mode.symbol,
                                           keywords: "mode " + mode.name.lowercased()) { Switchboard.shared.toggleMode(mode) })
            }
            for tool in ToolKind.available {
                list.append(PaletteCommand(id: "tool-" + tool.rawValue, title: tool.rawValue, subtitle: tool.about, symbol: tool.symbol,
                                           keywords: "tool " + tool.group.lowercased()) { ToolsWindow.shared.show(tool) })
            }
        }
        if !Edition.isAppStore {
            list.append(PaletteCommand(id: "page-live", title: "Live View", subtitle: "Every core, network and apps over time", symbol: "waveform.path.ecg",
                                       keywords: "activity monitor graphs") { LiveWindow.shared.show() })
        }
        // Every setting, opening Settings at its page.
        for (index, entry) in SettingsIndex.entries.enumerated() {
            guard let tab = SettingsTab(rawValue: entry.tab) else { continue }
            list.append(PaletteCommand(id: "setting-\(index)", title: entry.label, subtitle: "Settings › \(tab.title)", symbol: "gearshape",
                                       keywords: "setting preference option") { [weak self] in
                self?.navigation.tab = tab
                self?.showSettings()
            })
        }
        // Every menu item, run as if chosen from the menu.
        let menu = NSMenu()
        menuNeedsUpdate(menu)
        func walk(_ menu: NSMenu, path: [String]) {
            for item in menu.items where !item.isSeparatorItem && !item.title.isEmpty {
                if let sub = item.submenu {
                    walk(sub, path: path + [item.title])
                } else if let action = item.action, item.isEnabled {
                    let target = item.target
                    list.append(PaletteCommand(id: "menu-\((path + [item.title]).joined(separator: "/"))", title: item.title,
                                               subtitle: (["Menu"] + path).joined(separator: " › "), symbol: "filemenu.and.selection",
                                               keywords: path.joined(separator: " ")) {
                        NSApp.sendAction(action, to: target, from: item)
                    })
                }
            }
        }
        walk(menu, path: [])
        return list
    }

    private func saveAppPair(from id: WindowID) {
        guard var pair = engine.appPair(from: id) else {
            toast.show("A pair needs windows of at least two apps in one slide")
            return
        }
        guard let name = TextPrompt.ask(
            title: "Save app pair",
            message: "Open these apps side by side in one slide any time, from App Pairs in the menu bar.",
            initial: pair.name, placeholder: pair.name, button: "Save")
        else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { pair.name = trimmed }
        store.settings.appPairs.removeAll { $0.name == pair.name }
        store.settings.appPairs.append(pair)
        toast.show("Saved app pair “\(pair.name)”")
    }

    private func renameWindow(_ id: WindowID) {
        let current = engine.allWindowSummaries().first { $0.id == id }
        guard let name = TextPrompt.ask(
            title: "Rename window",
            message: "Shown in Monorail’s previews, overview and menus. Leave empty to use the window’s own title.",
            initial: engine.customName(of: id) ?? "",
            placeholder: current?.title ?? "")
        else { return }
        engine.rename(id, to: name)
    }

    @objc private func stepLeft() { engine.step(forward: false, honourReverse: false, visual: true) }
    @objc private func stepRight() { engine.step(forward: true, honourReverse: false, visual: true) }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenu.delegate = self
        statusMenu.autoenablesItems = false
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = Brand.full
        updateStatusItem()
    }

    /// The menu bar shows only the Monorail icon. Its shape and colour say what's on: the menu bar's
    /// own colour while running, the middle window outlined while paused, orange while Stay Awake is on,
    /// red while recording. Position, timers and notices live in the panel instead.
    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let paused = engine.isPaused && !Edition.isAppStore
        // Its own colours, never black: the chosen style, orange while Stay Awake is on, red while recording.
        let tint: NSColor? = engine.isRecording ? .systemRed : (awake.isOn && !paused) ? .systemOrange : nil
        button.image = StatusIcon.image(paused: paused, style: StatusIcon.Style(rawValue: store.settings.menuBarIconStyle) ?? .colour, tint: tint,
                                         pulse: Edition.isAppStore)
        button.title = ""
        button.imagePosition = .imageOnly
        button.appearsDisabled = false
        button.contentTintColor = nil
        var states: [String] = []
        if paused { states.append("paused") }
        if awake.isOn { states.append("Stay Awake on") }
        if engine.isRecording { states.append("recording") }
        if updater.available != nil { states.append("update ready") }
        if let statusExtra { states.append(statusExtra) }
        button.setAccessibilityLabel(states.isEmpty ? "Monorail" : "Monorail, " + states.joined(separator: ", "))
        button.toolTip = states.isEmpty ? nil : states.joined(separator: " · ")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if Edition.isAppStore {
            stationMenu(menu)
            return
        }
        let trusted = Accessibility.isTrusted(prompt: false)

        let header = NSMenuItem(title: headerTitle(trusted: trusted), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if let release = updater.available {
            let update = item("Update to Monorail \(release.version)…", #selector(installUpdate))
            update.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
            menu.addItem(update)
        }

        if !trusted {
            menu.addItem(item(L("Grant Accessibility Access…"), #selector(grantAccessibilityFromMenu)))
            menu.addItem(item("Using Monorail Without It…", #selector(explainWithoutAccessibility)))
            if usesScriptableArranging { menu.addItem(scriptableMenu()) }
            menu.addItem(.separator())
        }
        menu.addItem(awakeMenu())
        menu.addItem(keepAvailableItem())
        menu.addItem(eveningMenu())
        menu.addItem(displayMenu.menuItem())
        addAshfordeSection(to: menu)
        let animate = item(L("Animate Windows"), #selector(toggleAnimationsFromMenu), action: .toggleAnimations)
        animate.state = store.settings.animate ? .on : .off
        animate.toolTip = "Off: windows move instantly. Everything else works the same, and it saves energy."
        menu.addItem(animate)

        // Without Accessibility the window tools can't work: the menu keeps to what does.
        guard engine.isRunning else {
            menu.addItem(.separator())
            menu.addItem(item(L("Command Palette…"), #selector(showPalette), action: .commandPalette))
            addFooter(to: menu)
            return
        }

        let windows = engine.activeStripWindows()
        if !windows.isEmpty {
            menu.addItem(.separator())
            // Compact by default: the windows live in a submenu, so the menu stays short.
            let list: NSMenu
            if store.settings.menuWindowsInline {
                list = menu
            } else {
                let parent = NSMenuItem(title: "Windows (\(windows.count))", action: nil, keyEquivalent: "")
                parent.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
                list = NSMenu()
                parent.submenu = list
                menu.addItem(parent)
            }
            for (index, window) in windows.enumerated() {
                var title = window.title.isEmpty ? window.appName : "\(window.appName) — \(window.title)"
                if title.count > 60 { title = String(title.prefix(59)) + "…" }
                let entry = item("\(index + 1). \(title)", #selector(focusWindowFromMenu(_:)))
                entry.tag = Int(window.id)
                entry.state = window.isFocused ? .on : .off
                entry.image = window.icon.map { icon in
                    let copy = icon.copy() as! NSImage
                    copy.size = NSSize(width: 16, height: 16)
                    return copy
                }
                list.addItem(entry)
            }
        }

        menu.addItem(.separator())
        menu.addItem(
            item(engine.isPaused ? L("Resume Tiling") : L("Pause Tiling"), #selector(togglePause), action: .togglePause))
        menu.addItem(item(L("Overview"), #selector(showOverview), action: .overview))
        menu.addItem(item(L("Search Windows…"), #selector(showSwitcher), action: .windowSwitcher))
        menu.addItem(item(L("Command Palette…"), #selector(showPalette), action: .commandPalette))
        let focusItem = item(
            engine.isFocusMode ? L("End Focus Mode") : L("Focus Mode"), #selector(toggleFocusMode), action: .toggleFocusMode)
        if let ends = engine.focusEnds {
            focusItem.toolTip = "Ends at \(DateFormatter.localizedString(from: ends, dateStyle: .none, timeStyle: .short))"
        }
        menu.addItem(focusItem)
        menu.addItem(item(L("Reset to Smart Pairs"), #selector(regroup), action: .regroup))
        menu.addItem(savedLayoutsMenu())
        menu.addItem(appPairsMenu())
        menu.addItem(snapshotsMenu())
        if !store.settings.templates.isEmpty { menu.addItem(templatesMenu()) }
        let recent = engine.recentSlides()
        if recent.count > 1 {
            let list = NSMenu()
            for slide in recent.dropFirst() {
                let entry = item(slide.title, #selector(focusWindowFromMenu(_:)))
                entry.tag = Int(slide.window)
                list.addItem(entry)
            }
            let parent = NSMenuItem(title: L("Recent Slides"), action: nil, keyEquivalent: "")
            parent.submenu = list
            menu.addItem(parent)
        }
        menu.addItem(item(
            engine.isPresenting ? L("End Presentation Mode") : L("Presentation Mode"), #selector(togglePresentation),
            action: .presentationMode))
        if engine.isRecording { menu.addItem(item(L("Stop Recording"), #selector(stopRecording), action: .recordSlide)) }
        let undoItem = item(L("Undo Layout Change"), #selector(undoLayout), action: .undo)
        undoItem.isEnabled = engine.canUndo
        menu.addItem(undoItem)
        let redoItem = item("Redo Layout Change", #selector(redoLayout), action: .redo)
        redoItem.isEnabled = engine.canRedo
        menu.addItem(redoItem)
        let changes = engine.undoHistory()
        if !changes.isEmpty {
            let timeline = NSMenu()
            let time = DateFormatter()
            time.timeStyle = .short
            for (index, change) in changes.enumerated() {
                let entry = item("\(change.label) · \(time.string(from: change.date))", #selector(undoToStep(_:)))
                entry.tag = index + 1
                entry.toolTip = index == 0 ? "Undo just this change" : "Undo this change and the \(index) after it"
                timeline.addItem(entry)
            }
            let parent = NSMenuItem(title: "Undo History", action: nil, keyEquivalent: "")
            parent.submenu = timeline
            menu.addItem(parent)
        }
        let fitItem = item("Fit Every Slide on Screen", #selector(toggleFitFromMenu), action: .toggleFitMode)
        if let status = engine.status() { fitItem.state = store.settings.isFit(status.workspace - 1 + engine.activeProfile * 100) ? .on : .off }
        menu.addItem(fitItem)
        menu.addItem(item(L("Retile Windows"), #selector(retile), action: .retile))
        menu.addItem(item("Rescue Windows", #selector(rescueFromMenu), action: .rescueWindows))

        let workspaceCount = engine.workspaceCount
        if workspaceCount > 1 {
            let workspaces = NSMenu()
            workspaces.autoenablesItems = false
            let current = engine.status()?.workspace
            for n in 1...workspaceCount {
                let action = Action.allCases.first { $0.workspaceNumber == n }!
                var title = store.settings.workspaceName(n - 1)
                if engine.isParked(n - 1) { title += " (parked)" }
                let entry = item(title, #selector(switchWorkspaceFromMenu(_:)), action: action)
                entry.tag = n
                entry.state = current == n ? .on : .off
                workspaces.addItem(entry)
            }
            workspaces.addItem(.separator())
            let park = NSMenu()
            for n in 1...workspaceCount {
                let parked = engine.isParked(n - 1)
                let entry = item(
                    "\(parked ? "Bring Back" : "Park") \(store.settings.workspaceName(n - 1))",
                    #selector(toggleParkFromMenu(_:)))
                entry.tag = n
                park.addItem(entry)
            }
            let parkParent = NSMenuItem(title: L("Park Workspace"), action: nil, keyEquivalent: "")
            parkParent.submenu = park
            parkParent.toolTip = "Minimise a workspace’s windows to the Dock and bring them back to the same slides later"
            workspaces.addItem(parkParent)
            let parent = NSMenuItem(title: L("Workspaces"), action: nil, keyEquivalent: "")
            parent.submenu = workspaces
            menu.addItem(parent)
        }
        // Views: back and forward like a browser, and the saved views of this display.
        let views = NSMenu()
        for (title, action) in [(L("Back"), Action.viewBack), (L("Forward"), Action.viewForward)] {
            let entry = item(title, #selector(performMenuAction(_:)), action: action)
            entry.representedObject = action.rawValue
            views.addItem(entry)
        }
        views.addItem(.separator())
        let saved = engine.savedViewList()
        for view in saved {
            let entry = item("View \(view.number) · \(store.settings.workspaceName(view.workspace - 1))", #selector(performMenuAction(_:)),
                             action: Action(rawValue: "view-\(view.number)"))
            entry.representedObject = "view-\(view.number)"
            views.addItem(entry)
        }
        if saved.isEmpty {
            let hint = NSMenuItem(title: "Save a view with ⌃⌥⌘⇧ and a number", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            views.addItem(hint)
        }
        let next = (1...9).first { n in !saved.contains { $0.number == n } } ?? 9
        let save = item("Save This View as \(next)", #selector(performMenuAction(_:)), action: Action(rawValue: "save-view-\(next)"))
        save.representedObject = "save-view-\(next)"
        views.addItem(save)
        let viewsParent = NSMenuItem(title: L("Views"), action: nil, keyEquivalent: "")
        viewsParent.submenu = views
        menu.addItem(viewsParent)
        if store.settings.profiles.count > 1 {
            let profiles = NSMenu()
            for (index, name) in store.settings.profiles.enumerated() {
                let entry = item(name, #selector(switchProfileFromMenu(_:)))
                entry.tag = index
                entry.state = engine.activeProfile == index ? .on : .off
                profiles.addItem(entry)
            }
            let parent = NSMenuItem(title: "Profile: \(engine.profileName)", action: nil, keyEquivalent: "")
            parent.submenu = profiles
            menu.addItem(parent)
        }

        addFooter(to: menu)
    }

    /// Settings, help, updates and Quit, at the foot of the menu.
    private func addFooter(to menu: NSMenu) {
        menu.addItem(.separator())
        if SuiteRole.shared.stationAlongside {
            // Both apps here: Monorail leads, Signalbox rests until Monorail quits.
            let note = NSMenuItem(title: "Signalbox is resting while Monorail runs", action: nil, keyEquivalent: "")
            note.isEnabled = false
            note.toolTip = "Monorail does everything Signalbox does. Quit Monorail and Signalbox takes over again by itself."
            menu.addItem(note)
        }
        menu.addItem(item(L("Settings…"), #selector(showSettingsFromMenu), key: ","))
        menu.addItem(item(L("Send Feedback…"), #selector(sendFeedbackFromMenu)))
        menu.addItem(shortcutsMenu())
        menu.addItem(item(L("Welcome Tour…"), #selector(showWelcomeFromMenu)))
        menu.addItem(item(L("What’s New") + "…", #selector(showWhatsNewFromMenu)))
        if !Edition.isAppStore { menu.addItem(item(L("Check for Updates…"), #selector(checkForUpdates))) }
        menu.addItem(item("About \(Brand.full)", #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item(Edition.isAppStore ? "Quit \(Brand.name)" : L("Quit Monorail"), #selector(quit), key: "q"))
    }

    /// Every shortcut, so nobody has to remember them. Choosing one runs it.
    private func shortcutsMenu() -> NSMenuItem {
        let menu = NSMenu()
        let slide = NSMenuItem(
            title: store.settings.slideTrigger == .off
                ? "Slide mode is off"
                : "Tap \(store.settings.slideTrigger.title) for slide mode, then ← → R F C…",
            action: nil, keyEquivalent: "")
        slide.isEnabled = false
        menu.addItem(slide)
        menu.addItem(.separator())
        for action in Action.allCases where action.columnNumber == nil {
            let shortcuts = store.settings.keymap.shortcuts(for: action).map(\.displayString)
            let title = shortcuts.isEmpty ? action.title : "\(action.title)    \(shortcuts.joined(separator: "  "))"
            let entry = NSMenuItem(title: title, action: #selector(performFromMenu(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = action.rawValue
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        menu.addItem(item(L("Change Shortcuts…"), #selector(showShortcuts)))
        let parent = NSMenuItem(title: L("Keyboard Shortcuts"), action: nil, keyEquivalent: "")
        parent.submenu = menu
        return parent
    }

    @objc private func performFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = Action(rawValue: raw) else { return }
        // Let the menu close and focus return to the previous app first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.engine.perform(action) }
    }

    @objc private func switchWorkspaceFromMenu(_ sender: NSMenuItem) {
        let index = sender.tag - 1
        afterMenu { $0.engine.switchWorkspace(to: index) }
    }

    @objc private func showOverview() { overview.show() }
    @objc private func showPalette() { afterMenu { $0.palette.show() } }
    @objc private func toggleFocusMode() { afterMenu { $0.engine.setFocusMode(!$0.engine.isFocusMode) } }

    /// Snapshots ▸ Take Snapshot…, each snapshot to restore, and Delete ▸.
    private func snapshotsMenu() -> NSMenuItem {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item(L("Take Snapshot…"), #selector(takeSnapshotFromMenu), action: .takeSnapshot))
        let snapshots = engine.snapshots
        if !snapshots.isEmpty {
            menu.addItem(.separator())
            for snapshot in snapshots {
                let entry = item(snapshot.name, #selector(restoreSnapshotFromMenu(_:)))
                entry.representedObject = snapshot.name
                entry.toolTip = "\(snapshot.windowCount) windows, \(snapshot.apps?.count ?? 0) apps"
                menu.addItem(entry)
            }
            menu.addItem(.separator())
            let delete = NSMenu()
            for snapshot in snapshots {
                let entry = item(snapshot.name, #selector(deleteLayout(_:)))
                entry.representedObject = snapshot.name
                delete.addItem(entry)
            }
            let parent = NSMenuItem(title: L("Delete"), action: nil, keyEquivalent: "")
            parent.submenu = delete
            menu.addItem(parent)
        }
        let parent = NSMenuItem(title: L("Snapshots"), action: nil, keyEquivalent: "")
        parent.submenu = menu
        return parent
    }

    @objc private func takeSnapshotFromMenu() { afterMenu { $0.takeSnapshot() } }

    @objc private func restoreSnapshotFromMenu(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        afterMenu { $0.engine.restoreSnapshot(named: name) }
    }

    @objc private func toggleParkFromMenu(_ sender: NSMenuItem) {
        let index = sender.tag - 1
        afterMenu { delegate in
            if delegate.engine.isParked(index) {
                delegate.engine.unparkWorkspace(index)
            } else {
                delegate.engine.parkWorkspace(index)
            }
        }
    }

    @objc private func switchProfileFromMenu(_ sender: NSMenuItem) {
        let index = sender.tag
        afterMenu { $0.engine.switchProfile(to: index) }
    }

    /// App Pairs ▸ each saved pair, to open its apps in one slide.
    private func appPairsMenu() -> NSMenuItem {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let pairs = store.settings.appPairs
        if pairs.isEmpty {
            let hint = NSMenuItem(
                title: "Right-click a slide’s preview ▸ Save Slide as App Pair", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }
        for pair in pairs {
            let entry = item(pair.name, #selector(openPairFromMenu(_:)))
            entry.representedObject = pair.id
            entry.image = NSImage(systemSymbolName: pair.arrangement.symbol, accessibilityDescription: nil)
            menu.addItem(entry)
        }
        if !pairs.isEmpty {
            menu.addItem(.separator())
            let delete = NSMenu()
            for pair in pairs {
                let entry = item(pair.name, #selector(deletePairFromMenu(_:)))
                entry.representedObject = pair.id
                delete.addItem(entry)
            }
            let parent = NSMenuItem(title: L("Delete"), action: nil, keyEquivalent: "")
            parent.submenu = delete
            menu.addItem(parent)
        }
        let parent = NSMenuItem(title: L("App Pairs"), action: nil, keyEquivalent: "")
        parent.submenu = menu
        return parent
    }

    @objc private func openPairFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
            let pair = store.settings.appPairs.first(where: { $0.id == id })
        else { return }
        afterMenu { $0.engine.openPair(pair) }
    }

    @objc private func deletePairFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        store.settings.appPairs.removeAll { $0.id == id }
    }
    @objc private func regroup() { afterMenu { $0.engine.perform(.regroup) } }
    @objc private func installUpdate() { afterMenu { $0.updater.installAvailable() } }

    /// Saved Layouts ▸ Save Current Layout…, each saved layout, and Delete ▸.
    private func savedLayoutsMenu() -> NSMenuItem {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(item(L("Save Current Layout…"), #selector(saveLayout)))
        let layouts = engine.layouts
        if !layouts.isEmpty {
            menu.addItem(.separator())
            for layout in layouts {
                let entry = item(layout.name, #selector(applyLayout(_:)))
                entry.representedObject = layout.name
                entry.toolTip = "\(layout.windowCount) windows in \(layout.workspaces.count) workspace(s)"
                menu.addItem(entry)
            }
            menu.addItem(.separator())
            let delete = NSMenu()
            let share = NSMenu()
            for layout in layouts {
                let entry = item(layout.name, #selector(shareLayout(_:)))
                entry.representedObject = layout.name
                share.addItem(entry)
            }
            let shareParent = NSMenuItem(title: L("Share Layout…"), action: nil, keyEquivalent: "")
            shareParent.submenu = share
            menu.addItem(shareParent)
            let links = NSMenu()
            for layout in layouts {
                let entry = item(layout.name, #selector(copyShareLink(_:)))
                entry.representedObject = layout.name
                links.addItem(entry)
            }
            let linksParent = NSMenuItem(title: L("Copy Share Link"), action: nil, keyEquivalent: "")
            linksParent.submenu = links
            menu.addItem(linksParent)
            for layout in layouts {
                let entry = item(layout.name, #selector(deleteLayout(_:)))
                entry.representedObject = layout.name
                delete.addItem(entry)
            }
            let parent = NSMenuItem(title: L("Delete"), action: nil, keyEquivalent: "")
            parent.submenu = delete
            menu.addItem(parent)
        }
        let parent = NSMenuItem(title: L("Saved Layouts"), action: nil, keyEquivalent: "")
        parent.submenu = menu
        return parent
    }

    @objc private func saveLayout() {
        afterMenu { delegate in
            guard let name = TextPrompt.ask(
                title: "Save layout",
                message: "Saves how the windows on this display are arranged in every workspace. Apply it any time from Saved Layouts.",
                initial: "", placeholder: "Coding, Writing, Meetings…", button: "Save"),
                !name.trimmingCharacters(in: .whitespaces).isEmpty
            else { return }
            delegate.engine.saveLayout(named: name.trimmingCharacters(in: .whitespaces))
        }
    }

    @objc private func applyLayout(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        afterMenu { $0.engine.applyLayout(named: name) }
    }

    @objc private func deleteLayout(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        afterMenu { $0.engine.deleteLayout(named: name) }
    }
    @objc private func undoLayout() { afterMenu { $0.engine.undo() } }

    /// Runs `work` once the menu has fully closed, so window moves and focus
    /// changes don't race the menu's own teardown.
    private func afterMenu(_ work: @escaping (AppDelegate) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            work(self)
        }
    }
    @objc private func checkForUpdates() { updater.check(userInitiated: true) }

    private func headerTitle(trusted: Bool) -> String {
        if !trusted { return PermissionStatus.headline }
        if engine.isPaused { return "Monorail is paused" }
        if let status = engine.status() {
            let workspace = engine.workspaceCount > 1
                ? "\(store.settings.workspaceName(status.workspace - 1)) · " : ""
            if status.columnCount == 0 { return "\(workspace)No windows yet" }
            return "\(workspace)Slide \(status.focusedColumn) of \(status.columnCount)"
        }
        return "Monorail is running"
    }

    @objc private func sendFeedbackFromMenu() { afterMenu { _ in ProblemReport.feedback() } }

    @objc private func performMenuAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = Action(rawValue: raw) else { return }
        afterMenu { [weak self] _ in self?.engine.perform(action) }
    }

    private func item(_ title: String, _ selector: Selector, key: String = "", action: Action? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        if let action, let shortcut = store.settings.keymap.shortcuts(for: action).first,
            let character = menuKeyEquivalent(for: shortcut.keyCode)
        {
            item.keyEquivalent = character
            var mask: NSEvent.ModifierFlags = []
            if shortcut.modifiers.contains(.control) { mask.insert(.control) }
            if shortcut.modifiers.contains(.option) { mask.insert(.option) }
            if shortcut.modifiers.contains(.shift) { mask.insert(.shift) }
            if shortcut.modifiers.contains(.command) { mask.insert(.command) }
            item.keyEquivalentModifierMask = mask
        }
        return item
    }

    /// A menu key equivalent for display, for letter keys and Escape/Space.
    private func menuKeyEquivalent(for keyCode: UInt16) -> String? {
        if keyCode == KeyCode.escape { return "\u{1b}" }
        if keyCode == KeyCode.space { return " " }
        let name = KeyCode.name(for: keyCode)
        return name.count == 1 ? name.lowercased() : nil
    }

    @objc private func togglePause() { afterMenu { $0.engine.togglePause() } }
    @objc private func retile() { afterMenu { $0.engine.retile() } }
    @objc private func showSwitcher() { switcher.show() }
    @objc private func showSettingsFromMenu() { showSettings() }
    @objc private func showWelcomeFromMenu() { showWelcome() }
    @objc private func quit() { NSApp.terminate(nil) }

    /// Signalbox's menu: only what Signalbox does, and the way to the full Monorail.
    private func stationMenu(_ menu: NSMenu) {
        let header = NSMenuItem(title: Brand.full, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(awakeMenu())
        menu.addItem(eveningMenu())
        menu.addItem(.separator())
        // Said specifically when Monorail would help right now ("11 windows open"), plainly otherwise.
        let reason = MonorailNudgeWatch.shared.reason
        let monorail = item(MonorailNudgeWatch.shared.monorailInstalled ? "Open Monorail"
                            : reason.map { "\($0.headline): Try Monorail…" } ?? "Get Monorail: Arrange Your Windows…", #selector(openMonorailSite))
        if let reason { monorail.toolTip = reason.pitch }
        monorail.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: nil)
        menu.addItem(monorail)
        menu.addItem(.separator())
        menu.addItem(item(L("Settings…"), #selector(showSettingsFromMenu), key: ","))
        menu.addItem(item("About \(Brand.full)", #selector(showAbout)))
        menu.addItem(item("Quit \(Brand.name)", #selector(quit), key: "q"))
    }

    @objc private func openMonorailSite() {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.ashforde.monorail") {
            NSWorkspace.shared.openApplication(at: app, configuration: .init())
        } else {
            NSWorkspace.shared.open(Brand.monorailURL)
        }
    }

    @objc private func focusWindowFromMenu(_ sender: NSMenuItem) {
        let id = WindowID(sender.tag)
        afterMenu { $0.engine.focusAndReveal(id) }
    }

    @objc private func showShortcuts() {
        navigation.tab = .shortcuts
        showSettings()
    }

    @objc private func showAbout() {
        navigation.tab = .about
        showSettings()
    }

    // MARK: - Windows

    private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                store: store,
                navigation: navigation,
                stats: stats,
                isPaused: { [weak self] in self?.engine.isPaused ?? false },
                setPaused: { [weak self] in self?.engine.setPaused($0) }
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "\(Brand.full) — Settings"
            // Closing Settings mid-recording must not leave shortcuts paused.
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in self?.store.stopRecording() }
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.contentMinSize = NSSize(width: 640, height: 440)
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("MonorailSettings")
            window.center()
            settingsWindow = window
        }
        present(settingsWindow!)
    }

    /// Closes a window by shrinking it into the Monorail icon in the menu bar, so you see
    /// where Monorail lives. Just closes with Reduce Motion on.
    private func shrinkIntoMenuBar(_ window: NSWindow?) {
        guard let window else { return }
        guard !Motion.reduced, let button = statusItem?.button, let bar = button.window else {
            window.close()
            return
        }
        let icon = bar.convertToScreen(button.convert(button.bounds, to: nil))
        let original = window.frame
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)
            window.animator().setFrame(NSRect(x: icon.midX - 20, y: icon.midY - 14, width: 40, height: 28), display: true)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.close()
            window.alphaValue = 1
            window.setFrame(original, display: false)
        })
    }

    private func showWelcome() {
        if welcomeWindow == nil {
            var view = WelcomeView(store: store, practice: practice) { [weak self] in
                guard let self else { return }
                self.store.settings.hasCompletedOnboarding = true
                self.closeDemoWindows()
                self.shrinkIntoMenuBar(self.welcomeWindow)
            }
            view.practiceWindows = { [weak self] open in
                if open { self?.openDemoWindows() } else { self?.closeDemoWindows() }
            }
            // One page at a time, in a window with no visible title bar, like a new Apple app.
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Welcome to \(Brand.full)"
            window.keepInFront()
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            welcomeWindow = window
        }
        present(welcomeWindow!)
        // Coach tips stay up while you try things out (also after the tour
        // closes), until every practice step is done or ten minutes pass.
        if practice.next != nil, Accessibility.isTrusted(prompt: false) {
            coach.start(practice)
            DispatchQueue.main.asyncAfter(deadline: .now() + 600) { [weak self] in self?.coach.stop() }
        }
    }

    private func present(_ window: NSWindow) {
        fitOnScreen(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Monorail's open windows that no screen shows fully any more are fitted again.
    private func refitOwnWindows() {
        for window in NSApp.windows where window.isVisible && window.styleMask.contains(.titled) {
            let shown = NSScreen.screens.contains { $0.visibleFrame.insetBy(dx: -2, dy: -2).contains(window.frame) }
            if !shown { fitOnScreen(window) }
        }
    }

    /// Monorail's own windows always fit the screen they open on (the one with the pointer):
    /// smaller screens get a smaller window, and nothing hangs off an edge.
    private func fitOnScreen(_ window: NSWindow) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame.insetBy(dx: 16, dy: 16)
        var frame = window.frame
        let tooBig = frame.width > visible.width || frame.height > visible.height
        frame.size.width = min(frame.width, visible.width)
        frame.size.height = min(frame.height, visible.height)
        // Already fully on this screen and not too big: leave it where the person put it.
        if !tooBig, visible.insetBy(dx: -16, dy: -16).contains(window.frame) { return }
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        window.setFrame(frame, display: true)
    }
}

// MARK: - UI test

/// `Monorail --ui-test`: drives real windows end to end on a Mac where Monorail has
/// Accessibility access (run by the UI-test workflow on a self-hosted Mac).
enum UITest {
    static var isRequested: Bool { CommandLine.arguments.contains("--ui-test") }
}

extension AppDelegate {
    func runUITest() {
        var passed = 0
        var failed = 0
        func check(_ ok: Bool, _ name: String) {
            print(ok ? "  ✓ \(name)" : "  ✗ \(name)")
            if ok { passed += 1 } else { failed += 1 }
        }
        func textEdit() -> [[String: Any]] { engine.windowList().filter { $0["app"] as? String == "TextEdit" } }
        func finish() {
            SessionTabs.run("tell application \"TextEdit\" to close every document saving no")
            SessionTabs.run("tell application \"TextEdit\" to quit")
            print("\n\(passed) passed, \(failed) failed")
            fflush(stdout)
            exit(failed == 0 ? 0 : 1)
        }
        guard Accessibility.isTrusted(prompt: false) else {
            print("Monorail needs Accessibility access on this Mac for --ui-test")
            exit(77)
        }
        print("==> Monorail UI test")
        // Steps run one after another, a moment apart, while windows settle.
        let steps: [(Double, () -> Void)] = [
            (0.5, {
                DispatchQueue.global().async {
                    SessionTabs.run("tell application \"TextEdit\" to repeat 3 times\nmake new document\nend repeat")
                }
            }),
            (4.0, {
                let windows = textEdit()
                check(windows.count == 3, "sees three TextEdit windows (found \(windows.count))")
                check(windows.allSatisfy { $0["floating"] as? Bool == false }, "tiles them")
            }),
            (1.0, { [self] in
                let ids = textEdit().prefix(2).compactMap { ($0["id"] as? Int).map { WindowID($0) } }
                let slidesBefore = Set(textEdit().compactMap { $0["slide"] as? Int }).count
                UserDefaults.standard.set(slidesBefore, forKey: "MonorailUITestSlides")
                check(engine.pairWindows(ids, arrangement: .columns), "pairs two windows")
            }),
            (1.2, { [self] in
                let windows = textEdit()
                check(windows.count >= 2 && windows[0]["slide"] as? Int == windows[1]["slide"] as? Int, "the pair shares a slide")
                engine.undo()
            }),
            (1.2, { [self] in
                let before = UserDefaults.standard.integer(forKey: "MonorailUITestSlides")
                check(Set(textEdit().compactMap { $0["slide"] as? Int }).count == before, "undo puts the slides back")
                if let id = textEdit().first?["id"] as? Int { engine.moveWindow(WindowID(id), toWorkspace: 1) }
            }),
            (1.2, { [self] in
                let moved = textEdit().first
                check(moved?["workspace"] as? Int == 2, "moves a window to workspace 2")
                engine.switchWorkspace(to: 0)
            }),
            (0.8, { finish() }),
        ]
        var delay = 0.0
        for (wait, step) in steps {
            delay += wait
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: step)
        }
        // Never hang a runner.
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            print("Timed out")
            exit(2)
        }
    }
}
#endif
