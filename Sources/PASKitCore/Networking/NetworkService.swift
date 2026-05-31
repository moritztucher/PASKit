//
//  NetworkService.swift
//  PASKitCore
//
//  The single networking seam. Callers build `URLRequest`s and call `send`;
//  they never touch `URLSession` directly, so retry, logging, and test doubles
//  all have one home.
//

import Foundation

public protocol NetworkService: Sendable {
    /// Send a request and decode the response body as `T`. Throws
    /// `PASError.requestFailed` for non-2xx, `PASError.decodingFailed` on a
    /// decode failure, `PASError.networkUnreachable` when offline.
    func send<T: Decodable & Sendable>(
        _ request: URLRequest,
        as: T.Type,
        decoder: JSONDecoder
    ) async throws -> T
}

public extension NetworkService {
    func send<T: Decodable & Sendable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        try await send(request, as: type, decoder: JSONDecoder())
    }
}
