import Foundation

/// AI Usage: plan limits, tokens, spend and context for every AI account on this Mac, cloud or local.
/// Everything here is pure (parsing and arithmetic) so it's tested on Linux; the app does the reading.

public enum AIProvider: String, Codable, CaseIterable, Sendable {
    case claude, codex, gemini, openclaw, hermes, ollama, lmstudio
    case anthropicAPI, openai, openrouter, deepseek, moonshot, litellm, custom

    public var name: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .openclaw: return "OpenClaw"
        case .hermes: return "Hermes"
        case .ollama: return "Ollama"
        case .lmstudio: return "LM Studio"
        case .anthropicAPI: return "Claude API"
        case .openai: return "OpenAI API"
        case .openrouter: return "OpenRouter"
        case .deepseek: return "DeepSeek"
        case .moonshot: return "Moonshot (Kimi)"
        case .litellm: return "LiteLLM"
        case .custom: return "Other (OpenAI-compatible)"
        }
    }

    public enum Kind: String, Sendable { case plan, agent, local, apiKey }

    public var kind: Kind {
        switch self {
        case .claude, .codex, .gemini: return .plan
        case .openclaw, .hermes: return .agent
        case .ollama, .lmstudio: return .local
        case .anthropicAPI, .openai, .openrouter, .deepseek, .moonshot, .litellm, .custom: return .apiKey
        }
    }

    public var symbol: String {
        switch kind {
        case .plan: return "sparkles"
        case .agent: return "person.crop.circle.badge.checkmark"
        case .local: return "cpu"
        case .apiKey: return "key"
        }
    }

    /// Where the provider's own tool keeps its sign-in and logs (relative to home).
    public var defaultFolder: String? {
        switch self {
        case .claude: return ".claude"
        case .codex: return ".codex"
        case .gemini: return ".gemini"
        case .openclaw: return ".openclaw"
        case .hermes: return ".hermes"
        default: return nil
        }
    }

    public var defaultBaseURL: String? {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .lmstudio: return "http://localhost:1234"
        case .anthropicAPI: return "https://api.anthropic.com"
        case .openai: return "https://api.openai.com"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .deepseek: return "https://api.deepseek.com"
        case .moonshot: return "https://api.moonshot.ai"
        case .litellm: return "http://localhost:4000"
        default: return nil
        }
    }

    public var needsKey: Bool { kind == .apiKey }

    /// The provider's public status page (Atlassian Statuspage JSON).
    public var statusURL: String? {
        switch self {
        case .claude, .anthropicAPI: return "https://status.claude.com/api/v2/status.json"
        case .codex, .openai: return "https://status.openai.com/api/v2/status.json"
        default: return nil
        }
    }
}

/// One account: a provider plus where to read it (a config folder, a server, or a key kept in the Keychain).
public struct AIAccount: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var provider: AIProvider
    public var label: String
    public var folder: String?
    public var baseURL: String?
    /// The Keychain item name holding this account's key; the key itself is never stored in settings.
    public var keyRef: String?
    public var enabled: Bool
    public var notify: Bool

    public init(id: String = UUID().uuidString, provider: AIProvider, label: String? = nil, folder: String? = nil,
                baseURL: String? = nil, keyRef: String? = nil, enabled: Bool = true, notify: Bool = true) {
        self.id = id
        self.provider = provider
        self.label = label ?? provider.name
        self.folder = folder ?? provider.defaultFolder.map { "~/" + $0 }
        self.baseURL = baseURL ?? provider.defaultBaseURL
        self.keyRef = keyRef
        self.enabled = enabled
        self.notify = notify
    }
}

/// A plan limit: a five-hour session, a week, a month.
public struct UsageWindow: Codable, Equatable, Sendable {
    public var name: String
    public var usedPercent: Double
    public var resetsAt: Date?
    public var length: TimeInterval?

    public init(name: String, usedPercent: Double, resetsAt: Date? = nil, length: TimeInterval? = nil) {
        self.name = name
        self.usedPercent = max(0, usedPercent)
        self.resetsAt = resetsAt
        self.length = length
    }

    public enum Pace: Equatable, Sendable {
        /// Using less than the time gone by: this much of the limit is in reserve.
        case reserve(Double)
        case onPace
        /// At this rate the limit runs out before it resets.
        case runsOut(in: TimeInterval)
    }

