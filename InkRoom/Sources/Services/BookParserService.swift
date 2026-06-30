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

final class BookParserService {
    static let shared = BookParserService()

    private var parseCache: [String: ParsedBook] = [:]
    private let cacheQueue = DispatchQueue(label: "com.inkroom.parsercache", attributes: .concurrent)
    
    // Cache limits to prevent memory pressure
    private let maxCacheEntries = 20
    private let maxCacheSizeBytes = 50 * 1024 * 1024 // 50 MB
    private var currentCacheSizeBytes: Int = 0

    private init() {}

    // MARK: - Cache
    private func cachedBook(for path: String) -> ParsedBook? {
        cacheQueue.sync { parseCache[path] }
    }

    private func setCache(_ book: ParsedBook, for path: String) {
        cacheQueue.async(flags: .barrier) { 
            // Estimate size of parsed book
            let estimatedSize = book.chapters.reduce(0) { $0 + $1.content.count } + (book.coverImage?.count ?? 0)
            
            // Evict oldest entries if cache would exceed limits
            while self.parseCache.count >= self.maxCacheEntries || self.currentCacheSizeBytes + estimatedSize > self.maxCacheSizeBytes {
                if let (oldestKey, oldestValue) = self.parseCache.first {
                    self.currentCacheSizeBytes -= oldestValue.chapters.reduce(0) { $0 + $1.content.count } + (oldestValue.coverImage?.count ?? 0)
                    self.parseCache.removeValue(forKey: oldestKey)
                } else {
                    break
                }
            }
            
            self.parseCache[path] = book
            self.currentCacheSizeBytes += estimatedSize
        }
    }

    func clearCache(for path: String? = nil) {
        if let path = path {
            cacheQueue.async(flags: .barrier) { 
                if let removed = self.parseCache.removeValue(forKey: path) {
                    self.currentCacheSizeBytes -= removed.chapters.reduce(0) { $0 + $1.content.count } + (removed.coverImage?.count ?? 0)
                }
            }
        } else {
            cacheQueue.async(flags: .barrier) { 
                self.parseCache.removeAll()
                self.currentCacheSizeBytes = 0
            }
        }
    }

