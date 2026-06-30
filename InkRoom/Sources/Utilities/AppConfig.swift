import Foundation

enum AppConfig {
    /// App Store / TestFlight 使用的 Bundle ID，需与 project.yml 中一致。
    static let bundleIdentifier = "com.inkroom.app"

    /// App Store 应用页（上架后填写数字 ID，例如 "https://apps.apple.com/app/id1234567890"）。
    /// 留空时由 iTunes Lookup API 返回的 trackViewUrl 自动获取。
    static let appStoreFallbackURL: String? = nil

    /// 墨斋 Pro 订阅/内购说明页（可选，上架后填写）。
    static let proUpgradeURL: String? = nil

    /// iTunes Lookup 国家/地区代码。
    static let appStoreCountryCode = "cn"
}
