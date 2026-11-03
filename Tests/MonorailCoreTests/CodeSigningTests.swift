import MonorailCore
import XCTest

final class CodeSigningTests: XCTestCase {
    func testDeveloperIDRequirementPinsTheTeamAndIdentifiers() {
        let req = CodeSigning.developerIDRequirement(identifiers: ["org.ashforde.monorail", "org.ashforde.macslider"])
        XCTAssertTrue(req.hasPrefix("(identifier \"org.ashforde.monorail\" or identifier \"org.ashforde.macslider\") and anchor apple generic"))
        XCTAssertTrue(req.contains("certificate leaf[subject.OU] = \"D69G45342Y\""))
        XCTAssertTrue(req.contains("1.2.840.113635.100.6.1.13"), "the Developer ID Application marker")
    }

    func testUpdatesAcceptTheOldCertificateOrTheDeveloperID() {
        let old = "identifier \"org.ashforde.monorail\" and certificate leaf = H\"abc\""
        let req = CodeSigning.updateRequirement(running: old, identifiers: ["org.ashforde.monorail"])
        XCTAssertTrue(req.hasPrefix("(\(old)) or ("))
        XCTAssertEqual(CodeSigning.teamID.count, 10)
    }
}
