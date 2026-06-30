import Foundation
import SQLite

actor DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?

    /// 数据库初始化过程中遇到的错误（若有）。`isReady` 为 false 时上层应提示用户。
    ///
    /// `nonisolated(unsafe)`：仅在 nonisolated `init` 中写入一次，之后只在 actor 内部读取，
    /// 无并发风险；标记是为了让 actor 的 nonisolated 初始化器能够赋值。
    nonisolated(unsafe) private var setupError: DatabaseError?

    /// 数据库是否初始化成功并可正常使用。
    var isReady: Bool { db != nil && setupError == nil }

    // MARK: - Tables
    let books = Table("books")
    let categories = Table("categories")
    let chapters = Table("chapters")
    let bookmarks = Table("bookmarks")
    let readingSessions = Table("reading_sessions")

    // MARK: - Book Columns
    let bookId = Expression<String>("id")
    let bookTitle = Expression<String>("title")
    let bookAuthor = Expression<String>("author")
    let bookCoverPath = Expression<String?>("cover_path")
    let bookFilePath = Expression<String?>("file_path")
    let bookTotalPages = Expression<Int>("total_pages")
    let bookCurrentPage = Expression<Int>("current_page")
    let bookLastReadDate = Expression<Double?>("last_read_date")
    let bookIsFavorite = Expression<Bool>("is_favorite")
    let bookAddedDate = Expression<Double>("added_date")

    // MARK: - Category Columns
    let categoryId = Expression<String>("id")
    let categoryName = Expression<String>("name")
    let categoryIconName = Expression<String>("icon_name")
    let categoryColorHex = Expression<String>("color_hex")

    // MARK: - Chapter Columns
    let chapterId = Expression<String>("id")
    let chapterBookId = Expression<String>("book_id")
    let chapterTitle = Expression<String>("title")
    let chapterStartPage = Expression<Int>("start_page")
    let chapterEndPage = Expression<Int>("end_page")
    let chapterOrder = Expression<Int>("order_index")

    // MARK: - Bookmark Columns
    let bookmarkId = Expression<String>("id")
    let bookmarkBookId = Expression<String>("book_id")
    let bookmarkPage = Expression<Int>("page")
    let bookmarkChapterTitle = Expression<String>("chapter_title")
    let bookmarkContent = Expression<String>("content")
    let bookmarkCreatedAt = Expression<Double>("created_at")

    // MARK: - Book-Category Relation Columns
    let relationBookId = Expression<String>("book_id")
    let relationCategoryId = Expression<String>("category_id")

    // MARK: - Reading Session Columns
    let sessionId = Expression<String>("id")
    let sessionBookId = Expression<String>("book_id")
    let sessionBookTitle = Expression<String>("book_title")
    let sessionStartTime = Expression<Double>("start_time")
    let sessionEndTime = Expression<Double>("end_time")
    let sessionDuration = Expression<Double>("duration")
    let sessionPagesRead = Expression<Int>("pages_read")

    private init() {
        // actor 的 init 是 nonisolated，无法调用 isolated 方法，
        // 因此把初始化逻辑内联，并把辅助方法标为 nonisolated / static。
        do {
            let path = Self.getDatabasePath()
            let connection = try Connection(path)
            db = connection
            try createTables(on: connection)
        } catch let error as DatabaseError {
            setupError = error
            print("[DatabaseService][\(error.errorCode)] setupDatabase failed: \(error)")
        } catch {
            setupError = .connectionFailed(underlying: error)
            print("[DatabaseService][DB_001] setupDatabase failed: \(error)")
        }
    }

    private nonisolated static func getDatabasePath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("inkroom.sqlite3").path
    }

    /// 建表与索引。标 nonisolated：仅读取 `let` 表/列定义（Sendable），仅在 init 期间调用。
    private nonisolated func createTables(on db: Connection) throws {
        do {
            try db.run(books.create(ifNotExists: true) { t in
                t.column(bookId, primaryKey: true)
                t.column(bookTitle)
                t.column(bookAuthor)
                t.column(bookCoverPath)
                t.column(bookFilePath)
                t.column(bookTotalPages, defaultValue: 0)
                t.column(bookCurrentPage, defaultValue: 0)
                t.column(bookLastReadDate)
                t.column(bookIsFavorite, defaultValue: false)
                t.column(bookAddedDate)
            })

            try db.run(categories.create(ifNotExists: true) { t in
                t.column(categoryId, primaryKey: true)
                t.column(categoryName)
                t.column(categoryIconName)
                t.column(categoryColorHex)
            })

            try db.run(chapters.create(ifNotExists: true) { t in
                t.column(chapterId, primaryKey: true)
                t.column(chapterBookId)
                t.column(chapterTitle)
                t.column(chapterStartPage)
                t.column(chapterEndPage)
                t.column(chapterOrder)
            })

            try db.run("""
                CREATE TABLE IF NOT EXISTS book_category_relations (
                    book_id TEXT NOT NULL,
                    category_id TEXT NOT NULL,
                    PRIMARY KEY (book_id, category_id)
                )
            """)

            try db.run(bookmarks.create(ifNotExists: true) { t in
                t.column(bookmarkId, primaryKey: true)
                t.column(bookmarkBookId)
                t.column(bookmarkPage)
                t.column(bookmarkChapterTitle)
                t.column(bookmarkContent)
                t.column(bookmarkCreatedAt)
            })

            try db.run(readingSessions.create(ifNotExists: true) { t in
                t.column(sessionId, primaryKey: true)
                t.column(sessionBookId)
                t.column(sessionBookTitle)
                t.column(sessionStartTime)
                t.column(sessionEndTime)
                t.column(sessionDuration)
                t.column(sessionPagesRead)
            })

            try db.run("CREATE INDEX IF NOT EXISTS idx_books_last_read ON books(last_read_date DESC)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_books_added_date ON books(added_date DESC)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_chapters_book_id ON chapters(book_id, order_index)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_bookmarks_book_id ON bookmarks(book_id, page)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON reading_sessions(start_time DESC)")
            try db.run("CREATE INDEX IF NOT EXISTS idx_sessions_book_id ON reading_sessions(book_id)")

        } catch {
            throw DatabaseError.tableCreationFailed(underlying: error)
        }
    }

    /// 结构化错误日志：统一打印 errorCode、操作、底层错误，便于排查。
    private func log(_ error: DatabaseError, operation: String) {
        let underlying = error.underlyingError.map { " \($0)" } ?? ""
        print("[DatabaseService][\(error.errorCode)] \(operation) failed\(underlying)")
    }

    private func parseUUID(_ string: String, context: String) -> UUID? {
        guard let uuid = UUID(uuidString: string) else {
            print("[DatabaseService] WARNING: UUID 解析失败: \"\(string)\" (\(context))")
            return nil
        }
        return uuid
    }

    // MARK: - Book Operations

    func insertBook(_ book: Book) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let insert = books.insert(
                bookId <- book.id.uuidString,
                bookTitle <- book.title,
                bookAuthor <- book.author,
                bookCoverPath <- book.coverImageName,
                bookFilePath <- book.filePath,
                bookTotalPages <- book.totalPages,
                bookCurrentPage <- book.currentPage,
                bookLastReadDate <- book.lastReadDate?.timeIntervalSince1970,
                bookIsFavorite <- book.isFavorite,
                bookAddedDate <- book.addedDate.timeIntervalSince1970
            )
            try db.run(insert)
        } catch {
            throw DatabaseError.insertFailed(table: "books", underlying: error)
        }

        for categoryId in book.categoryIds {
            try addBookToCategory(bookId: book.id, categoryId: categoryId)
        }
    }

    func fetchAllBooks() -> [Book] {
        guard let db = db else { return [] }

        var results: [Book] = []
        do {
            var bookCategoryMap: [String: [UUID]] = [:]
            for row in try db.prepare("SELECT book_id, category_id FROM book_category_relations") {
                if let bookIdStr = row[0] as? String, let categoryIdStr = row[1] as? String,
                   let catId = parseUUID(categoryIdStr, context: "book_category_relations.category_id") {
                    bookCategoryMap[bookIdStr, default: []].append(catId)
                }
            }

            for row in try db.prepare(books.order(bookLastReadDate.desc, bookAddedDate.desc)) {
                let bookIdStr = row[bookId]
                guard let bookUUID = parseUUID(bookIdStr, context: "books.id") else { continue }
                let book = Book(
                    id: bookUUID,
                    title: row[bookTitle],
                    author: row[bookAuthor],
                    coverImageName: row[bookCoverPath],
                    filePath: row[bookFilePath],
                    totalPages: row[bookTotalPages],
                    currentPage: row[bookCurrentPage],
                    lastReadDate: row[bookLastReadDate].map { Date(timeIntervalSince1970: $0) },
                    categoryIds: bookCategoryMap[bookIdStr] ?? [],
                    isFavorite: row[bookIsFavorite],
                    addedDate: Date(timeIntervalSince1970: row[bookAddedDate])
                )
                results.append(book)
            }
        } catch {
            log(.fetchFailed(table: "books", underlying: error), operation: "fetchAllBooks")
        }
        return results
    }

    func updateBook(_ book: Book) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let target = books.filter(bookId == book.id.uuidString)
            try db.run(target.update(
                bookTitle <- book.title,
                bookAuthor <- book.author,
                bookCoverPath <- book.coverImageName,
                bookFilePath <- book.filePath,
                bookTotalPages <- book.totalPages,
                bookCurrentPage <- book.currentPage,
                bookLastReadDate <- book.lastReadDate?.timeIntervalSince1970,
                bookIsFavorite <- book.isFavorite
            ))
        } catch {
            throw DatabaseError.updateFailed(table: "books", underlying: error)
        }
    }

    func deleteBook(_ book: Book) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        let bookIdStr = book.id.uuidString

        do {
            let target = books.filter(bookId == bookIdStr)
            try db.run(target.delete())

            let chaptersTarget = chapters.filter(chapterBookId == bookIdStr)
            try db.run(chaptersTarget.delete())

            let bookmarksTarget = bookmarks.filter(bookmarkBookId == bookIdStr)
            try db.run(bookmarksTarget.delete())

            let sessionsTarget = readingSessions.filter(sessionBookId == bookIdStr)
            try db.run(sessionsTarget.delete())

            try db.run("DELETE FROM book_category_relations WHERE book_id = ?", bookIdStr)
        } catch {
            throw DatabaseError.deleteFailed(table: "books", underlying: error)
        }

        if let filePath = book.filePath {
            try? FileManager.default.removeItem(atPath: filePath)
            // BookParserService 是 actor，clearCache 为 nonisolated 可直接调用。
            BookParserService.shared.clearCache(for: filePath)
        }
        if let coverURL = book.coverImageURL {
            CoverImageCache.shared.remove(for: coverURL.path)
            try? FileManager.default.removeItem(at: coverURL)
        }
    }

    func updateReadingProgress(bookId id: UUID, page: Int) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let target = books.filter(bookId == id.uuidString)
            try db.run(target.update(
                bookCurrentPage <- page,
                bookLastReadDate <- Date().timeIntervalSince1970
            ))
        } catch {
            throw DatabaseError.updateFailed(table: "books", underlying: error)
        }
    }

    func toggleFavorite(bookId id: UUID, isFavorite: Bool) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let target = books.filter(bookId == id.uuidString)
            try db.run(target.update(bookIsFavorite <- isFavorite))
        } catch {
            throw DatabaseError.updateFailed(table: "books", underlying: error)
        }
    }

    // MARK: - Category Operations

    func insertCategory(_ category: Category) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let insert = categories.insert(
                categoryId <- category.id.uuidString,
                categoryName <- category.name,
                categoryIconName <- category.iconName,
                categoryColorHex <- category.colorHex
            )
            try db.run(insert)
        } catch {
            throw DatabaseError.insertFailed(table: "categories", underlying: error)
        }
    }

    func fetchAllCategories() -> [Category] {
        guard let db = db else { return [] }

        var results: [Category] = []
        do {
            var categoryBookMap: [String: [UUID]] = [:]
            for row in try db.prepare("SELECT category_id, book_id FROM book_category_relations") {
                if let categoryIdStr = row[0] as? String, let bookIdStr = row[1] as? String,
                   let bookUUID = parseUUID(bookIdStr, context: "book_category_relations.book_id") {
                    categoryBookMap[categoryIdStr, default: []].append(bookUUID)
                }
            }

            for row in try db.prepare(categories) {
                let categoryIdStr = row[categoryId]
                guard let categoryUUID = parseUUID(categoryIdStr, context: "categories.id") else { continue }
                let category = Category(
                    id: categoryUUID,
                    name: row[categoryName],
                    iconName: row[categoryIconName],
                    colorHex: row[categoryColorHex],
                    bookIds: categoryBookMap[categoryIdStr] ?? []
                )
                results.append(category)
            }
        } catch {
            log(.fetchFailed(table: "categories", underlying: error), operation: "fetchAllCategories")
        }
        return results
    }

    func deleteCategory(_ category: Category) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let target = categories.filter(categoryId == category.id.uuidString)
            try db.run(target.delete())

            try db.run("DELETE FROM book_category_relations WHERE category_id = ?", category.id.uuidString)
        } catch {
            throw DatabaseError.deleteFailed(table: "categories", underlying: error)
        }
    }

    // MARK: - Chapter Operations

    func insertChapters(_ chaptersList: [Chapter], forBookId bookIdValue: UUID) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let existing = chapters.filter(chapterBookId == bookIdValue.uuidString)
            try db.run(existing.delete())

            try db.transaction {
                for (index, chapter) in chaptersList.enumerated() {
                    let insert = chapters.insert(
                        chapterId <- chapter.id.uuidString,
                        chapterBookId <- bookIdValue.uuidString,
                        chapterTitle <- chapter.title,
                        chapterStartPage <- chapter.startPage,
                        chapterEndPage <- chapter.endPage,
                        chapterOrder <- index
                    )
                    try db.run(insert)
                }
            }
        } catch {
            throw DatabaseError.transactionFailed(underlying: error)
        }
    }

    func fetchChapters(forBookId bookIdValue: UUID) -> [Chapter] {
        guard let db = db else { return [] }

        var results: [Chapter] = []
        do {
            let query = chapters.filter(chapterBookId == bookIdValue.uuidString)
                               .order(chapterOrder)
            for row in try db.prepare(query) {
                guard let chapterUUID = parseUUID(row[chapterId], context: "chapters.id") else { continue }
                let chapter = Chapter(
                    id: chapterUUID,
                    title: row[chapterTitle],
                    startPage: row[chapterStartPage],
                    endPage: row[chapterEndPage]
                )
                results.append(chapter)
            }
        } catch {
            log(.fetchFailed(table: "chapters", underlying: error), operation: "fetchChapters")
        }
        return results
    }

    // MARK: - Bookmark Operations

    func addBookmark(_ bookmark: Bookmark) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let insert = bookmarks.insert(
                bookmarkId <- bookmark.id.uuidString,
                bookmarkBookId <- bookmark.bookId.uuidString,
                bookmarkPage <- bookmark.page,
                bookmarkChapterTitle <- bookmark.chapterTitle,
                bookmarkContent <- bookmark.content,
                bookmarkCreatedAt <- bookmark.createdAt.timeIntervalSince1970
            )
            try db.run(insert)
        } catch {
            throw DatabaseError.insertFailed(table: "bookmarks", underlying: error)
        }
    }

    func removeBookmark(_ bookmark: Bookmark) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let target = bookmarks.filter(bookmarkId == bookmark.id.uuidString)
            try db.run(target.delete())
        } catch {
            throw DatabaseError.deleteFailed(table: "bookmarks", underlying: error)
        }
    }

    func fetchBookmarks(forBookId bookIdValue: UUID) -> [Bookmark] {
        guard let db = db else { return [] }

        var results: [Bookmark] = []
        do {
            let query = bookmarks.filter(bookmarkBookId == bookIdValue.uuidString)
                               .order(bookmarkPage)
            for row in try db.prepare(query) {
                guard let bookmarkUUID = parseUUID(row[bookmarkId], context: "bookmarks.id") else { continue }
                let bookmark = Bookmark(
                    id: bookmarkUUID,
                    bookId: bookIdValue,
                    page: row[bookmarkPage],
                    chapterTitle: row[bookmarkChapterTitle],
                    content: row[bookmarkContent],
                    createdAt: Date(timeIntervalSince1970: row[bookmarkCreatedAt])
                )
                results.append(bookmark)
            }
        } catch {
            log(.fetchFailed(table: "bookmarks", underlying: error), operation: "fetchBookmarks")
        }
        return results
    }

    func isBookmarked(bookId: UUID, page: Int) -> Bool {
        guard let db = db else { return false }

        do {
            let query = bookmarks.filter(bookmarkBookId == bookId.uuidString && bookmarkPage == page)
            return try db.scalar(query.count) > 0
        } catch {
            return false
        }
    }

    // MARK: - Reading Session Operations

    func insertReadingSession(_ session: ReadingSession) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            let insert = readingSessions.insert(
                sessionId <- session.id.uuidString,
                sessionBookId <- session.bookId.uuidString,
                sessionBookTitle <- session.bookTitle,
                sessionStartTime <- session.startTime.timeIntervalSince1970,
                sessionEndTime <- session.endTime.timeIntervalSince1970,
                sessionDuration <- session.duration,
                sessionPagesRead <- session.pagesRead
            )
            try db.run(insert)
        } catch {
            throw DatabaseError.insertFailed(table: "reading_sessions", underlying: error)
        }
    }

    func fetchAllSessions() -> [ReadingSession] {
        guard let db = db else { return [] }

        var results: [ReadingSession] = []
        do {
            for row in try db.prepare(readingSessions.order(sessionStartTime.desc)) {
                if let session = mapReadingSession(from: row) {
                    results.append(session)
                }
            }
        } catch {
            log(.fetchFailed(table: "reading_sessions", underlying: error), operation: "fetchAllSessions")
        }
        return results
    }

    func fetchSessionsForToday() -> [ReadingSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date()).timeIntervalSince1970
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!.timeIntervalSince1970
        return fetchSessions(from: startOfDay, to: endOfDay)
    }

    func fetchSessionsForWeek() -> [ReadingSession] {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: Date())!).timeIntervalSince1970
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!.timeIntervalSince1970
        return fetchSessions(from: startOfWeek, to: endOfDay)
    }

    private func fetchSessions(from start: Double, to end: Double) -> [ReadingSession] {
        guard let db = db else { return [] }

        var results: [ReadingSession] = []
        do {
            let query = readingSessions
                .filter(sessionStartTime >= start && sessionStartTime < end)
                .order(sessionStartTime.desc)
            for row in try db.prepare(query) {
                if let session = mapReadingSession(from: row) {
                    results.append(session)
                }
            }
        } catch {
            log(.fetchFailed(table: "reading_sessions", underlying: error), operation: "fetchSessions(from:to:)")
        }
        return results
    }

    private func mapReadingSession(from row: Row) -> ReadingSession? {
        guard let sessionUUID = parseUUID(row[sessionId], context: "reading_sessions.id"),
              let bookUUID = parseUUID(row[sessionBookId], context: "reading_sessions.book_id") else {
            return nil
        }
        return ReadingSession(
            id: sessionUUID,
            bookId: bookUUID,
            bookTitle: row[sessionBookTitle],
            startTime: Date(timeIntervalSince1970: row[sessionStartTime]),
            endTime: Date(timeIntervalSince1970: row[sessionEndTime]),
            duration: row[sessionDuration],
            pagesRead: row[sessionPagesRead]
        )
    }

    func fetchTotalReadingMinutes() -> Int {
        guard let db = db else { return 0 }

        do {
            let total: Double? = try db.scalar(readingSessions.select(sessionDuration.sum))
            return Int((total ?? 0) / 60)
        } catch {
            log(.fetchFailed(table: "reading_sessions", underlying: error), operation: "fetchTotalReadingMinutes")
            return 0
        }
    }

    func fetchReadingStatistics() -> ReadingStatistics {
        let allSessions = fetchAllSessions()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date()).timeIntervalSince1970
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!.timeIntervalSince1970
        let startOfWeek = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: Date())!).timeIntervalSince1970

        var todayDuration: TimeInterval = 0
        var weekDuration: TimeInterval = 0
        var totalDuration: TimeInterval = 0

        for session in allSessions {
            let start = session.startTime.timeIntervalSince1970
            totalDuration += session.duration
            if start >= startOfDay && start < endOfDay {
                todayDuration += session.duration
            }
            if start >= startOfWeek && start < endOfDay {
                weekDuration += session.duration
            }
        }

        return ReadingStatistics(
            todayMinutes: Int(todayDuration / 60),
            weekMinutes: Int(weekDuration / 60),
            totalMinutes: Int(totalDuration / 60),
            streakDays: computeStreakDays(from: allSessions),
            recentBookStats: computeBookStats(from: allSessions)
        )
    }

    private func computeStreakDays(from sessions: [ReadingSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let calendar = Calendar.current
        var daySet = Set<DateComponents>()
        for session in sessions {
            let comps = calendar.dateComponents([.year, .month, .day], from: session.startTime)
            daySet.insert(comps)
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        if !daySet.contains(calendar.dateComponents([.year, .month, .day], from: cursor)) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while daySet.contains(calendar.dateComponents([.year, .month, .day], from: cursor)) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func computeBookStats(from sessions: [ReadingSession]) -> [BookReadingStat] {
        var grouped: [UUID: (title: String, duration: TimeInterval, lastRead: Date)] = [:]
        for session in sessions {
            if let existing = grouped[session.bookId] {
                grouped[session.bookId] = (
                    title: existing.title,
                    duration: existing.duration + session.duration,
                    lastRead: max(existing.lastRead, session.startTime)
                )
            } else {
                grouped[session.bookId] = (
                    title: session.bookTitle,
                    duration: session.duration,
                    lastRead: session.startTime
                )
            }
        }
        return grouped
            .map { BookReadingStat(id: $0.key, title: $0.value.title, totalDuration: $0.value.duration, lastRead: $0.value.lastRead) }
            .sorted { $0.lastRead > $1.lastRead }
    }

    // MARK: - Relations

    func addBookToCategory(bookId bookIdValue: UUID, categoryId catId: UUID) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            try db.run("INSERT OR IGNORE INTO book_category_relations (book_id, category_id) VALUES (?, ?)",
                       bookIdValue.uuidString, catId.uuidString)
        } catch {
            throw DatabaseError.insertFailed(table: "book_category_relations", underlying: error)
        }
    }

    func removeBookFromCategory(bookId bookIdValue: UUID, categoryId catId: UUID) throws {
        guard let db = db else { throw DatabaseError.connectionFailed(underlying: nil) }

        do {
            try db.run("DELETE FROM book_category_relations WHERE book_id = ? AND category_id = ?",
                       bookIdValue.uuidString, catId.uuidString)
        } catch {
            throw DatabaseError.deleteFailed(table: "book_category_relations", underlying: error)
        }
    }

    // MARK: - Default Categories

    func setupDefaultCategoriesIfNeeded() {
        let existingCategories = fetchAllCategories()
        if existingCategories.isEmpty {
            let defaults = [
                Category(name: "中国古典", iconName: "book.fill", colorHex: "#C45C4A"),
                Category(name: "现代文学", iconName: "pencil", colorHex: "#4A7BC4"),
                Category(name: "外国名著", iconName: "globe", colorHex: "#4A8C6F"),
                Category(name: "诗词歌赋", iconName: "music.note", colorHex: "#C49A4A")
            ]
            for category in defaults {
                try? insertCategory(category)
            }
        } else {
            migrateLegacyCategoryIcons()
        }
    }

    private func migrateLegacyCategoryIcons() {
        guard let db = db else { return }

        let legacyIcons: [(old: String, new: String)] = [
            ("book.open", "book.fill"),
            ("music", "music.note"),
            ("textformat.letterSpacing", "character")
        ]

        for mapping in legacyIcons {
            try? db.run(
                categories.filter(categoryIconName == mapping.old)
                    .update(categoryIconName <- mapping.new)
            )
        }
    }
}
