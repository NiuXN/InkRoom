import SwiftUI

struct StatisticsView: View {
    @Environment(\.layoutSizeClass) private var sizeClass

    @State private var statistics = ReadingStatistics(
        todayMinutes: 0,
        weekMinutes: 0,
        totalMinutes: 0,
        streakDays: 0,
        recentBookStats: []
    )
    @State private var isLoading = true

    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        LoadingStateView()
                            .padding(.top, 48)
                    } else {
                        summaryGrid
                        recentBooksSection
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color.inkRoomBackground)
            .navigationTitle("统计")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
.refreshable {
            await loadStatistics()
        }
        .task {
            await loadStatistics()
        }
    }

    // MARK: - Summary
    private var summaryGrid: some View {
        let columns = summaryColumns
        return LazyVGrid(columns: columns, spacing: 12) {
            summaryCard(title: "今日时长", value: DurationFormatter.minutesText(statistics.todayMinutes), icon: "sun.max", iconColor: .stateWarning)
            summaryCard(title: "本周时长", value: DurationFormatter.minutesText(statistics.weekMinutes), icon: "calendar", iconColor: .stateInfo)
            summaryCard(title: "总时长", value: DurationFormatter.minutesText(statistics.totalMinutes), icon: "hourglass", iconColor: .inkRoomPrimary)
            summaryCard(title: "连续天数", value: "\(statistics.streakDays)天", icon: "flame", iconColor: .stateError)
        }
    }

    private var summaryColumns: [GridItem] {
        switch sizeClass {
        case .compact:
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        case .regular, .expanded:
            return [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ]
        }
    }

    private func summaryCard(title: String, value: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconBadgeView(icon: icon, iconSize: 16, color: iconColor, background: iconColor.opacity(0.15))

                Spacer()
            }

            Spacer()

            Text(value)
                .font(.inkRoomLargeTitle)
                .foregroundStyle(Color.inkRoomTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.inkRoomFootnote)
                .foregroundStyle(Color.inkRoomTextTertiary)
        }
        .padding(LayoutMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: sizeClass == .compact ? 104 : 112)
        .background(Color.inkRoomCard)
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
        .shadow(color: Color.inkRoomShadow(opacity: 0.03), radius: 4, x: 0, y: 2)
    }

    // MARK: - Recent Books
    private var recentBooksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近阅读")
                    .font(.inkRoomTitle)
                    .foregroundStyle(Color.inkRoomTextPrimary)

                Spacer()

                Text("\(statistics.recentBookStats.count) 本")
                    .font(.inkRoomSubheadlineRegular)
                    .foregroundStyle(Color.inkRoomTextTertiary)
            }
            .padding(.horizontal, 4)

            if statistics.recentBookStats.isEmpty {
                emptyRecentView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(statistics.recentBookStats.enumerated()), id: \.element.id) { index, stat in
                        bookRow(stat)
                        if index < statistics.recentBookStats.count - 1 {
                            Divider()
                                .background(Color.inkRoomTextTertiary.opacity(0.15))
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color.inkRoomCard)
                .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
                .shadow(color: Color.inkRoomShadow(opacity: 0.03), radius: 4, x: 0, y: 2)
            }
        }
    }

    private var emptyRecentView: some View {
        EmptyStateView(icon: "book.closed", iconSize: 32, title: "还没有阅读记录", message: "开始阅读后，这里会展示你的阅读统计")
            .background(Color.inkRoomCard)
            .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
    }

    private func bookRow(_ stat: BookReadingStat) -> some View {
        HStack(spacing: 12) {
            IconBadgeView(icon: "book.closed", iconSize: 18, badgeSize: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.title)
                    .font(.inkRoomHeadline)
                    .foregroundStyle(Color.inkRoomTextPrimary)
                    .lineLimit(1)

                Text(DurationFormatter.relativeText(from: stat.lastRead))
                    .font(.inkRoomCaption)
                    .foregroundStyle(Color.inkRoomTextTertiary)
            }

            Spacer()

            Text(DurationFormatter.secondsText(stat.totalDuration))
                .font(.inkRoomSubheadline)
                .foregroundStyle(Color.inkRoomPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Layout Helpers
    private var contentMaxWidth: CGFloat? {
        switch sizeClass {
        case .compact:
            return nil
        case .regular:
            return 640
        case .expanded:
            return 720
        }
    }

    private var contentHorizontalPadding: CGFloat {
        switch sizeClass {
        case .compact:
            return 16
        case .regular, .expanded:
            return 24
        }
    }

    // MARK: - Data Loading
    private func loadStatistics() async {
        isLoading = true
        let stats = await DatabaseService.shared.fetchReadingStatistics()
        statistics = stats
        isLoading = false
    }
}

#Preview {
    StatisticsView()
}
