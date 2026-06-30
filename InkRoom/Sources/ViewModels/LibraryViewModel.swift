import Foundation
import SwiftUI
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var categories: [Category] = []
    @Published var viewMode: ViewMode = .grid
    @Published var searchText: String = ""
    @Published private(set) var debouncedSearchText: String = ""
    @Published var selectedGroup: BookGroup = .all
    @Published var isLoading = false
    @Published var isImporting = false
    @Published var errorMessage: String?

    enum ViewMode: String, CaseIterable {
        case grid = "网格"
        case list = "列表"
    }

    var filteredBooks: [Book] {
        BookFilter.filter(books, group: selectedGroup, searchText: debouncedSearchText)
    }

    private let database: DatabaseService
    private let bookParser: BookParserService
    private var cancellables = Set<AnyCancellable>()

    init(dependencies: AppDependencies = .shared) {
        self.database = dependencies.database
        self.bookParser = dependencies.bookParser

        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$debouncedSearchText)

        NotificationCenter.default.publisher(for: .bookImportedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadAllData()
            }
            .store(in: &cancellables)

        Task { await loadData() }
    }

    func loadData() async {
        isLoading = true

        database.setupDefaultCategoriesIfNeeded()
        var loadedBooks = database.fetchAllBooks()
        var loadedCategories = database.fetchAllCategories()

        #if DEBUG
        if loadedBooks.isEmpty {
            loadSampleData()
            loadedBooks = database.fetchAllBooks()
            loadedCategories = database.fetchAllCategories()
        }
        #endif

        books = loadedBooks
        categories = loadedCategories
        isLoading = false
        updateWidgetData()
    }

    private func reloadBooks() {
        books = database.fetchAllBooks()
        updateWidgetData()
    }

    private func reloadCategories() {
        categories = database.fetchAllCategories()
    }

    private func reloadAllData() {
        books = database.fetchAllBooks()
        categories = database.fetchAllCategories()
        updateWidgetData()
    }

    @discardableResult
    private func perform(_ operation: () throws -> Void) -> Bool {
        do {
            try operation()
            return true
        } catch {
            errorMessage = InkRoomErrorMessage.friendly(for: error)
            return false
        }
    }

    #if DEBUG
    func loadSampleData() {
        let sampleBooks = [
            Book(
                title: "人间草木",
                author: "汪曾祺",
                coverImageName: "book-cover-1",
                totalPages: 256,
                currentPage: 175,
                lastReadDate: Date().addingTimeInterval(-3600),
                categoryIds: [],
                isFavorite: false
            ),
            Book(
                title: "浮生六记",
                author: "沈复",
                coverImageName: "book-cover-2",
                totalPages: 198,
                currentPage: 83,
                lastReadDate: Date().addingTimeInterval(-86400),
                categoryIds: [],
                isFavorite: false
            ),
            Book(
                title: "围城",
                author: "钱钟书",
                coverImageName: "book-cover-3",
                totalPages: 320,
                currentPage: 320,
                lastReadDate: Date().addingTimeInterval(-604800),
                categoryIds: [],
                isFavorite: true
            )
        ]

        for book in sampleBooks {
            try? database.insertBook(book)
        }

        books = database.fetchAllBooks()
    }
    #endif

    func importBook(from url: URL) async {
        isImporting = true
        errorMessage = nil

        do {
            let book = try await bookParser.importBook(from: url)
            try database.insertBook(book)
            let chapters = await bookParser.getChapters(for: book)
            if !chapters.isEmpty {
                try database.insertChapters(chapters, forBookId: book.id)
            }
            reloadBooks()
        } catch {
            errorMessage = InkRoomErrorMessage.friendly(for: error)
        }

        isImporting = false
    }

    func addBook(_ book: Book) {
        perform {
            try database.insertBook(book)
            reloadBooks()
        }
    }

    func deleteBook(_ book: Book) {
        perform {
            try database.deleteBook(book)
            reloadBooks()
        }
    }

    func updateReadingProgress(for book: Book, to page: Int) {
        perform {
            try database.updateReadingProgress(bookId: book.id, page: page)
            if let index = books.firstIndex(where: { $0.id == book.id }) {
                books[index].currentPage = page
                books[index].lastReadDate = Date()
            }
            updateWidgetData()
        }
    }

    func toggleFavorite(for book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        let newValue = !books[index].isFavorite
        perform {
            try database.toggleFavorite(bookId: book.id, isFavorite: newValue)
            books[index].isFavorite = newValue
        }
    }

    func addBookToCategory(_ book: Book, category: Category) {
        perform {
            try database.addBookToCategory(bookId: book.id, categoryId: category.id)
            reloadAllData()
        }
    }

    func removeBookFromCategory(_ book: Book, category: Category) {
        perform {
            try database.removeBookFromCategory(bookId: book.id, categoryId: category.id)
            reloadAllData()
        }
    }

    func getChapters(for book: Book) -> [Chapter] {
        database.fetchChapters(forBookId: book.id)
    }

    func addBookmark(_ bookmark: Bookmark) {
        perform { try database.addBookmark(bookmark) }
    }

    func removeBookmark(_ bookmark: Bookmark) {
        perform { try database.removeBookmark(bookmark) }
    }

    func getBookmarks(for book: Book) -> [Bookmark] {
        database.fetchBookmarks(forBookId: book.id)
    }

    func isBookmarked(_ book: Book, page: Int) -> Bool {
        database.isBookmarked(bookId: book.id, page: page)
    }

    func addCategory(_ category: Category) {
        perform {
            try database.insertCategory(category)
            reloadCategories()
        }
    }

    func deleteCategory(_ category: Category) {
        perform {
            try database.deleteCategory(category)
            reloadAllData()
        }
    }

    // MARK: - Widget Data

    func updateWidgetData() {
        let recentBooks = Array(
            books
                .filter { $0.lastReadDate != nil }
                .sorted { ($0.lastReadDate ?? $0.addedDate) > ($1.lastReadDate ?? $1.addedDate) }
                .prefix(5)
        )

        let widgetBooks = recentBooks.map { book -> WidgetBookData in
            WidgetBookData(
                id: book.id.uuidString,
                title: book.title,
                author: book.author,
                currentPage: book.currentPage,
                totalPages: book.totalPages,
                lastReadDate: book.lastReadDate ?? book.addedDate,
                coverData: nil,
                currentChapterTitle: ""
            )
        }

        let widgetData = WidgetData(
            currentBook: widgetBooks.first,
            recentBooks: widgetBooks,
            totalBooks: books.count,
            totalReadingMinutes: database.fetchTotalReadingMinutes()
        )

        WidgetDataManager.saveWidgetData(widgetData)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
