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

    @Test func verifiedAndUnverifiedBothYieldTheirEnvironment() {
        #expect(PASDistribution.environment(of: .verified(.production)) == .production)
        #expect(PASDistribution.environment(of: .unverified(.production)) == .production)
        #expect(PASDistribution.environment(of: .unverified(.sandbox)) == .sandbox)
        #expect(PASDistribution.classify(PASDistribution.environment(of: .unverified(.xcode))) == .development)
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

    private let build = "1.0 (1)"

    private var storedHint: String? {
        AppInfo.storedDistribution(in: defaults, buildIdentifier: build)?.rawValue
    }

    private func makeSUT() -> DistributionResolver {
        DistributionResolver(defaultsSuiteName: suiteName, buildIdentifier: build, debugBuild: false)
    }

    @Test func sandboxProbeResolvesTestFlightAndPersistsHint() async {
        let sut = makeSUT()
        let value = await sut.resolve(timeout: .seconds(5)) { .sandbox }
        #expect(value == .testFlight)
        #expect(storedHint == "testFlight")
    }

    @Test func slowProbeTimesOutAndPersistsNothing() async {
        let sut = makeSUT()
        let value = await sut.resolve(timeout: .milliseconds(50)) {
            try await Task.sleep(for: .seconds(10))
            return .production
        }
        #expect(value == .unknown)
        #expect(storedHint == nil)
    }

    @Test func throwingProbeIsUnknownInRelease() async {
        struct ProbeError: Error {}
        let sut = makeSUT()
        let value = await sut.resolve(timeout: .seconds(5)) { throw ProbeError() }
        #expect(value == .unknown)
        #expect(storedHint == nil)
    }

    @Test func successfulResolutionIsMemoised() async {
        let counter = ProbeCounter()
        let sut = makeSUT()
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

    @Test func nonCancellableProbeStillTimesOut() async {
        let sut = makeSUT()
        let clock = ContinuousClock()
        let start = clock.now
        // Never resumes and ignores cancellation, like a stuck StoreKit call.
        let value = await sut.resolve(timeout: .milliseconds(100)) {
            await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
            return .production
        }
        #expect(value == .unknown)
        #expect(clock.now - start < .seconds(2))
    }

    @Test func concurrentCallersShareOneProbe() async {
        let counter = ProbeCounter()
        let sut = makeSUT()
        let probe: DistributionResolver.Probe = {
            await counter.increment()
            try await Task.sleep(for: .milliseconds(100))
            return .sandbox
        }
        async let first = sut.resolve(timeout: .seconds(5), probe: probe)
        async let second = sut.resolve(timeout: .seconds(5), probe: probe)
        let results = await [first, second]
        #expect(results == [.testFlight, .testFlight])
        #expect(await counter.calls == 1)
    }

    @Test func downgradeSequenceKeepsLastKnownHint() async {
        struct ProbeError: Error {}
        #expect(await makeSUT().resolve(timeout: .seconds(5)) { .production } == .appStore)
        #expect(storedHint == "appStore")
        #expect(await makeSUT().resolve(timeout: .seconds(5)) { .sandbox } == .testFlight)
        #expect(storedHint == "testFlight")
        #expect(await makeSUT().resolve(timeout: .seconds(5)) { throw ProbeError() } == .unknown)
        #expect(storedHint == "testFlight")
    }

    @Test func hintIsBoundToTheBuild() async {
        #expect(await makeSUT().resolve(timeout: .seconds(5)) { .production } == .appStore)
        #expect(AppInfo.storedDistribution(in: defaults, buildIdentifier: build) == .appStore)
        #expect(AppInfo.storedDistribution(in: defaults, buildIdentifier: "1.0 (2)") == nil)
        #expect(AppInfo.storedDistribution(in: defaults, buildIdentifier: "1.1 (1)") == nil)
    }

    @Test func unknownResultIsNotCached() async {
        struct ProbeError: Error {}
        let counter = ProbeCounter()
        let sut = makeSUT()
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
