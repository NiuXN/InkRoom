import Foundation

enum DurationFormatter {
    static func minutesText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)分钟" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)小时" : "\(hours)小时\(mins)分"
    }

    static func secondsText(_ seconds: TimeInterval) -> String {
        minutesText(Int(seconds / 60))
    }

    static func relativeText(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}
