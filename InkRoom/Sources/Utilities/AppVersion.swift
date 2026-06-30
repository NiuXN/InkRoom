import Foundation

enum AppVersion {
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static var displayString: String {
        "\(current) (\(build))"
    }

    /// 比较 store 版本是否高于 local 版本。
    static func isVersion(_ store: String, newerThan local: String) -> Bool {
        compare(store, local) == .orderedDescending
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        // 非数字段（如 "beta"、"rc1"）视为 -1，低于任何数字段，
        // 使预发布版本（1.0.beta）正确小于正式版本（1.0.0）。
        let left = lhs.split(separator: ".").map { Int($0) ?? -1 }
        let right = rhs.split(separator: ".").map { Int($0) ?? -1 }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l > r { return .orderedDescending }
            if l < r { return .orderedAscending }
        }
        return .orderedSame
    }
}
