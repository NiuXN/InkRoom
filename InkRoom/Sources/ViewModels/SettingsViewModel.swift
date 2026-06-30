import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @AppStorage("isDarkMode") var isDarkMode: Bool = false
    @AppStorage("followSystemTheme") var followSystemTheme: Bool = false
    @AppStorage("readingFontSize") var readingFontSize: Int = 18
    @AppStorage("readingLineSpacing") var readingLineSpacing: Int = 8
    @AppStorage("readingLetterSpacing") var readingLetterSpacing: Int = 0
    @AppStorage("readerTheme") var readerThemeRaw: String = ReadingSettings.ReaderTheme.light.rawValue
    @AppStorage("pageTurnStyle") var pageTurnStyleRaw: String = ReadingSettings.PageTurnStyle.swipe.rawValue
    @AppStorage("wifiTransferEnabled") var wifiTransferEnabled: Bool = true
    @AppStorage("ttsRate") var ttsRate: Double = 0.5
    @AppStorage("ttsPitch") var ttsPitch: Double = 1.0
    @AppStorage("ttsVoiceIdentifier") var ttsVoiceIdentifier: String = ""
    @AppStorage("ttsTimerMinutes") var ttsTimerMinutes: Int = 0
    @AppStorage("ttsHighlightEnabled") var ttsHighlightEnabled: Bool = true
    @AppStorage("autoCheckUpdates") var autoCheckUpdates: Bool = true

    var readerTheme: ReadingSettings.ReaderTheme {
        get { ReadingSettings.ReaderTheme(rawValue: readerThemeRaw) ?? .light }
        set { readerThemeRaw = newValue.rawValue }
    }

    var pageTurnStyle: ReadingSettings.PageTurnStyle {
        get { ReadingSettings.PageTurnStyle(rawValue: pageTurnStyleRaw) ?? .swipe }
        set { pageTurnStyleRaw = newValue.rawValue }
    }

    var readingSettings: ReadingSettings {
        ReadingSettings(
            fontSize: readingFontSize,
            lineSpacing: readingLineSpacing,
            letterSpacing: readingLetterSpacing,
            readerTheme: readerTheme,
            pageTurnStyle: pageTurnStyle,
            ttsRate: Float(ttsRate),
            ttsPitch: Float(ttsPitch),
            ttsVoiceIdentifier: ttsVoiceIdentifier.isEmpty ? nil : ttsVoiceIdentifier,
            ttsTimerMinutes: ttsTimerMinutes == 0 ? nil : ttsTimerMinutes,
            ttsHighlightEnabled: ttsHighlightEnabled
        )
    }
    
    func updateReadingSettings(_ settings: ReadingSettings) {
        readingFontSize = settings.fontSize
        readingLineSpacing = settings.lineSpacing
        readingLetterSpacing = settings.letterSpacing
        readerTheme = settings.readerTheme
        pageTurnStyle = settings.pageTurnStyle
        ttsRate = Double(settings.ttsRate)
        ttsPitch = Double(settings.ttsPitch)
        ttsVoiceIdentifier = settings.ttsVoiceIdentifier ?? ""
        ttsTimerMinutes = settings.ttsTimerMinutes ?? 0
        ttsHighlightEnabled = settings.ttsHighlightEnabled
    }
}
