//
//  NWReachability.swift
//  PASKitCore
//
//  `Reachability` backed by `NWPathMonitor`. Owns a background queue for path
//  callbacks and hops state updates onto the main actor so `@Observable`
//  consumers always read on main.
//

import Foundation
import Network
import os

@MainActor
@Observable
public final class NWReachability: Reachability {
    public private(set) var status: NetworkStatus = .unknown

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private let log: Logger
    private var isStarted = false

    public init() {
        self.monitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "\(PASLogger.subsystem).reachability", qos: .utility)
        self.log = PASLogger.make(category: "reachability")
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            let next: NetworkStatus = path.status == .satisfied ? .online : .offline
            Task { @MainActor [weak self] in
                self?.apply(next)
            }
        }
        monitor.start(queue: queue)
        log.info("reachability started")
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        monitor.cancel()
        log.info("reachability stopped")
    }

    private func apply(_ next: NetworkStatus) {
        guard status != next else { return }
        status = next
        log.info("network status changed to \(String(describing: next), privacy: .public)")
    }
}
