import Foundation

/// Where the optional assistant sends a sentence it couldn't understand. Anthropic uses its own
/// Messages API; the rest speak the widely used chat-completions format.
public enum AssistantProvider: String, Codable, CaseIterable, Sendable {
    case anthropic, openai, gemini, xai, openrouter, ollama, custom

    public var title: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .xai: return "xAI (Grok)"
        case .openrouter: return "OpenRouter"
        case .ollama: return "Ollama on this Mac"
        case .custom: return "Other (OpenAI-compatible)"
        }
    }

    /// The short name in notices: "Asking Grok…".
    public var shortName: String {
        switch self {
        case .anthropic: return "Claude"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .xai: return "Grok"
        case .openrouter: return "OpenRouter"
        case .ollama: return "Ollama"
        case .custom: return "the assistant"
        }
    }

    /// The base address for chat completions (nil for Anthropic, which has its own API).
    public var defaultBaseURL: String? {
        switch self {
        case .anthropic: return nil
        case .openai: return "https://api.openai.com/v1"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .xai: return "https://api.x.ai/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .custom: return nil
        }
    }

    /// Whether it needs an API key (Ollama runs on the Mac; a custom server may or may not).
    public var needsKey: Bool { self != .ollama && self != .custom }

    /// Where to get a key.
    public var keyPage: String? {
        switch self {
        case .anthropic: return "https://platform.claude.com/settings/keys"
        case .openai: return "https://platform.openai.com/api-keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        case .xai: return "https://console.x.ai"
        case .openrouter: return "https://openrouter.ai/keys"
        case .ollama, .custom: return nil
        }
    }

    /// Whether everything stays on this Mac.
    public var isLocal: Bool { self == .ollama }

    /// The chat-completions endpoint for a base address, tolerating a trailing slash or a full path.
    public static func chatURL(base: String) -> URL? {
        var trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasSuffix("/chat/completions") { return URL(string: trimmed) }
        return URL(string: trimmed + "/chat/completions")
    }

    /// The JSON object in a model's reply, even when it's wrapped in a code fence or a sentence.
    public static func jsonObject(in text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        return Data(text[start...end].utf8)
    }
}
