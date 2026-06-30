import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import SwiftUI

@MainActor
final class AppStoreUpdateService: ObservableObject {
    static let shared = AppStoreUpdateService()

    struct UpdateInfo: Equatable {
        let latestVersion: String
        let releaseNotes: String
        let storeURL: URL
    }

    @Published private(set) var pendingUpdate: UpdateInfo?
    @Published private(set) var isChecking = false
    @Published var statusMessage: String?

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 启动时静默检查（受「自动检查更新」开关与 24 小时间隔限制）。
    func checkOnLaunchIfNeeded(autoCheckEnabled: Bool) async {
        guard autoCheckEnabled else { return }
        guard shouldPerformBackgroundCheck else { return }
        await checkForUpdate(showStatusWhenUpToDate: false)
    }

    /// 手动检查更新。
    func checkForUpdate(showStatusWhenUpToDate: Bool = true) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            if let info = try await fetchLatestRelease() {
                if AppVersion.isVersion(info.latestVersion, newerThan: AppVersion.current) {
                    pendingUpdate = info
                    statusMessage = "发现新版本 \(info.latestVersion)"
                } else {
                    pendingUpdate = nil
                    if showStatusWhenUpToDate {
                        statusMessage = "当前已是最新版本"
                    }
                }
            } else {
                pendingUpdate = nil
                if showStatusWhenUpToDate {
                    statusMessage = "暂未在 App Store 找到该应用，可能尚未上架"
                }
            }
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)
        } catch {
            pendingUpdate = nil
            if showStatusWhenUpToDate {
                statusMessage = "检查更新失败：\(error.localizedDescription)"
            }
        }
    }

    func openAppStore(for update: UpdateInfo? = nil) {
        let url = update?.storeURL ?? pendingUpdate?.storeURL ?? fallbackStoreURL
        guard let url else { return }
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    func openProUpgradePage() {
        if let raw = AppConfig.proUpgradeURL, let url = URL(string: raw) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        } else {
            openAppStore()
        }
    }

    func dismissPendingUpdate() {
        pendingUpdate = nil
    }

    // MARK: - Private

    private static let lastCheckKey = "lastAppStoreUpdateCheck"

    private var shouldPerformBackgroundCheck: Bool {
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        guard last > 0 else { return true }
        return Date().timeIntervalSince1970 - last >= 24 * 3600
    }

    private var fallbackStoreURL: URL? {
        guard let raw = AppConfig.appStoreFallbackURL else { return nil }
        return URL(string: raw)
    }

    private struct LookupResponse: Decodable {
        struct Result: Decodable {
            let version: String
            let trackViewUrl: String
            let releaseNotes: String?
        }
        let results: [Result]
    }

    private func fetchLatestRelease() async throws -> UpdateInfo? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: AppConfig.bundleIdentifier),
            URLQueryItem(name: "country", value: AppConfig.appStoreCountryCode)
        ]
        guard let url = components.url else { return nil }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UpdateError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
        guard let item = decoded.results.first,
              let storeURL = URL(string: item.trackViewUrl) else {
            return nil
        }

        return UpdateInfo(
            latestVersion: item.version,
            releaseNotes: item.releaseNotes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            storeURL: storeURL
        )
    }

    enum UpdateError: LocalizedError {
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "App Store 响应无效"
            }
        }
    }
}
