@testable import MonorailCore
import XCTest

final class AIUsageTests: XCTestCase {
    func testClaudeLimitsAndCredentials() {
        let json = #"{"five_hour":{"utilization":42.0,"resets_at":"2026-11-13T15:00:00.000Z"},"seven_day":{"utilization":10,"resets_at":"2026-11-18T09:00:00Z"},"seven_day_opus":null}"#
        let w = AIParse.claudeLimits(Data(json.utf8))
        XCTAssertEqual(w.map(\.name), ["Session", "Week"])
        XCTAssertEqual(w.first?.usedPercent, 42)
        XCTAssertNotNil(w.first?.resetsAt)
        let creds = #"{"claudeAiOauth":{"accessToken":"tok","expiresAt":1900000000000,"subscriptionType":"max"}}"#
        let c = AIParse.claudeCredentials(Data(creds.utf8))
        XCTAssertEqual(c?.token, "tok")
        XCTAssertEqual(c?.plan, "Max")
        XCTAssertEqual(c?.expires, Date(timeIntervalSince1970: 1_900_000_000))
    }

    func testClaudeLogLinesCountOnce() {
        let line = #"{"type":"assistant","sessionId":"s1","cwd":"/Users/a/monorail","timestamp":"2026-11-13T10:00:00Z","requestId":"r1","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":1000,"cache_creation_input_tokens":200}}}"#
        var seen = Set<String>()
        let first = AIParse.claudeLogLine(line, seen: &seen)
        XCTAssertEqual(first?.totals.total, 1350)
        XCTAssertEqual(first?.project, "monorail")
        XCTAssertNil(AIParse.claudeLogLine(line, seen: &seen))
        XCTAssertNil(AIParse.claudeLogLine(#"{"type":"user","message":{"content":"hi"}}"#, seen: &seen))
    }

    func testCodexLogAndAPI() {
        let line = #"{"timestamp":"2026-11-13T10:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":5000,"cached_input_tokens":4000,"output_tokens":300},"model_context_window":272000},"rate_limits":{"primary":{"used_percent":30,"window_minutes":300,"resets_in_seconds":3600},"secondary":{"used_percent":12,"window_minutes":10080,"resets_in_seconds":86400}}}}"#
        let r = AIParse.codexLogLine(line)
        XCTAssertEqual(r?.windows.map(\.name), ["Session", "Week"])
        XCTAssertEqual(r?.used, 5300)
        XCTAssertEqual(r?.window, 272_000)
        XCTAssertEqual(r?.last?.cacheRead, 4000)
        XCTAssertEqual(r?.last?.input, 1000)
        let api = #"{"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":55,"limit_window_seconds":18000,"reset_at":1900000000},"secondary_window":{"used_percent":20,"limit_window_seconds":604800,"reset_after_seconds":100}},"credits":{"balance":"12.5"}}"#
        let parsed = AIParse.codexLimits(Data(api.utf8))
        XCTAssertEqual(parsed.plan, "Plus")
        XCTAssertEqual(parsed.windows.first?.usedPercent, 55)
        XCTAssertEqual(parsed.credits, 12.5)
        XCTAssertEqual(AIParse.codexCredentials(Data(#"{"tokens":{"access_token":"a","account_id":"acc"}}"#.utf8))?.account, "acc")
    }

    func testGenericUsageShapes() {
        let openclaw = #"{"type":"message","timestamp":"2026-11-13T10:00:00Z","message":{"model":"kimi-k2","usage":{"input":10,"output":5,"cacheRead":2,"cost":{"total":0.01}}}}"#
        XCTAssertEqual(AIParse.genericUsageLine(openclaw)?.totals.total, 17)
        XCTAssertEqual(AIParse.genericUsageLine(openclaw)?.totals.cost, 0.01)
        let openai = #"{"model":"hermes-4","usage":{"prompt_tokens":100,"completion_tokens":20,"prompt_tokens_details":{"cached_tokens":60}}}"#
        let o = AIParse.genericUsageLine(openai)
        XCTAssertEqual(o?.model, "hermes-4")
        XCTAssertEqual(o?.totals.input, 40)
        XCTAssertEqual(o?.totals.cacheRead, 60)
        XCTAssertNil(AIParse.genericUsageLine(#"{"usage":{}}"#))
    }

    func testLocalModelsAndKeys() {
        let ps = #"{"models":[{"name":"llama3:8b","size":5000000000,"size_vram":4000000000,"context_length":8192,"expires_at":"2026-11-13T10:05:00Z"}]}"#
        XCTAssertEqual(AIParse.ollamaRunning(Data(ps.utf8)).first?.contextLength, 8192)
        let lms = #"{"data":[{"id":"qwen3","type":"llm","state":"loaded","max_context_length":32768},{"id":"nomic","type":"embeddings","state":"loaded"}]}"#
        let models = AIParse.lmStudioModels(Data(lms.utf8))
        XCTAssertEqual(models.count, 1)
        XCTAssertTrue(models[0].loaded)
        let or = AIParse.openRouter(Data(#"{"data":{"usage":3.5,"limit":10,"limit_remaining":6.5}}"#.utf8))
        XCTAssertEqual(or.balance, 6.5)
        XCTAssertEqual(AIParse.deepseekBalance(Data(#"{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"20.00"}]}"#.utf8))?.currency, "CNY")
        XCTAssertEqual(AIParse.anthropicCosts(Data(#"{"data":[{"results":[{"amount":"250.0"}]},{"results":[{"amount":"50"}]}]}"#.utf8)), 3)
        XCTAssertEqual(AIParse.status(Data(#"{"status":{"indicator":"minor","description":"Elevated errors"}}"#.utf8)), "Elevated errors")
        XCTAssertNil(AIParse.status(Data(#"{"status":{"indicator":"none","description":"All good"}}"#.utf8)))
    }

    func testPaceAndAlerts() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Half the window gone, 80% used: runs out before the reset.
        let hot = UsageWindow(name: "Session", usedPercent: 80, resetsAt: now.addingTimeInterval(9000), length: 18000)
        if case .runsOut(let s)? = hot.pace(now: now) { XCTAssertEqual(s, 2250, accuracy: 1) } else { XCTFail() }
        let calm = UsageWindow(name: "Week", usedPercent: 10, resetsAt: now.addingTimeInterval(3 * 86400), length: 7 * 86400)
        if case .reserve(let r)? = calm.pace(now: now) { XCTAssertGreaterThan(r, 40) } else { XCTFail() }
        XCTAssertEqual(AIAlerts.crossed(previous: 70, now: 96, thresholds: [80, 95]), 95)
        XCTAssertNil(AIAlerts.crossed(previous: 81, now: 85, thresholds: [80, 95]))
        XCTAssertNil(AIAlerts.crossed(previous: nil, now: 85, thresholds: [80]))
        XCTAssertTrue(AIAlerts.didReset(previous: 90, now: 2))
        XCTAssertFalse(AIAlerts.didReset(previous: 90, now: 85))
        XCTAssertTrue(AIAlerts.message(account: "Claude", window: hot, threshold: 80, now: now).body.contains("runs out"))
    }

    func testLedgerPricingAndFormat() {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_763_000_000)
        var ledger = UsageLedger()
        ledger.add(TokenTotals(input: 1_000_000, output: 0, requests: 1), model: "claude-opus-5-5", at: now, calendar: c)
        ledger.add(TokenTotals(output: 10, requests: 1), model: "claude-haiku-5-5", at: now.addingTimeInterval(-86400), calendar: c)
        XCTAssertEqual(ledger.sum(lastDays: 1, now: now, calendar: c).input, 1_000_000)
        XCTAssertEqual(ledger.lastDays(7, now: now, calendar: c).count, 7)
        XCTAssertEqual(ledger.topModel(lastDays: 7, now: now, calendar: c), "claude-opus-5-5")
        XCTAssertEqual(AIPricing.cost(TokenTotals(input: 1_000_000), model: "claude-opus-5-5"), 4, accuracy: 0.001)
        XCTAssertEqual(AIPricing.cost(TokenTotals(output: 1_000_000), model: "claude-sonnet-4-5-20250929"), 15, accuracy: 0.001)
        XCTAssertEqual(AIPricing.contextWindow(for: "claude-haiku-4-5"), 200_000)
        XCTAssertEqual(AIPricing.contextWindow(for: "claude-opus-5-5"), 1_000_000)
        XCTAssertEqual(AIPricing.contextWindow(for: "claude-haiku-4-5", used: 300_000), 400_000)
        ledger.note(ContextReading(session: "s", used: 150_000, window: 200_000, at: now))
        XCTAssertEqual(ledger.liveContexts(now: now).first?.percent, 75)
        ledger.prune(keep: 0, now: now.addingTimeInterval(86400 * 3), calendar: c)
        XCTAssertTrue(ledger.days.isEmpty)
        XCTAssertEqual(AIFormat.tokens(1_500_000), "1.5M")
        XCTAssertEqual(AIFormat.money(3.456), "$3.46")
        XCTAssertEqual(AIFormat.duration(3 * 3600 + 120), "3h 2m")
    }
}
