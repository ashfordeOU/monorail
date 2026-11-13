import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// The Tools window's text and developer tools: pure, so they're tested on Linux too.
public enum DevTools {
    public static func prettyJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let out = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]) else { return nil }
        return String(decoding: out, as: UTF8.self)
    }

    public static func minifyJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let out = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]) else { return nil }
        return String(decoding: out, as: UTF8.self)
    }

    public static func base64Encode(_ text: String) -> String { Data(text.utf8).base64EncodedString() }

    public static func base64Decode(_ text: String) -> String? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s).flatMap { String(data: $0, encoding: .utf8) }
    }

    #if canImport(CryptoKit)
    public static func hashes(_ text: String) -> [(name: String, hex: String)] {
        let data = Data(text.utf8)
        func hex<D: Sequence>(_ d: D) -> String where D.Element == UInt8 { d.map { String(format: "%02x", $0) }.joined() }
        return [("MD5", hex(Insecure.MD5.hash(data: data))), ("SHA-1", hex(Insecure.SHA1.hash(data: data))),
                ("SHA-256", hex(SHA256.hash(data: data))), ("SHA-512", hex(SHA512.hash(data: data)))]
    }
    #endif

    /// A Unix timestamp (seconds or milliseconds) as a date, or a date as a timestamp.
    public static func timestamp(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        if let number = Double(t) {
            let seconds = number > 1e11 ? number / 1000 : number
            return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: seconds))
        }
        if let date = ISO8601DateFormatter().date(from: t) { return String(Int(date.timeIntervalSince1970)) }
        return nil
    }

    /// The header and claims of a JSON Web Token, pretty printed.
    public static func decodeJWT(_ token: String) -> (header: String, payload: String)? {
        let parts = token.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".")
        guard parts.count >= 2, let h = base64Decode(String(parts[0])), let p = base64Decode(String(parts[1])) else { return nil }
        return (prettyJSON(h) ?? h, prettyJSON(p) ?? p)
    }

    /// A link without tracking parameters (utm_*, fbclid, gclid and friends).
    public static func cleanLink(_ text: String) -> String? {
        guard var parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), parts.host != nil else { return nil }
        let tracking: Set<String> = ["fbclid", "gclid", "dclid", "msclkid", "mc_eid", "mc_cid", "igshid", "yclid", "_hsenc", "_hsmi", "ref_src", "si", "spm"]
        parts.queryItems = parts.queryItems?.filter { item in !item.name.lowercased().hasPrefix("utm_") && !tracking.contains(item.name.lowercased()) }
        if parts.queryItems?.isEmpty == true { parts.queryItems = nil }
        return parts.string
    }

    /// A strong password from letters, digits and symbols, with no look-alike characters.
    public static func password(length: Int = 20, symbols: Bool = true) -> String {
        let letters = Array("abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"), digits = Array("23456789"), marks = Array("!@#$%^&*-_=+?")
        let pool = letters + digits + (symbols ? marks : [])
        var chars = (0..<max(length, 8)).map { _ in pool.randomElement()! }
        chars[0] = letters.randomElement()!
        chars[1] = digits.randomElement()!
        if symbols { chars[2] = marks.randomElement()! }
        return String(chars.shuffled())
    }

    public enum Case: String, CaseIterable, Sendable {
        case upper = "UPPER", lower = "lower", title = "Title Case", sentence = "Sentence case", camel = "camelCase", snake = "snake_case", kebab = "kebab-case"
    }

    public static func convert(_ text: String, to style: Case) -> String {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        switch style {
        case .upper: return text.uppercased()
        case .lower: return text.lowercased()
        case .title: return text.capitalized
        case .sentence:
            let lower = text.lowercased()
            return lower.prefix(1).uppercased() + lower.dropFirst()
        case .camel:
            var out = ""
            for (i, word) in words.enumerated() { out += i == 0 ? word.lowercased() : word.capitalized }
            return out
        case .snake: return words.map { $0.lowercased() }.joined(separator: "_")
        case .kebab: return words.map { $0.lowercased() }.joined(separator: "-")
        }
    }
}

/// Batch rename: a new name for each file from a pattern. {name} the old name, {n} a running number,
/// {date} the file's date (yyyy-MM-dd); plus find and replace.
public enum BatchRename {
    public static func names(_ files: [(name: String, ext: String, date: Date)], pattern: String, find: String = "", replace: String = "",
                             start: Int = 1, calendar: Calendar = .current) -> [String] {
        let width = String(start + files.count - 1).count
        var result: [String] = []
        for (index, file) in files.enumerated() {
            var base = file.name
            if !find.isEmpty { base = base.replacingOccurrences(of: find, with: replace) }
            let c = calendar.dateComponents([.year, .month, .day], from: file.date)
            let date = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
            let number = String(format: "%0\(width)d", start + index)
            var out = base
            if !pattern.isEmpty {
                out = pattern.replacingOccurrences(of: "{name}", with: base)
                out = out.replacingOccurrences(of: "{n}", with: number)
                out = out.replacingOccurrences(of: "{date}", with: date)
            }
            out = out.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            result.append(file.ext.isEmpty ? out : "\(out).\(file.ext)")
        }
        return result
    }

    /// The same name twice gets " 2", " 3" so nothing is overwritten.
    public static func unique(_ names: [String]) -> [String] {
        var seen: [String: Int] = [:]
        var result: [String] = []
        for name in names {
            let key = name.lowercased()
            let count = seen[key, default: 0]
            seen[key] = count + 1
            if count == 0 { result.append(name); continue }
            let ext = (name as NSString).pathExtension, base = (name as NSString).deletingPathExtension
            result.append(ext.isEmpty ? "\(base) \(count + 1)" : "\(base) \(count + 1).\(ext)")
        }
        return result
    }
}

/// Screenshot Names: a short, readable name from the text found in a screenshot.
public enum ScreenshotName {
    static let noise: Set<String> = ["file", "edit", "view", "window", "help", "go", "history", "bookmarks", "format", "tools"]

    static func isCandidate(_ line: String) -> Bool {
        let words = line.split(separator: " ")
        guard line.count >= 4, words.count >= 2 || line.count >= 8 else { return false }
        if words.allSatisfy({ noise.contains($0.lowercased()) }) { return false }
        if line.range(of: #"^\d{1,2}[:.]\d{2}"#, options: .regularExpression) != nil { return false }
        let letters = line.filter(\.isLetter).count
        return Double(letters) / Double(line.count) > 0.6
    }

    /// The most telling line (a title-like line near the top, not a clock or a menu), cut to six words.
    public static func suggest(from lines: [String]) -> String? {
        let trimmed = lines.prefix(12).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard var best = trimmed.first(where: isCandidate) else { return nil }
        // A title before a separator ("Dashboard: battery and more") is the name.
        for separator in [": ", " | ", " — ", " - "] {
            if let range = best.range(of: separator), best[..<range.lowerBound].split(separator: " ").count >= 2 {
                best = String(best[..<range.lowerBound])
                break
            }
        }
        let words = best.split(whereSeparator: { $0 == " " || $0 == "/" || $0 == ":" || $0 == "|" }).prefix(6)
        let name = words.joined(separator: " ").trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        return name.isEmpty ? nil : String(name.prefix(60))
    }
}
