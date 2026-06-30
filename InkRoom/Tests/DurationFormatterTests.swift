import XCTest
@testable import InkRoom

final class DurationFormatterTests: XCTestCase {

    // MARK: - Minutes Text Tests

    func testMinutesTextLessThan60() {
        XCTAssertEqual(DurationFormatter.minutesText(0), "0分钟")
        XCTAssertEqual(DurationFormatter.minutesText(1), "1分钟")
        XCTAssertEqual(DurationFormatter.minutesText(30), "30分钟")
        XCTAssertEqual(DurationFormatter.minutesText(59), "59分钟")
    }

    func testMinutesTextExactly60() {
        XCTAssertEqual(DurationFormatter.minutesText(60), "1小时")
    }

    func testMinutesTextWithMinutes() {
        XCTAssertEqual(DurationFormatter.minutesText(61), "1小时1分")
        XCTAssertEqual(DurationFormatter.minutesText(90), "1小时30分")
        XCTAssertEqual(DurationFormatter.minutesText(125), "2小时5分")
    }

    func testMinutesTextExactHours() {
        XCTAssertEqual(DurationFormatter.minutesText(120), "2小时")
        XCTAssertEqual(DurationFormatter.minutesText(180), "3小时")
    }

    // MARK: - Seconds Text Tests

    func testSecondsText() {
        XCTAssertEqual(DurationFormatter.secondsText(0), "0分钟")
        XCTAssertEqual(DurationFormatter.secondsText(60), "1分钟")
        XCTAssertEqual(DurationFormatter.secondsText(3600), "1小时")
        XCTAssertEqual(DurationFormatter.secondsText(3660), "1小时1分")
    }

    // MARK: - Relative Text Tests

    func testRelativeTextJustNow() {
        let date = Date()
        XCTAssertEqual(DurationFormatter.relativeText(from: date), "刚刚")
    }

    func testRelativeTextMinutesAgo() {
        let date = Date().addingTimeInterval(-5 * 60) // 5 minutes ago
        XCTAssertEqual(DurationFormatter.relativeText(from: date), "5分钟前")
    }

    func testRelativeTextHoursAgo() {
        let date = Date().addingTimeInterval(-2 * 3600) // 2 hours ago
        XCTAssertEqual(DurationFormatter.relativeText(from: date), "2小时前")
    }

    func testRelativeTextDaysAgo() {
        let date = Date().addingTimeInterval(-3 * 86400) // 3 days ago
        XCTAssertEqual(DurationFormatter.relativeText(from: date), "3天前")
    }

    func testRelativeTextWeeksAgo() {
        let date = Date().addingTimeInterval(-10 * 86400) // 10 days ago
        // Should return formatted date (MM-dd)
        let result = DurationFormatter.relativeText(from: date)
        XCTAssertTrue(result.contains("-"))
    }
}
