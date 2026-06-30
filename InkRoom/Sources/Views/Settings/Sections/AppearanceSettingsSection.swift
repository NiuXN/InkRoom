import SwiftUI

/// Appearance settings section (theme, dark mode, follow system)
struct AppearanceSettingsSection: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Section {
            appearanceToggle(
                title: "跟随系统",
                icon: "sun.max",
                color: .stateWarning,
                isOn: $settingsViewModel.followSystemTheme
            )

            appearanceToggle(
                title: "深色模式",
                icon: "moon",
                color: .stateInfo,
                isOn: $settingsViewModel.isDarkMode
            )
            .disabled(settingsViewModel.followSystemTheme)
            .opacity(settingsViewModel.followSystemTheme ? 0.5 : 1.0)
        } header: {
            Text("外观")
                .textCase(nil)
                .foregroundStyle(Color.inkRoomTextSecondary)
        } footer: {
            if settingsViewModel.followSystemTheme {
                Text("开启跟随系统后，将自动使用系统当前的外观设置")
                    .textCase(nil)
                    .font(.inkRoomFootnote)
            }
        }
        .listRowBackground(Color.inkRoomCard)
    }

    private func appearanceToggle(
        title: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                IconBadgeView(
                    icon: icon,
                    iconSize: 14,
                    badgeSize: LayoutMetrics.iconBadgeSize,
                    color: color,
                    background: color.opacity(0.15)
                )

                Text(title)
                    .font(.inkRoomBody)
            }
        }
        .tint(Color.inkRoomPrimary)
    }
}
