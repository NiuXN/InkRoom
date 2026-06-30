import Foundation
import SwiftUI

struct WidgetBookData: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let author: String
    let currentPage: Int
    let totalPages: Int
    let lastReadDate: Date
    let coverData: Data?
    let currentChapterTitle: String
    
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
    
    var progressText: String {
        String(format: "%.0f%%", progress * 100)
    }
    
    var lastReadText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastReadDate, relativeTo: Date())
    }
}

struct WidgetData: Codable, Sendable {
    let currentBook: WidgetBookData?
    let recentBooks: [WidgetBookData]
    let totalBooks: Int
    let totalReadingMinutes: Int
    
    static let `default` = WidgetData(
        currentBook: nil,
        recentBooks: [],
        totalBooks: 0,
        totalReadingMinutes: 0
    )
}

enum WidgetDataManager {
    static let appGroupIdentifier = "group.com.inkroom.app"
    static let widgetDataKey = "InkRoomWidgetData"
    
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    static func loadWidgetData() -> WidgetData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetDataKey),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .default
        }
        return widgetData
    }
    
    static func saveWidgetData(_ data: WidgetData) {
        guard let defaults = sharedDefaults,
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: widgetDataKey)
    }
}
