import Foundation
import ZIPFoundation

/// EPUB-specific parser. Handles EPUB file structure, OPF metadata, and chapter extraction.
struct EpubParser {
    /// Parse an EPUB file and return structured content
    static func parse(at url: URL) async throws -> ParsedBook {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw BookParseError.invalidEpub(underlying: nil)
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
            throw BookParseError.invalidEpubStructure
        }

        // Parse content.opf
        let opfURL = tempDirectory.appendingPathComponent(containerRootfile)
        let opfData = try Data(contentsOf: opfURL)
        let opfBaseURL = opfURL.deletingLastPathComponent()

        guard let opfResult = EPUBXMLParser.parseOPF(from: opfData) else {
            throw BookParseError.invalidOPF
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

        for spineItem in spineItems {
            if let manifestItem = manifest[spineItem],
               let contentURL = URL(string: manifestItem.href, relativeTo: opfBaseURL) {
                if let contentData = try? Data(contentsOf: contentURL),
                   let content = String(data: contentData, encoding: .utf8) {
                    let cleanContent = stripHTML(content)
                    let chapterTitle = extractTitle(from: content) ?? manifestItem.title ?? "Chapter \(chapters.count + 1)"
                    chapters.append(ParsedBook.ParsedChapter(title: chapterTitle, content: cleanContent))
                }
            }
        }

        let totalPages = max(1, chapters.reduce(0) { $0 + PageCalculator.pageCount(for: $1.content) })

        return ParsedBook(
            title: metadata.title ?? url.deletingPathExtension().lastPathComponent,
            author: metadata.author ?? "Unknown",
            chapters: chapters,
            coverImage: coverImage,
            totalPages: totalPages
        )
    }

    // MARK: - Private Helpers

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

    private static func extractCoverImage(
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

    private static func stripHTML(_ html: String) -> String {
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
        result = HTMLEntityDecoder.decode(result)

        // Clean up whitespace
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    private static func extractTitle(from html: String) -> String? {
        let titlePattern = #"<h[12][^>]*>([^<]+)</h[12]>"#
        if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}
