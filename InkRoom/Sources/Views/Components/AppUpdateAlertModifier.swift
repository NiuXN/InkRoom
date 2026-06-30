import SwiftUI

struct AppUpdateAlertModifier: ViewModifier {
    @ObservedObject var updateService: AppStoreUpdateService

    func body(content: Content) -> some View {
        content
            .alert("发现新版本", isPresented: updateAvailableBinding) {
                Button("稍后") {
                    updateService.dismissPendingUpdate()
                }
                Button("前往 App Store 更新") {
                    updateService.openAppStore()
                    updateService.dismissPendingUpdate()
                }
            } message: {
                if let update = updateService.pendingUpdate {
                    if update.releaseNotes.isEmpty {
                        Text("墨斋 \(update.latestVersion) 已在 App Store 发布，建议更新以获得最新功能与修复。")
                    } else {
                        Text("墨斋 \(update.latestVersion)\n\n\(update.releaseNotes)")
                    }
                }
            }
    }

    private var updateAvailableBinding: Binding<Bool> {
        Binding(
            get: { updateService.pendingUpdate != nil },
            set: { if !$0 { updateService.dismissPendingUpdate() } }
        )
    }
}

extension View {
    func appUpdateAlert(updateService: AppStoreUpdateService) -> some View {
        modifier(AppUpdateAlertModifier(updateService: updateService))
    }
}
