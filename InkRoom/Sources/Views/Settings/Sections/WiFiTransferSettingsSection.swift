import SwiftUI

/// WiFi transfer settings section
struct WiFiTransferSettingsSection: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @StateObject private var wifiService = WiFiTransferService.shared
    @Binding var wifiError: String?

    var body: some View {
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
                    IconBadgeView(icon: "wifi", iconSize: 14)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wi-Fi 传书")

                        if settingsViewModel.wifiTransferEnabled && !wifiService.ipAddress.isEmpty {
                            Text(wifiService.ipAddress)
                                .font(.inkRoomCaption)
                                .foregroundStyle(Color.stateSuccess)
                        }
                    }
                }
            }
            .tint(Color.inkRoomPrimary)

            NavigationLink {
                WiFiTransferDetailView()
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
                .foregroundStyle(Color.inkRoomTextSecondary)
        } footer: {
            if settingsViewModel.wifiTransferEnabled {
                Text("在电脑浏览器中输入上方地址，即可上传书籍")
                    .textCase(nil)
            }
        }
        .listRowBackground(Color.inkRoomCard)
    }

    private func settingsRow(
        title: String,
        icon: String,
        value: String?
    ) -> some View {
        HStack(spacing: 12) {
            IconBadgeView(icon: icon, iconSize: 14)

            Text(title)

            if let value = value {
                Spacer()
                Text(value)
                    .foregroundStyle(Color.inkRoomTextTertiary)
            }
        }
    }

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
}

/// WiFi transfer detail view (upload history)
struct WiFiTransferDetailView: View {
    @StateObject private var wifiService = WiFiTransferService.shared

    var body: some View {
        List {
            Section {
                HStack {
                    Text("IP 地址")
                    Spacer()
                    Text(wifiService.ipAddress)
                        .foregroundStyle(Color.inkRoomTextTertiary)
                }
                HStack {
                    Text("端口")
                    Spacer()
                    Text(":8080")
                        .foregroundStyle(Color.inkRoomTextTertiary)
                }
            } header: {
                Text("连接信息")
                    .textCase(nil)
            }
            .listRowBackground(Color.inkRoomCard)

            Section {
                if wifiService.uploadedFiles.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        iconSize: 32,
                        title: "暂无上传记录",
                        message: "通过 Wi-Fi 传书上传的文件将显示在这里"
                    )
                } else {
                    ForEach(wifiService.uploadedFiles) { file in
                        UploadedFileRow(file: file)
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
}

struct UploadedFileRow: View {
    let file: WiFiTransferService.UploadedFile

    var body: some View {
        HStack(spacing: 12) {
            IconBadgeView(icon: "doc", iconSize: 14, badgeSize: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.inkRoomBody)
                    .foregroundStyle(Color.inkRoomTextPrimary)
                    .lineLimit(1)

                Text("\(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)) · \(file.uploadedAt.formatted(.dateTime.hour().minute()))")
                    .font(.inkRoomCaption)
                    .foregroundStyle(Color.inkRoomTextTertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.stateSuccess)
        }
    }
}
