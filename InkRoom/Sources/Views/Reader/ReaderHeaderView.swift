import SwiftUI

struct ReaderCompactHeader: View {
    let book: Book
    let currentPage: Int
    let totalPages: Int
    let isBookmarked: Bool
    let textColor: Color
    let backgroundColor: Color
    
    @Environment(\.dismiss) private var dismiss
    
    var onToggleBookmark: () -> Void
    var onShowToc: () -> Void
    
    private var safeAreaTop: CGFloat {
        #if os(iOS)
        return (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top) ?? 44
        #else
        return 0
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(textColor)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("关闭阅读器")

                Spacer()

                VStack(spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(textColor)

                    Text("第 \(currentPage) / \(totalPages) 页")
                        .font(.system(size: 11))
                        .foregroundStyle(textColor.opacity(0.6))
                }

                Spacer()

                Button {
                    onToggleBookmark()
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isBookmarked ? Color.inkRoomPrimary : textColor)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isBookmarked ? "取消书签" : "添加书签")

                Button {
                    onShowToc()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(textColor)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("打开目录")
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            ProgressBar(
                progress: totalPages > 0 ? Double(currentPage) / Double(totalPages) : 0,
                height: 2
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .padding(.top, safeAreaTop)
        .background(backgroundColor.opacity(0.95))
    }
}

struct ReaderExpandedToolbar: View {
    let book: Book
    let currentPage: Int
    let totalPages: Int
    let isBookmarked: Bool
    let isSpeaking: Bool
    let textColor: Color
    
    @Environment(\.dismiss) private var dismiss
    @Binding var showSettings: Bool
    
    var onToggleBookmark: () -> Void
    var onToggleTTS: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(textColor)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("返回书架")

            Spacer()

            VStack(spacing: 2) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(textColor)

                Text("第 \(currentPage) / \(totalPages) 页")
                    .font(.system(size: 11))
                    .foregroundStyle(textColor.opacity(0.6))
            }

            Spacer()

            Button {
                onToggleBookmark()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isBookmarked ? Color.inkRoomPrimary : textColor)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(isBookmarked ? "取消书签" : "添加书签")

            Button {
                onToggleTTS()
            } label: {
                Image(systemName: isSpeaking ? "headphones.circle.fill" : "headphones")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSpeaking ? Color.inkRoomPrimary : textColor)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(isSpeaking ? "停止听书" : "开始听书")

            Menu {
                Button {
                    showSettings.toggle()
                } label: {
                    Label("阅读设置", systemImage: "textformat.size")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(textColor)
                    .frame(width: 40, height: 40)
            }
            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                ReaderSettingsPopover()
            }
            .accessibilityLabel("更多选项")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}
