//
//  DistributionTests.swift
//  PASKitCoreTests
//
//  PASDistribution's StoreKit-environment mapping, the analytics-value
//  contract, and DistributionResolver's timeout / memoisation / hint
//  persistence. The StoreKit probe is injected, so nothing here touches
//  AppTransaction and the suite runs on the macOS host.
//

import Foundation
import StoreKit
import Testing
@testable import PASKitCore

/// Thread-safe call counter for injected probes.
private actor ProbeCounter {
    private(set) var calls = 0
    func increment() { calls += 1 }
}

@Suite("PASDistribution")
struct DistributionClassifyTests {

    @Test func productionMapsToAppStore() {
        #expect(PASDistribution.classify(.production) == .appStore)
    }

    @Test func sandboxMapsToTestFlight() {
        #expect(PASDistribution.classify(.sandbox) == .testFlight)
    }

    @Test func xcodeMapsToDevelopment() {
        #expect(PASDistribution.classify(.xcode) == .development)
    }

    @Test func missingEnvironmentMatchesBuildConfiguration() {
        #if DEBUG
        #expect(PASDistribution.classify(nil) == .development)
        #else
        #expect(PASDistribution.classify(nil) == .unknown)
        #endif
    }

    @Test func missingEnvironmentInReleaseIsUnknown() {
        #expect(PASDistribution.classify(nil, debugBuild: false) == .unknown)
        #expect(PASDistribution.classify(nil, debugBuild: true) == .development)
    }

    @Test func unrecognisedEnvironmentFailsClosedInRelease() {
        #expect(PASDistribution.classify(AppStore.Environment(rawValue: "Future"), debugBuild: false) == .unknown)
    }

    @Test func onlyAppStoreIsAppStore() {
        #expect(PASDistribution.allCases.filter(\.isAppStore) == [.appStore])
    }

    @Test func analyticsValuesAreTheFilterContract() {
        #expect(PASDistribution.appStore.analyticsValue == "appstore")
        #expect(PASDistribution.testFlight.analyticsValue == "testflight")
        #expect(PASDistribution.development.analyticsValue == "development")
        #expect(PASDistribution.unknown.analyticsValue == "unknown")
    }

    @Test func codableRoundTrips() throws {
        for value in PASDistribution.allCases {
            let data = try JSONEncoder().encode(value)
            #expect(try JSONDecoder().decode(PASDistribution.self, from: data) == value)
            #expect(PASDistribution(rawValue: value.rawValue) == value)
        }
    }
}

@Suite("DistributionResolver")
final class DistributionResolverTests {

    private let suiteName = "PASKitCoreTests.Distribution.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() { defaults = UserDefaults(suiteName: suiteName)! }

    deinit { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

    private var storedHint: String? { defaults.string(forKey: AppInfo.distributionDefaultsKey) }

    @Test func sandboxProbeResolvesTestFlightAndPersistsHint() async {
        let sut = DistributionResolver(defaultsSuiteName: suiteName, debugBuild: false)
        let value = await sut.resolve(timeout: .seconds(5)) { .sandbox }
        #expect(value == .testFlight)
        #expect(storedHint == "testFlight")
    }

    @Test func slowProbeTimesOutAndPersistsNothing() async {
        let sut = DistributionResolver(defaultsSuiteName: suiteName, debugBuild: false)
        let value = await sut.resolve(timeout: .milliseconds(50)) {
            try await Task.sleep(for: .seconds(10))
            return .production
        }
        #expect(value == .unknown)
        #expect(storedHint == nil)
    }

    @Test func throwingProbeIsUnknownInRelease() async {
        struct ProbeError: Error {}
        let sut = DistributionResolver(defaultsSuiteName: suiteName, debugBuild: false)
        let value = await sut.resolve(timeout: .seconds(5)) { throw ProbeError() }
        #expect(value == .unknown)
        #expect(storedHint == nil)
    }

    @Test func successfulResolutionIsMemoised() async {
        let counter = ProbeCounter()
        let sut = DistributionResolver(defaultsSuiteName: suiteName, debugBuild: false)
        let probe: DistributionResolver.Probe = {
            await counter.increment()
            return .production
        }
        let first = await sut.resolve(timeout: .seconds(5), probe: probe)
        let second = await sut.resolve(timeout: .seconds(5), probe: probe)
        #expect(first == .appStore)
        #expect(second == .appStore)
        #expect(await counter.calls == 1)
    }

    @Test func unknownResultIsNotCached() async {
        struct ProbeError: Error {}
        let counter = ProbeCounter()
        let sut = DistributionResolver(defaultsSuiteName: suiteName, debugBuild: false)
        let failing: DistributionResolver.Probe = {
            await counter.increment()
            throw ProbeError()
        }
        #expect(await sut.resolve(timeout: .seconds(5), probe: failing) == .unknown)
        #expect(await sut.resolve(timeout: .seconds(5)) { .production } == .appStore)
        #expect(await counter.calls == 1)
        #expect(storedHint == "appStore")
    }
}
