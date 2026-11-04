import XCTest
@testable import MonorailCore

final class NoPermissionTests: XCTestCase {
    // MARK: Actions without Accessibility

    func testActionsThatNeedNoAccessibility() {
        for action: Action in [.toggleAwake, .keepAvailable, .toggleEvening, .displayDimmer, .displayMoreSpace, .openSettings, .commandPalette] {
            XCTAssertTrue(action.worksWithoutAccessibility, "\(action)")
        }
        for action: Action in [.focusLeft, .focusRight, .overview, .retile, .stashWindow] {
            XCTAssertFalse(action.worksWithoutAccessibility, "\(action)")
        }
    }

    func testKeepAvailableIsAnAction() {
        XCTAssertEqual(Action(rawValue: "keep-available"), .keepAvailable)
        XCTAssertFalse(Action.keepAvailable.title.isEmpty)
        XCTAssertTrue(Action.unboundByDefault.contains(.keepAvailable))
    }

    // MARK: Allowlist

    func testAllowlist() {
        let ids = Set(ScriptableApps.all.map(\.bundleID))
        XCTAssertEqual(ids.count, 12)
        for id in ["com.apple.Safari", "com.google.Chrome", "com.apple.finder", "com.apple.Terminal", "com.apple.Notes",
                   "com.apple.mail", "com.apple.TextEdit", "com.apple.iWork.Pages", "com.apple.iWork.Numbers",
                   "com.apple.iWork.Keynote", "com.apple.Preview", "com.googlecode.iterm2"] {
            XCTAssertTrue(ScriptableApps.isScriptable(id), id)
        }
        XCTAssertTrue(ScriptableApps.isScriptable("com.apple.safari"), "case doesn't matter")
        XCTAssertFalse(ScriptableApps.isScriptable("com.microsoft.teams2"))
        XCTAssertFalse(ScriptableApps.isScriptable(""))
        // Nothing that could break out of the quoted identifier in a script.
        XCTAssertTrue(ScriptableApps.all.allSatisfy { !$0.bundleID.contains("\"") && !$0.bundleID.contains("\\") })
    }

    func testFrontTwoSkipsOthersAndDuplicates() {
        let two = ScriptableApps.frontTwo(["com.tinyspeck.slackmacgap", "com.apple.Safari", "com.apple.Safari", "com.apple.Notes", "com.apple.finder"])
        XCTAssertEqual(two.map(\.name), ["Safari", "Notes"])
        XCTAssertEqual(ScriptableApps.frontTwo(["com.apple.Safari"]).count, 1)
        XCTAssertTrue(ScriptableApps.frontTwo([]).isEmpty)
    }

    // MARK: Frame maths

    /// A 1440×900 main display with a 25-point menu bar and an 80-point Dock, in AppKit coordinates.
    private let cocoaVisible = Rect(x: 0, y: 80, width: 1440, height: 795)

    func testFlipToAppleScriptSpace() {
        let topLeft = ScriptBounds.topLeft(fromCocoa: cocoaVisible, primaryHeight: 900)
        XCTAssertEqual(topLeft, Rect(x: 0, y: 25, width: 1440, height: 795), "the menu bar is at the top")
        // A second display above the main one has negative y in AppleScript space.
        let above = ScriptBounds.topLeft(fromCocoa: Rect(x: 0, y: 900, width: 1920, height: 1080), primaryHeight: 900)
        XCTAssertEqual(above.y, -1080)
    }

    func testBoundsRoundTrip() {
        let rect = Rect(x: 10.4, y: 25, width: 700.2, height: 795)
        XCTAssertEqual(ScriptBounds.bounds(of: rect), [10, 25, 711, 820])
        XCTAssertEqual(ScriptBounds.rect(fromBounds: [10, 25, 711, 820]), Rect(x: 10, y: 25, width: 701, height: 795))
        XCTAssertNil(ScriptBounds.rect(fromBounds: [1, 2, 3]))
    }

