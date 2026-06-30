import Foundation
import SwiftUI

// Book type is defined in Models/Book.swift - this utility operates on Book arrays
// The actual Book struct is in the same module so it's available at compile time

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

enum BookSortOption: String, CaseIterable, Identifiable {
    case recentRead = "最近阅读"
    case addedDate = "导入时间"
    case title = "书名"
    case author = "作者"
    case progress = "阅读进度"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recentRead: return "clock.arrow.circlepath"
        case .addedDate: return "square.and.arrow.down"
        case .title: return "textformat"
        case .author: return "person"
        case .progress: return "chart.bar"
        }
    }

    /// 该排序项默认是否升序。
    var defaultAscending: Bool {
        switch self {
        case .title, .author: return true
        case .recentRead, .addedDate, .progress: return false
        }
    }
}

enum BookFilter {
    static func count(in books: [Book], for group: BookGroup) -> Int {
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
        return result.count
    }

    static func filter(
        _ books: [Book],
        group: BookGroup,
        searchText: String,
        sortBy: BookSortOption = .recentRead,
        ascending: Bool? = nil
    ) -> [Book] {
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

        let isAscending = ascending ?? sortBy.defaultAscending
        return sort(result, by: sortBy, ascending: isAscending)
    }

    static func sort(_ books: [Book], by option: BookSortOption, ascending: Bool) -> [Book] {
        books.sorted { lhs, rhs in
            let ordered: Bool
            switch option {
case .recentRead:
                let left = lhs.lastReadDate ?? .distantPast
                let right = rhs.lastReadDate ?? .distantPast
                ordered = left < right
            case .addedDate:
                ordered = lhs.addedDate < rhs.addedDate
            case .title:
                ordered = lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .author:
                ordered = lhs.author.localizedStandardCompare(rhs.author) == .orderedAscending
            case .progress:
                ordered = lhs.readingProgress < rhs.readingProgress
            }
            return ascending ? ordered : !ordered
        }
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
