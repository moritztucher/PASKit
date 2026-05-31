//
//  NetworkStatus.swift
//  PASKitCore
//
//  Tri-state network-reachability classification surfaced by `Reachability`.
//

import Foundation

public enum NetworkStatus: Sendable, Equatable {
    case unknown
    case online
    case offline
}
