import XCTest
@testable import InkRoom

final class BookModelTests: XCTestCase {

    // MARK: - Reading Progress Tests

    func testReadingProgressWithZeroPages() {
        let book = Book(title: "Test", author: "Author", totalPages: 0, currentPage: 0)
        XCTAssertEqual(book.readingProgress, 0)
    }

    func testReadingProgressAtStart() {
        let book = Book(title: "Test", author: "Author", totalPages: 100, currentPage: 0)
        XCTAssertEqual(book.readingProgress, 0)
    }

    func testReadingProgressAtMiddle() {
        let book = Book(title: "Test", author: "Author", totalPages: 100, currentPage: 50)
        XCTAssertEqual(book.readingProgress, 0.5)
    }

    func testReadingProgressAtEnd() {
        let book = Book(title: "Test", author: "Author", totalPages: 100, currentPage: 100)
        XCTAssertEqual(book.readingProgress, 1.0)
    }

    func testReadingProgressBeyondEnd() {
        let book = Book(title: "Test", author: "Author", totalPages: 100, currentPage: 150)
        XCTAssertEqual(book.readingProgress, 1.5)
    }

    // MARK: - Is Started Tests

    func testIsStartedFalse() {
        let book = Book(title: "Test", author: "Author", totalPages: 100, currentPage: 0)
        XCTAssertFalse(book.isStarted)
    }

    func testIsStartedTrue() {
        let book = Book(title: "Test", author: "Author", totalPages: 100, currentPage: 1)
        XCTAssertTrue(book.isStarted)
    }

    // MARK: - Cover Image URL Tests

    func testCoverImageURLWithNilName() {
        let book = Book(title: "Test", author: "Author", coverImageName: nil)
        XCTAssertNil(book.coverImageURL)
    }

    func testCoverImageURLWithName() {
        let book = Book(title: "Test", author: "Author", coverImageName: "cover.jpg")
        XCTAssertNotNil(book.coverImageURL)
        XCTAssertTrue(book.coverImageURL!.path.contains("cover.jpg"))
    }

    // MARK: - Equatable Tests

    func testBookEquality() {
        let id = UUID()
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let book1 = Book(id: id, title: "Test", author: "Author", addedDate: fixedDate)
        let book2 = Book(id: id, title: "Test", author: "Author", addedDate: fixedDate)
        XCTAssertEqual(book1, book2)
    }

    func testBookInequality() {
        let book1 = Book(title: "Test1", author: "Author")
        let book2 = Book(title: "Test2", author: "Author")
        XCTAssertNotEqual(book1, book2)
    }

    // MARK: - Codable Tests

    func testBookCodable() throws {
        let original = Book(
            title: "人间草木",
            author: "汪曾祺",
            totalPages: 256,
            currentPage: 100,
            isFavorite: true,
            bookDescription: "Test description"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Book.self, from: encoded)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.author, decoded.author)
        XCTAssertEqual(original.totalPages, decoded.totalPages)
        XCTAssertEqual(original.currentPage, decoded.currentPage)
        XCTAssertEqual(original.isFavorite, decoded.isFavorite)
        XCTAssertEqual(original.bookDescription, decoded.bookDescription)
    }
}

final class ReadingSettingsTests: XCTestCase {

    // MARK: - Reader Theme Tests

    func testReaderThemeBackgroundColors() {
        XCTAssertEqual(ReadingSettings.ReaderTheme.light.backgroundColor, "#F5F0E8")
        XCTAssertEqual(ReadingSettings.ReaderTheme.warm.backgroundColor, "#F0E6D0")
        XCTAssertEqual(ReadingSettings.ReaderTheme.dark.backgroundColor, "#1A1A1A")
    }

    func testReaderThemeTextColors() {
        XCTAssertEqual(ReadingSettings.ReaderTheme.light.textColor, "#2C2C2C")
        XCTAssertEqual(ReadingSettings.ReaderTheme.warm.textColor, "#3D3D3D")
        XCTAssertEqual(ReadingSettings.ReaderTheme.dark.textColor, "#D4CFC7")
    }

    func testReaderThemeAllCases() {
        let themes = ReadingSettings.ReaderTheme.allCases
        XCTAssertEqual(themes.count, 3)
        XCTAssertTrue(themes.contains(.light))
        XCTAssertTrue(themes.contains(.warm))
        XCTAssertTrue(themes.contains(.dark))
    }

    // MARK: - Page Turn Style Tests

    func testPageTurnStyleAllCases() {
        let styles = ReadingSettings.PageTurnStyle.allCases
        XCTAssertEqual(styles.count, 3)
        XCTAssertTrue(styles.contains(.swipe))
        XCTAssertTrue(styles.contains(.tap))
        XCTAssertTrue(styles.contains(.scroll))
    }

    // MARK: - Default Settings Tests

    func testDefaultSettings() {
        let defaults = ReadingSettings.default
        XCTAssertEqual(defaults.fontSize, 18)
        XCTAssertEqual(defaults.lineSpacing, 8)
        XCTAssertEqual(defaults.letterSpacing, 0)
        XCTAssertEqual(defaults.readerTheme, .light)
        XCTAssertEqual(defaults.pageTurnStyle, .swipe)
        XCTAssertEqual(defaults.ttsRate, 0.5)
        XCTAssertEqual(defaults.ttsPitch, 1.0)
        XCTAssertNil(defaults.ttsVoiceIdentifier)
        XCTAssertNil(defaults.ttsTimerMinutes)
        XCTAssertTrue(defaults.ttsHighlightEnabled)
    }

    // MARK: - Codable Tests

    func testReadingSettingsCodable() throws {
        let original = ReadingSettings(
            fontSize: 20,
            lineSpacing: 10,
            letterSpacing: 2,
            readerTheme: .dark,
            pageTurnStyle: .scroll,
            ttsRate: 0.6,
            ttsPitch: 1.2,
            ttsVoiceIdentifier: "voice-id",
            ttsTimerMinutes: 30,
            ttsHighlightEnabled: false
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReadingSettings.self, from: encoded)

        XCTAssertEqual(original.fontSize, decoded.fontSize)
        XCTAssertEqual(original.lineSpacing, decoded.lineSpacing)
        XCTAssertEqual(original.readerTheme, decoded.readerTheme)
        XCTAssertEqual(original.pageTurnStyle, decoded.pageTurnStyle)
        XCTAssertEqual(original.ttsRate, decoded.ttsRate)
        XCTAssertEqual(original.ttsTimerMinutes, decoded.ttsTimerMinutes)
    }
}
