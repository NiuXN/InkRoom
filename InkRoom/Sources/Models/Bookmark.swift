import Foundation

struct Bookmark: Identifiable, Codable, Hashable {
    let id: UUID
    let bookId: UUID
    let page: Int
    let chapterTitle: String
    let content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        bookId: UUID,
        page: Int,
        chapterTitle: String,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.page = page
        self.chapterTitle = chapterTitle
        self.content = content
        self.createdAt = createdAt
    }
}
