import XCTest
@testable import PASKitCrash

final class PASCrashTests: XCTestCase {

    private struct SampleError: Error {}

    func test_config_defaults_matchBrief() {
        let sut = PASCrashConfig(dsn: "https://k@example.ingest.de.sentry.io/1")

        XCTAssertEqual(sut.environment, "production")
        XCTAssertNil(sut.releaseName)
        XCTAssertEqual(sut.tracesSampleRate, 0)
        XCTAssertFalse(sut.debug)
    }

    func test_makeOptions_privacyFloor_isEnforced() {
        let sut = PASCrash.makeOptions(PASCrashConfig(dsn: "https://k@example.ingest.de.sentry.io/1"))

        XCTAssertFalse(sut.sendDefaultPii)
        XCTAssertFalse(sut.enableNetworkBreadcrumbs)
        XCTAssertFalse(sut.enableCaptureFailedRequests)
        XCTAssertFalse(sut.enableLogs)
        #if os(iOS)
        XCTAssertFalse(sut.attachScreenshot)
        XCTAssertFalse(sut.attachViewHierarchy)
        XCTAssertFalse(sut.enableUserInteractionTracing)
        XCTAssertEqual(sut.sessionReplay.sessionSampleRate, 0)
        XCTAssertEqual(sut.sessionReplay.onErrorSampleRate, 0)
        #endif
    }

    func test_makeOptions_configValues_arePassedThrough() {
        let config = PASCrashConfig(
            dsn: "https://k@example.ingest.de.sentry.io/1",
            environment: "staging",
            releaseName: "app@1.0+1",
            debug: true
        )

        let sut = PASCrash.makeOptions(config)

        XCTAssertEqual(sut.dsn, config.dsn)
        XCTAssertEqual(sut.environment, "staging")
        XCTAssertEqual(sut.releaseName, "app@1.0+1")
        XCTAssertTrue(sut.debug)
    }

    func test_makeOptions_zeroTracesSampleRate_leavesTracingOff() {
        let sut = PASCrash.makeOptions(PASCrashConfig(dsn: "https://k@example.ingest.de.sentry.io/1"))

        XCTAssertNil(sut.tracesSampleRate)
    }

    func test_makeOptions_positiveTracesSampleRate_isApplied() {
        let config = PASCrashConfig(dsn: "https://k@example.ingest.de.sentry.io/1", tracesSampleRate: 0.25)

        let sut = PASCrash.makeOptions(config)

        XCTAssertEqual(sut.tracesSampleRate?.doubleValue, 0.25)
    }

    func test_makeOptions_nilReleaseName_leavesSDKDefault() {
        let defaultRelease = PASCrash.makeOptions(PASCrashConfig(dsn: "https://k@example.ingest.de.sentry.io/1")).releaseName
        let sut = PASCrash.makeOptions(PASCrashConfig(dsn: "https://k@example.ingest.de.sentry.io/1", releaseName: nil))

        XCTAssertEqual(sut.releaseName, defaultRelease)
    }

    func test_capture_whenNotRunning_isNoOp() {
        let sut = PASCrash.shared

        sut.capture(error: SampleError(), context: ["k": "v"])
        sut.capture(message: "m", level: .fatal)
        sut.addBreadcrumb("b", category: "c", data: ["k": "v"])
        sut.setTag("v", forKey: "k")

        XCTAssertFalse(sut.isRunning)
    }
}
