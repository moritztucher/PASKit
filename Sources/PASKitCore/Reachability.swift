//
//  Reachability.swift
//  PASKitCore
//
//  Network-state observer — drives offline UI and lets callers pause refreshes.
//  `Reachability` is the contract; `NWReachability` is the implementation.
//

import Foundation
import Observation

public enum NetworkStatus: Sendable, Equatable {
    case unknown
    case online
    case offline
}

@MainActor
public protocol Reachability: AnyObject, Observable {
    var status: NetworkStatus { get }
    func start()
    func stop()
}
