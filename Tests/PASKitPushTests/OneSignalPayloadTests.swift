import XCTest
@testable import PASKitPush

final class OneSignalPayloadTests: XCTestCase {

    func test_routingKeys_oneSignalPayload_returnsAdditionalDataStrings() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Hi"],
            "custom": ["i": "notification-uuid", "a": ["destination": "path", "count": 3]],
        ]

        let sut = OneSignalPayload.routingKeys(from: userInfo)

        XCTAssertEqual(sut, ["destination": "path"])
    }

    func test_routingKeys_nonOneSignalPayload_returnsEmpty() {
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": "Hi"], "destination": "path"]

        let sut = OneSignalPayload.routingKeys(from: userInfo)

        XCTAssertTrue(sut.isEmpty)
    }

    func test_routingKeys_customWithoutAdditionalData_returnsEmpty() {
        let userInfo: [AnyHashable: Any] = ["custom": ["i": "notification-uuid"]]

        let sut = OneSignalPayload.routingKeys(from: userInfo)

        XCTAssertTrue(sut.isEmpty)
    }
}
