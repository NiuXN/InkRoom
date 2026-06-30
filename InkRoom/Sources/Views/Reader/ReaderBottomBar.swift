import SwiftUI

struct ReaderCompactBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let isSpeaking: Bool
    let textColor: Color
    let backgroundColor: Color
    
    var onPrevPage: () -> Void
    var onNextPage: () -> Void
    var onToggleTTS: () -> Void
    var onShowSettings: () -> Void
    
    private var safeAreaBottom: CGFloat {
        #if os(iOS)
        return (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom) ?? 34
        #else
        return 0
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ProgressBar(
                progress: totalPages > 0 ? Double(currentPage) / Double(totalPages) : 0,
                height: 2
            )

            HStack {
                Button {
                    onPrevPage()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一页")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(currentPage > 1 ? textColor : textColor.opacity(0.3))
                }
                .disabled(currentPage <= 1)
                .accessibilityLabel("上一页")

                Spacer()

                Button {
                    onToggleTTS()
                } label: {
                    Image(systemName: isSpeaking ? "headphones.circle.fill" : "headphones")
                        .font(.system(size: 20))
                        .foregroundStyle(isSpeaking ? Color.inkRoomPrimary : textColor)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(isSpeaking ? "停止听书" : "开始听书")

                Spacer()

                Button {
                    onShowSettings()
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 18))
                        .foregroundStyle(textColor)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("阅读设置")

                Spacer()

                Button {
                    onNextPage()
                } label: {
                    HStack(spacing: 4) {
                        Text("下一页")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(currentPage < totalPages ? textColor : textColor.opacity(0.3))
                }
                .disabled(currentPage >= totalPages)
                .accessibilityLabel("下一页")
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, safeAreaBottom)
        .background(backgroundColor.opacity(0.95))
    }
}

struct ReaderExpandedBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let textColor: Color
    let backgroundColor: Color
    
    var onPrevPage: () -> Void
    var onNextPage: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ProgressBar(
                progress: totalPages > 0 ? Double(currentPage) / Double(totalPages) : 0,
                height: 2
            )

            HStack {
                Button {
                    onPrevPage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("上一页")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(currentPage > 1 ? textColor : textColor.opacity(0.3))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(textColor.opacity(0.08))
                    .cornerRadius(8)
                }
                .disabled(currentPage <= 1)
                .accessibilityLabel("上一页")

                Spacer()

                Text("\(currentPage) / \(totalPages)")
                    .font(.system(size: 13))
                    .foregroundStyle(textColor.opacity(0.7))

                Spacer()

                Button {
                    onNextPage()
                } label: {
                    HStack(spacing: 6) {
                        Text("下一页")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(currentPage < totalPages ? textColor : textColor.opacity(0.3))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(textColor.opacity(0.08))
                    .cornerRadius(8)
                }
                .disabled(currentPage >= totalPages)
                .accessibilityLabel("下一页")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(backgroundColor.opacity(0.95))
    }
}
