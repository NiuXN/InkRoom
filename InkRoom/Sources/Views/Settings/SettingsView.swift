import SwiftUI

/// Main settings view - composed of focused section components
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
            AppearanceSettingsSection()
            ReadingSettingsSection()
            WiFiTransferSettingsSection(wifiError: $wifiError)
            ProUpgradeSection(showProAlert: $showProAlert)
            AboutSettingsSection(showUpdateStatus: $showUpdateStatus)
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
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
        .environmentObject(AppStoreUpdateService.shared)
}
