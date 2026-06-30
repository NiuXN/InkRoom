import SwiftUI

/// About section (version, update check, privacy, thanks)
struct AboutSettingsSection: View {
    @EnvironmentObject var updateService: AppStoreUpdateService
    @Binding var showUpdateStatus: Bool

    var body: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                if updateService.isChecking {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(AppVersion.displayString)
                        .foregroundStyle(Color.inkRoomTextTertiary)
                }
            }

            Button {
                Task {
                    await updateService.checkForUpdate()
                    showUpdateStatus = true
                }
            } label: {
                HStack(spacing: 12) {
                    IconBadgeView(icon: "arrow.down.circle", iconSize: 14)

                    Text("检查 App Store 更新")

                    Spacer()

                    if updateService.pendingUpdate != nil {
                        Text("有新版本")
                            .font(.inkRoomFootnoteEmphasized)
                            .foregroundStyle(Color.inkRoomPrimary)
                    }
                }
            }
            .disabled(updateService.isChecking)

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Text("隐私政策")
            }

            NavigationLink {
                ThanksView()
            } label: {
                Text("感谢")
            }
        } header: {
            Text("关于")
                .textCase(nil)
                .foregroundStyle(Color.inkRoomTextSecondary)
        } footer: {
            Text("自动检查更新每 24 小时最多执行一次，仅在发现新版本时弹出提醒。")
                .textCase(nil)
                .font(.inkRoomFootnote)
        }
        .listRowBackground(Color.inkRoomCard)
    }
}

/// Privacy policy view
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("隐私政策")
                    .font(.inkRoomLargeTitle)
                    .foregroundStyle(Color.inkRoomTextPrimary)

                Text("更新日期：2026年6月")
                    .font(.inkRoomFootnote)
                    .foregroundStyle(Color.inkRoomTextTertiary)

                infoBlock(
                    title: "数据存储",
                    content: "墨斋是一款本地优先的阅读应用。您导入的所有书籍、阅读进度、笔记和书签等数据均存储在您的设备本地，不会上传至任何服务器。"
                )

                infoBlock(
                    title: "网络使用",
                    content: "应用仅在您主动开启「Wi-Fi 传书」功能时使用局域网络，用于在您的设备与同一 Wi-Fi 网络下的电脑之间传输文件。传输过程完全在局域网内完成，不经过任何第三方服务器。"
                )

                infoBlock(
                    title: "隐私承诺",
                    content: "墨斋不收集任何用户数据，不进行任何形式的信息上传，不包含任何广告追踪或分析 SDK。您的阅读数据完全由您自己掌控。"
                )
            }
            .padding(20)
        }
        .background(Color.inkRoomBackground)
        .navigationTitle("隐私政策")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func infoBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.inkRoomHeadline)
                .foregroundStyle(Color.inkRoomTextPrimary)

            Text(content)
                .font(.inkRoomBody)
                .foregroundStyle(Color.inkRoomTextSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inkRoomCard()
    }
}

/// Thanks view
struct ThanksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("感谢")
                    .font(.inkRoomLargeTitle)
                    .foregroundStyle(Color.inkRoomTextPrimary)

                Text("墨斋的成长离不开开源社区的支持。感谢以下优秀的开源项目：")
                    .font(.inkRoomBody)
                    .foregroundStyle(Color.inkRoomTextSecondary)
                    .lineSpacing(4)

                VStack(spacing: 12) {
                    thanksItem(
                        name: "SQLite.swift",
                        description: "用于本地数据的持久化存储",
                        icon: "internaldrive"
                    )
                    thanksItem(
                        name: "ZIPFoundation",
                        description: "用于 EPUB 文件的解压解析",
                        icon: "archivebox"
                    )
                    thanksItem(
                        name: "Swifter",
                        description: "用于 Wi-Fi 传书的轻量 HTTP 服务器",
                        icon: "antenna.radiowaves.left.and.right"
                    )
                }

                Text("感谢每一位使用墨斋的读者，是你们让这款应用有了意义。")
                    .font(.inkRoomBody)
                    .foregroundStyle(Color.inkRoomTextSecondary)
                    .lineSpacing(4)
            }
            .padding(20)
        }
        .background(Color.inkRoomBackground)
        .navigationTitle("感谢")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func thanksItem(name: String, description: String, icon: String) -> some View {
        HStack(spacing: 12) {
            IconBadgeView(icon: icon, iconSize: 16, badgeSize: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.inkRoomHeadline)
                    .foregroundStyle(Color.inkRoomTextPrimary)

                Text(description)
                    .font(.inkRoomFootnote)
                    .foregroundStyle(Color.inkRoomTextTertiary)
            }

            Spacer()
        }
        .inkRoomCard()
    }
}
