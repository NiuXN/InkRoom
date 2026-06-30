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

    private let database: any DatabaseServiceProtocol
    private let bookParser: BookParserServiceProtocol
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
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.reloadAllData() }
            }
            .store(in: &cancellables)

        Task { await loadData() }
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        await database.setupDefaultCategoriesIfNeeded()
        books = await database.fetchAllBooks()
        categories = await database.fetchAllCategories()

        #if DEBUG
        if books.isEmpty {
            await loadSampleData()
            books = await database.fetchAllBooks()
            categories = await database.fetchAllCategories()
        }
        #endif

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

    private func reloadBooks() async {
        books = await database.fetchAllBooks()
        categories = await database.fetchAllCategories()
        updateWidgetData()
    }

    private func reloadCategories() async {
        categories = await database.fetchAllCategories()
    }

    private func reloadAllData() async {
        books = await database.fetchAllBooks()
        categories = await database.fetchAllCategories()
        updateWidgetData()
    }

    @discardableResult
    private func perform(_ operation: () async throws -> Void) async -> Bool {
        do {
            try await operation()
            return true
        } catch {
            errorMessage = InkRoomErrorMessage.friendly(for: error)
            return false
        }
    }

    #if DEBUG
    func loadSampleData() async {
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
            try? await database.insertBook(book)
        }

        books = await database.fetchAllBooks()
    }
    #endif

    func importBook(from url: URL) async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            let book = try await bookParser.importBook(from: url, copyFile: true)
            try await database.insertBook(book)
            let chapters = await bookParser.getChapters(for: book)
            if !chapters.isEmpty {
                try await database.insertChapters(chapters, forBookId: book.id)
            }
            await reloadBooks()
        } catch {
            errorMessage = InkRoomErrorMessage.friendly(for: error)
        }
    }

    func addBook(_ book: Book) async {
        await perform {
            try await database.insertBook(book)
            await reloadBooks()
        }
    }

    func deleteBook(_ book: Book) async {
        await perform {
            try await database.deleteBook(book)
            await reloadBooks()
        }
    }

    func updateReadingProgress(for book: Book, to page: Int) async {
        await perform {
            try await database.updateReadingProgress(bookId: book.id, page: page)
            if let index = books.firstIndex(where: { $0.id == book.id }) {
                books[index].currentPage = page
                books[index].lastReadDate = Date()
            }
            updateWidgetData()
        }
    }

    func toggleFavorite(for book: Book) async {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        let newValue = !books[index].isFavorite
        await perform {
            try await database.toggleFavorite(bookId: book.id, isFavorite: newValue)
            books[index].isFavorite = newValue
        }
    }

    func addBookToCategory(_ book: Book, category: Category) async {
        await perform {
            try await database.addBookToCategory(bookId: book.id, categoryId: category.id)
            await reloadAllData()
        }
    }

    func removeBookFromCategory(_ book: Book, category: Category) async {
        await perform {
            try await database.removeBookFromCategory(bookId: book.id, categoryId: category.id)
            await reloadAllData()
        }
    }

    func getChapters(for book: Book) async -> [Chapter] {
        await database.fetchChapters(forBookId: book.id)
    }

    func addBookmark(_ bookmark: Bookmark) async {
        await perform { try await database.addBookmark(bookmark) }
    }

    func removeBookmark(_ bookmark: Bookmark) async {
        await perform { try await database.removeBookmark(bookmark) }
    }

    func getBookmarks(for book: Book) async -> [Bookmark] {
        await database.fetchBookmarks(forBookId: book.id)
    }

    func isBookmarked(_ book: Book, page: Int) async -> Bool {
        await database.isBookmarked(bookId: book.id, page: page)
    }

    func addCategory(_ category: Category) async {
        await perform {
            try await database.insertCategory(category)
            await reloadCategories()
        }
    }

    func deleteCategory(_ category: Category) async {
        await perform {
            try await database.deleteCategory(category)
            for index in books.indices {
                books[index].categoryIds.removeAll { $0 == category.id }
            }
            await reloadCategories()
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

        Task {
            let totalMinutes = await database.fetchTotalReadingMinutes()
            let widgetData = WidgetData(
                currentBook: widgetBooks.first,
                recentBooks: widgetBooks,
                totalBooks: books.count,
                totalReadingMinutes: totalMinutes
            )
            WidgetDataManager.saveWidgetData(widgetData)

            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
}
