//
//  Reachability.swift
//  PASKitCore
//
//  Network-state observer contract — drives offline UI and lets callers pause
//  refreshes. `Reachability` is the protocol; `NWReachability` is the
//  implementation; `NetworkStatus` is the observed value.
//

import Foundation
import Observation

@MainActor
public protocol Reachability: AnyObject, Observable {
    var status: NetworkStatus { get }
    func start()
    func stop()
}
