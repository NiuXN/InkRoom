import XCTest
@testable import InkRoom

final class AppVersionTests: XCTestCase {

    // MARK: - Version Comparison Tests

    func testIsVersionNewerThan() {
        XCTAssertTrue(AppVersion.isVersion("1.0.1", newerThan: "1.0.0"))
        XCTAssertTrue(AppVersion.isVersion("1.1.0", newerThan: "1.0.0"))
        XCTAssertTrue(AppVersion.isVersion("2.0.0", newerThan: "1.9.9"))
        XCTAssertTrue(AppVersion.isVersion("1.0.0.1", newerThan: "1.0.0"))
    }

    func testIsVersionNotNewerThan() {
        XCTAssertFalse(AppVersion.isVersion("1.0.0", newerThan: "1.0.0"))
        XCTAssertFalse(AppVersion.isVersion("1.0.0", newerThan: "1.0.1"))
        XCTAssertFalse(AppVersion.isVersion("0.9.9", newerThan: "1.0.0"))
    }

    func testVersionComparisonWithDifferentLengths() {
        XCTAssertTrue(AppVersion.isVersion("1.0.0.1", newerThan: "1.0.0"))
        XCTAssertTrue(AppVersion.isVersion("1.0.1", newerThan: "1.0.0.0"))
    }

    func testVersionComparisonWithNonNumericParts() {
        // Non-numeric parts should be treated as 0
        XCTAssertTrue(AppVersion.isVersion("1.0.0", newerThan: "1.0.beta"))
        XCTAssertFalse(AppVersion.isVersion("1.0.beta", newerThan: "1.0.0"))
    }
}
