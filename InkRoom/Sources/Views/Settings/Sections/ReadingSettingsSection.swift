import SwiftUI

/// Reading settings section (font size, line spacing, theme)
struct ReadingSettingsSection: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Section {
            NavigationLink {
                ReadingSettingsView()
            } label: {
                settingsRow(
                    title: "默认字号",
                    icon: "textformat.size",
                    value: "\(settingsViewModel.readingFontSize)pt"
                )
            }

            NavigationLink {
                ReadingSettingsView()
            } label: {
                settingsRow(
                    title: "默认行距",
                    icon: "text.alignleft",
                    value: lineSpacingLabel
                )
            }

            NavigationLink {
                ReadingSettingsView()
            } label: {
                settingsRow(
                    title: "阅读主题",
                    icon: "paintpalette",
                    value: settingsViewModel.readerTheme.rawValue
                )
            }
        } header: {
            Text("阅读")
                .textCase(nil)
                .foregroundColor(.inkRoomTextSecondary)
        }
        .listRowBackground(Color.inkRoomCard)
    }

    private var lineSpacingLabel: String {
        switch settingsViewModel.readingLineSpacing {
        case 0...4: return "紧凑"
        case 5...8: return "适中"
        case 9...12: return "宽松"
        default: return "舒适"
        }
    }

    private func settingsRow(
        title: String,
        icon: String,
        value: String?
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.inkRoomPrimaryLight)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomPrimary)
            }

            Text(title)

            if let value = value {
                Spacer()
                Text(value)
                    .foregroundColor(.inkRoomTextTertiary)
            }
        }
    }
}
