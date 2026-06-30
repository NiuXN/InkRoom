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
                        .foregroundStyle(Color.inkRoomTextTertiary)

                        Slider(
                            value: Binding(
                                get: { Double(settingsViewModel.readingFontSize) },
                                set: { settingsViewModel.readingFontSize = Int($0) }
                            ),
                            in: 12...28,
                            step: 1
                        )
                        .tint(Color.inkRoomPrimary)

                        HStack {
                            Text("小")
                                .font(.inkRoomCaption)
                                .foregroundStyle(Color.inkRoomTextTertiary)
                            Spacer()
                            Text("当前: \(settingsViewModel.readingFontSize)pt")
                                .font(.inkRoomCaptionEmphasized)
                                .foregroundStyle(Color.inkRoomPrimary)
                            Spacer()
                            Text("大")
                                .font(.inkRoomCaption)
                                .foregroundStyle(Color.inkRoomTextTertiary)
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
                        .tint(Color.inkRoomPrimary)

                        HStack {
                            Text("紧凑")
                                .font(.inkRoomCaption)
                                .foregroundStyle(Color.inkRoomTextTertiary)
                            Spacer()
                            Text("当前: \(settingsViewModel.readingLineSpacing)")
                                .font(.inkRoomCaptionEmphasized)
                                .foregroundStyle(Color.inkRoomPrimary)
                            Spacer()
                            Text("宽松")
                                .font(.inkRoomCaption)
                                .foregroundStyle(Color.inkRoomTextTertiary)
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
                                get: { settingsViewModel.readingLetterSpacing },
                                set: { settingsViewModel.readingLetterSpacing = $0 }
                            ),
                            in: 0...10,
                            step: 0.5
                        )
                        .tint(Color.inkRoomPrimary)

                        HStack {
                            Text("紧凑")
                                .font(.inkRoomCaption)
                                .foregroundStyle(Color.inkRoomTextTertiary)
                            Spacer()
                            Text(String(format: "当前: %.1f", settingsViewModel.readingLetterSpacing))
                                .font(.inkRoomCaptionEmphasized)
                                .foregroundStyle(Color.inkRoomPrimary)
                            Spacer()
                            Text("宽松")
                                .font(.inkRoomCaption)
                                .foregroundStyle(Color.inkRoomTextTertiary)
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
            .padding(.bottom, LayoutMetrics.bottomInsetForTabBar)
        }
        .background(Color.inkRoomBackground)
        .navigationTitle("阅读设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sensoryFeedback(.selection, trigger: settingsViewModel.readingFontSize)
        .sensoryFeedback(.selection, trigger: settingsViewModel.readerThemeRaw)
        .sensoryFeedback(.selection, trigger: settingsViewModel.pageTurnStyleRaw)
    }

    private var previewCard: some View {
        let bgColor = Color(hex: settingsViewModel.readerTheme.backgroundColor) ?? .readerBackgroundLight
        let textColor = Color(hex: settingsViewModel.readerTheme.textColor) ?? Color.inkRoomTextPrimary

        return VStack(alignment: .leading, spacing: CGFloat(settingsViewModel.readingLineSpacing)) {
            Text("墨斋 InkRoom")
                .font(.system(size: CGFloat(settingsViewModel.readingFontSize), weight: .medium))
                .foregroundStyle(textColor)

            Text("东方禅意 · 水墨书房 · iOS 阅读器")
                .font(.system(size: CGFloat(settingsViewModel.readingFontSize - 2)))
                .foregroundStyle(textColor.opacity(0.7))

            Text("在繁忙的生活中，阅读是一种难得的宁静。一本好书，如同一杯清茶，让人回味无穷。")
                .font(.system(size: CGFloat(settingsViewModel.readingFontSize - 4)))
                .foregroundStyle(textColor.opacity(0.6))
                .lineSpacing(4)
                .tracking(CGFloat(settingsViewModel.readingLetterSpacing) * 0.1)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
        .shadow(color: Color.inkRoomShadow(opacity: 0.05), radius: 8, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusCard)
                .stroke(Color.inkRoomTextTertiary.opacity(0.1), lineWidth: 0.5)
        }
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
                    .foregroundStyle(Color.inkRoomPrimary)

                Text(title)
                    .font(.inkRoomHeadline)
                    .foregroundStyle(Color.inkRoomTextPrimary)
            }

            content()
                .inkRoomCard()
        }
    }

    private func themeButton(_ theme: ReadingSettings.ReaderTheme) -> some View {
        let isSelected = settingsViewModel.readerTheme == theme
        let bgColor = Color(hex: theme.backgroundColor) ?? .readerBackgroundLight

        return Button {
            settingsViewModel.readerTheme = theme
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusSmall)
                    .fill(bgColor)
                    .frame(height: 40)
                    .overlay {
                        RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusSmall)
                            .stroke(
                                isSelected ? Color.inkRoomPrimary : Color.inkRoomTextTertiary.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }

                Text(theme.rawValue)
                    .font(.inkRoomCaption)
                    .foregroundStyle(isSelected ? Color.inkRoomPrimary : Color.inkRoomTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(theme.rawValue)主题")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func pageTurnButton(_ style: ReadingSettings.PageTurnStyle) -> some View {
        let isSelected = settingsViewModel.pageTurnStyle == style

        return Button {
            settingsViewModel.pageTurnStyle = style
        } label: {
            Text(style.rawValue)
                .font(.inkRoomSubheadline)
                .foregroundStyle(isSelected ? Color.inkRoomOnPrimary : Color.inkRoomTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.inkRoomPrimary : Color.inkRoomBackgroundElevated)
                .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusMedium))
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(style.rawValue)翻页方式")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        ReadingSettingsView()
            .environmentObject(SettingsViewModel())
    }
}