    // MARK: - Public Methods
    func parseBook(from url: URL) async throws -> ParsedBook {
        let cacheKey = url.path
        if let cached = cachedBook(for: cacheKey) {
            return cached
        }

        let fileExtension = url.pathExtension.lowercased()
        let parsedBook: ParsedBook

        switch fileExtension {
        case "epub":
            parsedBook = try await parseEpub(at: url)
        case "txt":
            parsedBook = try parseTxt(at: url)
        default:
            throw BookParserError.unsupportedFormat
        }

        setCache(parsedBook, for: cacheKey)
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

    // MARK: - EPUB Parser
    private func parseEpub(at url: URL) async throws -> ParsedBook {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw BookParserError.invalidEpub
        }

        // Extract EPUB to temp directory
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        for entry in archive {
            let entryPath = tempDirectory.appendingPathComponent(entry.path)
            if entry.type == .directory {
                try FileManager.default.createDirectory(at: entryPath, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(at: entryPath.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try archive.extract(entry, to: entryPath)
            }
        }

        // Find and parse container.xml
        let containerPath = tempDirectory.appendingPathComponent("META-INF/container.xml")
        guard let containerData = try? Data(contentsOf: containerPath),
              let containerRootfile = EPUBXMLParser.containerRootPath(from: containerData) else {
            throw BookParserError.invalidEpubStructure
        }

        // Parse content.opf
        let opfURL = tempDirectory.appendingPathComponent(containerRootfile)
        let opfData = try Data(contentsOf: opfURL)
        let opfBaseURL = opfURL.deletingLastPathComponent()

        guard let opfResult = EPUBXMLParser.parseOPF(from: opfData) else {
            throw BookParserError.invalidOPF
        }

        let metadata = OPFMetadata(title: opfResult.title, author: opfResult.author)
        let spineItems = opfResult.spineItemRefs
        var manifest: [String: ManifestItem] = [:]
        for (id, item) in opfResult.manifest {
            manifest[id] = ManifestItem(href: item.href, mediaType: item.mediaType, title: nil, id: item.id)
        }

        // Extract cover image
        let coverImage = extractCoverImage(
            manifest: manifest,
            coverItemId: opfResult.coverItemId,
            baseURL: opfBaseURL,
            archive: archive
        )

        // Parse chapters from spine
        var chapters: [ParsedBook.ParsedChapter] = []
        var contentParts: [String] = []

        for spineItem in spineItems {
            if let manifestItem = manifest[spineItem],
               let contentURL = URL(string: manifestItem.href, relativeTo: opfBaseURL) {
                if let contentData = try? Data(contentsOf: contentURL),
                   let content = String(data: contentData, encoding: .utf8) {
                    let cleanContent = stripHTML(content)
                    let chapterTitle = extractTitle(from: content) ?? manifestItem.title ?? "Chapter \(chapters.count + 1)"
                    chapters.append(ParsedBook.ParsedChapter(title: chapterTitle, content: cleanContent))
                    contentParts.append(cleanContent)
                }
            }
        }

        let totalContent = contentParts.joined()
        // Improved page calculation: account for Chinese (denser) vs English text
        // Chinese chars take ~2x the visual space of English chars
        let chineseCharCount = totalContent.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
        let englishCharCount = totalContent.count - chineseCharCount
        // Weighted: Chinese chars count as 2, English as 1
        let weightedChars = chineseCharCount * 2 + englishCharCount
        let totalPages = max(1, weightedChars / AppConfig.charsPerPage)

        return ParsedBook(
            title: metadata.title ?? url.deletingPathExtension().lastPathComponent,
            author: metadata.author ?? "Unknown",
            chapters: chapters,
            coverImage: coverImage,
            totalPages: totalPages
        )
    }

    private struct OPFMetadata {
        var title: String?
        var author: String?
    }

    private struct ManifestItem {
        var href: String
        var mediaType: String
        var title: String?
        var id: String?
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let named: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")
        ]
        for (entity, char) in named {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        if let decimalRegex = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = decimalRegex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard let codeRange = Range(match.range(at: 1), in: result),
                      let code = Int(result[codeRange]),
                      let scalar = UnicodeScalar(code) else { continue }
                if let fullRange = Range(match.range, in: result) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        if let hexRegex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]+);"#) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = hexRegex.matches(in: result, range: nsRange).reversed()
            for match in matches {
                guard let codeRange = Range(match.range(at: 1), in: result),
                      let code = Int(result[codeRange], radix: 16),
                      let scalar = UnicodeScalar(code) else { continue }
                if let fullRange = Range(match.range, in: result) {
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }

        return result
    }

    private func extractCoverImage(
        manifest: [String: ManifestItem],
        coverItemId: String?,
        baseURL: URL,
        archive: Archive
    ) -> Data? {
        if let coverItemId, let item = manifest[coverItemId] {
            let imageURL = URL(string: item.href, relativeTo: baseURL) ?? baseURL.appendingPathComponent(item.href)
            if let data = try? Data(contentsOf: imageURL) { return data }
        }

        // Find cover image in manifest by filename
        for (_, item) in manifest {
            let lowerHref = item.href.lowercased()
            if lowerHref.contains("cover") && (item.mediaType.contains("image") || lowerHref.hasSuffix(".jpg") || lowerHref.hasSuffix(".png") || lowerHref.hasSuffix(".jpeg")) {
                let imageURL = URL(string: item.href, relativeTo: baseURL) ?? baseURL.appendingPathComponent(item.href)
                return try? Data(contentsOf: imageURL)
            }
        }
        return nil
    }

    private func stripHTML(_ html: String) -> String {
        var result = html

        // Remove scripts and styles
        result = result.replacingOccurrences(of: #"<script[^>]*>[\s\S]*?</script>"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"<style[^>]*>[\s\S]*?</style>"#, with: "", options: .regularExpression)

        // Replace common block elements with newlines
        result = result.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: #"</p>"#, with: "\n\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: #"</div>"#, with: "\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: #"</h[1-6]>"#, with: "\n\n", options: .regularExpression)

        // Remove all HTML tags
        result = result.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)

        // Decode HTML entities
        result = decodeHTMLEntities(result)

        // Clean up whitespace
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    private func extractTitle(from html: String) -> String? {
        // Try to find title in h1, h2 tags
        let titlePattern = #"<h[12][^>]*>([^<]+)</h[12]>"#
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    // MARK: - TXT Parser
    private func parseTxt(at url: URL) throws -> ParsedBook {
        guard let content = TextEncoding.readString(from: url) else {
            throw BookParserError.invalidTxt
        }

        let title = url.deletingPathExtension().lastPathComponent
        let author = "Unknown"

        // Split into chapters (by double newlines or chapter markers)
        let chapters = splitIntoChapters(content)

        // Calculate pages with weighted char count (Chinese chars are denser)
        let chineseCharCount = content.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
        let englishCharCount = content.count - chineseCharCount
        let weightedChars = chineseCharCount * 2 + englishCharCount
        let totalPages = max(1, weightedChars / AppConfig.charsPerPage)

        return ParsedBook(
            title: title,
            author: author,
            chapters: chapters,
            coverImage: nil,
            totalPages: totalPages
        )
    }

    private func splitIntoChapters(_ content: String) -> [ParsedBook.ParsedChapter] {
        var chapters: [ParsedBook.ParsedChapter] = []
        let lines = content.components(separatedBy: .newlines)

        var currentChapter: ParsedBook.ParsedChapter?
        var currentContent = ""
        var foundFirstChapter = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                currentContent += "\n"
                continue
            }

            if isChapterTitle(trimmed) {
                foundFirstChapter = true
                if !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || currentChapter != nil {
                    chapters.append(ParsedBook.ParsedChapter(
                        title: currentChapter?.title ?? "正文",
                        content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
                currentChapter = ParsedBook.ParsedChapter(title: trimmed, content: "")
                currentContent = ""
            } else {
                if !foundFirstChapter && !trimmed.isEmpty {
                    // Content before first chapter - treat as preface
                    if currentChapter == nil {
                        currentChapter = ParsedBook.ParsedChapter(title: "前言", content: "")
                    }
                }
                currentContent += trimmed + "\n"
            }
        }

        // Add last chapter
        if !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || currentChapter != nil {
            chapters.append(ParsedBook.ParsedChapter(
                title: currentChapter?.title ?? "正文",
                content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }

        // If no chapters were found, create one chapter with all content
        if chapters.isEmpty {
            chapters.append(ParsedBook.ParsedChapter(title: "正文", content: content))
        }

        return chapters
    }

    private func isChapterTitle(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Chapter titles are usually short (less than 30 chars)
        guard trimmed.count <= 30 else { return false }

        let patterns = [
            #"^第[一二三四五六七八九十百千万零\d]+[章回节卷集部篇]"#,
            #"^Chapter\s*\d+"#,
            #"^CHAPTER\s*\d+"#,
            #"^第\s*\d+\s*[章回节卷集部篇]"#,
            #"^[一二三四五六七八九十百千万]+、"#,
            #"^\d+\s*[.、]．"#,
            #"^序[一二三四五六七八九十\d]?$"#,
            #"^楔子$"#,
            #"^引子$"#,
            #"^尾声$"#,
            #"^后记$"#,
            #"^前言$"#,
            #"^序曲$"#,
            #"^终章$"#,
            #"^番外[一二三四五六七八九十\d]?$"#,
            #"^【[^】]+】$"#,
            #"^《[^》]+》$"#,
            #"^[（(][^)）]+[)）]$"#,
            #"^卷[一二三四五六七八九十百千万\d]+"#,
            #"^Part\s*\d+"#,
            #"^PART\s*\d+"#,
            #"^Book\s*\d+"#,
            #"^BOOK\s*\d+"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - Chapter Content
    func getChapters(for book: Book) async -> [Chapter] {
        guard let filePath = book.filePath else {
            return []
        }
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let parsedBook = try await parseBook(from: fileURL)
            var chapters: [Chapter] = []
            var currentPage = 1

            for parsedChapter in parsedBook.chapters {
                let chapterPages = max(1, parsedChapter.content.count / 500)
                let chapter = Chapter(
                    title: parsedChapter.title,
                    startPage: currentPage,
                    endPage: currentPage + chapterPages - 1
                )
                chapters.append(chapter)
                currentPage += chapterPages
            }

            return chapters
        } catch {
            print("Failed to parse chapters: \(error)")
            return []
        }
    }

    func getChapterContent(for book: Book, page: Int) async -> String? {
        guard page >= 1, let filePath = book.filePath else { return nil }
        let fileURL = URL(fileURLWithPath: filePath)

        do {
            let parsedBook = try await parseBook(from: fileURL)
            var chapterStartPage = 1

            for parsedChapter in parsedBook.chapters {
                let chapterContent = parsedChapter.content
                let charsPerPage = 500
                let chapterPages = max(1, chapterContent.count / charsPerPage)
                let chapterEndPage = chapterStartPage + chapterPages - 1

                if page >= chapterStartPage && page <= chapterEndPage {
                    let pageOffset = page - chapterStartPage
                    let startIndex = chapterContent.index(
                        chapterContent.startIndex,
                        offsetBy: pageOffset * charsPerPage,
                        limitedBy: chapterContent.endIndex
                    ) ?? chapterContent.startIndex
                    let endIndex = chapterContent.index(
                        startIndex,
                        offsetBy: charsPerPage,
                        limitedBy: chapterContent.endIndex
                    ) ?? chapterContent.endIndex
                    return String(chapterContent[startIndex..<endIndex])
                }
                chapterStartPage += chapterPages
            }
            return nil
        } catch {
            print("Failed to get chapter content: \(error)")
            return nil
        }
    }

    func getChapterContent(for chapterIndex: Int, from filePath: String, charsPerPage: Int = 500) async throws -> String? {
        let fileURL = URL(fileURLWithPath: filePath)
        let parsedBook = try await parseBook(from: fileURL)
        guard chapterIndex >= 0 && chapterIndex < parsedBook.chapters.count else { return nil }
        return parsedBook.chapters[chapterIndex].content
    }
}

// MARK: - Errors
enum BookParserError: Error, LocalizedError {
    case unsupportedFormat
    case invalidEpub
    case invalidEpubStructure
    case invalidOPF
    case invalidTxt
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "不支持的文件格式"
        case .invalidEpub:
            return "无效的 EPUB 文件"
        case .invalidEpubStructure:
            return "EPUB 文件结构错误"
        case .invalidOPF:
            return "无法解析 EPUB 元数据"
        case .invalidTxt:
            return "无法读取文本文件"
        case .parsingFailed(let message):
            return "解析失败: \(message)"
        }
    }
}
