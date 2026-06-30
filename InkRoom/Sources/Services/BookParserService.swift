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

    private init() {}

    // MARK: - Cache
    private func cachedBook(for path: String) -> ParsedBook? {
        cacheQueue.sync { parseCache[path] }
    }

    private func setCache(_ book: ParsedBook, for path: String) {
        cacheQueue.async(flags: .barrier) { self.parseCache[path] = book }
    }

    func clearCache(for path: String? = nil) {
        if let path = path {
            cacheQueue.async(flags: .barrier) { self.parseCache.removeValue(forKey: path) }
        } else {
            cacheQueue.async(flags: .barrier) { self.parseCache.removeAll() }
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
              let containerRootfile = parseContainerXML(containerData) else {
            throw BookParserError.invalidEpubStructure
        }

        // Parse content.opf
        let opfURL = tempDirectory.appendingPathComponent(containerRootfile)
        let opfData = try Data(contentsOf: opfURL)
        let opfBaseURL = opfURL.deletingLastPathComponent()

        let (metadata, spineItems, manifest) = try parseOPF(opfData, baseURL: opfBaseURL)

        // Extract cover image
        let coverImage = extractCoverImage(manifest: manifest, baseURL: opfBaseURL, archive: archive)

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
        let totalPages = max(1, totalContent.count / 500)

        return ParsedBook(
            title: metadata.title ?? url.deletingPathExtension().lastPathComponent,
            author: metadata.author ?? "Unknown",
            chapters: chapters,
            coverImage: coverImage,
            totalPages: totalPages
        )
    }

    private func parseContainerXML(_ data: Data) -> String? {
        guard let xmlString = String(data: data, encoding: .utf8) else { return nil }

        // Simple XML parsing for rootfile path
        let pattern = #"full-path=\"([^\"]+)\""#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
           let range = Range(match.range(at: 1), in: xmlString) {
            return String(xmlString[range])
        }
        return nil
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

    private func parseManifestItems(from xmlString: String) -> [String: ManifestItem] {
        var manifest: [String: ManifestItem] = [:]
        let itemPattern = #"<item\s+([^>/]+)/?>"#
        guard let regex = try? NSRegularExpression(pattern: itemPattern, options: .caseInsensitive) else {
            return manifest
        }

        for match in regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)) {
            guard let attrRange = Range(match.range(at: 1), in: xmlString) else { continue }
            let attrs = String(xmlString[attrRange])
            guard let id = extractXMLAttribute("id", from: attrs),
                  let href = extractXMLAttribute("href", from: attrs) else { continue }
            let mediaType = extractXMLAttribute("media-type", from: attrs)
                ?? extractXMLAttribute("mediaType", from: attrs)
                ?? "application/xhtml+xml"
            manifest[id] = ManifestItem(href: href, mediaType: mediaType, title: nil, id: id)
        }
        return manifest
    }

    private func extractXMLAttribute(_ name: String, from attrs: String) -> String? {
        let pattern = "\(name)=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)),
              let range = Range(match.range(at: 1), in: attrs) else {
            return nil
        }
        return String(attrs[range])
    }

    private func parseOPF(_ data: Data, baseURL: URL) throws -> (OPFMetadata, [String], [String: ManifestItem]) {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw BookParserError.invalidOPF
        }

        var metadata = OPFMetadata()
        var spineItems: [String] = []
        var manifest: [String: ManifestItem] = [:]

        // Parse title
        if let titleMatch = xmlString.range(of: #"<dc:title[^>]*>([^<]+)</dc:title>"#, options: .regularExpression) {
            let titleString = String(xmlString[titleMatch])
            if let contentMatch = titleString.range(of: ">([^<]+)<", options: .regularExpression) {
                let content = String(titleString[contentMatch]).dropFirst().dropLast()
                metadata.title = String(content)
            }
        }

        // Parse author/creator
        if let authorMatch = xmlString.range(of: #"<dc:creator[^>]*>([^<]+)</dc:creator>"#, options: .regularExpression) {
            let authorString = String(xmlString[authorMatch])
            if let contentMatch = authorString.range(of: ">([^<]+)<", options: .regularExpression) {
                let content = String(authorString[contentMatch]).dropFirst().dropLast()
                metadata.author = String(content)
            }
        }

        manifest = parseManifestItems(from: xmlString)

        // Parse spine
        let spinePattern = #"<itemref[^>]+idref=\"([^\"]+)\""#
        if let regex = try? NSRegularExpression(pattern: spinePattern) {
            let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: xmlString) {
                    spineItems.append(String(xmlString[idRange]))
                }
            }
        }

        return (metadata, spineItems, manifest)
    }

    private func extractCoverImage(manifest: [String: ManifestItem], baseURL: URL, archive: Archive) -> Data? {
        // Find cover image in manifest
        for (_, item) in manifest {
            let lowerHref = item.href.lowercased()
            if lowerHref.contains("cover") && (item.mediaType.contains("image") || lowerHref.hasSuffix(".jpg") || lowerHref.hasSuffix(".png") || lowerHref.hasSuffix(".jpeg")) {
                let imageURL = baseURL.appendingPathComponent(item.href)
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
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")

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

        // Calculate pages
        let totalPages = max(1, content.count / 500)

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
