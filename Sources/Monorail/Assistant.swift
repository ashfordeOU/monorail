#if os(macOS)
import Foundation
import MonorailCore
import Security

/// The optional assistant (Settings → Smart → Assistant): when a sentence isn't understood on
/// this Mac, and you've added your own Anthropic API key, Claude rewrites it as commands Monorail
/// already understands. Monorail shows them and runs them only after you confirm. Only the
/// sentence, the names of open apps and the list of commands are sent, straight to Anthropic.
enum Assistant {
    struct Plan: Decodable {
        var commands: [String]
        var explanation: String
    }

    // MARK: Key (Keychain)

    private static let service = "org.ashforde.monorail.anthropic"

    static var hasKey: Bool { key != nil }

    static var key: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        return text.isEmpty ? nil : text
    }

    static func setKey(_ value: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
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

    /// Calls the Messages API. Hands back the plan or a message to show.
    static func plan(for request: String, apps: [String], actions: [String], model: String,
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
