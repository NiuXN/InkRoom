import SwiftUI

/// Pro upgrade card section
struct ProUpgradeSection: View {
    @EnvironmentObject var updateService: AppStoreUpdateService
    @Binding var showProAlert: Bool

    var body: some View {
        Section {
            proUpgradeCard
        } header: {
            Text("")
                .textCase(nil)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var proUpgradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "crown")
                    .foregroundStyle(Color.inkRoomPrimary)

                Text("升级墨斋 Pro")
                    .font(.inkRoomTitle)
                    .foregroundStyle(Color.inkRoomTextPrimary)
            }

            Text("解锁无限书架、高级字体、完整听书体验")
                .font(.inkRoomSubheadlineRegular)
                .foregroundStyle(Color.inkRoomTextSecondary)

            Button {
                if AppConfig.proUpgradeURL != nil {
                    updateService.openProUpgradePage()
                } else if AppConfig.appStoreFallbackURL != nil {
                    updateService.openAppStore()
                } else {
                    showProAlert = true
                }
            } label: {
                Text(AppConfig.proUpgradeURL != nil ? "前往 App Store" : "了解更多")
                    .font(.inkRoomBodyEmphasized)
                    .foregroundStyle(Color.inkRoomPrimary)
            }
        }
        .padding(LayoutMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.inkRoomPrimary.opacity(0.06),
                    Color.inkRoomPrimary.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
        .overlay {
            RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusCard)
                .stroke(Color.inkRoomPrimary.opacity(0.15), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        .alert("墨斋 Pro", isPresented: $showProAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("墨斋 Pro 正在开发中，敬请期待。Pro 版本将提供：\n\n• 云端同步\n• 高级阅读主题\n• 无限书架\n• 数据备份恢复")
        }
    }
}
