/// Who may sign a Monorail update (checked by the updater before it replaces the app).
public enum CodeSigning {
    /// Ashforde OÜ's Apple Developer Team.
    public static let teamID = "D69G45342Y"

    /// Apple's standard requirement for a Developer ID app from `teamID` with one of `identifiers`.
    public static func developerIDRequirement(identifiers: [String], teamID: String = teamID) -> String {
        let ids = identifiers.map { "identifier \"\($0)\"" }.joined(separator: " or ")
        return "(\(ids)) and anchor apple generic"
            + " and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */"
            + " and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */"
            + " and certificate leaf[subject.OU] = \"\(teamID)\""
    }

    /// What an update must satisfy: the running app's own requirement (same certificate), or
    /// Ashforde's Developer ID, so self-signed builds can update to notarised ones once.
    public static func updateRequirement(running designated: String, identifiers: [String]) -> String {
        "(\(designated)) or (\(developerIDRequirement(identifiers: identifiers)))"
    }
}
