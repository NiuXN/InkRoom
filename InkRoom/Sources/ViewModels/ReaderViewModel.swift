import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class ReaderViewModel: ObservableObject {
    let book: Book

    @Published var currentPage: Int
    @Published var chapters: [Chapter] = []
    @Published var pageText: String = ""
    @Published var isLoading = true
    @Published var currentChapterTitle: String = ""
    @Published var currentChapterIndex: Int = 0
    @Published var chapterTexts: [Int: String] = [:]
    @Published var isCurrentPageBookmarked = false
    @Published var bookmarks: [Bookmark] = []
    @Published var pagesReadInSession = 0
    @Published var pendingScrollToPage: Int?

    private(set) var readingSessionStart: Date?
    private var libraryViewModel: LibraryViewModel?
    private var pageLoadGeneration = 0
    private var pageLoadTask: Task<Void, Never>?
    private var scrollUpdateTask: Task<Void, Never>?

    var activeBook: Book {
        libraryViewModel?.books.first(where: { $0.id == book.id }) ?? book
    }

    init(book: Book) {
        self.book = book
        self.currentPage = max(1, book.currentPage)
    }

    func attach(library: LibraryViewModel) {
        libraryViewModel = library
    }

    func onAppear(isScrollMode: Bool) {
        readingSessionStart = Date()
        pagesReadInSession = 0
        Task {
            await loadChapters()
            if isScrollMode {
                isLoading = false
                pendingScrollToPage = currentPage
            } else {
                await loadPageContent()
            }
            loadBookmarks()
            checkCurrentPageBookmark()
        }
    }

    func onDisappear() {
        saveProgress()
        saveReadingSession()
    }

    func prevPage(isScrollMode: Bool) -> Bool {
        guard currentPage > 1 else { return false }
        currentPage -= 1
        pagesReadInSession += 1
        saveProgress()
        if isScrollMode {
            pendingScrollToPage = currentPage
        } else {
            schedulePageLoad()
        }
        checkCurrentPageBookmark()
        return true
    }

    func nextPage(isScrollMode: Bool) -> Bool {
        guard currentPage < activeBook.totalPages else { return false }
        currentPage += 1
        pagesReadInSession += 1
        saveProgress()
        if isScrollMode {
            pendingScrollToPage = currentPage
        } else {
            schedulePageLoad()
        }
        checkCurrentPageBookmark()
        return true
    }

    func navigateToPage(_ page: Int, isScrollMode: Bool) {
        guard page >= 1, page <= activeBook.totalPages, page != currentPage else { return }
        pagesReadInSession += 1
        currentPage = page
        saveProgress()
        if isScrollMode {
            pendingScrollToPage = page
            updateChapterMetadata(for: page)
            checkCurrentPageBookmark()
        } else {
            schedulePageLoad()
        }
    }

    func updateFromScroll(frames: [Int: CGRect]) {
        scrollUpdateTask?.cancel()
        scrollUpdateTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            guard let page = ScrollReadingPosition.estimatePage(frames: frames, chapters: chapters) else { return }
            guard page != currentPage else { return }
            currentPage = page
            updateChapterMetadata(for: page)
            schedulePageTextRefresh()
            checkCurrentPageBookmark()
        }
    }

    func loadBookmarks() {
        guard let libraryViewModel else { return }
        bookmarks = libraryViewModel.getBookmarks(for: activeBook)
    }

    func checkCurrentPageBookmark() {
        guard let libraryViewModel else { return }
        isCurrentPageBookmarked = libraryViewModel.isBookmarked(activeBook, page: currentPage)
    }

    func toggleBookmark(pageText: String, chapterTitle: String) {
        guard let libraryViewModel else { return }
        if isCurrentPageBookmarked {
            if let bookmark = bookmarks.first(where: { $0.page == currentPage }) {
                libraryViewModel.removeBookmark(bookmark)
            }
        } else {
            let bookmark = Bookmark(
                bookId: activeBook.id,
                page: currentPage,
                chapterTitle: chapterTitle,
                content: String(pageText.prefix(80))
            )
            libraryViewModel.addBookmark(bookmark)
        }
        loadBookmarks()
        checkCurrentPageBookmark()
    }

    func ensureChapterTextLoaded(at index: Int) async {
        guard chapterTexts[index] == nil,
              index >= 0, index < chapters.count,
              let filePath = activeBook.filePath else { return }

        if let content = try? await BookParserService.shared.getChapterContent(
            for: index,
            from: filePath,
            charsPerPage: 10000
        ) {
            chapterTexts[index] = content
        }
    }

    func chapterTitle(for index: Int) -> String {
        guard index >= 0, index < chapters.count else { return "" }
        return chapters[index].title
    }

    func chapterDisplayText(at index: Int) -> String {
        chapterTexts[index] ?? "加载中..."
    }

    // MARK: - Private

    private func schedulePageLoad() {
        pageLoadTask?.cancel()
        pageLoadTask = Task {
            await loadPageContent()
            checkCurrentPageBookmark()
        }
    }

    private func schedulePageTextRefresh() {
        pageLoadTask?.cancel()
        pageLoadTask = Task {
            await refreshPageTextOnly()
        }
    }

    private func updateChapterMetadata(for page: Int) {
        currentChapterTitle = findChapterTitle(for: page)
        currentChapterIndex = findChapterIndex(for: page)
    }

    private func loadChapters() async {
        guard let libraryViewModel else { return }
        let stored = libraryViewModel.getChapters(for: activeBook)
        if !stored.isEmpty {
            chapters = stored
            return
        }

        if activeBook.filePath != nil {
            chapters = await BookParserService.shared.getChapters(for: activeBook)
            if !chapters.isEmpty {
                try? DatabaseService.shared.insertChapters(chapters, forBookId: activeBook.id)
            }
        } else if chapters.isEmpty {
            chapters = Self.demoChapters
        }
    }

    func applyDemoPageText(_ text: String) {
        pageText = text
        isLoading = false
        updateChapterMetadata(for: currentPage)
    }

    private static let demoChapters: [Chapter] = [
        Chapter(title: "第一章 · 人间草木", startPage: 1, endPage: 25),
        Chapter(title: "第二章 · 四时佳兴", startPage: 26, endPage: 58),
        Chapter(title: "第三章 · 美食美味", startPage: 59, endPage: 95),
        Chapter(title: "第四章 · 人物风物", startPage: 96, endPage: 145),
        Chapter(title: "第五章 · 往事如烟", startPage: 146, endPage: 198),
        Chapter(title: "第六章 · 旅途见闻", startPage: 199, endPage: 256)
    ]

    private func loadPageContent() async {
        let generation = pageLoadGeneration + 1
        pageLoadGeneration = generation
        isLoading = true

        if activeBook.filePath != nil {
            if let content = await BookParserService.shared.getChapterContent(for: activeBook, page: currentPage) {
                guard generation == pageLoadGeneration else { return }
                pageText = content
            } else {
                guard generation == pageLoadGeneration else { return }
                pageText = "无法加载页面内容"
            }
        }

        updateChapterMetadata(for: currentPage)
        await preloadAdjacentChapterTexts()
        guard generation == pageLoadGeneration else { return }
        isLoading = false
    }

    private func refreshPageTextOnly() async {
        guard activeBook.filePath != nil else { return }
        if let content = await BookParserService.shared.getChapterContent(for: activeBook, page: currentPage) {
            pageText = content
        }
    }

    private func preloadAdjacentChapterTexts() async {
        await ensureChapterTextLoaded(at: currentChapterIndex)
        await ensureChapterTextLoaded(at: currentChapterIndex - 1)
        await ensureChapterTextLoaded(at: currentChapterIndex + 1)
    }

    private func saveProgress() {
        guard let libraryViewModel else { return }
        let baselinePage = max(1, activeBook.currentPage)
        guard pagesReadInSession > 0 || currentPage != baselinePage else { return }
        libraryViewModel.updateReadingProgress(for: activeBook, to: currentPage)
    }

    private func saveReadingSession() {
        guard let start = readingSessionStart else { return }
        let end = Date()
        let duration = end.timeIntervalSince(start)
        guard duration >= 5, pagesReadInSession > 0 else {
            readingSessionStart = nil
            return
        }
        let session = ReadingSession(
            id: UUID(),
            bookId: activeBook.id,
            bookTitle: activeBook.title,
            startTime: start,
            endTime: end,
            duration: duration,
            pagesRead: pagesReadInSession
        )
        try? DatabaseService.shared.insertReadingSession(session)
        readingSessionStart = nil
    }

    private func findChapterIndex(for page: Int) -> Int {
        ScrollReadingPosition.chapterIndex(for: page, in: chapters)
    }

    private func findChapterTitle(for page: Int) -> String {
        for chapter in chapters {
            if page >= chapter.startPage && page <= chapter.endPage {
                return chapter.title
            }
        }
        return ""
    }
}
