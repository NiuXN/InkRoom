import Foundation

/// 应用级依赖容器，统一管理各 Service 单例，便于测试注入与替换。
@MainActor
final class AppDependencies: ObservableObject {
    let database: DatabaseService
    let bookParser: BookParserService
    let wifiTransfer: WiFiTransferService

    static let shared = AppDependencies()

    init(
        database: DatabaseService = .shared,
        bookParser: BookParserService = .shared,
        wifiTransfer: WiFiTransferService = .shared
    ) {
        self.database = database
        self.bookParser = bookParser
        self.wifiTransfer = wifiTransfer
    }
}
