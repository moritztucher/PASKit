//
//  URLRequestCURLTests.swift
//  PASKitCoreTests
//

import Foundation
import Testing
@testable import PASKitCore

@Suite("URLRequest+cURL")
struct URLRequestCURLTests {

    private func request(_ urlString: String) -> URLRequest {
        URLRequest(url: URL(string: urlString)!)
    }

    @Test("A bare GET renders without an explicit method")
    func bareGet() {
        let out = request("https://api.example.com/v1/items").cURL()
        #expect(out == "curl 'https://api.example.com/v1/items'")
    }

    @Test("A non-GET method is emitted with -X")
    func methodEmitted() {
        var req = request("https://x.com")
        req.httpMethod = "POST"
        #expect(req.cURL().contains("-X POST"))
    }

    @Test("Headers are emitted in alphabetical order")
    func headersSorted() {
        var req = request("https://x.com")
        req.setValue("a", forHTTPHeaderField: "Z-Header")
        req.setValue("b", forHTTPHeaderField: "A-Header")
        let out = req.cURL()
        let aIndex = out.range(of: "A-Header")!.lowerBound
        let zIndex = out.range(of: "Z-Header")!.lowerBound
        #expect(aIndex < zIndex)
    }

    @Test("Single quotes in the body are escaped for shell safety")
    func bodyQuotesEscaped() {
        var req = request("https://x.com")
        req.httpMethod = "POST"
        req.httpBody = Data(#"{"q":"it's"}"#.utf8)
        let out = req.cURL()
        #expect(out.contains("-d '"))
        #expect(out.contains(#"'\''"#))
    }

    @Test("pretty mode breaks options onto continuation lines")
    func prettyContinuations() {
        var req = request("https://x.com")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        #expect(req.cURL(pretty: true).contains(" \\\n  "))
    }
}
