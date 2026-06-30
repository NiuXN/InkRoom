import Foundation
import ZIPFoundation

struct ParsedBook {
    let title: String
    let author: String
    let chapters: [ParsedChapter]
    let coverImage: Data?
    let totalPages: Int

    struct ParsedChapter {
        let title: String
        let content: String
    }
}

/// 书籍解析服务：根据文件类型分派到 `EpubParser` / `TxtParser`，
/// 并通过 `BookParserCache` 缓存解析结果，避免重复解析。
///
/// 实现为 `actor`，解析等重计算在自身执行器上运行，不阻塞主线程。
/// 所有页数计算统一走 `PageCalculator`，确保 `ParsedBook.totalPages`
/// 与各章节页数之和一致。
actor BookParserService {
    static let shared = BookParserService()

    private init() {}

    // MARK: - Public

    func parseBook(from url: URL) async throws -> ParsedBook {
        let cacheKey = url.path
        if let cached = BookParserCache.shared.book(for: cacheKey) {
            return cached
        }

        let fileExtension = url.pathExtension.lowercased()
        let parsedBook: ParsedBook

        switch fileExtension {
        case "epub":
            parsedBook = try await EpubParser.parse(at: url)
        case "txt":
            parsedBook = try TxtParser.parse(at: url)
        default:
            throw BookParseError.unsupportedFormat(extension: fileExtension)
        }

        BookParserCache.shared.set(parsedBook, for: cacheKey)
        return parsedBook
    }

    func importBook(from sourceURL: URL, copyFile: Bool = true) async throws -> Book {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let booksDirectory = documentsPath.appendingPathComponent("Books", isDirectory: true)
        let coversDirectory = documentsPath.appendingPathComponent("Covers", isDirectory: true)

        try FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: coversDirectory, withIntermediateDirectories: true)

        let destinationURL: URL
        if copyFile {
            var targetURL = booksDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                let base = sourceURL.deletingPathExtension().lastPathComponent
                let ext = sourceURL.pathExtension
                targetURL = booksDirectory.appendingPathComponent("\(base)-\(UUID().uuidString.prefix(8)).\(ext)")
            }
            _ = try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            destinationURL = targetURL
        } else {
            destinationURL = sourceURL
        }

        let parsedBook = try await parseBook(from: destinationURL)

        var coverFileName: String?
        if let coverData = parsedBook.coverImage {
            let fileName = UUID().uuidString + ".jpg"
            let coverURL = coversDirectory.appendingPathComponent(fileName)
            try coverData.write(to: coverURL)
            coverFileName = fileName
        }

        let book = Book(
            title: parsedBook.title,
            author: parsedBook.author,
            coverImageName: coverFileName,
            filePath: destinationURL.path,
            totalPages: parsedBook.totalPages,
            currentPage: 0,
            lastReadDate: nil,
            categoryIds: [],
            isFavorite: false,
            addedDate: Date()
        )

        return book
    }

    // MARK: - Chapter Access

    /// 根据书籍元数据生成章节列表（含页码范围）。
    /// 页数计算与 `parseBook` 完全一致，保证目录跳转与翻页不越界。
    func getChapters(for book: Book) async -> [Chapter] {
        guard let filePath = book.filePath else { return [] }
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let parsedBook = try await parseBook(from: fileURL)
            return buildChapters(from: parsedBook.chapters)
        } catch {
            print("[BookParserService] Failed to parse chapters: \(error)")
            return []
        }
    }

    /// 取指定页所属章节的内容片段。
    func getChapterContent(for book: Book, page: Int) async -> String? {
        guard page >= 1, let filePath = book.filePath else { return nil }
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let parsedBook = try await parseBook(from: fileURL)
            return content(at: page, in: buildChapters(from: parsedBook.chapters), parsed: parsedBook)
        } catch {
            print("[BookParserService] Failed to get chapter content: \(error)")
            return nil
        }
    }

    /// 取整章内容（用于阅读器预加载整章后再自行切分）。
    /// `charsPerPage` 仅用于兼容旧接口，当其大于章节内容权重时返回整章。
    func getChapterContent(for chapterIndex: Int, from filePath: String, charsPerPage: Int = 500) async throws -> String? {
        let fileURL = URL(fileURLWithPath: filePath)
        let parsedBook = try await parseBook(from: fileURL)
        guard chapterIndex >= 0 && chapterIndex < parsedBook.chapters.count else { return nil }
        return parsedBook.chapters[chapterIndex].content
    }

    // MARK: - Cache

    /// 清理解析缓存。`nonisolated` 因为 `BookParserCache` 自身线程安全，可从任意上下文调用。
    nonisolated func clearCache(for path: String? = nil) {
        BookParserCache.shared.clear(for: path)
    }

    // MARK: - Helpers

    /// 把解析出的章节列表转换为带页码范围的 `Chapter`，页数由 `PageCalculator` 统一计算。
    private func buildChapters(from parsedChapters: [ParsedBook.ParsedChapter]) -> [Chapter] {
        var chapters: [Chapter] = []
        var currentPage = 1

        for parsedChapter in parsedChapters {
            let chapterPages = PageCalculator.pageCount(for: parsedChapter.content)
            chapters.append(Chapter(
                title: parsedChapter.title,
                startPage: currentPage,
                endPage: currentPage + chapterPages - 1
            ))
            currentPage += chapterPages
        }
        return chapters
    }

    /// 在分页后的章节中定位指定页的内容。
    private func content(at page: Int, in chapters: [Chapter], parsed: ParsedBook) -> String? {
        for (index, chapter) in chapters.enumerated() {
            guard page >= chapter.startPage, page <= chapter.endPage,
                  index < parsed.chapters.count else { continue }
            let pages = PageCalculator.paginate(parsed.chapters[index].content)
            let pageOffset = page - chapter.startPage
            if pageOffset >= 0 && pageOffset < pages.count {
                return pages[pageOffset]
            }
            return pages.last
        }
        return nil
    }
}
