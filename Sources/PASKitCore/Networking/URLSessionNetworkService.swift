//
//  URLSessionNetworkService.swift
//  PASKitCore
//
//  Default `URLSession`-backed `NetworkService` implementation.
//

import Foundation

/// Default `URLSession`-backed implementation. Inject this — or a mock
/// conforming to `NetworkService` — into types that make requests.
public struct URLSessionNetworkService: NetworkService {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send<T: Decodable & Sendable>(
        _ request: URLRequest,
        as type: T.Type,
        decoder: JSONDecoder
    ) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet {
            throw PASError.networkUnreachable
        } catch is CancellationError {
            throw PASError.cancelled
        } catch {
            throw PASError.unexpected(description: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw PASError.unexpected(description: "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            if http.statusCode == 429 {
                let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                throw PASError.rateLimited(retryAfter: retry)
            }
            throw PASError.requestFailed(statusCode: http.statusCode, body: body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PASError.decodingFailed(description: String(describing: error))
        }
    }
}
