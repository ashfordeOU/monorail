#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

/// The Dashboard's AI Usage page: every AI account on this Mac with its limits, tokens, spend,
/// context and local models, plus the alerts.
struct AIUsageSection: View {
    @ObservedObject private var watch = AIUsageWatch.shared
    @State private var editing: AIAccount?

    var body: some View {
        let store = DashboardContext.store
        let accounts = store?.settings.aiAccounts ?? []
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Usage").font(.system(size: 22, weight: .bold))
                    Text("Limits, tokens, spend and context for every AI account, cloud or on this Mac").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { watch.refresh() } label: { Label(watch.refreshing ? "Reading…" : "Refresh", systemImage: "arrow.clockwise") }
                    .disabled(watch.refreshing)
                Button { editing = AIAccount(provider: .claude, label: "Claude") } label: { Label("Add Account", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
            }
            if AIUsageWatch.needsHomeGrant {
                Notice(symbol: "folder.badge.questionmark", text: "Allow your home folder once so \(Brand.name) can read Claude Code, Codex, OpenClaw and Hermes logs. Nothing leaves your Mac.",
                       action: "Allow…") { StorageWatch.shared.grantHome(); watch.detectAccounts(); watch.refresh() }
            }
            if let store, !store.settings.aiLiveLimits {
                Notice(symbol: "gauge.with.needle", text: "Turn on live limits to see your Claude and Codex plan limits as the providers count them, using the sign-in their own apps saved. \(Edition.isAppStore ? "" : "macOS asks once before Monorail reads Claude Code's sign-in.")",
                       action: "Turn On") {
                    store.settings.aiLiveLimits = true
                    watch.refresh()
                }
            }
            if accounts.isEmpty {
                DashCard(title: "No accounts yet") {
                    Text("Add Claude, Codex, Gemini, OpenClaw, Hermes, Ollama, LM Studio or any API key. \(Brand.name) found nothing to add on its own.").foregroundStyle(.secondary)
                    Button("Look Again") { watch.detectAccounts() }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 14) {
                ForEach(accounts) { account in
                    AIAccountCard(account: account, report: watch.reports[account.id], edit: { editing = account })
                }
            }
            if let store { AIAlertsCard(store: store) }
        }
        .sectionScroll()
        .onAppear { watch.start() }
        .sheet(item: $editing) { account in
            AIAccountEditor(account: account, isNew: !accounts.contains { $0.id == account.id }) { editing = nil }
        }
    }
}

private struct Notice: View {
    let symbol: String
    let text: String
    let action: String
    let perform: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Color(nsColor: .systemOrange)).frame(width: 24)
            Text(text).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action, action: perform)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))
    }
}

/// One account: its limits as bars with pace, then tokens and spend, live conversations and models.
struct AIAccountCard: View {
    let account: AIAccount
    let report: AIReport?
    let edit: () -> Void

