import Foundation

/// Protocol-based dependency injection for testability.
/// All services should be accessed through these protocols.
@MainActor
protocol AppDependenciesProtocol: AnyObject {
    var database: DatabaseServiceProtocol { get }
    var bookParser: BookParserServiceProtocol { get }
    var wifiTransfer: WiFiTransferServiceProtocol { get }
    var updateService: AppStoreUpdateServiceProtocol { get }
}

/// Concrete implementation of the dependency container.
/// Manages service singletons and provides them to ViewModels.
@MainActor
final class AppDependencies: ObservableObject, AppDependenciesProtocol {
    let database: DatabaseServiceProtocol
    let bookParser: BookParserServiceProtocol
    let wifiTransfer: WiFiTransferServiceProtocol
    let updateService: AppStoreUpdateServiceProtocol

    static let shared = AppDependencies()

    init(
        database: DatabaseServiceProtocol? = nil,
        bookParser: BookParserServiceProtocol? = nil,
        wifiTransfer: WiFiTransferServiceProtocol? = nil,
        updateService: AppStoreUpdateServiceProtocol? = nil
    ) {
        // Allow injection for testing, default to shared singletons
        self.database = database ?? DatabaseService.shared
        self.bookParser = bookParser ?? BookParserService.shared
        self.wifiTransfer = wifiTransfer ?? WiFiTransferService.shared
        self.updateService = updateService ?? AppStoreUpdateService.shared
    }

    /// Create a test instance with mock services
    static func test(
        database: DatabaseServiceProtocol? = nil,
        bookParser: BookParserServiceProtocol? = nil,
        wifiTransfer: WiFiTransferServiceProtocol? = nil,
        updateService: AppStoreUpdateServiceProtocol? = nil
    ) -> AppDependencies {
        AppDependencies(
            database: database,
            bookParser: bookParser,
            wifiTransfer: wifiTransfer,
            updateService: updateService
        )
    }
}

// MARK: - Service Protocols

/// Protocol for database operations - enables mocking for tests
@MainActor
protocol DatabaseServiceProtocol: AnyObject {
    func setupDefaultCategoriesIfNeeded()
    func fetchAllBooks() -> [Book]
    func fetchAllCategories() -> [Category]
    func insertBook(_ book: Book) throws
    func deleteBook(_ book: Book) throws
    func updateReadingProgress(bookId: UUID, page: Int) throws
    func toggleFavorite(bookId: UUID, isFavorite: Bool) throws
    func insertChapters(_ chapters: [Chapter], forBookId: UUID) throws
    func fetchChapters(forBookId: UUID) -> [Chapter]
    func addBookmark(_ bookmark: Bookmark) throws
    func removeBookmark(_ bookmark: Bookmark) throws
    func fetchBookmarks(forBookId: UUID) -> [Bookmark]
    func isBookmarked(bookId: UUID, page: Int) -> Bool
    func insertCategory(_ category: Category) throws
    func deleteCategory(_ category: Category) throws
    func addBookToCategory(bookId: UUID, categoryId: UUID) throws
    func removeBookFromCategory(bookId: UUID, categoryId: UUID) throws
    func insertReadingSession(_ session: ReadingSession) throws
    func fetchAllSessions() -> [ReadingSession]
    func fetchTotalReadingMinutes() -> Int
    func fetchReadingStatistics() -> ReadingStatistics
}

/// Protocol for book parsing operations
@MainActor
protocol BookParserServiceProtocol: AnyObject {
    func parseBook(from url: URL) async throws -> ParsedBook
    func importBook(from sourceURL: URL, copyFile: Bool) async throws -> Book
    func getChapters(for book: Book) async -> [Chapter]
    func getChapterContent(for book: Book, page: Int) async -> String?
    func getChapterContent(for chapterIndex: Int, from filePath: String, charsPerPage: Int) async throws -> String?
    func clearCache(for path: String?)
}

/// Protocol for WiFi transfer operations
@MainActor
protocol WiFiTransferServiceProtocol: AnyObject {
    var isRunning: Bool { get }
    var ipAddress: String { get }
    var port: UInt16 { get }
    var uploadedFiles: [WiFiTransferService.UploadedFile] { get }
    func startServer() async throws
    func stopServer()
}

/// Protocol for App Store update operations
@MainActor
protocol AppStoreUpdateServiceProtocol: AnyObject {
    var pendingUpdate: AppStoreUpdateService.UpdateInfo? { get }
    var isChecking: Bool { get }
    var statusMessage: String? { get }
    func checkForUpdate(showStatusWhenUpToDate: Bool) async
    func openAppStore()
    func openProUpgradePage()
}

// MARK: - Protocol Conformance

extension DatabaseService: DatabaseServiceProtocol {}
extension BookParserService: BookParserServiceProtocol {}
extension WiFiTransferService: WiFiTransferServiceProtocol {}
extension AppStoreUpdateService: AppStoreUpdateServiceProtocol {}
