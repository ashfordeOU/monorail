import XCTest
@testable import MonorailCore

final class ShortcutClashTests: XCTestCase {
    private func hotkey(_ keyCode: Int, _ flags: Int, enabled: Bool = true) -> [String: Any] {
        ["enabled": enabled, "value": ["parameters": [65535, keyCode, flags], "type": "standard"]]
    }

    func testParsesTurnedOnShortcutsOnly() {
        let parsed = SystemShortcuts.parse([
            "79": hotkey(123, 0x40000),             // ⌃← Move left a space
            "81": hotkey(124, 0x40000, enabled: false),
            "64": hotkey(49, 0x100000),             // ⌘Space
            "999": hotkey(65535, 0x100000),         // no key
        ])
        XCTAssertEqual(parsed.map(\.id), [64, 79])
        XCTAssertEqual(parsed[1].shortcut, Shortcut(keyCode: KeyCode.left, modifiers: .control))
        XCTAssertEqual(parsed[1].name, "Move left a space")
        XCTAssertEqual(SystemShortcuts.name(for: 120), "Switch to Desktop 3")
    }

    func testFindsClashWithMacOSAndSuggestsAFreeKey() {
        let taken = Shortcut(keyCode: KeyCode.left, modifiers: [.control, .option])
        var keymap = Keymap(bindings: [:])
        keymap.bindings[.focusLeft] = [taken]
        let system = [SystemShortcuts.Entry(id: 79, name: "Move left a space", shortcut: taken)]
        let clashes = keymap.clashes(with: system)
        XCTAssertEqual(clashes.count, 1)
        XCTAssertEqual(clashes[0].usedBy, "macOS: Move left a space")
        let suggestion = try! XCTUnwrap(clashes[0].suggestion)
        XCTAssertNotEqual(suggestion, taken)
        XCTAssertEqual(suggestion.keyCode, KeyCode.left)
    }

    func testDefaultKeymapHasNoClashesWithItself() {
        XCTAssertTrue(Keymap.default.clashes(with: []).isEmpty)
    }
}

final class ReservedEdgesTests: XCTestCase {
    func testInsetsEachEdge() {
        let area = Rect(x: 0, y: 25, width: 1440, height: 875)
        let inset = ReservedEdges(top: 30, bottom: 10, left: 50, right: 0).inset(area)
        XCTAssertEqual(inset, Rect(x: 50, y: 55, width: 1390, height: 835))
        XCTAssertEqual(ReservedEdges().inset(area), area)
    }

    func testNeverSmallerThanAUsableArea() {
        let inset = ReservedEdges(top: 900, left: 2000).inset(Rect(x: 0, y: 0, width: 1000, height: 800))
        XCTAssertEqual(inset.width, 200)
        XCTAssertEqual(inset.height, 200)
    }

    func testOldSettingsDecodeWithDefaults() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(settings.pauseForStageManager)
        XCTAssertTrue(settings.portraitStacks)
        XCTAssertFalse(settings.restoreHidesOthers)
        XCTAssertEqual(settings.appAppearance, .system)
        XCTAssertTrue(settings.reservedEdges.isEmpty)
    }
}

final class PortraitTests: XCTestCase {
    func testPortraitTurnsSideBySideIntoStacked() {
        XCTAssertEqual(Arrangement.columns.forPortrait, .stack)
        XCTAssertEqual(Arrangement.mainLeft.forPortrait, .mainTop)
        XCTAssertEqual(Arrangement.grid.forPortrait, .grid)
    }
}

final class PowerUseTests: XCTestCase {
    func testEstimatesShareOfCoreAndBatteryPerHour() {
        // 30 s of processor time and 600 J over 60 s on a 60 Wh battery: half a core, 10 W, 16.7% an hour.
        let use = PowerEstimate.use(bundleID: "a", appName: "A", before: PowerReading(cpuSeconds: 10, joules: 1000),
                                    after: PowerReading(cpuSeconds: 40, joules: 1600), seconds: 60, batteryWattHours: 60)
        XCTAssertEqual(use.cpuPercent, 50, accuracy: 0.01)
        XCTAssertEqual(use.percentPerHour!, 16.67, accuracy: 0.01)
        XCTAssertTrue(use.isHungry)
        XCTAssertEqual(use.summary, "About 17% of the battery an hour")
    }

