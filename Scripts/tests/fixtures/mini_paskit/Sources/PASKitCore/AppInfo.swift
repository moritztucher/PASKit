import Foundation

/// Mentions `public struct Fake` in a doc comment — must not be extracted.
// public struct Fake {}
public struct AppInfo {
    public static let version: String = "1.0"
    public static let build: String = "1"
    private static let secret: String = "not extracted"
}

struct InternalHelper {
    // No access keyword -> internal by default -> must not be extracted.
    func helperMethod() {}
}

let stringWithBrace = "this has a { brace and a // fake comment inside a string"
