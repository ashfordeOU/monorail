import Foundation
import XCTest
@testable import MonorailCore

final class IntelligenceTests: XCTestCase {
    let apps = ["Slack", "Mail", "Safari", "Visual Studio Code", "Figma"]

    func testPairSentence() {
        XCTAssertEqual(CommandParser.parse("Slack and Mail side by side on 3", apps: apps),
                       .pair(apps: ["Slack", "Mail"], arrangement: .columns, workspace: 2))
        XCTAssertEqual(CommandParser.parse("figma and safari stacked", apps: apps),
                       .pair(apps: ["Figma", "Safari"], arrangement: .stack, workspace: nil))
    }

    func testWidthAndWorkspace() {
        XCTAssertEqual(CommandParser.parse("Safari two thirds", apps: apps), .width(app: "Safari", share: 2.0 / 3.0))
        XCTAssertEqual(CommandParser.parse("make this half", apps: apps), .width(app: nil, share: 0.5))
        XCTAssertEqual(CommandParser.parse("move mail to workspace two", apps: apps), .moveTo(app: "Mail", workspace: 1))
        XCTAssertEqual(CommandParser.parse("go to workspace 4", apps: apps), .switchTo(workspace: 3))
        XCTAssertEqual(CommandParser.parse("open visual studio code", apps: apps), .open(app: "Visual Studio Code"))
        XCTAssertEqual(CommandParser.parse("focus mode on", apps: apps), .focusMode(true))
        XCTAssertEqual(CommandParser.parse("undo", apps: apps), .action(.undo))
        XCTAssertNil(CommandParser.parse("xyzzy", apps: apps))
    }

    func testIntentMatching() {
        let candidates = [
            IntentCandidate(kind: .template, name: "Coding", keywords: ["Xcode", "Terminal"]),
            IntentCandidate(kind: .layout, name: "Writing", keywords: ["Pages"]),
            IntentCandidate(kind: .pair, name: "Comms", keywords: ["Slack", "Mail"]),
        ]
        XCTAssertEqual(IntentMatcher.best(for: "write the Q3 report", in: candidates)?.0.name, "Writing")
        XCTAssertEqual(IntentMatcher.best(for: "let's do some debugging code", in: candidates)?.0.name, "Coding")
        XCTAssertEqual(IntentMatcher.best(for: "check my email", in: candidates)?.0.name, "Comms")
        XCTAssertNil(IntentMatcher.best(for: "bake bread", in: candidates))
    }

    func testPrediction() {
        var p = SequencePredictor()
        for _ in 0..<4 { p.record("Figma"); p.record("Slack") }
        p.record("Figma"); p.record("Linear")
        let next = p.predict(after: "Figma")
        XCTAssertEqual(next?.app, "Slack")
        XCTAssertEqual(next?.confidence ?? 0, 0.8, accuracy: 0.01)
        XCTAssertNil(SequencePredictor().predict(after: "Figma"))
    }

    func testSwitchRate() {
        var monitor = SwitchRateMonitor(window: 60, threshold: 3)
        let now = Date()
        XCTAssertFalse(monitor.record(at: now))
        XCTAssertFalse(monitor.record(at: now.addingTimeInterval(1)))
        XCTAssertTrue(monitor.record(at: now.addingTimeInterval(2)))
        XCTAssertFalse(monitor.record(at: now.addingTimeInterval(3)))  // no repeat alert
    }

    func testCorrectionLearner() {
        var learner = CorrectionLearner()
        XCTAssertNil(learner.record(app: "Xcode", width: 0.66))
        XCTAssertNil(learner.record(app: "Xcode", width: 0.67))
        XCTAssertEqual(learner.record(app: "Xcode", width: 0.65) ?? 0, 2.0 / 3.0, accuracy: 0.001)
        XCTAssertNil(learner.record(app: "Xcode", width: 0.66))
    }

