import XCTest
@testable import InkRoom

final class BookFilterTests: XCTestCase {

    // MARK: - Test Data

    private func makeBook(
        title: String = "Test",
        author: String = "Author",
        currentPage: Int = 0,
        totalPages: Int = 100,
        lastReadDate: Date? = nil,
        isFavorite: Bool = false,
        addedDaysAgo: Int = 0
    ) -> Book {
        Book(
            title: title,
            author: author,
            totalPages: totalPages,
            currentPage: currentPage,
            lastReadDate: lastReadDate,
            isFavorite: isFavorite,
            addedDate: Date().addingTimeInterval(-Double(addedDaysAgo) * 86400)
        )
    }

    // MARK: - Group Filtering Tests

    func testFilterAllGroup() {
        let books = [
            makeBook(title: "A", currentPage: 0),
            makeBook(title: "B", currentPage: 50),
            makeBook(title: "C", currentPage: 100)
        ]

        let result = BookFilter.filter(books, group: .all, searchText: "")
        XCTAssertEqual(result.count, 3)
    }

    func testFilterReadingGroup() {
        let books = [
            makeBook(title: "Unread", currentPage: 0),
            makeBook(title: "Reading", currentPage: 50),
            makeBook(title: "Completed", currentPage: 100)
        ]

        let result = BookFilter.filter(books, group: .reading, searchText: "")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Reading")
    }

    func testFilterCompletedGroup() {
        let books = [
            makeBook(title: "Unread", currentPage: 0),
            makeBook(title: "Reading", currentPage: 50),
            makeBook(title: "Completed", currentPage: 100)
        ]

        let result = BookFilter.filter(books, group: .completed, searchText: "")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Completed")
    }

    func testFilterFavoritesGroup() {
        let books = [
            makeBook(title: "A", isFavorite: true),
            makeBook(title: "B", isFavorite: false),
            makeBook(title: "C", isFavorite: true)
        ]

        let result = BookFilter.filter(books, group: .favorites, searchText: "")
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Search Tests

    func testSearchByTitle() {
        let books = [
            makeBook(title: "人间草木", author: "汪曾祺"),
            makeBook(title: "围城", author: "钱钟书"),
            makeBook(title: "浮生六记", author: "沈复")
        ]

        let result = BookFilter.filter(books, group: .all, searchText: "围城")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "围城")
    }

    func testSearchByAuthor() {
        let books = [
            makeBook(title: "A", author: "汪曾祺"),
            makeBook(title: "B", author: "钱钟书"),
            makeBook(title: "C", author: "沈复")
        ]

        let result = BookFilter.filter(books, group: .all, searchText: "钱钟书")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.author, "钱钟书")
    }

    func testSearchCaseInsensitive() {
        let books = [
            makeBook(title: "Hello World"),
            makeBook(title: "Goodbye World")
        ]

        let result = BookFilter.filter(books, group: .all, searchText: "hello")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Hello World")
    }

    func testSearchEmpty() {
        let books = [
            makeBook(title: "A"),
            makeBook(title: "B")
        ]

        let result = BookFilter.filter(books, group: .all, searchText: "")
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Sort Tests

    func testSortByTitleAscending() {
        let books = [
            makeBook(title: "Charlie"),
            makeBook(title: "Alpha"),
            makeBook(title: "Bravo")
        ]

        let result = BookFilter.sort(books, by: .title, ascending: true)
        XCTAssertEqual(result.map { $0.title }, ["Alpha", "Bravo", "Charlie"])
    }

    func testSortByTitleDescending() {
        let books = [
            makeBook(title: "Alpha"),
            makeBook(title: "Charlie"),
            makeBook(title: "Bravo")
        ]

        let result = BookFilter.sort(books, by: .title, ascending: false)
        XCTAssertEqual(result.map { $0.title }, ["Charlie", "Bravo", "Alpha"])
    }

    func testSortByRecentReadWithNilDates() {
        // Unread books (nil lastReadDate) should sort to the end
        let books = [
            makeBook(title: "Unread1", lastReadDate: nil),
            makeBook(title: "Read1", lastReadDate: Date().addingTimeInterval(-3600)),
            makeBook(title: "Unread2", lastReadDate: nil),
            makeBook(title: "Read2", lastReadDate: Date().addingTimeInterval(-7200))
        ]

        let result = BookFilter.sort(books, by: .recentRead, ascending: false)
        // Read books should come first (most recent first), then unread
        XCTAssertEqual(result[0].title, "Read1")
        XCTAssertEqual(result[1].title, "Read2")
        // Unread books should be at the end (sorted by distantPast)
        XCTAssertTrue(result[2].title.hasPrefix("Unread"))
        XCTAssertTrue(result[3].title.hasPrefix("Unread"))
    }

    func testSortByProgress() {
        let books = [
            makeBook(title: "A", currentPage: 50, totalPages: 100),
            makeBook(title: "B", currentPage: 25, totalPages: 100),
            makeBook(title: "C", currentPage: 75, totalPages: 100)
        ]

        let result = BookFilter.sort(books, by: .progress, ascending: true)
        XCTAssertEqual(result.map { $0.title }, ["B", "A", "C"])
    }

    // MARK: - Count Tests

    func testCountInGroup() {
        let books = [
            makeBook(title: "A", currentPage: 0),
            makeBook(title: "B", currentPage: 50),
            makeBook(title: "C", currentPage: 100),
            makeBook(title: "D", isFavorite: true)
        ]

        XCTAssertEqual(BookFilter.count(in: books, for: .all), 4)
        XCTAssertEqual(BookFilter.count(in: books, for: .reading), 1)
        XCTAssertEqual(BookFilter.count(in: books, for: .completed), 1)
        XCTAssertEqual(BookFilter.count(in: books, for: .favorites), 1)
    }

    // MARK: - Combined Tests

    func testFilterAndSort() {
        let books = [
            makeBook(title: "Charlie", currentPage: 50),
            makeBook(title: "Alpha", currentPage: 50),
            makeBook(title: "Bravo", currentPage: 50)
        ]

        let result = BookFilter.filter(books, group: .reading, searchText: "", sortBy: .title, ascending: true)
        XCTAssertEqual(result.map { $0.title }, ["Alpha", "Bravo", "Charlie"])
    }
}
