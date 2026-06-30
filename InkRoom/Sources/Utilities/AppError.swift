import Foundation

/// Structured error protocol for the InkRoom app.
/// All app-specific errors should conform to this protocol for consistent error handling.
protocol AppError: LocalizedError {
    var errorCode: String { get }
    var underlyingError: Error? { get }
    var context: [String: Any]? { get }
}

extension AppError {
    var underlyingError: Error? { nil }
    var context: [String: Any]? { nil }

    var errorDescription: String? {
        // Default implementation uses the friendly message
        AppErrorMessage.friendly(for: self)
    }
}

// MARK: - Database Errors

enum DatabaseError: AppError {
    case connectionFailed(underlying: Error?)
    case tableCreationFailed(underlying: Error?)
    case insertFailed(table: String, underlying: Error?)
    case fetchFailed(table: String, underlying: Error?)
    case updateFailed(table: String, underlying: Error?)
    case deleteFailed(table: String, underlying: Error?)
    case invalidUUID(string: String, context: String)
    case transactionFailed(underlying: Error?)

    var errorCode: String {
        switch self {
        case .connectionFailed: return "DB_001"
        case .tableCreationFailed: return "DB_002"
        case .insertFailed: return "DB_003"
        case .fetchFailed: return "DB_004"
        case .updateFailed: return "DB_005"
        case .deleteFailed: return "DB_006"
        case .invalidUUID: return "DB_007"
        case .transactionFailed: return "DB_008"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .connectionFailed(let err), .tableCreationFailed(let err), .transactionFailed(let err):
            return err
        case .insertFailed(_, let err), .fetchFailed(_, let err),
             .updateFailed(_, let err), .deleteFailed(_, let err):
            return err
        case .invalidUUID:
            return nil
        }
    }

    var context: [String: Any]? {
        switch self {
        case .insertFailed(let table, _), .fetchFailed(let table, _),
             .updateFailed(let table, _), .deleteFailed(let table, _):
            return ["table": table]
        case .invalidUUID(let string, let context):
            return ["uuid_string": string, "context": context]
        default:
            return nil
        }
    }
}

enum BookParseError: AppError {
    case unsupportedFormat(extension: String)
    case invalidEpub(underlying: Error?)
    case invalidEpubStructure
    case invalidOPF
    case invalidTxt(underlying: Error?)
    case parsingFailed(reason: String, underlying: Error?)
    case fileNotFound(path: String)
    case fileReadError(path: String, underlying: Error?)

    var errorCode: String {
        switch self {
        case .unsupportedFormat: return "PARSE_001"
        case .invalidEpub: return "PARSE_002"
        case .invalidEpubStructure: return "PARSE_003"
        case .invalidOPF: return "PARSE_004"
        case .invalidTxt: return "PARSE_005"
        case .parsingFailed: return "PARSE_006"
        case .fileNotFound: return "PARSE_007"
        case .fileReadError: return "PARSE_008"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .invalidEpub(let err), .invalidTxt(let err),
             .parsingFailed(_, let err), .fileReadError(_, let err):
            return err
        default:
            return nil
        }
    }

    var context: [String: Any]? {
        switch self {
        case .unsupportedFormat(let ext):
            return ["extension": ext]
        case .parsingFailed(let reason, _):
            return ["reason": reason]
        case .fileNotFound(let path), .fileReadError(let path, _):
            return ["path": path]
        default:
            return nil
        }
    }
}

// MARK: - WiFi Transfer Errors

enum WiFiTransferError: AppError {
    case serverStartFailed(port: UInt16, underlying: Error?)
    case serverAlreadyRunning
    case serverNotRunning
    case invalidIPAddress
    case multipartParseFailed(reason: String)
    case fileSaveFailed(path: String, underlying: Error?)
    case fileTooLarge(size: Int64, maxSize: Int64)
    case invalidFileFormat(extension: String)

    var errorCode: String {
        switch self {
        case .serverStartFailed: return "WIFI_001"
        case .serverAlreadyRunning: return "WIFI_002"
        case .serverNotRunning: return "WIFI_003"
        case .invalidIPAddress: return "WIFI_004"
        case .multipartParseFailed: return "WIFI_005"
        case .fileSaveFailed: return "WIFI_006"
        case .fileTooLarge: return "WIFI_007"
        case .invalidFileFormat: return "WIFI_008"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .serverStartFailed(_, let err), .fileSaveFailed(_, let err):
            return err
        default:
            return nil
        }
    }

    var context: [String: Any]? {
        switch self {
        case .serverStartFailed(let port, _):
            return ["port": port]
        case .multipartParseFailed(let reason):
            return ["reason": reason]
        case .fileSaveFailed(let path, _):
            return ["path": path]
        case .fileTooLarge(let size, let maxSize):
            return ["size": size, "max_size": maxSize]
        case .invalidFileFormat(let ext):
            return ["extension": ext]
        default:
            return nil
        }
    }
}

// MARK: - TTS Errors

enum TTSError: AppError {
    case audioSessionConfigurationFailed(underlying: Error?)
    case speechSynthesisFailed(reason: String)
    case voiceNotFound(identifier: String)
    case invalidUtterance

    var errorCode: String {
        switch self {
        case .audioSessionConfigurationFailed: return "TTS_001"
        case .speechSynthesisFailed: return "TTS_002"
        case .voiceNotFound: return "TTS_003"
        case .invalidUtterance: return "TTS_004"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .audioSessionConfigurationFailed(let err):
            return err
        default:
            return nil
        }
    }