    func testProjects() {
        XCTAssertEqual(ProjectClusterer.project(in: "Engine.swift — monorail", appName: "Xcode"), "monorail")
        XCTAssertEqual(ProjectClusterer.project(in: "Acme Rebrand – Figma", appName: "Figma"), "Acme Rebrand")
        XCTAssertNil(ProjectClusterer.project(in: "Untitled", appName: "TextEdit"))
        let groups = ProjectClusterer.groups([
            (id: 1, app: "Xcode", title: "Engine.swift — monorail"),
            (id: 2, app: "Terminal", title: "zsh — Monorail"),
            (id: 3, app: "Figma", title: "Acme – Figma"),
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.values.first?.sorted(), [1, 2])
    }

    func testContentWidths() {
        XCTAssertEqual(ContentWidths.share(for: "com.googlecode.iterm2", displayWidth: 1512) ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(ContentWidths.share(for: "com.apple.Safari", displayWidth: 1512) ?? 0, 0.75, accuracy: 0.001)
        XCTAssertNil(ContentWidths.share(for: "com.example.unknown", displayWidth: 1512))
    }

    func testPathRules() {
        let rules = [PathRule(path: "~/Clients", workspace: 1), PathRule(path: "~/Clients/Acme", workspace: 2)]
        XCTAssertEqual(PathRule.workspace(for: "/Users/a/Clients/Acme/brief.pages", rules: rules, home: "/Users/a"), 2)
        XCTAssertEqual(PathRule.workspace(for: "/Users/a/Clients/Other/x.txt", rules: rules, home: "/Users/a"), 1)
        XCTAssertNil(PathRule.workspace(for: "/Users/a/ClientsX/y", rules: rules, home: "/Users/a"))
    }

    func testFlowAndAgents() {
        XCTAssertGreaterThan(FlowScore.score(focusMinutes: 200, activeMinutes: 240, switches: 40), 80)
        XCTAssertLessThan(FlowScore.score(focusMinutes: 10, activeMinutes: 240, switches: 900), 30)
        XCTAssertEqual(TimeBudget.over(used: 70, budget: 60), 10)
        XCTAssertNil(TimeBudget.over(used: 50, budget: 60))
        XCTAssertEqual(AgentWatch.state(title: "✳ Claude Code — needs approval"), .waiting)
        XCTAssertEqual(AgentWatch.state(title: "codex — running tests"), .working)
        XCTAssertNil(AgentWatch.state(title: "zsh — ~/src"))
        XCTAssertEqual(DisplayProfile.key(for: ["b", "a"]), "a+b")
    }
}

final class StripV12Tests: XCTestCase {
    func strip(_ widths: [Double]) -> Strip {
        Strip(columns: widths.enumerated().map { Column(windows: [WindowID($0.offset + 1)], width: $0.element) })
    }

    func testElasticFocusGrowsTheFocusedSlide() {
        var config = LayoutConfig()
        config.elasticFocus = 0.2
        let s = strip([0.5, 0.5, 0.5])
        XCTAssertEqual(s.elasticWidth(ofColumn: 0, config: config), 0.6, accuracy: 0.0001)
        XCTAssertEqual(s.elasticWidth(ofColumn: 1, config: config), 0.45, accuracy: 0.0001)
        XCTAssertEqual(s.elasticWidth(ofColumn: 1, config: LayoutConfig()), 0.5, accuracy: 0.0001)
        XCTAssertGreaterThan(s.width(ofColumn: 0, config: config, viewportWidth: 1440),
                             s.width(ofColumn: 1, config: config, viewportWidth: 1440))
    }

    func testTallSlideShowsActiveAndPeeksNext() {
        var s = Strip(columns: [Column(windows: [1, 2, 3], width: 0.5)])
        s.toggleTall()
        XCTAssertTrue(s.columns[0].isTall)
        let placements = s.layout(config: LayoutConfig(), viewport: Rect(x: 0, y: 0, width: 1440, height: 900))
        let one = placements.first { $0.window == 1 }!, two = placements.first { $0.window == 2 }!
        let three = placements.first { $0.window == 3 }!
        XCTAssertFalse(one.isHiddenTab)
        XCTAssertFalse(two.isHiddenTab)
        XCTAssertTrue(three.isHiddenTab)
        XCTAssertGreaterThan(two.frame.y, one.frame.y + one.frame.height - 1)
        XCTAssertGreaterThan(one.frame.height, 700)
        // Tall survives a round trip.
        let data = try! JSONEncoder().encode(s)
        XCTAssertTrue(try! JSONDecoder().decode(Strip.self, from: data).columns[0].isTall)
    }
}

final class ThemeTests: XCTestCase {
    func testEveryThemeIsGroupedOnce() {
        let grouped = Theme.classic + Theme.seasonal + Theme.unique
        XCTAssertEqual(Set(grouped), Set(Theme.allCases))
        XCTAssertEqual(grouped.count, Theme.allCases.count)
    }

    func testSeasonsFollowTheCalendar() {
        func date(_ m: Int) -> Date { Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: m, day: 10))! }
        XCTAssertEqual(Theme.seasons.resolved(on: date(4)), .spring)
        XCTAssertEqual(Theme.seasons.resolved(on: date(7)), .summer)
        XCTAssertEqual(Theme.seasons.resolved(on: date(10)), .autumn)
        XCTAssertEqual(Theme.seasons.resolved(on: date(1)), .winter)
        XCTAssertEqual(Theme.seasons.resolved(on: date(12)), .festive)
        XCTAssertEqual(Theme.seasons.resolved(on: date(7), southernHemisphere: true), .winter)
        XCTAssertEqual(Theme.nord.resolved(), Theme.nord)
    }
}