    /// How the limit is being spent compared with the time left before it resets.
    public func pace(now: Date = Date()) -> Pace? {
        guard let resetsAt, let length, length > 0 else { return nil }
        let left = resetsAt.timeIntervalSince(now)
        guard left > 0 else { return nil }
        let elapsed = max(length - left, 1)
        let expected = elapsed / length * 100
        if usedPercent >= 100 { return .runsOut(in: 0) }
        if usedPercent > expected + 5 {
            let rate = usedPercent / elapsed
            let runway = (100 - usedPercent) / rate
            return runway < left ? .runsOut(in: runway) : .onPace
        }
        if usedPercent < expected - 5 { return .reserve(expected - usedPercent) }
        return .onPace
    }
}

public struct TokenTotals: Codable, Equatable, Sendable {
    public var input = 0, output = 0, cacheRead = 0, cacheWrite = 0
    public var cost: Double = 0
    public var requests = 0

    public init(input: Int = 0, output: Int = 0, cacheRead: Int = 0, cacheWrite: Int = 0, cost: Double = 0, requests: Int = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheWrite = cacheWrite
        self.cost = cost
        self.requests = requests
    }

    public var total: Int { input + output + cacheRead + cacheWrite }

    public mutating func add(_ other: TokenTotals) {
        input += other.input
        output += other.output
        cacheRead += other.cacheRead
        cacheWrite += other.cacheWrite
        cost += other.cost
        requests += other.requests
    }
}

/// How full one conversation's context window is.
public struct ContextReading: Codable, Equatable, Sendable {
    public var session: String
    public var project: String?
    public var model: String?
    public var used: Int
    public var window: Int
    public var at: Date

    public init(session: String, project: String? = nil, model: String? = nil, used: Int, window: Int, at: Date) {
        self.session = session
        self.project = project
        self.model = model
        self.used = used
        self.window = window
        self.at = at
    }

    public var percent: Double { window > 0 ? min(100, Double(used) / Double(window) * 100) : 0 }
}

public struct LocalModel: Codable, Equatable, Sendable {
    public var name: String
    public var loaded: Bool
    public var sizeBytes: Int64
    public var vramBytes: Int64
    public var contextLength: Int?
    public var expiresAt: Date?

    public init(name: String, loaded: Bool, sizeBytes: Int64 = 0, vramBytes: Int64 = 0, contextLength: Int? = nil, expiresAt: Date? = nil) {
        self.name = name
        self.loaded = loaded
        self.sizeBytes = sizeBytes
        self.vramBytes = vramBytes
        self.contextLength = contextLength
        self.expiresAt = expiresAt
    }
}

/// What one account looks like right now.
public struct AIReport: Codable, Equatable, Sendable {
    public var accountID: String
    public var at: Date
    public var plan: String?
    public var windows: [UsageWindow] = []
    public var today = TokenTotals()
    public var month = TokenTotals()
    public var daily: [String: TokenTotals] = [:]
    public var topModel: String?
    public var contexts: [ContextReading] = []
    /// Credit left, money spent and the spending limit, in `currency`.
    public var balance: Double?
    public var spent: Double?
    public var limit: Double?
    public var currency = "USD"
    public var models: [LocalModel] = []
    public var incident: String?
    public var error: String?

    public init(accountID: String, at: Date = Date()) {
        self.accountID = accountID
        self.at = at
    }

    /// The fullest limit, which is what the menu bar shows.
    public var headline: UsageWindow? { windows.max { $0.usedPercent < $1.usedPercent } }
}

/// Token totals by day and model, built from the local logs of Claude Code, Codex, OpenClaw and Hermes.
public struct UsageLedger: Codable, Equatable, Sendable {
    public var days: [String: [String: TokenTotals]] = [:]
    public var contexts: [String: ContextReading] = [:]

    public init() {}

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public mutating func add(_ totals: TokenTotals, model: String, at date: Date, calendar: Calendar = .current) {
        let key = UsageLedger.dayKey(date, calendar: calendar)
        var day = days[key] ?? [:]
        var entry = day[model] ?? TokenTotals()
        entry.add(totals)
        day[model] = entry
        days[key] = day
    }

