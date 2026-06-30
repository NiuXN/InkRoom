import Foundation

enum BookGroup: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case all = "全部"
    case reading = "在读"
    case completed = "已读完"
    case favorites = "收藏"

    var icon: String {
        switch self {
        case .all: return "books.vertical"
        case .reading: return "book"
        case .completed: return "checkmark.circle"
        case .favorites: return "heart"
        }
    }
}

enum BookFilter {
    static func count(in books: [Book], for group: BookGroup) -> Int {
        filter(books, group: group, searchText: "").count
    }

    static func filter(_ books: [Book], group: BookGroup, searchText: String) -> [Book] {
        var result = books

        switch group {
        case .all:
            break
        case .reading:
            result = result.filter { $0.isStarted && $0.readingProgress < 1.0 }
        case .completed:
            result = result.filter { $0.readingProgress >= 1.0 }
        case .favorites:
            result = result.filter { $0.isFavorite }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }

        result.sort { ($0.lastReadDate ?? $0.addedDate) > ($1.lastReadDate ?? $1.addedDate) }
        return result
    }
}

enum InkRoomErrorMessage {
    static func friendly(for error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("sqlite") || description.contains("database") {
            return "数据操作失败，请稍后重试"
        }
        if description.contains("epub") || description.contains("zip") {
            return "文件解析失败，请检查文件格式是否正确"
        }
        if description.contains("disk") || description.contains("space") || description.contains("write") {
            return "存储空间不足，请清理后重试"
        }
        if description.contains("encoding") || description.contains("utf") {
            return "文件编码不支持，请转换为 UTF-8 编码"
        }
        if description.contains("not found") || description.contains("exist") {
            return "文件不存在或已被移除"
        }
        if description.contains("permission") || description.contains("denied") {
            return "没有访问权限，请检查文件权限设置"
        }

        return "操作失败，请稍后重试"
    }
}
