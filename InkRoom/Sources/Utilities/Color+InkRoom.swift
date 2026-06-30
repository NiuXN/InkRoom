import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension Color {
    // MARK: - Brand Colors
    static let inkRoomPrimary = Color(red: 0.769, green: 0.361, blue: 0.290)
    static let inkRoomPrimaryLight = Color(red: 0.769, green: 0.361, blue: 0.290).opacity(0.12)
    static let inkRoomPrimaryMuted = Color(red: 0.769, green: 0.361, blue: 0.290).opacity(0.06)

    // MARK: - Background Colors (adaptive for dark mode)
    static let inkRoomBackground = adaptiveColor(light: Color(red: 0.961, green: 0.941, blue: 0.910),
                                                  dark: Color(red: 0.102, green: 0.102, blue: 0.102))
    static let inkRoomBackgroundSecondary = adaptiveColor(light: Color(red: 0.929, green: 0.906, blue: 0.859),
                                                           dark: Color(red: 0.141, green: 0.141, blue: 0.141))
    static let inkRoomBackgroundElevated = adaptiveColor(light: Color(red: 0.980, green: 0.969, blue: 0.949),
                                                          dark: Color(red: 0.165, green: 0.165, blue: 0.165))
    static let inkRoomCard = adaptiveColor(light: Color.white,
                                            dark: Color(red: 0.180, green: 0.180, blue: 0.180))

    // MARK: - Text Colors (adaptive for dark mode)
    static let inkRoomTextPrimary = adaptiveColor(light: Color(red: 0.173, green: 0.173, blue: 0.173),
                                                   dark: Color(red: 0.831, green: 0.812, blue: 0.780))
    static let inkRoomTextSecondary = adaptiveColor(light: Color(red: 0.420, green: 0.420, blue: 0.420),
                                                     dark: Color(red: 0.658, green: 0.658, blue: 0.658))
    static let inkRoomTextTertiary = adaptiveColor(light: Color(red: 0.604, green: 0.604, blue: 0.604),
                                                    dark: Color(red: 0.501, green: 0.501, blue: 0.501))

    // MARK: - Reader Theme Colors
    static let readerBackgroundLight = Color(red: 0.961, green: 0.941, blue: 0.910)
    static let readerBackgroundWarm = Color(red: 0.941, green: 0.902, blue: 0.816)
    static let readerBackgroundDark = Color(red: 0.102, green: 0.102, blue: 0.102)

    // MARK: - Adaptive Color Helper
    private static func adaptiveColor(light: Color, dark: Color) -> Color {
        #if os(iOS)
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #endif
    }
}

// MARK: - State Colors
extension Color {
    static let stateSuccess = Color(red: 0.290, green: 0.549, blue: 0.435)
    static let stateWarning = Color(red: 0.769, green: 0.604, blue: 0.290)
    static let stateError = Color(red: 0.769, green: 0.290, blue: 0.290)
    static let stateInfo = Color(red: 0.290, green: 0.482, blue: 0.769)
}

// MARK: - Hex Initializer
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
