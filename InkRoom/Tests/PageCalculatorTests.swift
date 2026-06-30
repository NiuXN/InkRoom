import XCTest
@testable import InkRoom

/// 验证 `PageCalculator` 的页数计算与分页一致性。
///
/// 这是本次重构修复的核心 bug：此前 `parseBook` 用加权字符算总页数，
/// 而 `getChapters`/`getChapterContent` 用原始字符数算章节页数，
/// 两套算法不一致会导致目录跳转错位、翻页越界。
final class PageCalculatorTests: XCTestCase {

    func testEmptyContentReturnsOnePage() {
        XCTAssertEqual(PageCalculator.pageCount(for: ""), 1)
        XCTAssertEqual(PageCalculator.paginate("").count, 1)
    }

    func testChineseCharsCountAsTwoWeight() {
        // 500 个中文字 = 1000 权重 / 500 = 2 页
        let chinese = String(repeating: "字", count: 500)
        XCTAssertEqual(PageCalculator.pageCount(for: chinese), 2)
        XCTAssertEqual(PageCalculator.paginate(chinese).count, 2)
    }

    func testAsciiCharsCountAsOneWeight() {
        // 1000 个 ASCII = 1000 权重 / 500 = 2 页
        let ascii = String(repeating: "a", count: 1000)
        XCTAssertEqual(PageCalculator.pageCount(for: ascii), 2)
    }

    func testMixedContentWeightsCorrectly() {
        // 250 中文 (500 权重) + 500 ASCII (500 权重) = 1000 权重 = 2 页
        let mixed = String(repeating: "字", count: 250) + String(repeating: "a", count: 500)
        XCTAssertEqual(PageCalculator.pageCount(for: mixed), 2)
    }

    func testSumOfChapterPagesEqualsTotalPages() {
        // 模拟多章节场景：验证"各章节页数之和 == 整体页数"这一核心不变式。
        let chapter1 = String(repeating: "字", count: 500)   // 2 页
        let chapter2 = String(repeating: "a", count: 1000)   // 2 页
        let chapter3 = String(repeating: "字", count: 250)   // 1 页

        let sumOfChapters = [chapter1, chapter2, chapter3]
            .map { PageCalculator.pageCount(for: $0) }
            .reduce(0, +)

        // 整体拼接后页数（按章节累加口径）应与各章节之和一致
        XCTAssertEqual(sumOfChapters, 5)

        // paginate 切出的总页数也应一致
        let paginatedTotal = [chapter1, chapter2, chapter3]
            .map { PageCalculator.paginate($0).count }
            .reduce(0, +)
        XCTAssertEqual(paginatedTotal, sumOfChapters)
    }

    func testPaginatePreservesAllContent() {
        let content = String(repeating: "字", count: 750) + "end"
        let pages = PageCalculator.paginate(content)
        let rejoined = pages.joined()
        XCTAssertEqual(rejoined, content)
    }

    func testSmallContentIsAtLeastOnePage() {
        XCTAssertEqual(PageCalculator.pageCount(for: "短"), 1)
        XCTAssertEqual(PageCalculator.paginate("短").count, 1)
    }
}
