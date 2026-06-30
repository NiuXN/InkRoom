import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 兼容不同系统版本的 SF Symbol 名称，避免运行时找不到符号。
enum SFSymbolCompat {
    private static let aliases: [String: String] = [
        "book.open": "book.fill",
        "music": "music.note",
        "textformat.letterSpacing": "character",
        "text.word.spacing": "character",
        "folders": "folder.fill"
    ]

    static func resolve(_ name: String) -> String {
        if symbolExists(name) { return name }
        if let alias = aliases[name], symbolExists(alias) { return alias }
        if let alias = aliases[name] { return alias }
        return "questionmark.circle"
    }

    static func migrateStoredIconName(_ name: String) -> String {
        resolve(name)
    }

    private static func symbolExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(systemName: name) != nil
        #elseif canImport(AppKit)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #else
        return true
        #endif
    }
}

extension Image {
    init(safeSystemName name: String) {
        self.init(systemName: SFSymbolCompat.resolve(name))
    }
}
