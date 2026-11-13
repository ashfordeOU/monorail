#if os(macOS)
import AppKit
import Foundation
import MonorailCore
import Security
import UserNotifications

/// AI Usage: reads every AI account on this Mac and keeps a report for each.
/// Plans (Claude, Codex, Gemini) from their own tools' sign-in and logs; agents (OpenClaw, Hermes) from
/// their logs; local models (Ollama, LM Studio) from their servers; API keys from each provider's
/// usage or balance endpoint. Nothing is sent anywhere but the provider each account belongs to.
final class AIUsageWatch: ObservableObject {
    static let shared = AIUsageWatch()

    @Published private(set) var reports: [String: AIReport] = [:]
    @Published private(set) var refreshing = false
    var store: SettingsStore?

    private let queue = DispatchQueue(label: "org.ashforde.monorail.ai-usage", qos: .utility)
    private var timer: Timer?
    private var ledgers: [String: UsageLedger] = [:]
    private var offsets: [String: [String: UInt64]] = [:]
    private var seen: [String: Set<String>] = [:]
    private var lastPercent: [String: Double] = [:]
    private var told: Set<String> = []
    private var lastStatusCheck: [String: Date] = [:]
    private var incidents: [String: String] = [:]
    private var settings: AppSettings { store?.settings ?? AppSettings() }

    // MARK: Lifecycle

    func start() {
        guard timer == nil else { return }
        if settings.aiAccounts.isEmpty { detectAccounts() }
        refresh()
        timer = Timer.every(300) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 60
    }

    /// Reads every enabled account again, in the background.
    func refresh() {
        let accounts = settings.aiAccounts.filter(\.enabled)
        let live = settings.aiLiveLimits
        guard !accounts.isEmpty else { return }
        DispatchQueue.main.async { self.refreshing = true }
        queue.async {
            var fresh: [String: AIReport] = [:]
            for account in accounts { fresh[account.id] = self.read(account, live: live) }
            DispatchQueue.main.async {
                for (id, report) in fresh { self.reports[id] = report }
                self.refreshing = false
                self.alert(fresh, accounts: accounts)
            }
        }
    }

    /// The account most worth showing in the menu bar: the fullest limit across every plan.
    var headline: (account: AIAccount, window: UsageWindow)? {
        var best: (AIAccount, UsageWindow)?
        for account in settings.aiAccounts where account.enabled {
            guard let w = reports[account.id]?.headline else { continue }
            if best == nil || w.usedPercent > best!.1.usedPercent { best = (account, w) }
        }
        return best
    }

    // MARK: Accounts

    static var realHome: URL { StorageWatch.realHome }