    var context: [String: Any]? {
        switch self {
        case .speechSynthesisFailed(let reason):
            return ["reason": reason]
        case .voiceNotFound(let id):
            return ["voice_id": id]
        default:
            return nil
        }
    }
}

// MARK: - Network Errors

enum NetworkError: AppError {
    case noConnection
    case timeout
    case invalidResponse(statusCode: Int)
    case decodingFailed(underlying: Error?)
    case requestFailed(underlying: Error?)

    var errorCode: String {
        switch self {
        case .noConnection: return "NET_001"
        case .timeout: return "NET_002"
        case .invalidResponse: return "NET_003"
        case .decodingFailed: return "NET_004"
        case .requestFailed: return "NET_005"
        }
    }

    var underlyingError: Error? {
        switch self {
        case .decodingFailed(let err), .requestFailed(let err):
            return err
        default:
            return nil
        }
    }

    var context: [String: Any]? {
        switch self {
        case .invalidResponse(let code):
            return ["status_code": code]
        default:
            return nil
        }
    }
}

// MARK: - Error Message Helper

/// Converts errors to user-friendly Chinese messages.
/// Replaces the old string-matching based `InkRoomErrorMessage`.
enum AppErrorMessage {
    static func friendly(for error: Error) -> String {
        // First check if it's an AppError
        if let appError = error as? AppError {
            return friendlyMessage(for: appError)
        }

        // Fallback to string matching for non-AppError errors
        return friendlyMessageFromDescription(error.localizedDescription)
    }

    private static func friendlyMessage(for error: AppError) -> String {
        // Use type checking and pattern matching for each error type
        if let dbError = error as? DatabaseError {
            return friendlyDatabaseMessage(dbError)
        }
        if let parseError = error as? BookParseError {
            return friendlyParseMessage(parseError)
        }
        if let wifiError = error as? WiFiTransferError {
            return friendlyWiFiMessage(wifiError)
        }
        if let ttsError = error as? TTSError {
            return friendlyTTSMessage(ttsError)
        }
        if let networkError = error as? NetworkError {
            return friendlyNetworkMessage(networkError)
        }
        return "操作失败，请稍后重试"
    }

    private static func friendlyDatabaseMessage(_ error: DatabaseError) -> String {
        switch error {
        case .connectionFailed, .tableCreationFailed, .transactionFailed:
            return "数据操作失败，请稍后重试"
        case .insertFailed, .fetchFailed, .updateFailed, .deleteFailed:
            return "数据操作失败，请稍后重试"
        case .invalidUUID:
            return "数据格式错误，请尝试重新导入"
        }
    }

    private static func friendlyParseMessage(_ error: BookParseError) -> String {
        switch error {
        case .unsupportedFormat:
            return "不支持的文件格式，请使用 EPUB 或 TXT"
        case .invalidEpub, .invalidEpubStructure, .invalidOPF:
            return "EPUB 文件解析失败，请检查文件是否损坏"
        case .invalidTxt:
            return "TXT 文件读取失败，请检查文件编码"
        case .parsingFailed:
            return "文件解析失败，请检查文件格式"
        case .fileNotFound:
            return "文件不存在或已被移除"
        case .fileReadError:
            return "文件读取失败，请检查文件权限"
        }
    }

    private static func friendlyWiFiMessage(_ error: WiFiTransferError) -> String {
        switch error {
        case .serverStartFailed:
            return "Wi-Fi 传书服务启动失败，请检查网络设置"
        case .serverAlreadyRunning:
            return "Wi-Fi 传书服务已在运行"
        case .serverNotRunning:
            return "Wi-Fi 传书服务未启动"
        case .invalidIPAddress:
            return "无法获取 IP 地址，请检查 Wi-Fi 连接"
        case .multipartParseFailed:
            return "文件上传失败，请重试"
        case .fileSaveFailed:
            return "文件保存失败，请检查存储空间"
        case .fileTooLarge:
            return "文件超过大小限制"
        case .invalidFileFormat:
            return "不支持的文件格式"
        }
    }

    private static func friendlyTTSMessage(_ error: TTSError) -> String {
        switch error {
        case .audioSessionConfigurationFailed:
            return "音频会话配置失败"
        case .speechSynthesisFailed:
            return "语音合成失败"
        case .voiceNotFound:
            return "未找到指定的语音"
        case .invalidUtterance:
            return "无效的语音内容"
        }
    }

    private static func friendlyNetworkMessage(_ error: NetworkError) -> String {
        switch error {
        case .noConnection:
            return "网络连接失败，请检查网络设置"
        case .timeout:
            return "请求超时，请重试"
        case .invalidResponse:
            return "服务器响应异常"
        case .decodingFailed:
            return "数据解析失败"
        case .requestFailed:
            return "请求失败，请稍后重试"
        }
    }

    private static func friendlyMessageFromDescription(_ description: String) -> String {
        let lowercased = description.lowercased()

        if lowercased.contains("sqlite") || lowercased.contains("database") {
            return "数据操作失败，请稍后重试"
        }
        if lowercased.contains("epub") || lowercased.contains("zip") {
            return "文件解析失败，请检查文件格式是否正确"
        }
        if lowercased.contains("disk") || lowercased.contains("space") || lowercased.contains("write") {
            return "存储空间不足，请清理后重试"
        }
        if lowercased.contains("encoding") || lowercased.contains("utf") {
            return "文件编码不支持，请转换为 UTF-8 编码"
        }
        if lowercased.contains("not found") || lowercased.contains("exist") {
            return "文件不存在或已被移除"
        }
        if lowercased.contains("permission") || lowercased.contains("denied") {
            return "没有访问权限，请检查文件权限设置"
        }

        return "操作失败，请稍后重试"
    }
}
