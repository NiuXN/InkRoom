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
                    ZStack {
                        Circle()
                            .fill(Color.inkRoomPrimaryLight)
                            .frame(width: 32, height: 32)

                        Image(systemName: "wifi")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkRoomPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wi-Fi 传书")

                        if settingsViewModel.wifiTransferEnabled && !wifiService.ipAddress.isEmpty {
                            Text(wifiService.ipAddress)
                                .font(.system(size: 11))
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
            ZStack {
                Circle()
                    .fill(Color.inkRoomPrimaryLight)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkRoomPrimary)
            }

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
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.inkRoomTextTertiary)
                            Text("暂无上传记录")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.inkRoomTextTertiary)
                        }
                        .padding(.vertical, 24)
                        Spacer()
                    }
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
            ZStack {
                Circle()
                    .fill(Color.inkRoomPrimaryLight)
                    .frame(width: 36, height: 36)

                Image(systemName: "doc")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkRoomPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkRoomTextPrimary)
                    .lineLimit(1)

                Text("\(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)) · \(file.uploadedAt.formatted(.dateTime.hour().minute()))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkRoomTextTertiary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.stateSuccess)
        }
    }
}
