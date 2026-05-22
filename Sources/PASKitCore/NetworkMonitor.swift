//
//  NetworkMonitor.swift
//  PASKitCore
//
//  Observes device internet connectivity.
//

import Foundation
import Network
import Observation

/// Observes the device's internet connectivity.
///
/// SwiftUI views observe ``isConnected`` and ``connectionType`` directly — the
/// type is `@Observable`. Callers outside SwiftUI can consume ``connectivity()``
/// as an `AsyncStream<Bool>`.
@MainActor
@Observable
public final class NetworkMonitor {

    /// The active network interface type.
    public enum ConnectionType: Sendable {
        case wifi
        case cellular
        case ethernet
        case other
    }

    /// Whether the device currently has a satisfied network path.
    public private(set) var isConnected: Bool

    /// The current connection's interface type. Only meaningful while
    /// ``isConnected`` is `true`.
    public private(set) var connectionType: ConnectionType

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "studio.pocketapps.paskit.network-monitor")
    private var isMonitoring = false
    private var observers: [UUID: AsyncStream<Bool>.Continuation] = [:]

    /// Creates a monitor, seeds it from the current network path, and starts monitoring.
    public init() {
        let path = monitor.currentPath
        isConnected = path.status == .satisfied
        connectionType = Self.connectionType(for: path)
        start()
    }

    deinit {
        monitor.cancel()
    }

    /// Starts path monitoring. Safe to call repeatedly — a no-op once running.
    public func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitor.pathUpdateHandler = { [weak self] path in
            // Runs on `queue`. Reduce to Sendable values before crossing to the main actor.
            let connected = path.status == .satisfied
            let type = NetworkMonitor.connectionType(for: path)
            Task { @MainActor in
                self?.apply(connected: connected, type: type)
            }
        }
        monitor.start(queue: queue)
    }

    /// Stops path monitoring and finishes any active connectivity streams.
    public func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor.cancel()
        for continuation in observers.values { continuation.finish() }
        observers.removeAll()
    }

    /// Connectivity changes as an `AsyncStream`, for callers outside SwiftUI.
    /// Yields the current value immediately, then on every change.
    public func connectivity() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            observers[id] = continuation
            continuation.yield(isConnected)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.observers.removeValue(forKey: id) }
            }
        }
    }

    private func apply(connected: Bool, type: ConnectionType) {
        connectionType = type
        guard connected != isConnected else { return }
        isConnected = connected
        for continuation in observers.values { continuation.yield(connected) }
    }

    private nonisolated static func connectionType(for path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .other
    }
}
