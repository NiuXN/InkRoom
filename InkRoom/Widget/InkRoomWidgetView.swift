import SwiftUI
import WidgetKit

struct InkRoomWidgetView: View {
    let entry: InkRoomEntry
    
    @Environment(\.widgetFamily) private var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(book: entry.widgetData.currentBook, totalBooks: entry.widgetData.totalBooks)
        case .systemMedium:
            MediumWidgetView(book: entry.widgetData.currentBook, totalBooks: entry.widgetData.totalBooks)
        case .systemLarge:
            LargeWidgetView(data: entry.widgetData)
        default:
            SmallWidgetView(book: entry.widgetData.currentBook, totalBooks: entry.widgetData.totalBooks)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let book: WidgetBookData?
    let totalBooks: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.inkRoomPrimary)
                
                Spacer()
                
                if let book = book {
                    Text(book.progressText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.inkRoomPrimary)
                }
            }
            
            if let book = book {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.inkRoomTextPrimary)
                        .lineLimit(1)
                    
                    Text(book.author)
                        .font(.system(size: 12))
                        .foregroundColor(.inkRoomTextSecondary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 4)
                    
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                        .tint(.inkRoomPrimary)
                    
                    Text(book.lastReadText)
                        .font(.system(size: 10))
                        .foregroundColor(.inkRoomTextTertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("开始阅读")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.inkRoomTextPrimary)
                    
                    Text("共 \(totalBooks) 本书")
                        .font(.system(size: 12))
                        .foregroundColor(.inkRoomTextSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "book.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.inkRoomTextTertiary)
                }
            }
        }
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let book: WidgetBookData?
    let totalBooks: Int
    
    var body: some View {
        HStack(spacing: 16) {
            if let book = book {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.inkRoomPrimary)
                        
                        Text("最近阅读")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.inkRoomTextSecondary)
                        
                        Spacer()
                        
                        Text(book.progressText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.inkRoomPrimary)
                    }
                    
                    Spacer(minLength: 4)
                    
                    Text(book.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.inkRoomTextPrimary)
                        .lineLimit(1)
                    
                    Text(book.author)
                        .font(.system(size: 13))
                        .foregroundColor(.inkRoomTextSecondary)
                        .lineLimit(1)
                    
                    if !book.currentChapterTitle.isEmpty {
                        Text(book.currentChapterTitle)
                            .font(.system(size: 12))
                            .foregroundColor(.inkRoomTextTertiary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 4)
                    
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                        .tint(.inkRoomPrimary)
                    
                    HStack {
                        Text(book.lastReadText + "阅读")
                            .font(.system(size: 11))
                            .foregroundColor(.inkRoomTextTertiary)
                        
                        Spacer()
                        
                        Text("继续阅读")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.inkRoomPrimary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.inkRoomPrimary)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.inkRoomPrimary)
                        
                        Text("墨斋")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.inkRoomTextSecondary)
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Text("开启阅读之旅")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.inkRoomTextPrimary)
                    
                    Text("书架上共 \(totalBooks) 本书")
                        .font(.system(size: 13))
                        .foregroundColor(.inkRoomTextSecondary)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Image(systemName: "book.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.inkRoomPrimary.opacity(0.3))
                    }
                }
            }
        }
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let data: WidgetData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.inkRoomPrimary)
                
                Text("墨斋")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.inkRoomTextPrimary)
                
                Spacer()
                
                Text("\(data.totalBooks) 本藏书")
                    .font(.system(size: 12))
                    .foregroundColor(.inkRoomTextSecondary)
            }
            
            if let book = data.currentBook {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.inkRoomTextPrimary)
                                .lineLimit(1)
                            
                            Text(book.author)
                                .font(.system(size: 13))
                                .foregroundColor(.inkRoomTextSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .stroke(Color.inkRoomPrimary.opacity(0.2), lineWidth: 4)
                                .frame(width: 56, height: 56)
                            
                            Circle()
                                .trim(from: 0, to: book.progress)
                                .stroke(Color.inkRoomPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 56, height: 56)
                                .rotationEffect(.degrees(-90))
                            
                            Text(book.progressText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.inkRoomPrimary)
                        }
                    }
                    
                    if !book.currentChapterTitle.isEmpty {
                        Text(book.currentChapterTitle)
                            .font(.system(size: 13))
                            .foregroundColor(.inkRoomTextSecondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text(book.lastReadText + "阅读")
                            .font(.system(size: 12))
                            .foregroundColor(.inkRoomTextTertiary)
                        
                        Spacer()
                        
                        Text("继续阅读")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.inkRoomPrimary)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.inkRoomPrimary)
                    }
                }
                .padding(12)
                .background(Color.inkRoomCard)
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("最近阅读")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.inkRoomTextSecondary)
                
                if data.recentBooks.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "books.vertical")
                                .font(.system(size: 28))
                                .foregroundColor(.inkRoomTextTertiary)
                            Text("暂无阅读记录")
                                .font(.system(size: 13))
                                .foregroundColor(.inkRoomTextTertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(data.recentBooks.prefix(3)) { book in
                            BookRow(book: book)
                            
                            if book.id != data.recentBooks.prefix(3).last?.id {
                                Divider()
                                    .background(Color.inkRoomTextTertiary.opacity(0.1))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.inkRoomCard)
                    .cornerRadius(12)
                }
            }
            
            Spacer(minLength: 0)
        }
    }
}

struct BookRow: View {
    let book: WidgetBookData
    
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.inkRoomPrimary.opacity(0.15))
                .frame(width: 32, height: 44)
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.inkRoomPrimary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.inkRoomTextPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                        .tint(.inkRoomPrimary)
                        .frame(maxWidth: .infinity)
                    
                    Text(book.progressText)
                        .font(.system(size: 10))
                        .foregroundColor(.inkRoomTextTertiary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
