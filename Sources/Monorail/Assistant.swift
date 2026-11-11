#if os(macOS)
import Foundation
import MonorailCore
import Security

/// The optional assistant (Settings → Smart → Assistant): when a sentence isn't understood on
/// this Mac, a model of your choice rewrites it as commands Monorail already understands: Claude,
/// OpenAI, Gemini, Grok, OpenRouter, a model in Ollama on this Mac, or any OpenAI-compatible server.
/// Monorail shows the commands and runs them only after you confirm. Only the sentence, the names
/// of open apps and the list of commands are sent, straight to the provider you chose.
enum Assistant {
    struct Plan: Decodable {
        var commands: [String]
        var explanation: String
    }

    // MARK: Key (Keychain)

    private static func service(_ provider: AssistantProvider) -> String {
        provider == .anthropic ? "org.ashforde.monorail.anthropic" : "org.ashforde.monorail.assistant.\(provider.rawValue)"
    }

    static var hasKey: Bool { key != nil }
    static var key: String? { key(for: .anthropic) }
    static func setKey(_ value: String?) { setKey(value, for: .anthropic) }

    static func hasKey(for provider: AssistantProvider) -> Bool { key(for: provider) != nil }

    /// Whether the assistant can be asked with these settings.
    static func isReady(_ settings: AppSettings) -> Bool {
        let provider = settings.assistantProvider
        if provider == .custom && settings.assistantBaseURL.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        if provider != .anthropic && model(for: settings).isEmpty { return false }
        return provider.needsKey ? hasKey(for: provider) : true
    }

    /// The model to ask for the chosen provider.
    static func model(for settings: AppSettings) -> String {
        settings.assistantProvider == .anthropic
            ? settings.assistantModel
            : (settings.assistantModels[settings.assistantProvider.rawValue] ?? "").trimmingCharacters(in: .whitespaces)
    }

    static func key(for provider: AssistantProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service(provider),
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        return text.isEmpty ? nil : text
    }

