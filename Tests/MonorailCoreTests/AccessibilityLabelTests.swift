import Foundation
import XCTest

/// VoiceOver reads a button by its label: a button that only shows an icon needs one, or it's read
/// as just "button". This scans the app's SwiftUI for icon-only buttons without a label.
final class AccessibilityLabelTests: XCTestCase {
    func testIconOnlyButtonsHaveAccessibilityLabels() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../Sources/Monorail").standardizedFileURL
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        var missing: [String] = []
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains("Image(systemName:") && !line.contains("accessibilityLabel") {
                guard !line.contains("Label(") && !line.contains("Text(") else { continue }
                let oneLine = line.contains("Button") && line.range(of: #"\{\s*Image\(systemName:"#, options: .regularExpression) != nil
                let previous = index > 0 ? lines[index - 1] : ""
                let labelBlock = previous.trimmingCharacters(in: .whitespaces).hasSuffix("label: {")
                    && line.trimmingCharacters(in: .whitespaces).hasPrefix("Image(")
                let next = lines[index..<min(index + 3, lines.count)].joined()
                if (oneLine || labelBlock) && !next.contains("accessibilityLabel") {
                    missing.append("\(file.lastPathComponent):\(index + 1)")
                }
            }
        }
        XCTAssertEqual(missing, [], "icon-only buttons without .accessibilityLabel")
    }
}
