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
    @Published var sortOption: BookSortOption
    @Published var sortAscending: Bool
    @Published private(set) var filteredBooks: [Book] = []
    @Published private(set) var groupBookCounts: [BookGroup: Int] = [:]
    @Published var isLoading = false
    @Published var isImporting = false
    @Published var errorMessage: String?

    enum ViewMode: String, CaseIterable {
        case grid = "网格"
        case list = "列表"
    }

    private static let sortOptionKey = "librarySortOption"
    private static let sortAscendingKey = "librarySortAscending"

    private let database: DatabaseService
    private let bookParser: BookParserService
    private var cancellables = Set<AnyCancellable>()

    init(dependencies: AppDependencies = .shared) {
        self.database = dependencies.database
        self.bookParser = dependencies.bookParser

        let savedSort = UserDefaults.standard.string(forKey: Self.sortOptionKey)
        let option = BookSortOption(rawValue: savedSort ?? "") ?? .recentRead
        self.sortOption = option
        if UserDefaults.standard.object(forKey: Self.sortAscendingKey) != nil {
            self.sortAscending = UserDefaults.standard.bool(forKey: Self.sortAscendingKey)
        } else {
            self.sortAscending = option.defaultAscending
        }

        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: &$debouncedSearchText)

        Publishers.CombineLatest3($books, $selectedGroup, $debouncedSearchText)
            .combineLatest($sortOption, $sortAscending)
            .throttle(for: .milliseconds(50), scheduler: RunLoop.main, latest: true)
            .map { base, sortBy, ascending in
                let (books, group, search) = base
                return BookFilter.filter(books, group: group, searchText: search, sortBy: sortBy, ascending: ascending)
            }
            .removeDuplicates()
            .assign(to: &$filteredBooks)

        $books
            .map { books in
                Dictionary(uniqueKeysWithValues: BookGroup.allCases.map { group in
                    (group, BookFilter.count(in: books, for: group))
                })
            }
            .assign(to: &$groupBookCounts)

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

        let database = self.database
        var loaded = await Task.detached(priority: .userInitiated) {
            database.setupDefaultCategoriesIfNeeded()
            let books = database.fetchAllBooks()
            let categories = database.fetchAllCategories()
            return (books, categories)
        }.value

        #if DEBUG
        if loaded.0.isEmpty {
            loadSampleData()
            loaded = await Task.detached(priority: .userInitiated) {
                (database.fetchAllBooks(), database.fetchAllCategories())
            }.value
        }
        #endif

        books = loaded.0
        categories = loaded.1
        isLoading = false
        updateWidgetData()
    }

    func setSortOption(_ option: BookSortOption) {
        if sortOption == option {
            sortAscending.toggle()
        } else {
            sortOption = option
            sortAscending = option.defaultAscending
        }
        UserDefaults.standard.set(sortOption.rawValue, forKey: Self.sortOptionKey)
        UserDefaults.standard.set(sortAscending, forKey: Self.sortAscendingKey)
    }

    var sortOrderLabel: String {
        sortAscending ? "升序" : "降序"
    }

    private func reloadBooks() {
        books = database.fetchAllBooks()
        categories = database.fetchAllCategories()
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
            // Batch update: reload once at the end to avoid multiple UI updates
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
            for index in books.indices {
                books[index].categoryIds.removeAll { $0 == category.id }
            }
            reloadCategories()
        }
    }

    // MARK: - Widget Data

    func updateWidgetData() {
        let recentBooks = Array(
            books
                .filter { $0.lastReadDate != nil }
                .sorted { ($0.lastReadDate ?? .distantPast) > ($1.lastReadDate ?? .distantPast) }
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
