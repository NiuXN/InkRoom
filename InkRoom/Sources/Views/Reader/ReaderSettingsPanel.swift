import SwiftUI

// MARK: - Shared Reader Settings Sections
// ReaderSettingsPopover（macOS popover / 紧凑）与 ReaderSettingsOverlay（iOS 底部弹层 / 触控友好）
// 共用的字号、行距、主题区块。通过 buttonSize 参数区分触控目标尺寸。

struct ReaderFontSizeControl: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    let buttonSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("字号")
                .font(.inkRoomSectionLabel)
                .foregroundStyle(Color.inkRoomTextSecondary)

            HStack {
                Button {
                    if settingsViewModel.readingFontSize > 12 {
                        settingsViewModel.readingFontSize -= 1
                    }
                } label: {
                    Text("A")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkRoomTextPrimary)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.inkRoomBackgroundElevated)
                        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("减小字号")

                Slider(
                    value: Binding(
                        get: { Double(settingsViewModel.readingFontSize) },
                        set: { settingsViewModel.readingFontSize = Int($0) }
                    ),
                    in: 12...28,
                    step: 1
                )
                .tint(Color.inkRoomPrimary)

                Button {
                    if settingsViewModel.readingFontSize < 28 {
                        settingsViewModel.readingFontSize += 1
                    }
                } label: {
                    Text("A")
                        .font(.system(size: buttonSize == 36 ? 22 : 20))
                        .foregroundStyle(Color.inkRoomTextPrimary)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.inkRoomBackgroundElevated)
                        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusSmall))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("增大字号")
            }
        }
    }
}

struct ReaderLineSpacingControl: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("行距")
                .font(.inkRoomSectionLabel)
                .foregroundStyle(Color.inkRoomTextSecondary)

            HStack(spacing: 8) {
                ForEach([6, 10, 14], id: \.self) { spacing in
                    InkRoomChipButton(
                        title: spacing == 6 ? "紧凑" : spacing == 10 ? "标准" : "宽松",
                        isSelected: settingsViewModel.readingLineSpacing == spacing,
                        accessibilityLabel: spacing == 6 ? "紧凑行距" : spacing == 10 ? "标准行距" : "宽松行距"
                    ) {
                        settingsViewModel.readingLineSpacing = spacing
                    }
                }
            }
        }
    }
}

struct ReaderThemeControl: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    let spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("主题")
                .font(.inkRoomSectionLabel)
                .foregroundStyle(Color.inkRoomTextSecondary)

            HStack(spacing: spacing) {
                ForEach(ReadingSettings.ReaderTheme.allCases, id: \.self) { theme in
                    ReaderThemeButton(theme: theme, isSelected: settingsViewModel.readerTheme == theme) {
                        settingsViewModel.readerTheme = theme
                    }
                }
            }
        }
    }
}

struct ReaderThemeButton: View {
    let theme: ReadingSettings.ReaderTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let bgColor = Color(hex: theme.backgroundColor) ?? .readerBackgroundLight

        Button(action: action) {
            RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusMedium)
                .fill(bgColor)
                .frame(width: 60, height: 40)
                .overlay {
                    RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusMedium)
                        .stroke(
                            isSelected ? Color.inkRoomPrimary : Color.inkRoomTextTertiary.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.rawValue)主题")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - ReaderSettingsPopover (macOS popover / expanded toolbar)

struct ReaderSettingsPopover: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ReaderFontSizeControl(buttonSize: 32)
            ReaderLineSpacingControl()
            ReaderThemeControl(spacing: 10)
        }
        .padding(LayoutMetrics.cardPadding)
        .frame(width: 320)
        .background(Color.inkRoomCard)
        .sensoryFeedback(.selection, trigger: settingsViewModel.readingFontSize)
    }
}

// MARK: - ReaderSettingsOverlay (iOS bottom sheet)

#if os(iOS)
struct ReaderSettingsOverlay: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            Button {
                withAnimation { isPresented = false }
            } label: {
                Color.inkRoomShadow(opacity: 0.4).ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭设置面板")

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.inkRoomTextTertiary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                VStack(spacing: 16) {
                    ReaderFontSizeControl(buttonSize: 36)
                    ReaderThemeControl(spacing: 12)
                }
                .padding(LayoutMetrics.cardPadding)
                .padding(.bottom, safeAreaBottom)
            }
            .background(Color.inkRoomCard)
            .cornerRadius(LayoutMetrics.cornerRadiusLarge, corners: [.topLeft, .topRight])
        }
        .sensoryFeedback(.selection, trigger: settingsViewModel.readingFontSize)
    }

    private var safeAreaBottom: CGFloat {
        return (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom) ?? 34
    }
}
#endif
