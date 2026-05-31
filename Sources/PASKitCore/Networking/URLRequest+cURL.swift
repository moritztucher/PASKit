//
//  URLRequest+cURL.swift
//  PASKitCore
//
//  Render a `URLRequest` as a `curl` command for terminal replay during
//  debugging. Pairs naturally with `PASLogger` — log the cURL form of a
//  failing request and replay it in a terminal to inspect the response.
//

import Foundation

public extension URLRequest {
    /// Render this request as a `curl` command — paste-ready for a terminal.
    ///
    /// Headers are emitted in alphabetical order for deterministic output.
    /// Single quotes in the body are escaped (`'` → `'\''`). `GET` is left
    /// implicit since it's curl's default.
    ///
    /// - Parameter pretty: When `true`, break each option onto its own line
    ///   with `\` continuations. When `false`, render on one line.
    func cURL(pretty: Bool = false) -> String {
        guard let url else { return "" }
        let separator = pretty ? " \\\n  " : " "
        var parts: [String] = ["curl"]

        if let method = httpMethod, method != "GET" {
            parts.append("-X \(method)")
        }

        if let headers = allHTTPHeaderFields {
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                parts.append("-H '\(key): \(value)'")
            }
        }

        if let body = httpBody, let bodyString = String(data: body, encoding: .utf8) {
            let escaped = bodyString.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("-d '\(escaped)'")
        }

        parts.append("'\(url.absoluteString)'")
        return parts.joined(separator: separator)
    }
}
