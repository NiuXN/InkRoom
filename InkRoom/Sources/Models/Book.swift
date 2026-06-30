import Foundation

struct Book: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var author: String
    var coverImageName: String?
    var filePath: String?
    var totalPages: Int
    var currentPage: Int
    var lastReadDate: Date?
    var categoryIds: [UUID]
    var isFavorite: Bool
    var addedDate: Date

    var readingProgress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }

    var isStarted: Bool {
        currentPage > 0
    }

    var coverImageURL: URL? {
        guard let coverName = coverImageName else { return nil }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("Covers").appendingPathComponent(coverName)
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        coverImageName: String? = nil,
        filePath: String? = nil,
        totalPages: Int = 0,
        currentPage: Int = 0,
        lastReadDate: Date? = nil,
        categoryIds: [UUID] = [],
        isFavorite: Bool = false,
        addedDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverImageName = coverImageName
        self.filePath = filePath
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.lastReadDate = lastReadDate
        self.categoryIds = categoryIds
        self.isFavorite = isFavorite
        self.addedDate = addedDate
    }
}

struct Category: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var bookIds: [UUID]

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        bookIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.bookIds = bookIds
    }
}

struct Chapter: Identifiable, Codable {
    let id: UUID
    var title: String
    var startPage: Int
    var endPage: Int

    init(id: UUID = UUID(), title: String, startPage: Int, endPage: Int) {
        self.id = id
        self.title = title
        self.startPage = startPage
        self.endPage = endPage
    }
}