    var body: some View {
        DashCard(title: account.label, trailing: report?.plan ?? (account.label == account.provider.name ? nil : account.provider.name)) {
            if let incident = report?.incident {
                Label(incident, systemImage: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(Color(nsColor: .systemYellow))
            }
            if let report {
                ForEach(Array(report.windows.enumerated()), id: \.offset) { _, window in LimitBar(window: window) }
                if report.month.total > 0 { tokens(report) }
                if !report.contexts.isEmpty { contexts(report.contexts) }
                if !report.models.isEmpty { models(report.models) }
                money(report)
                if let error = report.error {
                    Text(error).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if report.windows.isEmpty && report.month.total == 0 && report.models.isEmpty && report.error == nil && report.balance == nil && report.spent == nil {
                    Text("Nothing used in the last 30 days.").foregroundStyle(.secondary)
                }
            } else {
                HStack { ProgressView().controlSize(.small); Text("Reading…").foregroundStyle(.secondary) }
            }
            HStack {
                Spacer()
                Button("Edit", action: edit).buttonStyle(.link).font(.system(size: 11.5))
            }
        }
    }

    private func tokens(_ r: AIReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                stat("Today", AIFormat.tokens(r.today.total), r.today.cost > 0 ? AIFormat.money(r.today.cost) : nil)
                stat("30 days", AIFormat.tokens(r.month.total), r.month.cost > 0 ? AIFormat.money(r.month.cost) : nil)
                stat("Requests", "\(r.month.requests)", nil)
            }
            if let top = r.topModel { Text("Mostly \(top)").font(.system(size: 11)).foregroundStyle(.secondary) }
            UsageBars(daily: r.daily)
            if r.month.cost > 0 && account.provider.kind == .plan {
                Text("Cost is what these tokens would cost at API prices; your plan covers them.").font(.system(size: 10.5)).foregroundStyle(.tertiary)
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased()).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .semibold)).monospacedDigit()
            Text(detail ?? " ").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func contexts(_ list: [ContextReading]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONTEXT IN USE").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(list.prefix(4), id: \.session) { c in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(c.project ?? c.model ?? "Conversation").font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Text("\(AIFormat.tokens(c.used)) / \(AIFormat.tokens(c.window))").font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Meter(fraction: c.percent / 100)
                }
            }
        }
    }

    private func models(_ list: [LocalModel]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(account.provider.kind == .local ? "MODELS" : "MODELS AVAILABLE").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(list.prefix(6), id: \.name) { m in
                HStack(spacing: 6) {
                    Circle().fill(m.loaded ? Color(nsColor: .systemGreen) : Color.secondary.opacity(0.4)).frame(width: 7, height: 7)
                    Text(m.name).font(.system(size: 12)).lineLimit(1)
                    Spacer()
                    if let context = m.contextLength { Text("\(AIFormat.tokens(context)) context").font(.system(size: 11)).foregroundStyle(.secondary) }
                    if m.vramBytes > 0 { Text(ByteCountFormatter.string(fromByteCount: m.vramBytes, countStyle: .memory) + " GPU").font(.system(size: 11)).foregroundStyle(.secondary) }
                    else if m.sizeBytes > 0 { Text(ByteCountFormatter.string(fromByteCount: m.sizeBytes, countStyle: .file)).font(.system(size: 11)).foregroundStyle(.tertiary) }
                }
                .monospacedDigit()
            }
        }
    }

    @ViewBuilder private func money(_ r: AIReport) -> some View {
        if r.balance != nil || r.spent != nil {
            HStack(spacing: 0) {
                if let balance = r.balance { stat(account.provider == .codex ? "Credits" : "Left", AIFormat.money(balance, currency: r.currency), nil) }
                if let spent = r.spent { stat(account.provider.kind == .apiKey && r.limit == nil ? "This month" : "Spent", AIFormat.money(spent, currency: r.currency), nil) }
                if let limit = r.limit { stat("Limit", AIFormat.money(limit, currency: r.currency), nil) }
            }
            if let spent = r.spent, let limit = r.limit, limit > 0 { Meter(fraction: spent / limit) }
        }
    }
}

/// A plan limit: how much is used, when it resets, and whether it'll last.
struct LimitBar: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.name).font(.system(size: 12.5, weight: .medium))
                Spacer()
                Text("\(Int(window.usedPercent.rounded()))%").font(.system(size: 13, weight: .semibold)).monospacedDigit()
            }
            Meter(fraction: window.usedPercent / 100)
            HStack {
                if let pace = window.pace() {
                    Text(AIFormat.pace(pace)).foregroundStyle(paceColour(pace))
                }
                Spacer()
                if let reset = window.resetsAt { Text("Resets " + AIFormat.countdown(to: reset)) }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private func paceColour(_ pace: UsageWindow.Pace) -> Color {
        if case .runsOut = pace { return Color(nsColor: .systemRed) }
        if case .reserve = pace { return Color(nsColor: .systemGreen) }
        return .secondary
    }
}

/// A rounded bar: green, then orange past 75%, red past 90%.
struct Meter: View {
    let fraction: Double

    var body: some View {
        let f = min(max(fraction, 0), 1)
        let colour: Color = f >= 0.9 ? Color(nsColor: .systemRed) : f >= 0.75 ? Color(nsColor: .systemOrange) : Color(nsColor: .systemGreen)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(colour).frame(width: max(4, geo.size.width * f))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityValue("\(Int(f * 100)) percent")
    }
}

/// Tokens by day for the last two weeks.
private struct UsageBars: View {
    let daily: [String: TokenTotals]

    var body: some View {
        let days = daily.keys.sorted().suffix(14)
        let values = days.map { Double(daily[$0]?.total ?? 0) }
        let top = max(values.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(nsColor: .systemOrange).opacity(index == days.count - 1 ? 1 : 0.8))
                    .frame(height: max(2, 36 * values[index] / top))
                    .frame(maxWidth: .infinity)
                    .help("\(day): \(AIFormat.tokens(Int(values[index]))) tokens")
            }
        }
        .frame(height: 36, alignment: .bottom)
        .accessibilityLabel("Tokens by day for the last two weeks")
    }
}

