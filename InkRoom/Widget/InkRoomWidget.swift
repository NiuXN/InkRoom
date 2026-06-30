import WidgetKit
import SwiftUI

struct InkRoomWidget: Widget {
    let kind: String = "InkRoomWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InkRoomProvider()) { entry in
            InkRoomWidgetView(entry: entry)
                .containerBackground(Color(hex: "#F5F0E8") ?? .white, for: .widget)
        }
        .configurationDisplayName("最近阅读")
        .description("快速继续阅读正在看的书")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge
        ])
    }
}

struct InkRoomEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}

struct InkRoomProvider: TimelineProvider {
    func placeholder(in context: Context) -> InkRoomEntry {
        InkRoomEntry(date: Date(), widgetData: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (InkRoomEntry) -> ()) {
        let data = WidgetDataManager.loadWidgetData()
        let entry = InkRoomEntry(date: Date(), widgetData: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InkRoomEntry>) -> ()) {
        let data = WidgetDataManager.loadWidgetData()
        let entry = InkRoomEntry(date: Date(), widgetData: data)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

extension WidgetData {
    static let sample: WidgetData = {
        let book = WidgetBookData(
            id: "sample-1",
            title: "人间草木",
            author: "汪曾祺",
            currentPage: 87,
            totalPages: 256,
            lastReadDate: Date().addingTimeInterval(-3600),
            coverData: nil,
            currentChapterTitle: "第三章 · 美食美味"
        )
        return WidgetData(
            currentBook: book,
            recentBooks: [book],
            totalBooks: 12,
            totalReadingMinutes: 186
        )
    }()
}