    public mutating func note(_ reading: ContextReading) {
        if let old = contexts[reading.session], old.at > reading.at { return }
        contexts[reading.session] = reading
    }

    public func total(on key: String) -> TokenTotals {
        var sum = TokenTotals()
        for (_, t) in days[key] ?? [:] { sum.add(t) }
        return sum
    }

    /// The last `count` days, oldest first, with empty days filled in.
    public func lastDays(_ count: Int, now: Date = Date(), calendar: Calendar = .current) -> [(day: String, totals: TokenTotals)] {
        var result: [(day: String, totals: TokenTotals)] = []
        for back in stride(from: count - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -back, to: now) else { continue }
            let key = UsageLedger.dayKey(date, calendar: calendar)
            result.append((key, total(on: key)))
        }
        return result
    }

    public func sum(lastDays count: Int, now: Date = Date(), calendar: Calendar = .current) -> TokenTotals {
        var sum = TokenTotals()
        for entry in lastDays(count, now: now, calendar: calendar) { sum.add(entry.totals) }
        return sum
    }

    public func topModel(lastDays count: Int, now: Date = Date(), calendar: Calendar = .current) -> String? {
        var byModel: [String: Int] = [:]
        for back in 0..<count {
            guard let date = calendar.date(byAdding: .day, value: -back, to: now) else { continue }
            for (model, t) in days[UsageLedger.dayKey(date, calendar: calendar)] ?? [:] { byModel[model, default: 0] += t.total }
        }
        var best: (String, Int)?
        for (model, tokens) in byModel where best == nil || tokens > best!.1 { best = (model, tokens) }
        return best?.0
    }

    /// Live conversations (touched in the last `within` seconds), fullest first.
    public func liveContexts(now: Date = Date(), within: TimeInterval = 3600) -> [ContextReading] {
        var live: [ContextReading] = []
        for (_, c) in contexts where now.timeIntervalSince(c.at) <= within { live.append(c) }
        live.sort { $0.percent > $1.percent }
        return live
    }

    /// Drops days older than `keep` days.
    public mutating func prune(keep: Int = 62, now: Date = Date(), calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -keep, to: now) else { return }
        let oldest = UsageLedger.dayKey(cutoff, calendar: calendar)
        for key in days.keys where key < oldest { days[key] = nil }
        for (id, c) in contexts where c.at < cutoff { contexts[id] = nil }
    }
}

/// List prices per million tokens, for estimating what local logs would cost at API rates.
public enum AIPricing {
    public struct Rate: Equatable, Sendable {
        public var input: Double, output: Double, cacheRead: Double, cacheWrite: Double
        init(_ input: Double, _ output: Double, cacheRead: Double? = nil) {
            self.input = input
            self.output = output
            self.cacheRead = cacheRead ?? input * 0.1
            self.cacheWrite = input * 1.25
        }
    }

    public static func rate(for model: String) -> Rate? {
        let m = model.lowercased()
        let table: [(String, Rate)] = [
            ("fable-5-2", Rate(8, 40, cacheRead: 0.2)), ("mythos-5-2", Rate(8, 40, cacheRead: 0.2)),
            ("fable-5", Rate(10, 50)), ("mythos-5", Rate(10, 50)),
            ("opus-5-5", Rate(4, 20, cacheRead: 0.2)), ("opus-5", Rate(5, 25)),
            ("opus-4-8", Rate(5, 25)), ("opus-4-7", Rate(5, 25)), ("opus-4-6", Rate(5, 25)), ("opus-4-5", Rate(5, 25)),
            ("opus-4", Rate(15, 75)), ("claude-3-opus", Rate(15, 75)),
            ("sonnet-5-5", Rate(2, 10, cacheRead: 0.1)), ("sonnet-5", Rate(2, 10)), ("sonnet-4", Rate(3, 15)), ("sonnet-3", Rate(3, 15)),
            ("haiku-5-5", Rate(0.1, 0.5)), ("haiku-4", Rate(1, 5)), ("haiku-3-5", Rate(0.8, 4)), ("haiku", Rate(0.25, 1.25)),
        ]
        for (key, rate) in table where m.contains(key) { return rate }
        return nil
    }