    func testPlacements() {
        let visible = ScriptBounds.topLeft(fromCocoa: cocoaVisible, primaryHeight: 900)
        XCTAssertEqual(ScriptBounds.frame(.leftHalf, in: visible), Rect(x: 0, y: 25, width: 720, height: 795))
        XCTAssertEqual(ScriptBounds.frame(.rightHalf, in: visible), Rect(x: 720, y: 25, width: 720, height: 795))
        XCTAssertEqual(ScriptBounds.frame(.fill, in: visible), visible)
        let centred = ScriptBounds.frame(.centre, in: visible, current: Rect(x: 0, y: 25, width: 800, height: 600))
        XCTAssertEqual(centred, Rect(x: 320, y: 122.5, width: 800, height: 600))
        // Too big for the screen: it's made to fit.
        XCTAssertEqual(ScriptBounds.frame(.centre, in: visible, current: Rect(x: 0, y: 0, width: 3000, height: 2000)), visible)
    }

    func testPlacementsWithGap() {
        let visible = Rect(x: 0, y: 25, width: 1440, height: 795)
        let left = ScriptBounds.frame(.leftHalf, in: visible, gap: 8)
        let right = ScriptBounds.frame(.rightHalf, in: visible, gap: 8)
        XCTAssertEqual(left, Rect(x: 8, y: 33, width: 708, height: 779))
        XCTAssertEqual(right.maxX, 1432)
        XCTAssertEqual(right.x - left.maxX, 8, "one gap between the halves")
    }

    func testScreenForWindow() {
        let main = Rect(x: 0, y: 25, width: 1440, height: 795)
        let right = Rect(x: 1440, y: 0, width: 1920, height: 1050)
        XCTAssertEqual(ScriptBounds.screen(for: Rect(x: 1500, y: 100, width: 400, height: 300), among: [main, right]), right)
        XCTAssertEqual(ScriptBounds.screen(for: Rect(x: 100, y: 100, width: 400, height: 300), among: [main, right]), main)
        // Centre off every screen: the one it overlaps most.
        XCTAssertEqual(ScriptBounds.screen(for: Rect(x: 1300, y: -500, width: 400, height: 600), among: [main, right]), right)
        XCTAssertEqual(ScriptBounds.screen(for: nil, among: [main, right]), main)
        XCTAssertNil(ScriptBounds.screen(for: nil, among: []))
    }

    // MARK: Scripts

    func testScripts() {
        let safari = ScriptableApps.app(for: "com.apple.Safari")!
        XCTAssertEqual(ScriptSource.setBounds(safari, Rect(x: 0, y: 25, width: 720, height: 795)),
                       "tell application id \"com.apple.Safari\" to set bounds of front window to {0, 25, 720, 820}")
        XCTAssertEqual(ScriptSource.getBounds(safari), "tell application id \"com.apple.Safari\" to get bounds of front window")
        XCTAssertTrue(ScriptSource.cycleWindows(safari, forward: true).contains("set index of front window to (count of windows)"))
        XCTAssertTrue(ScriptSource.cycleWindows(safari, forward: false).contains("set index of last window to 1"))
    }

    func testErrorMessages() {
        XCTAssertTrue(ScriptErrors.message(-1743, appName: "Safari").contains("Automation"))
        XCTAssertTrue(ScriptErrors.message(-1728, appName: "Notes").contains("no window"))
        XCTAssertTrue(ScriptErrors.message(-600, appName: "Mail").contains("isn’t open"))
        XCTAssertTrue(ScriptErrors.message(-42, appName: "Mail").contains("-42"))
    }

    // MARK: Keep me Available