/// When to be told.
private struct AIAlertsCard: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        DashCard(title: "Alerts") {
            HStack {
                Text("Tell me when a limit passes")
                Spacer()
                ForEach([50.0, 80, 90, 95], id: \.self) { t in
                    let on = store.settings.aiThresholds.contains(t)
                    Button {
                        var list = store.settings.aiThresholds.filter { $0 != t }
                        if !on { list.append(t) }
                        store.settings.aiThresholds = list.sorted()
                    } label: {
                        Label("\(Int(t))%", systemImage: on ? "checkmark" : "plus").labelStyle(.titleAndIcon)
                            .font(.system(size: 11.5, weight: on ? .semibold : .regular))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(on ? Color(nsColor: .systemOrange).opacity(0.85) : Color.white.opacity(0.08)))
                            .foregroundStyle(on ? Color.white : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Toggle("When a limit resets", isOn: $store.settings.aiNotifyResets)
            Toggle("When a conversation's context is 90% full", isOn: $store.settings.aiNotifyContext)
            Toggle("When Claude or OpenAI reports an incident", isOn: $store.settings.aiNotifyIncidents)
            Toggle("Live limits from Claude and Codex", isOn: $store.settings.aiLiveLimits)
            Text("Each account can be kept quiet in Edit. Keys stay in your Keychain; usage is read from each provider and from logs on this Mac, and never sent anywhere else.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .font(.system(size: 12.5))
    }
}

/// Add or change an account: provider, name, where to read it, and a key if it needs one.
struct AIAccountEditor: View {
    @State var account: AIAccount
    let isNew: Bool
    let close: () -> Void
    @State private var key = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "Add an AI Account" : "Edit \(account.label)").font(.system(size: 17, weight: .bold))
            Form {
                Picker("Provider", selection: Binding(get: { account.provider }, set: { p in
                    if account.label == account.provider.name { account.label = p.name }
                    account.provider = p
                    account.folder = p.defaultFolder.map { "~/" + $0 }
                    account.baseURL = p.defaultBaseURL
                })) {
                    ForEach(AIProvider.allCases, id: \.self) { Label($0.name, systemImage: $0.symbol).tag($0) }
                }
                TextField("Name", text: $account.label, prompt: Text("Work, Personal…"))
                if account.provider.defaultFolder != nil {
                    HStack {
                        TextField("Folder", text: Binding(get: { account.folder ?? "" }, set: { account.folder = $0 }))
                        Button("Choose…") { choose() }
                    }
                    Text(folderHelp).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if account.provider.kind != .plan && account.provider.kind != .agent {
                    TextField("Server", text: Binding(get: { account.baseURL ?? "" }, set: { account.baseURL = $0 }))
                }
                if account.provider.kind == .apiKey {
                    SecureField("Key", text: $key, prompt: Text(AIUsageWatch.key(for: account) == nil ? keyHint : "Saved in your Keychain"))
                }
                Toggle("Notify me about this account", isOn: $account.notify)
                Toggle("Show this account", isOn: $account.enabled)
            }
            HStack {
                if !isNew {
                    Button("Remove", role: .destructive) { AIUsageWatch.shared.remove(account); close() }
                }
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    if !key.isEmpty { AIUsageWatch.setKey(key, for: account) }
                    AIUsageWatch.shared.save(account)
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(account.label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var folderHelp: String {
        switch account.provider {
        case .claude: return "A second Claude account? Point this at its CLAUDE_CONFIG_DIR folder."
        case .codex: return "A second Codex account? Point this at its CODEX_HOME folder."
        default: return "Where \(account.provider.name) keeps its sessions."
        }
    }

    private var keyHint: String {
        switch account.provider {
        case .openai: return "An admin key, for this month's spend"
        case .anthropicAPI: return "An Admin API key (sk-ant-admin…)"
        case .litellm: return "A virtual key (optional)"
        case .custom: return "Optional"
        default: return "API key"
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.showsHiddenFiles = true
        panel.directoryURL = AIUsageWatch.realHome
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let home = AIUsageWatch.realHome.path
        account.folder = url.path.hasPrefix(home + "/") ? "~/" + url.path.dropFirst(home.count + 1) : url.path
    }
}
#endif
