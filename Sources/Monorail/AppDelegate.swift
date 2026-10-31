#if os(macOS)
import AppKit
import Combine
import MonorailCore
import SwiftUI
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = SettingsStore()
    private lazy var engine = Engine(settings: store.settings)
    private let input = InputMonitor()
    private let trackpad = TrackpadSwipe.shared
    private let switcher = SwitcherController()
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
    private let voice = VoiceCommands()
    private let headFocus = HeadFocus()
    private let webRemote = WebRemote()
    private let pairSync = PairSync()
    private let slideShare = ScreenMirror()
    private let windowMirror = ScreenMirror()
    private let demoLens = ScreenMirror()
    private let annotation = AnnotationOverlay()
    private let keystrokes = KeystrokeOverlay()
    private let presenterNotesPanel = PresenterNotes()
    private let cameraTile = CameraTile()
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
    let usage = UsageLog()
    private var awakeTicker: Timer?
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

        // The main thread never waits long on a busy app; window moves run in
        // the background with their own, longer allowance (see WindowWriter).
        Accessibility.setGlobalTimeout(0.25)
        // Hold ⌥ while Monorail starts for safe mode.
        safeMode = NSEvent.modifierFlags.contains(.option)
        setUpStatusItem()
        wireUp()
        handleTerminationSignals()

        if Accessibility.isTrusted(prompt: false) {
            startEngine()
        } else {
            waitForPermission()
        }
        if !store.settings.hasCompletedOnboarding || !Accessibility.isTrusted(prompt: false) {
            showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stats.save()
        // Give Caps Lock back to macOS while Monorail isn't running.
        if store.settings.capsLockKey { CapsLockKey.set(false) }
        sliderBar.hideAll(animated: false)
        input.stop()
        trackpad.stop()
        engine.shutdown()
        usage.awake(false)
        awake.shutdown()
        usage.save()
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
                engine.setPresenting(argument == "on")
            case "focus-mode" where argument == "on" || argument == "off":
                engine.setFocusMode(argument == "on")
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
            case "awake":
                // monorail://awake (toggle), awake/on, awake/off, awake/90 (minutes), awake/downloading
                switch argument.lowercased() {
                case "", "toggle": awake.toggle()
                case "on": awake.start(minutes: store.settings.awakeDefaultMinutes)
                case "off": awake.end()
                case "downloading": awake.start(.whileDownloading)
                default: if let minutes = Int(argument) { awake.start(minutes: minutes) }
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
            openSettings: { [weak self] in self?.showSettings() }
        )
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
        engine.onShowSwitcher = { [weak self] in self?.switcher.toggle() }
        engine.onShowOverview = { [weak self] in self?.overview.toggle() }
        engine.onNotice = { [weak self] text in
            guard let self, !self.engine.isPresenting, !self.store.settings.quietMode else { return }
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
        snapPicker.snap = { [weak self] id, position in self?.engine.snapWindow(id, to: position) }
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
        wireUpV11()
        wireUpV12()
    }

    // MARK: - 1.2

    private func wireUpV12() {
        engine.onAgentWaiting = { [weak self] id, app in
            guard let self else { return }
            self.toast.show("\(app): an agent is waiting for you · ⌃⌥/ then “agent”")
            NSSound(named: "Glass")?.play()
            self.postWebhook("agent_waiting", ["id": Int(id), "app": app])
        }
        engine.onRuleSuggestion = { [weak self] name, bundle, width in
            guard let self else { return }
            var settings = self.store.settings
            settings.suggestedRules[bundle] = width
            self.store.settings = settings
            self.toast.show("You keep giving \(name) \(Self.widthName(width)) · make it a rule in Settings → Smart")
        }
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
        SmartBridge.remoteURL = { [weak self] in self?.webRemote.url }
        SmartBridge.remoteQR = { [weak self] in self?.webRemote.qrCode() }
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
        voice.onState = { [weak self] text in self?.toast.show(text) }
        voice.onText = { [weak self] text in self?.say(text) }
        headFocus.onTurn = { [weak self] _ in self?.engine.perform(.focusNextDisplay) }
        webRemote.perform = { [weak self] name in if let action = Action(rawValue: name) { self?.engine.perform(action) } }
        webRemote.status = { [weak self] in
            guard let status = self?.engine.status() else { return "" }
            return "Workspace \(status.workspace) · slide \(status.focusedColumn) of \(status.columnCount)"
        }
        pairSync.onStatus = { [weak self] text in self?.toast.show(text) }
        pairSync.onLayout = { [weak self] json in _ = self?.engine.applyLayoutJSON(json) }
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
        if StageManagerCheck.isOn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.toast.show("Stage Manager is on as well · turn it off in Control Centre so Monorail can arrange windows")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.checkNotch() }
        watchDormancy()
        wireUpAwake()
    }

    // MARK: Stay Awake

    private func wireUpAwake() {
        engine.onActionPerformed = { [weak self] action in self?.usage.action(action) }
        whatsNew.tryAction = { [weak self] action in
            if action == .commandPalette { self?.palette.show() } else { self?.engine.perform(action) }
        }
        UsageBridge.log = usage
        awake.settings = { [weak self] in self?.store.settings ?? AppSettings() }
        awake.onChange = { [weak self] on, why in
            guard let self else { return }
            if self.store.settings.awakeNotify { self.toast.show(why) }
            if self.store.settings.awakeSound { NSSound(named: on ? "Purr" : "Pop")?.play() }
            self.postWebhook(on ? "stay_awake_on" : "stay_awake_off", ["status": self.awake.statusText])
            self.usage.awake(on)
            self.awakeTicker?.invalidate()
            self.awakeTicker = on ? Timer.every(20) { [weak self] _ in self?.updateStatusItem() } : nil
            self.updateStatusItem()
        }
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
            ("Stay Awake with the Lid Closed", settings.awakeClosedLid, #selector(toggleAwakeLidFromMenu)),
            ("Automatic Triggers", settings.awakeTriggersOn, #selector(toggleAwakeTriggersFromMenu)),
        ] {
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
            alert.informativeText = "During Stay Awake your MacBook keeps running when you close it, even without an external display. macOS asks for your password each time it turns on or off. Don't put a running Mac in a bag: it can get hot."
            alert.addButton(withTitle: "Turn On")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        toggleAwakeSetting { $0.awakeClosedLid.toggle() }
    }
    @objc private func toggleAwakeTriggersFromMenu() { toggleAwakeSetting { $0.awakeTriggersOn.toggle() } }
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
        headFocus.setEnabled(settings.headFocus)
        if settings.webRemote, settings.webRemoteToken.isEmpty {
            var changed = settings
            changed.webRemoteToken = Self.randomToken()
            DispatchQueue.main.async { [weak self] in self?.store.settings = changed }
        }
        webRemote.token = settings.webRemoteToken
        webRemote.setEnabled(settings.webRemote && !settings.webRemoteToken.isEmpty, port: UInt16(clamping: settings.apiPort + 1))
        shareWatch.setEnabled(settings.safeScreenShare)
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
                if store.settings.notchHUD {
                    notchHUD.show(slide: status.focusedColumn, slides: status.columnCount, workspace: status.workspace,
                                  workspaces: engine.workspaceCount)
                }
            }
        }
        if pairSync.isOn, Date().timeIntervalSince(lastSyncSent) > 1, let json = engine.layoutJSON() {
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
        toast.show("Didn’t catch that · try “Safari two thirds” or “Slack and Mail side by side on 2”")
        return false
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
        guard query.split(separator: " ").count >= 2 else { return [] }
        var list: [PaletteCommand] = []
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

    private func v12PaletteCommands() -> [PaletteCommand] {
        var list: [PaletteCommand] = []
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
        default:
            performAppActionV12(action)
        }
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
        engine.start()
        apply(store.settings)
        updateStatusItem()
        store.startCloudSync()
        store.watchFile()
        autoRules.start()
        // After an update: what changed. (Not on a first install.)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if store.settings.hasCompletedOnboarding, !version.isEmpty, store.settings.lastSeenVersion != version {
            if !store.settings.lastSeenVersion.isEmpty || store.settings.hasCompletedOnboarding {
                whatsNew.show(version: version)
            }
        }
        if store.settings.lastSeenVersion != version { store.settings.lastSeenVersion = version }
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

    /// Polls until the user grants Accessibility, then starts.
    private func waitForPermission() {
        permissionTimer = Timer.every(1.5) { [weak self] _ in
            guard Accessibility.isTrusted(prompt: false) else { return }
            self?.startEngine()
        }
    }

    private func apply(_ original: AppSettings) {
        let settings = adjustedV12(original)
        let syncWasOn = engine.settings.syncThroughICloud
        let liveReloadWasOn = engine.settings.liveReloadSettings
        engine.settings = settings
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
        updateArrowItems(visible: settings.showNavigationArrows)
        updater.setAutomatic(settings.checkForUpdates)
        updater.installAutomatically = settings.installUpdatesAutomatically
        hotEdges.onSlide = { [weak self] right in self?.engine.step(forward: right, honourReverse: false, visual: true) }
        hotEdges.setEnabled(settings.hotEdges && engine.isRunning)
        sliderBar.compact = settings.compactSlider
        sliderBar.showTitles = settings.sliderTitles
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
        commands.setCustomLayout = { [weak self] id, rows in self?.engine.setSlideLayout(of: id, to: .custom, rows: rows) }
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
        NSWorkspace.shared.open(link)
        toast.show("Joining “\(title)”")
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

    // MARK: Local API

    private func handleAPI(_ method: String, _ path: [String], _ body: [String: Any]) -> Any? {
        func int(_ key: String) -> Int? { (body[key] as? Int) ?? (body[key] as? String).flatMap { Int($0) } }
        func text(_ key: String) -> String? { body[key] as? String }
        switch (method, path.first ?? "") {
        case ("GET", "state"):
            guard let state = currentState(), let data = try? JSONEncoder().encode(state),
                let object = try? JSONSerialization.jsonObject(with: data)
            else { return [String: Any]() }
            return object
        case ("GET", "windows"):
            return engine.windowList()
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
        case ("GET", "awake"):
            return ["on": awake.isOn, "status": awake.statusText]
        case ("POST", "awake"):
            if text("state") == "off" { awake.end() } else if let minutes = int("minutes") { awake.start(minutes: minutes) } else {
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
            app: focused?.appName, title: focused?.title, focusMode: engine.isFocusMode)
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
        return v12PaletteCommands() + list
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

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        button.image = StatusIcon.image(paused: engine.isPaused, badge: updater.available != nil)
        button.imagePosition = .imageLeading
        if store.settings.menuBarStyle == .mini, store.settings.showColumnIndicator, !engine.isPaused,
            let status = engine.status()
        {
            // The position lives in the icon; only extras (pomodoro, recording, focus) add text.
            button.image = StatusIcon.mini(slide: status.focusedColumn, slides: status.columnCount,
                                           workspace: status.workspace, workspaces: engine.workspaceCount,
                                           badge: updater.available != nil)
            var title = ""
            if engine.isFocusMode { title += " ◉" }
            if engine.isRecording { title += " ● REC" }
            if store.settings.menuBarShowsApp, let app = engine.focusedAppName { title += " \(app)" }
            if store.settings.menuBarShowsTitle, let focused = engine.lastFocusedTitle {
                title += " " + (focused.count > 32 ? String(focused.prefix(31)) + "…" : focused)
            }
            if let statusExtra { title += " \(statusExtra)" }
            button.title = title
            button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular)
        } else if store.settings.showColumnIndicator, !engine.isPaused, let status = engine.status() {
            var position = "\(status.focusedColumn)/\(status.columnCount)"
            switch store.settings.menuBarStyle {
            case .dots where status.columnCount > 0 && status.columnCount <= 9:
                position = (1...status.columnCount).map { $0 == status.focusedColumn ? "●" : "○" }.joined()
            case .number:
                position = engine.workspaceCount > 1 ? "\(status.workspace)" : "\(status.focusedColumn)"
            default:
                break
            }
            var title = engine.workspaceCount > 1 && store.settings.menuBarStyle != .number
                ? " \(status.workspace) · \(position)" : " \(position)"
            if store.settings.menuBarShowsApp, let app = engine.focusedAppName { title = " \(app) ·" + title }
            if engine.isFocusMode { title = " ◉" + title }
            if engine.isRecording { title = " ● REC" + title }
            if store.settings.menuBarShowsTitle, let focused = engine.lastFocusedTitle {
                let short = focused.count > 32 ? String(focused.prefix(31)) + "…" : focused
                title = " \(short) ·" + title
            }
            if let statusExtra { title = " \(statusExtra) ·" + title }
            button.title = title
            button.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 1, weight: .regular)
        } else {
            button.title = statusExtra.map { " \($0)" } ?? ""
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
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
            menu.addItem(item("Grant Accessibility Access…", #selector(showWelcomeFromMenu)))
        }
        menu.addItem(awakeMenu())
        let animate = item(L("Animate Windows"), #selector(toggleAnimationsFromMenu), action: .toggleAnimations)
        animate.state = store.settings.animate ? .on : .off
        animate.toolTip = "Off: windows move instantly. Everything else works the same, and it saves energy."
        menu.addItem(animate)

        let windows = engine.activeStripWindows()
        if !windows.isEmpty {
            menu.addItem(.separator())
            for (index, window) in windows.enumerated() {
                let title = window.title.isEmpty ? window.appName : "\(window.appName) — \(window.title)"
                let entry = item("\(index + 1). \(title)", #selector(focusWindowFromMenu(_:)))
                entry.tag = Int(window.id)
                entry.state = window.isFocused ? .on : .off
                entry.image = window.icon.map { icon in
                    let copy = icon.copy() as! NSImage
                    copy.size = NSSize(width: 16, height: 16)
                    return copy
                }
                menu.addItem(entry)
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

        menu.addItem(.separator())
        menu.addItem(item(L("Settings…"), #selector(showSettingsFromMenu), key: ","))
        menu.addItem(shortcutsMenu())
        menu.addItem(item(L("Welcome Tour…"), #selector(showWelcomeFromMenu)))
        menu.addItem(item(L("What’s New") + "…", #selector(showWhatsNewFromMenu)))
        menu.addItem(item(L("Check for Updates…"), #selector(checkForUpdates)))
        menu.addItem(item("About \(Brand.full)", #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item(L("Quit Monorail"), #selector(quit), key: "q"))
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
        if !trusted { return "Monorail needs Accessibility access" }
        if engine.isPaused { return "Monorail is paused" }
        if let status = engine.status() {
            let workspace = engine.workspaceCount > 1
                ? "\(store.settings.workspaceName(status.workspace - 1)) · " : ""
            if status.columnCount == 0 { return "\(workspace)No windows yet" }
            return "\(workspace)Slide \(status.focusedColumn) of \(status.columnCount)"
        }
        return "Monorail is running"
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
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        present(settingsWindow!)
    }

    private func showWelcome() {
        if welcomeWindow == nil {
            var view = WelcomeView(store: store, practice: practice) { [weak self] in
                guard let self else { return }
                self.store.settings.hasCompletedOnboarding = true
                self.closeDemoWindows()
                self.welcomeWindow?.close()
            }
            view.practiceWindows = { [weak self] open in
                if open { self?.openDemoWindows() } else { self?.closeDemoWindows() }
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Welcome to \(Brand.full)"
            window.styleMask = [.titled, .closable]
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
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
#endif