    /// What's on this Mac: the folders of Claude Code, Codex, Gemini CLI, OpenClaw and Hermes, and Ollama or LM Studio if running.
    func detectAccounts() {
        guard let store else { return }
        var found: [AIAccount] = []
        for provider in [AIProvider.claude, .codex, .gemini, .openclaw, .hermes] {
            guard let folder = provider.defaultFolder else { continue }
            if FileManager.default.fileExists(atPath: Self.home.appendingPathComponent(folder).path) || !Edition.isAppStore && FileManager.default.fileExists(atPath: Self.realHome.appendingPathComponent(folder).path) {
                found.append(AIAccount(provider: provider))
            }
        }
        let group = DispatchGroup()
        var local: [AIAccount] = []
        for (provider, path) in [(AIProvider.ollama, "/api/version"), (.lmstudio, "/api/v0/models")] {
            guard let base = provider.defaultBaseURL, let url = URL(string: base + path) else { continue }
            group.enter()
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if (response as? HTTPURLResponse)?.statusCode == 200 { DispatchQueue.main.async { local.append(AIAccount(provider: provider)) } }
                group.leave()
            }.resume()
        }
        group.notify(queue: .main) {
            let all = found + local
            guard !all.isEmpty else { return }
            var settings = store.settings
            let existing = Set(settings.aiAccounts.map(\.provider))
            settings.aiAccounts += all.filter { !existing.contains($0.provider) }
            store.settings = settings
            self.refresh()
        }
    }

    func save(_ account: AIAccount) {
        guard let store else { return }
        var settings = store.settings
        if let i = settings.aiAccounts.firstIndex(where: { $0.id == account.id }) { settings.aiAccounts[i] = account } else { settings.aiAccounts.append(account) }
        store.settings = settings
        refresh()
    }

    func remove(_ account: AIAccount) {
        guard let store else { return }
        var settings = store.settings
        settings.aiAccounts.removeAll { $0.id == account.id }
        store.settings = settings
        Self.setKey(nil, for: account)
        reports[account.id] = nil
        try? FileManager.default.removeItem(at: ledgerURL(account.id))
    }

    // MARK: Keys (Keychain)

    private static func service(_ account: AIAccount) -> String { "org.ashforde.monorail.ai.\(account.keyRef ?? account.id)" }

    static func key(for account: AIAccount) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service(account),
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        return text.isEmpty ? nil : text
    }

    static func setKey(_ value: String?, for account: AIAccount) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service(account)]
        SecItemDelete(base as CFDictionary)
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    // MARK: Folders

    /// The home folder this edition can read: Signalbox reads it once you allow it (shared with Storage).
    static var home: URL { StorageWatch.home }

    /// Signalbox can't see the home folder (and so the agents' logs) until you allow it once.
    static var needsHomeGrant: Bool { Edition.isAppStore && StorageWatch.shared.granted == nil }

    static func canRead(_ url: URL) -> Bool { (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil }

    func folder(_ account: AIAccount) -> URL? {
        guard let path = account.folder, !path.isEmpty else { return nil }
        if path.hasPrefix("~/") { return Self.home.appendingPathComponent(String(path.dropFirst(2))) }
        return URL(fileURLWithPath: path)
    }

    /// Log files changed in the last two months, below `root`, whose names match.
    private func files(in root: URL, matching: (String) -> Bool, maxDepth: Int = 6) -> [URL] {
        let cutoff = Date().addingTimeInterval(-62 * 86400)
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                                                          options: [.skipsPackageDescendants]) else { return [] }
        var result: [URL] = []
        for case let url as URL in walker {
            if walker.level > maxDepth || ["node_modules", ".git", "cache", "Cache"].contains(url.lastPathComponent) { walker.skipDescendants(); continue }
            guard matching(url.lastPathComponent) else { continue }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if modified >= cutoff { result.append(url) }
        }
        return result
    }

    /// The new lines added to a log since it was last read.
    private func newLines(_ url: URL, account: String) -> [Substring] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        var start = offsets[account]?[url.path] ?? 0
        if start > size { start = 0 }
        guard size > start else { return [] }
        try? handle.seek(toOffset: start)
        guard let data = try? handle.readToEnd() else { return [] }
        // Stop at the last complete line, so a line being written is read next time.
        guard let lastNewline = data.lastIndex(of: 0x0A) else { return [] }
        let complete = data[data.startIndex...lastNewline]
        offsets[account, default: [:]][url.path] = start + UInt64(complete.count)
        return String(decoding: complete, as: UTF8.self).split(separator: "\n")
    }

    // MARK: Ledgers on disk

    private struct Saved: Codable {
        var ledger: UsageLedger
        var offsets: [String: UInt64]
    }

    private func ledgerURL(_ id: String) -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Edition.isAppStore ? "Signalbox" : "Monorail").appendingPathComponent("ai-usage")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(id).json")
    }

    private func loadLedger(_ id: String) -> UsageLedger {
        if let ledger = ledgers[id] { return ledger }
        if let data = try? Data(contentsOf: ledgerURL(id)), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            offsets[id] = saved.offsets
            ledgers[id] = saved.ledger
            return saved.ledger
        }
        return UsageLedger()
    }

    private func storeLedger(_ ledger: UsageLedger, id: String) {
        var ledger = ledger
        ledger.prune()
        ledgers[id] = ledger
        let saved = Saved(ledger: ledger, offsets: offsets[id] ?? [:])
        if let data = try? JSONEncoder().encode(saved) { try? data.write(to: ledgerURL(id), options: .atomic) }
    }

    // MARK: Reading one account

    private func read(_ account: AIAccount, live: Bool) -> AIReport {
        var report = AIReport(accountID: account.id)
        switch account.provider {
        case .claude: readClaude(account, live: live, into: &report)
        case .codex: readCodex(account, live: live, into: &report)
        case .gemini, .openclaw, .hermes: readAgentLogs(account, into: &report)
        case .ollama: readOllama(account, into: &report)
        case .lmstudio: readLMStudio(account, into: &report)
        default: readKey(account, into: &report)
        }
        if let status = account.provider.statusURL { report.incident = incident(status) }
        return report
    }

    private func finish(_ ledger: UsageLedger, account: AIAccount, into report: inout AIReport) {
        report.today = ledger.sum(lastDays: 1)
        report.month = ledger.sum(lastDays: 30)
        report.topModel = ledger.topModel(lastDays: 30)
        report.contexts = Array(ledger.liveContexts().prefix(8))
        for entry in ledger.lastDays(30) { report.daily[entry.day] = entry.totals }
        storeLedger(ledger, id: account.id)
    }

    private func readClaude(_ account: AIAccount, live: Bool, into report: inout AIReport) {
        guard let root = folder(account) else { return }
        var ledger = loadLedger(account.id)
        var seenIDs = seen[account.id] ?? []
        let logs = files(in: root.appendingPathComponent("projects"), matching: { $0.hasSuffix(".jsonl") }, maxDepth: 3)
        if logs.isEmpty && !FileManager.default.fileExists(atPath: root.path) {
            report.error = Edition.isAppStore ? "Allow your home folder so \(Brand.name) can read Claude Code's logs." : "Claude Code's folder wasn't found."
        }
        for file in logs {
            for line in newLines(file, account: account.id) {
                guard let entry = AIParse.claudeLogLine(String(line), seen: &seenIDs) else { continue }
                var totals = entry.totals
                if totals.cost == 0 { totals.cost = AIPricing.cost(totals, model: entry.model) }
                ledger.add(totals, model: entry.model, at: entry.at)
                let used = totals.input + totals.cacheRead + totals.cacheWrite + totals.output
                ledger.note(ContextReading(session: entry.session, project: entry.project, model: entry.model, used: used,
                                           window: AIPricing.contextWindow(for: entry.model, used: used), at: entry.at))
            }
        }
        seen[account.id] = seenIDs
        finish(ledger, account: account, into: &report)

        guard live else { return }
        var credentials: (token: String, expires: Date?, plan: String?)?
        if let data = try? Data(contentsOf: root.appendingPathComponent(".credentials.json")) { credentials = AIParse.claudeCredentials(data) }
        if credentials == nil, !Edition.isAppStore, let data = Self.claudeKeychain() { credentials = AIParse.claudeCredentials(data) }
        guard let credentials else {
            report.error = Edition.isAppStore ? "Live limits need Monorail: the App Store's sandbox can't read Claude Code's sign-in." : "Sign in to Claude Code to see live limits."
            return
        }
        report.plan = credentials.plan
        if let expires = credentials.expires, expires < Date() {
            report.error = "Claude Code's sign-in has expired. Open Claude Code once to renew it."
            return
        }
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        if let data = fetch(request, into: &report) { report.windows = AIParse.claudeLimits(data) }
    }

    /// Claude Code's sign-in in the login Keychain (macOS asks once to allow it).
    static func claudeKeychain() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Claude Code-credentials",
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private func readCodex(_ account: AIAccount, live: Bool, into report: inout AIReport) {
        guard let root = folder(account) else { return }
        var ledger = loadLedger(account.id)
        var latest: (windows: [UsageWindow], at: Date)?
        let logs = files(in: root.appendingPathComponent("sessions"), matching: { $0.hasPrefix("rollout-") && $0.hasSuffix(".jsonl") }, maxDepth: 4)
        for file in logs {
            var model = "codex"
            for line in newLines(file, account: account.id) {
                if line.contains("turn_context"), let m = Self.codexModel(String(line)) { model = m }
                guard let entry = AIParse.codexLogLine(String(line)) else { continue }
                if let last = entry.last {
                    var totals = last
                    totals.cost = AIPricing.cost(totals, model: model)
                    ledger.add(totals, model: model, at: entry.at)
                }
                if let used = entry.used {
                    ledger.note(ContextReading(session: file.deletingPathExtension().lastPathComponent, model: model, used: used,
                                               window: entry.window ?? AIPricing.contextWindow(for: model, used: used), at: entry.at))
                }
                if !entry.windows.isEmpty, latest == nil || entry.at > latest!.at { latest = (entry.windows, entry.at) }
            }
        }
        finish(ledger, account: account, into: &report)
        // Limits from the newest log line, kept between reads.
        if let latest { UserDefaults.standard.set(try? JSONEncoder().encode(latest.windows), forKey: "AICodexWindows.\(account.id)") }
        if let data = UserDefaults.standard.data(forKey: "AICodexWindows.\(account.id)"), let saved = try? JSONDecoder().decode([UsageWindow].self, from: data) {
            report.windows = saved.filter { $0.resetsAt.map { $0 > Date() } ?? true }
        }

        guard live, let data = try? Data(contentsOf: root.appendingPathComponent("auth.json")), let creds = AIParse.codexCredentials(data),
              creds.account != nil, let url = URL(string: "https://chatgpt.com/backend-api/wham/usage") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(creds.token)", forHTTPHeaderField: "Authorization")
        if let id = creds.account { request.setValue(id, forHTTPHeaderField: "ChatGPT-Account-Id") }
        if let body = fetch(request, into: &report) {
            let parsed = AIParse.codexLimits(body)
            report.plan = parsed.plan
            if !parsed.windows.isEmpty { report.windows = parsed.windows }
            report.balance = parsed.credits
        }
    }

    private static func codexModel(_ line: String) -> String? {
        guard let data = line.data(using: .utf8), let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let payload = root["payload"] as? [String: Any] else { return nil }
        return payload["model"] as? String
    }

    private func readAgentLogs(_ account: AIAccount, into report: inout AIReport) {
        guard let root = folder(account) else { return }
        var ledger = loadLedger(account.id)
        for file in files(in: root, matching: { $0.hasSuffix(".jsonl") }) {
            for line in newLines(file, account: account.id) {
                guard let entry = AIParse.genericUsageLine(String(line)) else { continue }
                var totals = entry.totals
                if totals.cost == 0 { totals.cost = AIPricing.cost(totals, model: entry.model) }
                let at = entry.at ?? Date()
                ledger.add(totals, model: entry.model, at: at)
                let used = totals.input + totals.cacheRead + totals.cacheWrite
                ledger.note(ContextReading(session: file.deletingPathExtension().lastPathComponent, model: entry.model, used: used,
                                           window: AIPricing.contextWindow(for: entry.model, used: used), at: at))
            }
        }
        finish(ledger, account: account, into: &report)
    }

    private func readOllama(_ account: AIAccount, into report: inout AIReport) {
        let base = account.baseURL ?? AIProvider.ollama.defaultBaseURL ?? ""
        guard let ps = URL(string: base + "/api/ps"), let tags = URL(string: base + "/api/tags") else { return }
        let running = fetch(URLRequest(url: ps), into: &report).map(AIParse.ollamaRunning) ?? []
        let installed = fetch(URLRequest(url: tags), into: &report).map(AIParse.ollamaInstalled) ?? []
        let loaded = Set(running.map(\.name))
        report.models = running + installed.filter { !loaded.contains($0.name) }
        if report.error != nil { report.error = "Ollama isn't running." }
    }

    private func readLMStudio(_ account: AIAccount, into report: inout AIReport) {
        let base = account.baseURL ?? AIProvider.lmstudio.defaultBaseURL ?? ""
        guard let url = URL(string: base + "/api/v0/models") else { return }
        report.models = fetch(URLRequest(url: url), into: &report).map(AIParse.lmStudioModels) ?? []
        report.models.sort { $0.loaded && !$1.loaded }
        if report.error != nil { report.error = "LM Studio's server isn't running. Turn it on in LM Studio → Developer." }
    }

    private func readKey(_ account: AIAccount, into report: inout AIReport) {
        let base = (account.baseURL ?? account.provider.defaultBaseURL ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let key = Self.key(for: account)
        if key == nil && account.provider != .litellm && account.provider != .custom {
            report.error = "Add a key for this account."
            return
        }
        func request(_ path: String, admin: Bool = false) -> URLRequest? {
            guard let url = URL(string: base + path) else { return nil }
            var r = URLRequest(url: url)
            if let key {
                if account.provider == .anthropicAPI {
                    r.setValue(key, forHTTPHeaderField: "x-api-key")
                    r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                } else {
                    r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                }
            }
            return r
        }
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        switch account.provider {
        case .openrouter:
            if let r = request("/credits"), let data = fetch(r, into: &report) {
                (report.spent, report.limit, report.balance) = AIParse.openRouter(data)
            }
            if report.limit == nil, let r = request("/key"), let data = fetch(r, into: &report) {
                (report.spent, report.limit, report.balance) = AIParse.openRouter(data)
            }
        case .deepseek:
            if let r = request("/user/balance"), let data = fetch(r, into: &report), let b = AIParse.deepseekBalance(data) {
                report.balance = b.balance
                report.currency = b.currency
            }
        case .moonshot:
            if let r = request("/v1/users/me/balance"), let data = fetch(r, into: &report) { report.balance = AIParse.moonshotBalance(data) }
        case .litellm:
            if let r = request("/key/info"), let data = fetch(r, into: &report) { (report.spent, report.limit) = AIParse.liteLLM(data) }
        case .openai:
            if let r = request("/v1/organization/costs?start_time=\(Int(monthStart.timeIntervalSince1970))&limit=31"), let data = fetch(r, into: &report) {
                report.spent = AIParse.openAICosts(data)
            }
            if report.error != nil { report.error = "Spend needs an admin key (platform.openai.com → Admin keys)." }
        case .anthropicAPI:
            let start = ISO8601DateFormatter().string(from: monthStart)
            if let r = request("/v1/organizations/cost_report?starting_at=\(start)&limit=31"), let data = fetch(r, into: &report) {
                report.spent = AIParse.anthropicCosts(data)
            }
            if report.error != nil { report.error = "Spend needs an Admin API key (platform.claude.com → Admin keys)." }
        default:
            // Any OpenAI-compatible server: check it answers and list its models.
            if let r = request("/models") ?? request("/v1/models"), let data = fetch(r, into: &report),
               let list = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["data"] as? [[String: Any]] {
                report.models = list.compactMap { ($0["id"] as? String).map { LocalModel(name: $0, loaded: true) } }
            }
        }
    }

    // MARK: Network

    /// A blocking fetch on the reading queue; failures are written into the report.
    private func fetch(_ request: URLRequest, into report: inout AIReport) -> Data? {
        var request = request
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let done = DispatchSemaphore(value: 0)
        var result: (Data?, URLResponse?, Error?) = (nil, nil, nil)
        URLSession.shared.dataTask(with: request) { result = ($0, $1, $2); done.signal() }.resume()
        _ = done.wait(timeout: .now() + 15)
        let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
        if status == 200, let data = result.0 { return data }
        switch status {
        case 401, 403: report.error = "The sign-in or key was refused (\(status))."
        case 429: report.error = "The provider asked to slow down; trying again in a few minutes."
        case 0: report.error = "Couldn't reach \(request.url?.host ?? "the server")."
        default: report.error = "\(request.url?.host ?? "The server") answered \(status)."
        }
        return nil
    }

    private func incident(_ statusURL: String) -> String? {
        if let last = lastStatusCheck[statusURL], Date().timeIntervalSince(last) < 900 { return incidents[statusURL] }
        lastStatusCheck[statusURL] = Date()
        guard let url = URL(string: statusURL) else { return nil }
        var ignored = AIReport(accountID: "")
        let found = fetch(URLRequest(url: url), into: &ignored).flatMap(AIParse.status)
        incidents[statusURL] = found
        return found
    }

    // MARK: Alerts

    private func alert(_ fresh: [String: AIReport], accounts: [AIAccount]) {
        let s = settings
        guard !SuiteRole.shared.pauses(.notifications) else { return }
        for account in accounts where account.notify {
            guard let report = fresh[account.id] else { continue }
            for window in report.windows {
                let key = account.id + "." + window.name
                let previous = lastPercent[key]
                lastPercent[key] = window.usedPercent
                if let threshold = AIAlerts.crossed(previous: previous, now: window.usedPercent, thresholds: s.aiThresholds) {
                    let m = AIAlerts.message(account: account.label, window: window, threshold: threshold)
                    notify(m.title, m.body)
                } else if s.aiNotifyResets, AIAlerts.didReset(previous: previous, now: window.usedPercent) {
                    notify("\(account.label): \(window.name.lowercased()) limit reset", "You have your full \(window.name.lowercased()) limit again.")
                }
            }
            if s.aiNotifyContext {
                for context in report.contexts where context.percent >= 90 && !told.contains("ctx." + context.session) {
                    told.insert("ctx." + context.session)
                    let place = context.project.map { " in \($0)" } ?? ""
                    notify("\(account.label): conversation \(Int(context.percent))% full",
                           "A conversation\(place) is nearly out of context (\(AIFormat.tokens(context.used)) of \(AIFormat.tokens(context.window))). Compact it or start a fresh one.")
                }
            }
            if s.aiNotifyIncidents, let incident = report.incident, !told.contains("inc." + account.provider.rawValue + incident) {
                told.insert("inc." + account.provider.rawValue + incident)
                notify("\(account.provider.name) is having problems", incident)
            }
        }
    }

    private func notify(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
#endif
