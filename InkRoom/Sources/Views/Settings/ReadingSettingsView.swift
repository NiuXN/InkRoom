import SwiftUI

struct ReadingSettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Preview Card
                previewCard

                // Font Size
                settingsSection(
                    title: "字号",
                    icon: "textformat.size"
                ) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("A")
                                .font(.system(size: 14))
                            Spacer()
                            Text("A")
                                .font(.system(size: 24))
                        }
                        .foregroundColor(.inkRoomTextTertiary)

                        Slider(
                            value: Binding(
                                get: { Double(settingsViewModel.readingFontSize) },
                                set: { settingsViewModel.readingFontSize = Int($0) }
                            ),
                            in: 12...28,
                            step: 1
                        )
                        .tint(.inkRoomPrimary)

                        HStack {
                            Text("小")
                                .font(.system(size: 11))
                                .foregroundColor(.inkRoomTextTertiary)
                            Spacer()
                            Text("当前: \(settingsViewModel.readingFontSize)pt")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.inkRoomPrimary)
                            Spacer()
                            Text("大")
                                .font(.system(size: 11))
                                .foregroundColor(.inkRoomTextTertiary)
                        }
                    }
                }

                // Line Spacing
                settingsSection(
                    title: "行距",
                    icon: "text.alignleft"
                ) {
                    VStack(spacing: 12) {
                        Slider(
                            value: Binding(
                                get: { Double(settingsViewModel.readingLineSpacing) },
                                set: { settingsViewModel.readingLineSpacing = Int($0) }
                            ),
                            in: 0...15,
                            step: 1
                        )
                        .tint(.inkRoomPrimary)

                        HStack {
                            Text("紧凑")
                                .font(.system(size: 11))
                                .foregroundColor(.inkRoomTextTertiary)
                            Spacer()
                            Text("当前: \(settingsViewModel.readingLineSpacing)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.inkRoomPrimary)
                            Spacer()
                            Text("宽松")
                                .font(.system(size: 11))
                                .foregroundColor(.inkRoomTextTertiary)
                        }
                    }
                }

                // Letter Spacing
                settingsSection(
                    title: "字距",
                    icon: "character"
                ) {
                    VStack(spacing: 12) {
                        Slider(
                            value: Binding(
                                get: { Double(settingsViewModel.readingLetterSpacing) },
                                set: { settingsViewModel.readingLetterSpacing = Int($0) }
                            ),
                            in: -2...8,
                            step: 1
                        )
                        .tint(.inkRoomPrimary)

                        HStack {
                            Text("紧凑")
                                .font(.system(size: 11))
                                .foregroundColor(.inkRoomTextTertiary)
                            Spacer()
                            Text("当前: \(settingsViewModel.readingLetterSpacing)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.inkRoomPrimary)
                            Spacer()
                            Text("宽松")
                                .font(.system(size: 11))
                                .foregroundColor(.inkRoomTextTertiary)
                        }
                    }
                }

                // Theme Selection
                settingsSection(
                    title: "阅读主题",
                    icon: "paintpalette"
                ) {
                    HStack(spacing: 12) {
                        ForEach(ReadingSettings.ReaderTheme.allCases, id: \.self) { theme in
                            themeButton(theme)
                        }
                    }
                }

                // Page Turn Style
                settingsSection(
                    title: "翻页方式",
                    icon: "arrow.right"
                ) {
                    HStack(spacing: 12) {
                        ForEach(ReadingSettings.PageTurnStyle.allCases, id: \.self) { style in
                            pageTurnButton(style)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
        .background(Color.inkRoomBackground)
        .navigationTitle("阅读设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var previewCard: some View {
        let bgColor = Color(hex: settingsViewModel.readerTheme.backgroundColor) ?? .readerBackgroundLight
        let textColor = Color(hex: settingsViewModel.readerTheme.textColor) ?? .inkRoomTextPrimary

        return VStack(alignment: .leading, spacing: CGFloat(settingsViewModel.readingLineSpacing)) {
            Text("墨斋 InkRoom")
                .font(.system(size: CGFloat(settingsViewModel.readingFontSize), weight: .medium))
                .foregroundColor(textColor)

            Text("东方禅意 · 水墨书房 · iOS 阅读器")
                .font(.system(size: CGFloat(settingsViewModel.readingFontSize - 2)))
                .foregroundColor(textColor.opacity(0.7))

            Text("在繁忙的生活中，阅读是一种难得的宁静。一本好书，如同一杯清茶，让人回味无穷。")
                .font(.system(size: CGFloat(settingsViewModel.readingFontSize - 4)))
                .foregroundColor(textColor.opacity(0.6))
                .lineSpacing(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inkRoomTextTertiary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(safeSystemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomPrimary)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.inkRoomTextPrimary)
            }

            content()
                .padding(16)
                .background(Color.inkRoomCard)
                .cornerRadius(12)
        }
    }

    private func themeButton(_ theme: ReadingSettings.ReaderTheme) -> some View {
        let isSelected = settingsViewModel.readerTheme == theme
        let bgColor = Color(hex: theme.backgroundColor) ?? .white

        return Button {
            settingsViewModel.readerTheme = theme
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(bgColor)
                    .frame(height: 40)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isSelected ? Color.inkRoomPrimary : Color.inkRoomTextTertiary.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }

                Text(theme.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .inkRoomPrimary : .inkRoomTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pageTurnButton(_ style: ReadingSettings.PageTurnStyle) -> some View {
        let isSelected = settingsViewModel.pageTurnStyle == style

        return Button {
            settingsViewModel.pageTurnStyle = style
        } label: {
            Text(style.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .inkRoomTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.inkRoomPrimary : Color.inkRoomBackgroundElevated)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        ReadingSettingsView()
            .environmentObject(SettingsViewModel())
    }
}