    public static func cost(_ t: TokenTotals, model: String) -> Double {
        guard let r = rate(for: model) else { return 0 }
        let sum = Double(t.input) * r.input + Double(t.output) * r.output + Double(t.cacheRead) * r.cacheRead + Double(t.cacheWrite) * r.cacheWrite
        return sum / 1_000_000
    }

    /// The model's context window in tokens.
    public static func contextWindow(for model: String, used: Int = 0) -> Int {
        let m = model.lowercased()
        var window = 200_000
        let million = ["fable", "mythos", "opus-5", "opus-4-8", "opus-4-7", "opus-4-6", "sonnet-5", "sonnet-4-6", "haiku-5", "[1m]", "gpt-4.1", "gemini"]
        for key in million where m.contains(key) { window = 1_000_000 }
        if m.contains("gpt-5") || m.contains("codex") { window = 400_000 }
        while used > window { window *= 2 }
        return window
    }
}

/// Parsers for every source. Each one is forgiving: an unknown shape gives nothing rather than an error.
public enum AIParse {
    static func object(_ data: Data) -> [String: Any]? { (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] }
    static func object(_ line: String) -> [String: Any]? { line.data(using: .utf8).flatMap { object($0) } }

    static func number(_ value: Any?) -> Double? {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    static func int(_ value: Any?) -> Int { Int(number(value) ?? 0) }

    static func date(_ value: Any?) -> Date? {
        if let s = value as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: s) { return d }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: s)
        }
        if let n = number(value) { return Date(timeIntervalSince1970: n > 1e11 ? n / 1000 : n) }
        return nil
    }

    // MARK: Claude (Pro/Max plan via Claude Code's sign-in)

    /// Claude Code's saved sign-in: the access token, when it expires, and the plan.
    public static func claudeCredentials(_ data: Data) -> (token: String, expires: Date?, plan: String?)? {
        guard let root = object(data), let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        let plan = (oauth["subscriptionType"] as? String).map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return (token, date(oauth["expiresAt"]), plan)
    }

    /// The plan limits from Claude's usage endpoint: five-hour session, week, and the per-model weeks.
    public static func claudeLimits(_ data: Data) -> [UsageWindow] {
        guard let root = object(data) else { return [] }
        let names: [(String, String, TimeInterval)] = [
            ("five_hour", "Session", 5 * 3600), ("seven_day", "Week", 7 * 86400),
            ("seven_day_opus", "Opus week", 7 * 86400), ("seven_day_sonnet", "Sonnet week", 7 * 86400),
        ]
        var windows: [UsageWindow] = []
        for (key, name, length) in names {
            guard let w = root[key] as? [String: Any], let used = number(w["utilization"]) else { continue }
            windows.append(UsageWindow(name: name, usedPercent: used, resetsAt: date(w["resets_at"]), length: length))
        }
        return windows
    }

    /// One line of a Claude Code conversation log. Returns tokens for assistant replies (once per message id).
    public static func claudeLogLine(_ line: String, seen: inout Set<String>) -> (model: String, totals: TokenTotals, at: Date, session: String, project: String?)? {
        guard line.contains("\"usage\""), let root = object(line), root["type"] as? String == "assistant",
              let message = root["message"] as? [String: Any], let usage = message["usage"] as? [String: Any] else { return nil }
        let id = ((message["id"] as? String) ?? "") + ":" + ((root["requestId"] as? String) ?? "")
        if id != ":" {
            if seen.contains(id) { return nil }
            seen.insert(id)
        }
        let model = (message["model"] as? String) ?? "claude"
        if model == "<synthetic>" { return nil }
        let t = TokenTotals(input: int(usage["input_tokens"]), output: int(usage["output_tokens"]),
                            cacheRead: int(usage["cache_read_input_tokens"]), cacheWrite: int(usage["cache_creation_input_tokens"]),
                            cost: number(root["costUSD"]) ?? 0, requests: 1)
        let project = (root["cwd"] as? String).map { ($0 as NSString).lastPathComponent }
        return (model, t, date(root["timestamp"]) ?? Date(), (root["sessionId"] as? String) ?? "", project)
    }

    // MARK: Codex (ChatGPT plan)

    /// Codex's saved sign-in: the token and the ChatGPT account it belongs to.
    public static func codexCredentials(_ data: Data) -> (token: String, account: String?)? {
        guard let root = object(data) else { return nil }
        if let tokens = root["tokens"] as? [String: Any], let access = tokens["access_token"] as? String {
            return (access, tokens["account_id"] as? String)
        }
        if let key = root["OPENAI_API_KEY"] as? String, !key.isEmpty { return (key, nil) }
        return nil
    }

    static func codexWindow(_ w: [String: Any]?, fallbackName: String, now: Date) -> UsageWindow? {
        guard let w, let used = number(w["used_percent"]) else { return nil }
        let minutes = number(w["window_minutes"]) ?? number(w["limit_window_seconds"]).map { $0 / 60 }
        var reset = date(w["reset_at"]) ?? date(w["resets_at"])
        if reset == nil, let seconds = number(w["resets_in_seconds"]) ?? number(w["reset_after_seconds"]) { reset = now.addingTimeInterval(seconds) }
        var name = fallbackName
        if let minutes { name = minutes <= 600 ? "Session" : minutes >= 40000 ? "Month" : "Week" }
        return UsageWindow(name: name, usedPercent: used, resetsAt: reset, length: minutes.map { $0 * 60 })
    }

    /// Codex's usage endpoint: plan, limits and credits.
    public static func codexLimits(_ data: Data, now: Date = Date()) -> (plan: String?, windows: [UsageWindow], credits: Double?) {
        guard let root = object(data) else { return (nil, [], nil) }
        let limits = root["rate_limit"] as? [String: Any]
        var windows: [UsageWindow] = []
        if let w = codexWindow(limits?["primary_window"] as? [String: Any], fallbackName: "Session", now: now) { windows.append(w) }
        if let w = codexWindow(limits?["secondary_window"] as? [String: Any], fallbackName: "Week", now: now) { windows.append(w) }
        let credits = (root["credits"] as? [String: Any]).flatMap { number($0["balance"]) }
        let plan = (root["plan_type"] as? String).map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return (plan, windows, credits)
    }

    /// One line of a Codex session log (rollout-*.jsonl). Token-count events carry the limits and the context.
    public static func codexLogLine(_ line: String, now: Date = Date()) -> (windows: [UsageWindow], last: TokenTotals?, used: Int?, window: Int?, at: Date)? {
        guard line.contains("token_count"), let root = object(line) else { return nil }
        let payload = (root["payload"] as? [String: Any]) ?? root
        guard payload["type"] as? String == "token_count" else { return nil }
        let at = date(root["timestamp"]) ?? now
        var windows: [UsageWindow] = []
        if let limits = payload["rate_limits"] as? [String: Any] {
            if let w = codexWindow(limits["primary"] as? [String: Any], fallbackName: "Session", now: at) { windows.append(w) }
            if let w = codexWindow(limits["secondary"] as? [String: Any], fallbackName: "Week", now: at) { windows.append(w) }
        }
        var last: TokenTotals?
        var used: Int?
        let info = payload["info"] as? [String: Any]
        if let l = info?["last_token_usage"] as? [String: Any] {
            let cached = int(l["cached_input_tokens"])
            last = TokenTotals(input: max(0, int(l["input_tokens"]) - cached), output: int(l["output_tokens"]), cacheRead: cached, requests: 1)
            used = int(l["input_tokens"]) + int(l["output_tokens"])
        }
        let window = (number(info?["model_context_window"])).map { Int($0) }
        return (windows, last, used, window, at)
    }

    // MARK: Agents (OpenClaw, Hermes and anything else that logs a `usage` object)

    /// Any JSON line with a usage object in the common shapes (Anthropic, OpenAI, OpenClaw).
    public static func genericUsageLine(_ line: String) -> (model: String, totals: TokenTotals, at: Date?)? {
        guard line.contains("sage"), let root = object(line) else { return nil }
        var usage: [String: Any]?
        var model = root["model"] as? String
        var at = date(root["timestamp"]) ?? date(root["created_at"]) ?? date(root["time"])
        if let u = root["usage"] as? [String: Any] { usage = u }
        if usage == nil, let message = root["message"] as? [String: Any] {
            usage = message["usage"] as? [String: Any]
            model = model ?? (message["model"] as? String)
            at = at ?? date(message["timestamp"])
        }
        if usage == nil, let response = root["response"] as? [String: Any] {
            usage = response["usage"] as? [String: Any]
            model = model ?? (response["model"] as? String)
        }
        guard let u = usage else { return nil }
        let input = int(u["input_tokens"] ?? u["input"] ?? u["prompt_tokens"] ?? u["promptTokens"])
        let output = int(u["output_tokens"] ?? u["output"] ?? u["completion_tokens"] ?? u["completionTokens"])
        let cacheRead = int(u["cache_read_input_tokens"] ?? u["cacheRead"] ?? (u["prompt_tokens_details"] as? [String: Any])?["cached_tokens"])
        let cacheWrite = int(u["cache_creation_input_tokens"] ?? u["cacheWrite"])
        var cost = number(u["cost"]) ?? 0
        if let c = u["cost"] as? [String: Any] { cost = number(c["total"]) ?? 0 }
        guard input + output + cacheRead + cacheWrite > 0 else { return nil }
        let promptIncludesCache = u["prompt_tokens"] != nil
        let t = TokenTotals(input: promptIncludesCache ? max(0, input - cacheRead) : input, output: output, cacheRead: cacheRead,
                            cacheWrite: cacheWrite, cost: cost, requests: 1)
        return (model ?? "unknown", t, at)
    }

    // MARK: Local models

    /// Ollama's running models (/api/ps).
    public static func ollamaRunning(_ data: Data) -> [LocalModel] {
        guard let models = object(data)?["models"] as? [[String: Any]] else { return [] }
        var result: [LocalModel] = []
        for m in models {
            let name = (m["name"] as? String) ?? (m["model"] as? String) ?? "model"
            result.append(LocalModel(name: name, loaded: true, sizeBytes: Int64(number(m["size"]) ?? 0), vramBytes: Int64(number(m["size_vram"]) ?? 0),
                                     contextLength: number(m["context_length"]).map { Int($0) }, expiresAt: date(m["expires_at"])))
        }
        return result
    }

    /// Ollama's installed models (/api/tags).
    public static func ollamaInstalled(_ data: Data) -> [LocalModel] {
        guard let models = object(data)?["models"] as? [[String: Any]] else { return [] }
        var result: [LocalModel] = []
        for m in models {
            let name = (m["name"] as? String) ?? (m["model"] as? String) ?? "model"
            result.append(LocalModel(name: name, loaded: false, sizeBytes: Int64(number(m["size"]) ?? 0)))
        }
        return result
    }

    /// LM Studio's models (/api/v0/models), loaded or not.
    public static func lmStudioModels(_ data: Data) -> [LocalModel] {
        guard let models = object(data)?["data"] as? [[String: Any]] else { return [] }
        var result: [LocalModel] = []
        for m in models where (m["type"] as? String) != "embeddings" {
            let loaded = (m["state"] as? String) == "loaded"
            let context = number(m["loaded_context_length"]) ?? number(m["max_context_length"])
            result.append(LocalModel(name: (m["id"] as? String) ?? "model", loaded: loaded, contextLength: context.map { Int($0) }))
        }
        return result
    }

    // MARK: API keys

    /// OpenRouter's key endpoint (/key) or credits endpoint (/credits).
    public static func openRouter(_ data: Data) -> (spent: Double?, limit: Double?, balance: Double?) {
        guard let d = object(data)?["data"] as? [String: Any] else { return (nil, nil, nil) }
        if let total = number(d["total_credits"]) {
            let used = number(d["total_usage"]) ?? 0
            return (used, total, total - used)
        }
        let limit = number(d["limit"])
        return (number(d["usage"]), limit, number(d["limit_remaining"]))
    }

    /// DeepSeek's balance (/user/balance).
    public static func deepseekBalance(_ data: Data) -> (balance: Double, currency: String)? {
        guard let infos = object(data)?["balance_infos"] as? [[String: Any]], let first = infos.first,
              let total = number(first["total_balance"]) else { return nil }
        return (total, (first["currency"] as? String) ?? "USD")
    }

    /// Moonshot's balance (/v1/users/me/balance).
    public static func moonshotBalance(_ data: Data) -> Double? {
        guard let d = object(data)?["data"] as? [String: Any] else { return nil }
        return number(d["available_balance"])
    }

    /// LiteLLM's key info (/key/info): spend and budget.
    public static func liteLLM(_ data: Data) -> (spent: Double?, limit: Double?) {
        guard let root = object(data) else { return (nil, nil) }
        let info = (root["info"] as? [String: Any]) ?? root
        return (number(info["spend"]), number(info["max_budget"]))
    }

    /// OpenAI's organisation costs (/v1/organization/costs): the sum of every bucket.
    public static func openAICosts(_ data: Data) -> Double? {
        guard let buckets = object(data)?["data"] as? [[String: Any]] else { return nil }
        var sum = 0.0
        for bucket in buckets {
            for result in bucket["results"] as? [[String: Any]] ?? [] {
                sum += number((result["amount"] as? [String: Any])?["value"]) ?? 0
            }
        }
        return sum
    }

    /// Anthropic's cost report (/v1/organizations/cost_report): amounts are in cents.
    public static func anthropicCosts(_ data: Data) -> Double? {
        guard let buckets = object(data)?["data"] as? [[String: Any]] else { return nil }
        var cents = 0.0
        for bucket in buckets {
            for result in bucket["results"] as? [[String: Any]] ?? [] { cents += number(result["amount"]) ?? 0 }
        }
        return cents / 100
    }

    /// A Statuspage summary: nil when all is well, otherwise what's wrong.
    public static func status(_ data: Data) -> String? {
        guard let s = object(data)?["status"] as? [String: Any], let indicator = s["indicator"] as? String, indicator != "none" else { return nil }
        return (s["description"] as? String) ?? indicator.capitalized
    }
}

