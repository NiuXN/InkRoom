import Foundation

struct ReadingSettings: Codable {
    var fontSize: Int
    var lineSpacing: Int
    var letterSpacing: Int
    var readerTheme: ReaderTheme
    var pageTurnStyle: PageTurnStyle
    var ttsRate: Float
    var ttsPitch: Float
    var ttsVoiceIdentifier: String?
    var ttsTimerMinutes: Int?
    var ttsHighlightEnabled: Bool

    enum ReaderTheme: String, Codable, CaseIterable {
        case light = "羊皮纸"
        case warm = "护眼"
        case dark = "夜间"

        var backgroundColor: String {
            switch self {
            case .light: return "#F5F0E8"
            case .warm: return "#F0E6D0"
            case .dark: return "#1A1A1A"
            }
        }

        var textColor: String {
            switch self {
            case .light: return "#2C2C2C"
            case .warm: return "#3D3D3D"
            case .dark: return "#D4CFC7"
            }
        }
    }

    enum PageTurnStyle: String, Codable, CaseIterable {
        case swipe = "滑动"
        case tap = "点击"
        case scroll = "滚动"
    }

    static let `default` = ReadingSettings(
        fontSize: 18,
        lineSpacing: 8,
        letterSpacing: 0,
        readerTheme: .light,
        pageTurnStyle: .swipe,
        ttsRate: 0.5,
        ttsPitch: 1.0,
        ttsVoiceIdentifier: nil,
        ttsTimerMinutes: nil,
        ttsHighlightEnabled: true
    )
}
