import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct InkRoomApp: App {
    @StateObject private var libraryViewModel = LibraryViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @StateObject private var updateService = AppStoreUpdateService.shared

    init() {
        TabBarAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryViewModel)
                .environmentObject(settingsViewModel)
                .environmentObject(updateService)
                .preferredColorScheme(colorScheme)
                .adaptiveLayout()
                .appUpdateAlert(updateService: updateService)
                .task {
                    await updateService.checkOnLaunchIfNeeded(
                        autoCheckEnabled: settingsViewModel.autoCheckUpdates
                    )
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入书籍...") {
                    NotificationCenter.default.post(name: .importBookNotification, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(after: .appInfo) {
                Divider()

                Button("设置...") {
                    NotificationCenter.default.post(name: .openSettingsNotification, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("墨斋帮助") {
                    if let url = URL(string: "https://github.com/inkroom/inkroom") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
        #elseif os(iOS)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(settingsViewModel)
                .environmentObject(libraryViewModel)
                .environmentObject(updateService)
                .adaptiveLayout()
                .frame(width: 560, height: 640)
        }
        #endif
    }

    private var colorScheme: ColorScheme? {
        if settingsViewModel.followSystemTheme {
            return nil
        }
        return settingsViewModel.isDarkMode ? .dark : .light
    }
}