final class VimTests: XCTestCase {
    func testCountsAndCommands() {
        var vim = VimMachine()
        XCTAssertEqual(vim.handle(keyCode: KeyCode.digits[2], modifiers: []), .pending)
        XCTAssertEqual(vim.pendingText, "3")
        XCTAssertEqual(vim.handle(keyCode: KeyCode.l, modifiers: []), .actions([.focusRight, .focusRight, .focusRight]))
        XCTAssertEqual(vim.handle(keyCode: KeyCode.g, modifiers: []), .pending)
        XCTAssertEqual(vim.handle(keyCode: KeyCode.g, modifiers: []), .actions([.focusFirst]))
        XCTAssertEqual(vim.handle(keyCode: KeyCode.g, modifiers: [.shift]), .actions([.focusLast]))
        XCTAssertEqual(vim.handle(keyCode: KeyCode.d, modifiers: []), .pending)
        XCTAssertEqual(vim.handle(keyCode: KeyCode.d, modifiers: []), .actions([.closeSlide]))
        XCTAssertEqual(vim.handle(keyCode: KeyCode.h, modifiers: [.shift]), .actions([.moveLeft]))
        XCTAssertEqual(vim.handle(keyCode: KeyCode.r, modifiers: [.control]), .actions([.redo]))
        XCTAssertEqual(vim.handle(keyCode: KeyCode.zero, modifiers: []), .actions([.focusFirst]))
        XCTAssertEqual(vim.handle(keyCode: KeyCode.c, modifiers: [.command]), .passThrough)
        XCTAssertEqual(vim.handle(keyCode: KeyCode.escape, modifiers: []), .exit)
    }
}

final class WholeSlidesTests: XCTestCase {
    func testPartlyVisibleNeighboursAreHidden() {
        var strip = Strip(columns: [Column(windows: [1], width: 0.5), Column(windows: [2], width: 0.5), Column(windows: [3], width: 0.5)])
        strip.focusColumn(at: 1)
        strip.scroll = 300  // the first slide is partly off the left edge
        var config = LayoutConfig()
        let viewport = Rect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertFalse(strip.columnFrames(config: config, viewport: viewport)[0].isParked)
        config.wholeSlidesOnly = true
        let frames = strip.columnFrames(config: config, viewport: viewport)
        XCTAssertTrue(frames[0].isParked)
        XCTAssertFalse(frames[1].isParked)
    }
}