    func testWithoutEnergyFallsBackToProcessorTime() {
        let use = PowerEstimate.use(bundleID: "a", appName: "A", before: PowerReading(cpuSeconds: 0, joules: nil),
                                    after: PowerReading(cpuSeconds: 6, joules: nil), seconds: 60, batteryWattHours: 60)
        XCTAssertNil(use.percentPerHour)
        XCTAssertFalse(use.isHungry)
        XCTAssertEqual(use.summary, "Busy: 10% of a core")
    }

    func testRestartedAppCountsAsNothingUsed() {
        let use = PowerEstimate.use(bundleID: "a", appName: "A", before: PowerReading(cpuSeconds: 100, joules: 900),
                                    after: PowerReading(cpuSeconds: 1, joules: 5), seconds: 60, batteryWattHours: 60)
        XCTAssertEqual(use.cpuPercent, 0)
        XCTAssertEqual(use.percentPerHour, 0)
    }

    func testParksOnlyHungryAppsLeftAloneForAnHour() {
        let now = Date()
        let uses = [PowerUse(bundleID: "hog", appName: "Hog", cpuPercent: 5, percentPerHour: 8),
                    PowerUse(bundleID: "front", appName: "Front", cpuPercent: 5, percentPerHour: 9),
                    PowerUse(bundleID: "recent", appName: "Recent", cpuPercent: 5, percentPerHour: 9),
                    PowerUse(bundleID: "calm", appName: "Calm", cpuPercent: 1, percentPerHour: 0.5)]
        let parked = PowerEstimate.toPark(uses, lastActive: ["recent": now.addingTimeInterval(-600)],
                                          watchingSince: now.addingTimeInterval(-7200), frontmost: "front", now: now)
        XCTAssertEqual(parked, ["hog"])
    }

    func testBatterySize() {
        XCTAssertEqual(PowerEstimate.wattHours(capacityMilliampHours: 6000, voltageMillivolts: 12000)!, 72, accuracy: 0.01)
        XCTAssertNil(PowerEstimate.wattHours(capacityMilliampHours: 100, voltageMillivolts: 12000))
    }
}

final class AssistantProviderTests: XCTestCase {
    func testChatURL() {
        XCTAssertEqual(AssistantProvider.chatURL(base: "http://localhost:1234/v1/")?.absoluteString, "http://localhost:1234/v1/chat/completions")
        XCTAssertEqual(AssistantProvider.chatURL(base: "https://x.example/v1/chat/completions")?.absoluteString, "https://x.example/v1/chat/completions")
        XCTAssertNil(AssistantProvider.chatURL(base: "  "))
    }

    func testFindsJSONInsideFencesAndSentences() throws {
        let reply = "Sure!\n```json\n{\"commands\":[\"go to 2\"],\"explanation\":\"Done\"}\n```"
        let data = try XCTUnwrap(AssistantProvider.jsonObject(in: reply))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["explanation"] as? String, "Done")
        XCTAssertNil(AssistantProvider.jsonObject(in: "no json here"))
    }

    func testOnlyLocalAndCustomWorkWithoutAKey() {
        XCTAssertEqual(AssistantProvider.allCases.filter { !$0.needsKey }, [.ollama, .custom])
        XCTAssertNil(AssistantProvider.anthropic.defaultBaseURL)
    }
}

final class AgentSkillTests: XCTestCase {
    func testBundledSkillMatchesTheFileInTheRepository() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = try String(contentsOf: root.appendingPathComponent("extensions/agent-skill/monorail/SKILL.md"), encoding: .utf8)
        XCTAssertEqual(AgentSkill.markdown.trimmingCharacters(in: .newlines), file.trimmingCharacters(in: .newlines))
        XCTAssertTrue(AgentSkill.markdown.hasPrefix("---\nname: monorail\n"))
    }
}

final class BatteryModelTests: XCTestCase {
    func testTimeLeftAndWhatQuittingWouldSave() {
        let state = BatteryState(percent: 44, isCharging: false, onBattery: true, watts: 6, remainingWattHours: 30)
        XCTAssertEqual(state.minutesAtCurrentRate, 300)
        XCTAssertEqual(state.minutesIfSaved(appWatts: 1), 360)
        XCTAssertEqual(BatteryState.duration(352), "5 hr 52 min")
        XCTAssertEqual(BatteryState.duration(38), "38 min")
        XCTAssertEqual(BatteryState.duration(nil), "—")
        let plugged = BatteryState(percent: 80, isCharging: true, onBattery: false, watts: 6, remainingWattHours: 30)
        XCTAssertNil(plugged.minutesAtCurrentRate)
    }

    func testMacOSFigureWinsWhenItHasOne() {
        let state = BatteryState(percent: 50, isCharging: false, onBattery: true, minutesLeft: 200, watts: 6, remainingWattHours: 30)
        XCTAssertEqual(state.minutesAtCurrentRate, 200)
    }

