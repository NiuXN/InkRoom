import XCTest
@testable import InkRoom

final class ScrollReadingPositionTests: XCTestCase {

    // MARK: - Test Data

    private func makeChapters() -> [Chapter] {
        [
            Chapter(title: "Chapter 1", startPage: 1, endPage: 25),
            Chapter(title: "Chapter 2", startPage: 26, endPage: 58),
            Chapter(title: "Chapter 3", startPage: 59, endPage: 95),
            Chapter(title: "Chapter 4", startPage: 96, endPage: 145),
            Chapter(title: "Chapter 5", startPage: 146, endPage: 198)
        ]
    }

    // MARK: - Chapter Index Tests

    func testChapterIndexForPageInRange() {
        let chapters = makeChapters()

        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 1, in: chapters), 0)
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 25, in: chapters), 0)
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 26, in: chapters), 1)
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 58, in: chapters), 1)
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 100, in: chapters), 3)
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 198, in: chapters), 4)
    }

    func testChapterIndexForPageBeforeFirst() {
        let chapters = makeChapters()
        // Page 0 is before first chapter, should return 0 (first chapter)
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 0, in: chapters), 0)
    }

    func testChapterIndexForPageAfterLast() {
        let chapters = makeChapters()
        // Page 999 is after last chapter, should return last chapter index
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 999, in: chapters), 4)
    }

    func testChapterIndexWithEmptyChapters() {
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 1, in: []), 0)
    }

    func testChapterIndexWithSingleChapter() {
        let chapters = [Chapter(title: "Only", startPage: 1, endPage: 100)]
        XCTAssertEqual(ScrollReadingPosition.chapterIndex(for: 50, in: chapters), 0)
    }

    // MARK: - Estimate Page Tests

    func testEstimatePageWithEmptyFrames() {
        let chapters = makeChapters()
        XCTAssertNil(ScrollReadingPosition.estimatePage(frames: [:], chapters: chapters))
    }

    func testEstimatePageWithEmptyChapters() {
        let frames: [Int: CGRect] = [0: CGRect(x: 0, y: 0, width: 100, height: 500)]
        XCTAssertNil(ScrollReadingPosition.estimatePage(frames: frames, chapters: []))
    }

    func testEstimatePageAtChapterStart() {
        let chapters = makeChapters()
        let frames: [Int: CGRect] = [
            0: CGRect(x: 0, y: 0, width: 100, height: 500),
            1: CGRect(x: 0, y: 500, width: 100, height: 500),
            2: CGRect(x: 0, y: 1000, width: 100, height: 500)
        ]

        // Anchor at top of chapter 1 (y=500)
        let page = ScrollReadingPosition.estimatePage(frames: frames, chapters: chapters, anchorY: 500)
        XCTAssertNotNil(page)
        XCTAssertEqual(page, 26) // Start of chapter 2
    }

    func testEstimatePageInMiddleOfChapter() {
        let chapters = makeChapters()
        let frames: [Int: CGRect] = [
            0: CGRect(x: 0, y: 0, width: 100, height: 1000),
            1: CGRect(x: 0, y: 1000, width: 100, height: 1000)
        ]

        // Anchor at middle of chapter 1 (y=1500)
        let page = ScrollReadingPosition.estimatePage(frames: frames, chapters: chapters, anchorY: 1500)
        XCTAssertNotNil(page)
        // Should be in the middle of chapter 2 (pages 26-58)
        XCTAssertTrue(page! >= 26 && page! <= 58)
    }

    func testEstimatePageWithZeroHeightFrame() {
        let chapters = makeChapters()
        let frames: [Int: CGRect] = [
            0: CGRect(x: 0, y: 0, width: 100, height: 0)
        ]

        let page = ScrollReadingPosition.estimatePage(frames: frames, chapters: chapters, anchorY: 0)
        XCTAssertEqual(page, 1) // Should return chapter start page
    }

    // MARK: - Binary Search Performance Tests

    func testBinarySearchPerformance() {
        // Create 1000 chapters
        var chapters: [Chapter] = []
        var page = 1
        for i in 0..<1000 {
            let pages = 10
            chapters.append(Chapter(title: "Chapter \(i)", startPage: page, endPage: page + pages - 1))
            page += pages
        }

        measure {
            for _ in 0..<1000 {
                _ = ScrollReadingPosition.chapterIndex(for: Int.random(in: 1...10000), in: chapters)
            }
        }
    }
}
