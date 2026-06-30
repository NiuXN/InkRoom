import Foundation

struct BookReadingStat: Identifiable {
    let id: UUID
    let title: String
    let totalDuration: TimeInterval
    let lastRead: Date
}

struct ReadingStatistics {
    let todayMinutes: Int
    let weekMinutes: Int
    let totalMinutes: Int
    let streakDays: Int
    let recentBookStats: [BookReadingStat]
}