    func testHistoryKeepsADayAndSkipsRepeats() {
        let now = Date()
        var points: [BatteryPoint] = [BatteryPoint(time: now.addingTimeInterval(-90_000), percent: 90, charging: false)]
        points = BatteryHistory.adding(BatteryPoint(time: now.addingTimeInterval(-600), percent: 50, charging: false), to: points)
        XCTAssertEqual(points.count, 1, "the 25-hour-old point is dropped")
        points = BatteryHistory.adding(BatteryPoint(time: now.addingTimeInterval(-500), percent: 50, charging: false), to: points)
        XCTAssertEqual(points.count, 1, "same reading a moment later is skipped")
        points = BatteryHistory.adding(BatteryPoint(time: now, percent: 49, charging: false), to: points)
        XCTAssertEqual(points.count, 2)
        let split = BatteryHistory.segments([BatteryPoint(time: now, percent: 1, charging: false),
                                             BatteryPoint(time: now.addingTimeInterval(300), percent: 1, charging: false),
                                             BatteryPoint(time: now.addingTimeInterval(9000), percent: 1, charging: false)])
        XCTAssertEqual(split.map(\.count), [2, 1])
    }

    func testRecognisesAgents() {
        XCTAssertEqual(AgentProcesses.agent(processName: "claude"), "Claude Code")
        XCTAssertEqual(AgentProcesses.agent(processName: "node", arguments: ["node", "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js"]), "Claude Code")
        XCTAssertEqual(AgentProcesses.agent(processName: "codex"), "Codex")
        XCTAssertNil(AgentProcesses.agent(processName: "node", arguments: ["node", "server.js"]))
    }
}

final class ChargeSessionTests: XCTestCase {
    func testAddsUpSinceUnpluggedAndRanksByEnergy() {
        var session = ChargeSession()
        session.start(at: Date(), percent: 100)
        session.add(id: "chrome", name: "Google Chrome", joules: 300, cpuSeconds: 30)
        session.add(id: "chrome", name: "Google Chrome", joules: 420, cpuSeconds: 20)
        session.add(id: "agent:Codex", name: "Codex", isAgent: true, joules: 100, cpuSeconds: 90)
        session.add(id: "mail", name: "Mail", joules: -50, cpuSeconds: 1)
        XCTAssertEqual(session.ranked.map(\.id), ["chrome", "agent:Codex"])
        XCTAssertEqual(session.totals["chrome"]?.joules, 720)
        // 720 J on a 50 Wh battery: 0.4 percentage points.
        XCTAssertEqual(ChargeSession.percentUsed(joules: 720, wattHours: 50)!, 0.4, accuracy: 0.0001)
        XCTAssertEqual(ChargeSession.usedText(session.totals["chrome"]!, wattHours: 50), "0.4% used")
        session.start(at: Date(), percent: 80)
        XCTAssertTrue(session.totals.isEmpty)
        XCTAssertEqual(session.startPercent, 80)
    }

    func testWithoutEnergyUsesProcessorTime() {
        var session = ChargeSession()
        session.add(id: "a", name: "A", joules: 0, cpuSeconds: 720)
        session.add(id: "b", name: "B", joules: 0, cpuSeconds: 60)
        XCTAssertEqual(session.ranked.map(\.id), ["a", "b"])
        XCTAssertEqual(ChargeSession.usedText(session.totals["a"]!, wattHours: nil), "12 min of processor time")
    }
}

final class BatteryCardsTests: XCTestCase {
    func testMovingAndKeepingASavedOrderValid() {
        let moved = BatteryCards.moving("agents", by: -1, in: BatteryCards.standard)
        XCTAssertEqual(moved.firstIndex(of: "agents"), BatteryCards.standard.firstIndex(of: "apps"))
        XCTAssertEqual(BatteryCards.moving("numbers", by: -1, in: BatteryCards.standard), BatteryCards.standard)
        // An older saved order without "sinceCharge", with a stale card and a duplicate.
        let old = ["agents", "numbers", "gone", "numbers", "history", "apps"]
        let fixed = BatteryCards.normalised(old)
        XCTAssertEqual(Set(fixed), Set(BatteryCards.standard))
        XCTAssertEqual(fixed.count, BatteryCards.standard.count)
        XCTAssertEqual(fixed.first, "agents", "the person's order is kept")
        XCTAssertLessThan(fixed.firstIndex(of: "sinceCharge")!, fixed.firstIndex(of: "history")!)
    }
}
