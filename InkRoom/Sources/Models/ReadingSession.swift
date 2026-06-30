import Foundation

struct ReadingSession: Identifiable, Codable {
    let id: UUID
    let bookId: UUID
    let bookTitle: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let pagesRead: Int

    var durationText: String {
        let minutes = Int(duration) / 60
        if minutes < 60 { return "\(minutes)分钟" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)小时\(mins)分"
    }
}