    static func setKey(_ value: String?, for provider: AssistantProvider) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service(provider)]
        SecItemDelete(base as CFDictionary)
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    // MARK: Asking

    static let models = ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]

    private static let system = """
        You turn a person's request about arranging windows on their Mac into commands for Monorail, \
        a scrolling window manager. Windows sit on a horizontal strip of slides; a slide holds one or \
        more windows; there are numbered workspaces.

        Reply only with commands from this grammar, one simple sentence each, in the order to run them:
        - "<App> and <App> side by side" (also: stacked, grid, main left, main top, spiral, accordion), \
        optionally ending "on <workspace number>"
        - "<App> half" (also: full width, two thirds, three quarters, one third, quarter)
        - "move <App> to <workspace number>"
        - "go to <workspace number>"
        - "open <App>"
        - "focus mode on" / "focus mode off"
        - the exact title of one of the listed actions

        Use app names exactly as listed when they are open. If something can't be expressed with this \
        grammar, leave it out and say so in the explanation. Keep the explanation to one short sentence \
        written for the person. Never invent apps that aren't listed unless the person asked to open them.
        """

    /// Asks the chosen provider. Hands back the plan or a message to show.
    static func plan(for request: String, apps: [String], actions: [String], settings: AppSettings,
                     completion: @escaping (Result<Plan, Error>) -> Void) {
        let provider = settings.assistantProvider
        if provider == .anthropic {
            return plan(for: request, apps: apps, actions: actions, model: settings.assistantModel, completion: completion)
        }
        let base = settings.assistantBaseURL.trimmingCharacters(in: .whitespaces).isEmpty
            ? provider.defaultBaseURL ?? "" : settings.assistantBaseURL
        guard let url = AssistantProvider.chatURL(base: base) else {
            return completion(.failure(Failure("Add the server's address in Settings → Smart → Assistant")))
        }
        let key = key(for: provider)
        if provider.needsKey && key == nil {
            return completion(.failure(Failure("Add your \(provider.title) API key in Settings → Smart → Assistant")))
        }
        let model = model(for: settings)
        guard !model.isEmpty else { return completion(.failure(Failure("Choose a model in Settings → Smart → Assistant"))) }
        let context = "Open apps: \(apps.prefix(60).joined(separator: ", "))\nActions: \(actions.joined(separator: "; "))"
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system + "\n\nReply with only a JSON object: {\"commands\": [strings], \"explanation\": string}."],
                ["role": "user", "content": context + "\n\nRequest: " + request],
            ],
        ]
        if provider != .custom { body["response_format"] = ["type": "json_object"] }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = provider.isLocal ? 120 : 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        if let key { urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "authorization") }
        if provider == .openrouter {
            urlRequest.setValue("https://monorail.ashforde.org", forHTTPHeaderField: "HTTP-Referer")
            urlRequest.setValue("Monorail", forHTTPHeaderField: "X-Title")
        }
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            let result = interpretChat(data: data, response: response, error: error, provider: provider)
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func interpretChat(data: Data?, response: URLResponse?, error: Error?, provider: AssistantProvider) -> Result<Plan, Error> {
        let name = provider.shortName
        if let error {
            return .failure(Failure(provider.isLocal ? "Couldn’t reach Ollama · is it running?" : "Couldn’t reach \(name): \(error.localizedDescription)"))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        guard status == 200 else {
            let message = (object["error"] as? [String: Any])?["message"] as? String ?? object["error"] as? String ?? "HTTP \(status)"
            return .failure(Failure(status == 401 || status == 403 ? "Your \(provider.title) API key was refused" : "\(name): \(message)"))
        }
        let choice = (object["choices"] as? [[String: Any]])?.first
        let text = (choice?["message"] as? [String: Any])?["content"] as? String ?? ""
        guard let json = AssistantProvider.jsonObject(in: text), let plan = try? JSONDecoder().decode(Plan.self, from: json) else {
            return .failure(Failure("\(name)’s answer couldn’t be read"))
        }
        return .success(plan)
    }

    /// Models installed in Ollama on this Mac.
    static func ollamaModels(base: String, completion: @escaping ([String]) -> Void) {
        var root = base.trimmingCharacters(in: .whitespaces)
        if root.isEmpty { root = "http://localhost:11434" }
        root = root.replacingOccurrences(of: "/v1", with: "")
        while root.hasSuffix("/") { root.removeLast() }
        guard let url = URL(string: root + "/api/tags") else { return completion([]) }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let names = (object?["models"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }.sorted()
            DispatchQueue.main.async { completion(names) }
        }.resume()
    }

    /// Calls Anthropic's Messages API.
    private static func plan(for request: String, apps: [String], actions: [String], model: String,
                             completion: @escaping (Result<Plan, Error>) -> Void) {
        guard let key else { return completion(.failure(Failure("Add your Anthropic API key in Settings → Smart → Assistant"))) }
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "commands": ["type": "array", "items": ["type": "string"]],
                "explanation": ["type": "string"],
            ],
            "required": ["commands", "explanation"],
            "additionalProperties": false,
        ]
        let context = "Open apps: \(apps.prefix(60).joined(separator: ", "))\nActions: \(actions.joined(separator: "; "))"
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4000,
            "system": system,
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": context + "\n\nRequest: " + request]],
        ]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        if model != "claude-haiku-5-5" {
            // If the model declines, Anthropic re-runs the request on its recommended fallback.
            body["fallbacks"] = "default"
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result = interpret(data: data, response: response, error: error)
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func interpret(data: Data?, response: URLResponse?, error: Error?) -> Result<Plan, Error> {
        if let error { return .failure(Failure("Couldn’t reach Claude: \(error.localizedDescription)")) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        guard status == 200 else {
            let message = (object["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(status)"
            return .failure(Failure(status == 401 ? "Your Anthropic API key was refused" : "Claude: \(message)"))
        }
        if object["stop_reason"] as? String == "refusal" { return .failure(Failure("Claude declined that request")) }
        let blocks = object["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
            let plan = try? JSONDecoder().decode(Plan.self, from: Data(text.utf8))
        else { return .failure(Failure("Claude’s answer couldn’t be read")) }
        return .success(plan)
    }

    struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
#endif
