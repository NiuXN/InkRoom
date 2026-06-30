import Foundation

/// TXT-specific parser. Handles plain text files with chapter detection.
struct TxtParser {
    /// Parse a TXT file and return structured content
    static func parse(at url: URL) throws -> ParsedBook {
        guard let content = TextEncoding.readString(from: url) else {
            throw BookParseError.invalidTxt(underlying: nil)
        }

        let title = url.deletingPathExtension().lastPathComponent
        let author = "Unknown"

        // Split into chapters (by double newlines or chapter markers)
        let chapters = splitIntoChapters(content)

        let totalPages = max(1, chapters.reduce(0) { $0 + PageCalculator.pageCount(for: $1.content) })

        return ParsedBook(
            title: title,
            author: author,
            chapters: chapters,
            coverImage: nil,
            totalPages: totalPages
        )
    }

    // MARK: - Chapter Splitting

    private static func splitIntoChapters(_ content: String) -> [ParsedBook.ParsedChapter] {
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

    private static func isChapterTitle(_ line: String) -> Bool {
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
}