final class FitWidthTests: XCTestCase {
    func testFitNeverSqueezesBelowTheMinimum() {
        let config = LayoutConfig()
        XCTAssertEqual(config.fitWidth(slides: 2, viewportWidth: 1512), 0.5, accuracy: 0.0001)
        XCTAssertEqual(config.fitWidth(slides: 3, viewportWidth: 1512), 1.0 / 3.0, accuracy: 0.0001)
        // Ten slides on a 1512 pt screen: only three fit at 480 pt or more; the rest scroll.
        XCTAssertEqual(config.fitWidth(slides: 10, viewportWidth: 1512), 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(config.fitWidth(slides: 10, viewportWidth: 3840), 1.0 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(config.fitWidth(slides: 1, viewportWidth: 800), 1, accuracy: 0.0001)
    }
}

final class TilesAcrossTests: XCTestCase {
    func testPairsNeedTwiceTheRoom() {
        XCTAssertEqual(Column(windows: [1], width: 0.5).tilesAcross, 1)
        XCTAssertEqual(Column(windows: [1, 2], width: 0.5, arrangement: .columns).tilesAcross, 2)
        XCTAssertEqual(Column(windows: [1, 2], width: 0.5, arrangement: .stack).tilesAcross, 1)
        XCTAssertEqual(Column(windows: [1, 2, 3, 4], width: 0.5, arrangement: .grid).tilesAcross, 2)
        XCTAssertEqual(Column(windows: [1, 2], width: 0.5, isTabbed: true, arrangement: .columns).tilesAcross, 1)
        // Five pairs on a laptop: each pair needs 960 pt, so one shares the screen at a time.
        XCTAssertEqual(LayoutConfig().fitWidth(slides: 5, viewportWidth: 1512, minimum: 960), 1, accuracy: 0.0001)
    }
}

final class AwakeTests: XCTestCase {
    func date(_ weekday: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        // 2026-11-01 is a Sunday (weekday 1).
        var c = DateComponents(year: 2026, month: 11, day: weekday, hour: hour, minute: minute)
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testTriggers() {
        let context = AwakeContext(now: date(2, 10), runningApps: ["us.zoom.xos"], frontApp: "com.apple.Keynote",
                                   externalDisplays: ["LG UltraFine"], wifi: "Office", charging: false, battery: 40,
                                   cpu: 72, downloadRate: 300, mountedVolumes: ["Backup"])
        func active(_ t: AwakeTrigger) -> Bool { AwakeRules.isActive(t, in: context, calendar: utc) }
        XCTAssertTrue(active(AwakeTrigger(kind: .app, value: "us.zoom.xos")))
        XCTAssertFalse(active(AwakeTrigger(kind: .app, value: "com.apple.Music")))
        XCTAssertTrue(active(AwakeTrigger(kind: .frontApp, value: "com.apple.Keynote")))
        XCTAssertTrue(active(AwakeTrigger(kind: .display)))
        XCTAssertTrue(active(AwakeTrigger(kind: .display, value: "ultrafine")))
        XCTAssertTrue(active(AwakeTrigger(kind: .wifi, value: "Office")))
        XCTAssertFalse(active(AwakeTrigger(kind: .charging)))
        XCTAssertTrue(active(AwakeTrigger(kind: .cpu, threshold: 60)))
        XCTAssertTrue(active(AwakeTrigger(kind: .downloading)))
        XCTAssertTrue(active(AwakeTrigger(kind: .drive, value: "backup")))
        XCTAssertTrue(active(AwakeTrigger(kind: .schedule, startMinute: 9 * 60, endMinute: 17 * 60, weekdays: [2, 3, 4, 5, 6])))
        XCTAssertFalse(active(AwakeTrigger(kind: .schedule, startMinute: 9 * 60, endMinute: 17 * 60, weekdays: [1, 7])))
        XCTAssertFalse(active(AwakeTrigger(kind: .app, value: "us.zoom.xos", isEnabled: false)))
    }

    func testOvernightScheduleAndSessions() {
        let night = AwakeTrigger(kind: .schedule, startMinute: 22 * 60, endMinute: 6 * 60)
        XCTAssertTrue(AwakeRules.isActive(night, in: AwakeContext(now: date(2, 23)), calendar: utc))
        XCTAssertTrue(AwakeRules.isActive(night, in: AwakeContext(now: date(3, 5)), calendar: utc))
        XCTAssertFalse(AwakeRules.isActive(night, in: AwakeContext(now: date(3, 12)), calendar: utc))
        let now = Date()
        XCTAssertTrue(AwakeRules.sessionContinues(.until(now.addingTimeInterval(60)), in: AwakeContext(now: now)))
        XCTAssertFalse(AwakeRules.sessionContinues(.until(now.addingTimeInterval(-1)), in: AwakeContext(now: now)))
        XCTAssertFalse(AwakeRules.sessionContinues(.whileApp("a"), in: AwakeContext(runningApps: ["b"])))
        XCTAssertTrue(AwakeRules.batteryTooLow(AwakeContext(charging: false, battery: 8), cutoff: 10))
        XCTAssertFalse(AwakeRules.batteryTooLow(AwakeContext(charging: true, battery: 8), cutoff: 10))
        XCTAssertEqual(AwakeFormat.remaining(65 * 60), "1 h 05")
        XCTAssertEqual(AwakeFormat.clock(3725), "1:02")
        XCTAssertEqual(AwakeFormat.clock(125), "2:05")
        XCTAssertEqual(AwakeSession.until(now.addingTimeInterval(1800)).describe(now: now), "for 30 min")
    }
}