    func testDeclareActivityOnlyWhenIdleAndDue() {
        func declare(awake: Bool = true, keep: Bool = true, cursor: Bool = false, idle: Double = 60, since: Double = 60) -> Bool {
            AwakePresence.shouldDeclareActivity(awake: awake, keepAvailable: keep, moveCursor: cursor, idleSeconds: idle, sinceLastDeclare: since)
        }
        XCTAssertTrue(declare())
        XCTAssertTrue(declare(keep: false, cursor: true), "the pointer option also keeps you available without Accessibility")
        XCTAssertFalse(declare(keep: false, cursor: false))
        XCTAssertFalse(declare(awake: false))
        XCTAssertFalse(declare(idle: 30), "someone is at the Mac: nothing to do")
        XCTAssertFalse(declare(idle: 50), "over 50 seconds idle, not at")
        XCTAssertFalse(declare(since: 20), "about once a minute at most")
        XCTAssertTrue(declare(since: 55))
    }

    func testCursorNudgeNeedsAccessibility() {
        func nudge(trusted: Bool, idle: Double = 120, since: Double = 600) -> Bool {
            AwakePresence.shouldNudgeCursor(awake: true, moveCursor: true, canPostEvents: trusted, everyMinutes: 4,
                                            idleSeconds: idle, sinceLastNudge: since)
        }
        XCTAssertTrue(nudge(trusted: true))
        XCTAssertFalse(nudge(trusted: false))
        XCTAssertFalse(nudge(trusted: true, idle: 10))
        XCTAssertFalse(nudge(trusted: true, since: 100), "every four minutes")
    }

    func testIdleCheckVerdict() {
        XCTAssertTrue(AwakePresence.idleCheckVerdict(before: 120, after: 0.2).hasPrefix("passed"))
        XCTAssertTrue(AwakePresence.idleCheckVerdict(before: 120, after: 123).hasPrefix("did not drop"))
        XCTAssertTrue(AwakePresence.idleCheckVerdict(before: 0.1, after: 0.1).hasPrefix("inconclusive"))
    }

    /// The profile IT deploys to allow Accessibility: valid, minimal, and for Monorail only.
    func testAccessibilityProfile() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../packaging/mdm/Monorail-Accessibility.mobileconfig").standardizedFileURL
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any]
        let profile = try XCTUnwrap(plist)
        XCTAssertEqual(profile["PayloadType"] as? String, "Configuration")
        XCTAssertEqual(profile["PayloadScope"] as? String, "System")
        let payloads = try XCTUnwrap(profile["PayloadContent"] as? [[String: Any]])
        XCTAssertEqual(payloads.count, 1)
        let tcc = payloads[0]
        XCTAssertEqual(tcc["PayloadType"] as? String, "com.apple.TCC.configuration-profile-policy")
        XCTAssertNotEqual(tcc["PayloadUUID"] as? String, profile["PayloadUUID"] as? String)
        let services = try XCTUnwrap(tcc["Services"] as? [String: Any])
        XCTAssertEqual(Array(services.keys), ["Accessibility"])
        let entry = try XCTUnwrap((services["Accessibility"] as? [[String: Any]])?.first)
        XCTAssertEqual(entry["Identifier"] as? String, "org.ashforde.monorail")
        XCTAssertEqual(entry["IdentifierType"] as? String, "bundleID")
        XCTAssertEqual(entry["Allowed"] as? Bool, true)
        let requirement = try XCTUnwrap(entry["CodeRequirement"] as? String)
        XCTAssertTrue(requirement.hasPrefix("identifier \"org.ashforde.monorail\" and anchor apple generic"))
        XCTAssertTrue(requirement.hasSuffix("certificate leaf[subject.OU] = D69G45342Y"))
    }

    func testSettingsDefaultsAndOldFiles() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertFalse(settings.keepAvailable)
        XCTAssertTrue(settings.arrangeScriptableApps)
        var on = AppSettings()
        on.keepAvailable = true
        XCTAssertTrue(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(on)).keepAvailable)
        XCTAssertTrue(StarterExtra.keepAvailable.title.contains("Available"))
    }
}
