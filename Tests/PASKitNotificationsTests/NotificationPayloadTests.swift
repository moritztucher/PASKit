import XCTest
@testable import PASKitNotifications

final class NotificationPayloadTests: XCTestCase {

    func test_stringPairs_mixedValues_dropsNonStrings() {
        let sut = PASNotificationPayload.stringPairs(in: ["destination": "path", "count": 3, 7: "x"])

        XCTAssertEqual(sut, ["destination": "path"])
    }

    func test_routingKeys_registeredUnwrapper_mergesNestedKeysTopLevelWins() {
        PASNotificationPayload.registerUnwrapper { userInfo in
            guard let nested = userInfo["envelope"] as? [AnyHashable: Any] else { return [:] }
            return PASNotificationPayload.stringPairs(in: nested)
        }
        let userInfo: [AnyHashable: Any] = [
            "destination": "top",
            "envelope": ["destination": "nested", "lesson": "u1"],
        ]

        let sut = PASNotificationPayload.routingKeys(from: userInfo)

        XCTAssertEqual(sut, ["destination": "top", "lesson": "u1"])
    }
}