/// When to tell you: crossing a threshold, a limit resetting, a conversation nearly full, a local model loading.
public enum AIAlerts {
    /// The highest threshold crossed going from `previous` to `now`, if any.
    public static func crossed(previous: Double?, now: Double, thresholds: [Double]) -> Double? {
        guard let previous else { return nil }
        var hit: Double?
        for t in thresholds.sorted() where previous < t && now >= t { hit = t }
        return hit
    }

    /// A limit that was well used and is now back near zero has reset.
    public static func didReset(previous: Double?, now: Double) -> Bool {
        guard let previous else { return false }
        return previous >= 25 && now < previous - 20 && now < 10
    }

    public static func message(account: String, window: UsageWindow, threshold: Double, now: Date = Date()) -> (title: String, body: String) {
        var body = "\(Int(window.usedPercent))% of your \(window.name.lowercased()) limit used."
        if let reset = window.resetsAt { body += " Resets " + AIFormat.countdown(to: reset, now: now) + "." }
        if case .runsOut(let seconds)? = window.pace(now: now), seconds > 0 { body += " At this pace it runs out in " + AIFormat.duration(seconds) + "." }
        return ("\(account): \(Int(threshold))% used", body)
    }
}

public enum AIFormat {
    public static func tokens(_ n: Int) -> String {
        let d = Double(n)
        if d >= 1e9 { return String(format: "%.1fB", d / 1e9) }
        if d >= 1e6 { return String(format: "%.1fM", d / 1e6) }
        if d >= 1e3 { return String(format: "%.0fK", d / 1e3) }
        return String(n)
    }

    public static func money(_ amount: Double, currency: String = "USD") -> String {
        let symbol = ["USD": "$", "GBP": "£", "EUR": "€", "CNY": "¥"][currency] ?? currency + " "
        return amount < 10 ? symbol + String(format: "%.2f", amount) : symbol + String(format: "%.0f", amount)
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        if s >= 86400 { return "\(s / 86400)d \(s % 86400 / 3600)h" }
        if s >= 3600 { return "\(s / 3600)h \(s % 3600 / 60)m" }
        return "\(max(1, s / 60))m"
    }

    public static func countdown(to date: Date, now: Date = Date()) -> String {
        let left = date.timeIntervalSince(now)
        return left <= 0 ? "now" : "in " + duration(left)
    }

    public static func pace(_ pace: UsageWindow.Pace) -> String {
        switch pace {
        case .reserve(let p): return "\(Int(p))% in reserve"
        case .onPace: return "On pace"
        case .runsOut(let s): return s <= 0 ? "Limit reached" : "Runs out in " + duration(s)
        }
    }
}
