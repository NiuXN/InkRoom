import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var updateService: AppStoreUpdateService
    @Environment(\.layoutSizeClass) private var sizeClass
    @StateObject private var wifiService = WiFiTransferService.shared
    @State private var showReadingSettings = false
    @State private var wifiError: String?
    @State private var showProAlert = false
    @State private var showUpdateStatus = false

    var body: some View {
        List {
                // Appearance Section
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
                        .foregroundColor(.inkRoomTextSecondary)
                } footer: {
                    if settingsViewModel.followSystemTheme {
                        Text("开启跟随系统后，将自动使用系统当前的外观设置")
                            .textCase(nil)
                            .font(.system(size: 12))
                    }
                }
                .listRowBackground(Color.inkRoomCard)

                // Reading Section
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

                // Transfer Section
                Section {
                    Toggle(isOn: Binding(
                        get: { settingsViewModel.wifiTransferEnabled },
                        set: { newValue in
                            Task {
                                await toggleWiFiTransfer(enabled: newValue)
                            }
                        }
                    )) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.inkRoomPrimaryLight)
                                    .frame(width: 32, height: 32)

                                Image(systemName: "wifi")
                                    .font(.system(size: 14))
                                    .foregroundColor(.inkRoomPrimary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Wi-Fi 传书")

                                if settingsViewModel.wifiTransferEnabled && !wifiService.ipAddress.isEmpty {
                                    Text(wifiService.ipAddress)
                                        .font(.system(size: 11))
                                        .foregroundColor(.stateSuccess)
                                }
                            }
                        }
                    }
                    .tint(.inkRoomPrimary)

                    NavigationLink {
                        wifiTransferDetailView
                    } label: {
                        settingsRow(
                            title: "传书记录",
                            icon: "clock.arrow.circlepath",
                            value: "\(wifiService.uploadedFiles.count)"
                        )
                    }
                    .disabled(!settingsViewModel.wifiTransferEnabled)
                } header: {
                    Text("传书")
                        .textCase(nil)
                        .foregroundColor(.inkRoomTextSecondary)
                } footer: {
                    if settingsViewModel.wifiTransferEnabled {
                        Text("在电脑浏览器中输入上方地址，即可上传书籍")
                            .textCase(nil)
                    }
                }
                .listRowBackground(Color.inkRoomCard)

                // Pro Section
                Section {
                    proUpgradeCard
                } header: {
                    Text("")
                        .textCase(nil)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                // About Section
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        if updateService.isChecking {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(AppVersion.displayString)
                                .foregroundColor(.inkRoomTextTertiary)
                        }
                    }

                    Button {
                        Task {
                            await updateService.checkForUpdate()
                            showUpdateStatus = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.inkRoomPrimaryLight)
                                    .frame(width: 32, height: 32)

                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.inkRoomPrimary)
                            }

                            Text("检查 App Store 更新")

                            Spacer()

                            if updateService.pendingUpdate != nil {
                                Text("有新版本")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.inkRoomPrimary)
                            }
                        }
                    }
                    .disabled(updateService.isChecking)

                    Toggle(isOn: $settingsViewModel.autoCheckUpdates) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.stateInfo.opacity(0.15))
                                    .frame(width: 32, height: 32)

                                Image(systemName: "bell.badge")
                                    .font(.system(size: 14))
                                    .foregroundColor(.stateInfo)
                            }

                            Text("自动检查更新")
                        }
                    }
                    .tint(.inkRoomPrimary)

                    NavigationLink {
                        privacyPolicyView
                    } label: {
                        Text("隐私政策")
                    }

                    NavigationLink {
                        thanksView
                    } label: {
                        Text("感谢")
                    }
                } header: {
                    Text("关于")
                        .textCase(nil)
                        .foregroundColor(.inkRoomTextSecondary)
                } footer: {
                    Text("自动检查更新每 24 小时最多执行一次，仅在发现新版本时弹出提醒。")
                        .textCase(nil)
                        .font(.system(size: 12))
                }
                .listRowBackground(Color.inkRoomCard)
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.automatic)
            #endif
            .scrollContentBackground(.hidden)
            .background(Color.inkRoomBackground)
            .navigationTitle("我的")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        .frame(maxWidth: settingsMaxWidth)
        .frame(maxWidth: .infinity)
        .task {
            if settingsViewModel.wifiTransferEnabled && !wifiService.isRunning {
                try? await wifiService.startServer()
            }
        }
        .alert("Wi-Fi 传书", isPresented: Binding(
            get: { wifiError != nil },
            set: { if !$0 { wifiError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(wifiError ?? "")
        }
        .alert("检查更新", isPresented: $showUpdateStatus) {
            if updateService.pendingUpdate != nil {
                Button("稍后", role: .cancel) {}
                Button("前往 App Store") {
                    updateService.openAppStore()
                }
            } else {
                Button("好的", role: .cancel) {}
            }
        } message: {
            Text(updateService.statusMessage ?? "")
        }
    }

    private var settingsMaxWidth: CGFloat? {
        switch sizeClass {
        case .compact:
            return nil
        case .regular:
            return 640
        case .expanded:
            return 720
        }
    }

    private var lineSpacingLabel: String {
        switch settingsViewModel.readingLineSpacing {
        case 0...4: return "紧凑"
        case 5...8: return "适中"
        case 9...12: return "宽松"
        default: return "舒适"
        }
    }

    private func appearanceToggle(
        title: String,
        icon: String,
        color: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }

                Text(title)
            }
        }
        .tint(.inkRoomPrimary)
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

    private var proUpgradeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "crown")
                    .foregroundColor(.inkRoomPrimary)

                Text("升级墨斋 Pro")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.inkRoomTextPrimary)
            }

            Text("解锁无限书架、高级字体、完整听书体验")
                .font(.system(size: 13))
                .foregroundColor(.inkRoomTextSecondary)

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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.inkRoomPrimary)
            }
        }
        .padding(16)
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
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.inkRoomPrimary.opacity(0.15), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .alert("墨斋 Pro", isPresented: $showProAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("墨斋 Pro 正在开发中，敬请期待。Pro 版本将提供：\n\n• 云端同步\n• 高级阅读主题\n• 无限书架\n• 数据备份恢复")
        }
    }

    // MARK: - WiFi Transfer
    private func toggleWiFiTransfer(enabled: Bool) async {
        if enabled {
            do {
                try await wifiService.startServer()
                settingsViewModel.wifiTransferEnabled = true
            } catch {
                wifiError = error.localizedDescription
                settingsViewModel.wifiTransferEnabled = false
            }
        } else {
            wifiService.stopServer()
            settingsViewModel.wifiTransferEnabled = false
        }
    }

    private var wifiTransferDetailView: some View {
        List {
            Section {
                HStack {
                    Text("IP 地址")
                    Spacer()
                    Text(wifiService.ipAddress)
                        .foregroundColor(.inkRoomTextTertiary)
                }
                HStack {
                    Text("端口")
                    Spacer()
                    Text(":8080")
                        .foregroundColor(.inkRoomTextTertiary)
                }
            } header: {
                Text("连接信息")
                    .textCase(nil)
            }
            .listRowBackground(Color.inkRoomCard)

            Section {
                if wifiService.uploadedFiles.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundColor(.inkRoomTextTertiary)
                            Text("暂无上传记录")
                                .font(.system(size: 14))
                                .foregroundColor(.inkRoomTextTertiary)
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
                } else {
                    ForEach(wifiService.uploadedFiles) { file in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.inkRoomPrimaryLight)
                                    .frame(width: 36, height: 36)

                                Image(systemName: "doc")
                                    .font(.system(size: 14))
                                    .foregroundColor(.inkRoomPrimary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.fileName)
                                    .font(.system(size: 14))
                                    .foregroundColor(.inkRoomTextPrimary)
                                    .lineLimit(1)

                                Text("\(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)) · \(file.uploadedAt.formatted(.dateTime.hour().minute()))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.inkRoomTextTertiary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.stateSuccess)
                        }
                    }
                }
            } header: {
                Text("上传记录")
                    .textCase(nil)
            }
            .listRowBackground(Color.inkRoomCard)
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.automatic)
        #endif
        .scrollContentBackground(.hidden)
        .background(Color.inkRoomBackground)
        .navigationTitle("Wi-Fi 传书")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Privacy Policy
    private var privacyPolicyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("隐私政策")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.inkRoomTextPrimary)

                Text("更新日期：2026年6月")
                    .font(.system(size: 12))
                    .foregroundColor(.inkRoomTextTertiary)

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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.inkRoomTextPrimary)

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.inkRoomTextSecondary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.inkRoomCard)
        .cornerRadius(12)
    }

    // MARK: - Thanks
    private var thanksView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("感谢")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.inkRoomTextPrimary)

                Text("墨斋的成长离不开开源社区的支持。感谢以下优秀的开源项目：")
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomTextSecondary)
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
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomTextSecondary)
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
            ZStack {
                Circle()
                    .fill(Color.inkRoomPrimaryLight)
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.inkRoomPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.inkRoomTextPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.inkRoomTextTertiary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.inkRoomCard)
        .cornerRadius(12)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
        .environmentObject(AppStoreUpdateService.shared)
}
