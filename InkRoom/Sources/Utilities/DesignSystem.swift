import SwiftUI

// MARK: - Typography
// 字体体系：语义化字体样式，使用 Font.system(_:design:weight:) 文本样式，真正支持 Dynamic Type 缩放
// 仅用于"chrome" UI（按钮、标签、卡片标题等），阅读器正文使用 readingFontSize 用户设置（固定字号）
extension Font {
    /// 大标题（页面主标题，如隐私政策页）
    static let inkRoomLargeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    /// 标题（区块大标题）
    static let inkRoomTitle = Font.system(.title, design: .default, weight: .semibold)
    /// 标题2（卡片区块标题、详情区段）
    static let inkRoomHeadline = Font.system(.headline, design: .default, weight: .semibold)
    /// 正文（默认正文）
    static let inkRoomBody = Font.system(.body, design: .default, weight: .regular)
    /// 正文强调（按钮、强调正文）
    static let inkRoomBodyEmphasized = Font.system(.body, design: .default, weight: .medium)
    /// 副标题（卡片副标题、列表项）
    static let inkRoomSubheadline = Font.system(.subheadline, design: .default, weight: .medium)
    /// 副标题 regular（说明文字）
    static let inkRoomSubheadlineRegular = Font.system(.subheadline, design: .default, weight: .regular)
    /// 脚注（辅助说明、时间戳）
    static let inkRoomFootnote = Font.system(.footnote, design: .default, weight: .regular)
    /// 脚注强调（标签、状态值）
    static let inkRoomFootnoteEmphasized = Font.system(.footnote, design: .default, weight: .medium)
    /// 微字号（最小辅助文字）
    static let inkRoomCaption = Font.system(.caption, design: .default, weight: .regular)
    /// 微字号强调（进度文字、状态指示）
    static let inkRoomCaptionEmphasized = Font.system(.caption, design: .default, weight: .medium)

    /// 区段标签（设置区块小标题如"字号"、"行距"）
    static let inkRoomSectionLabel = Font.system(.subheadline, design: .default, weight: .medium)
}

// MARK: - LayoutMetrics
// 设计令牌：圆角、间距、尺寸等常量集中管理
enum LayoutMetrics {
    // MARK: Corner Radii
    /// 小圆角 6pt（小芯片、按钮内圆角）
    static let cornerRadiusSmall: CGFloat = 6
    /// 中圆角 8pt（按钮、搜索栏、tab chip）
    static let cornerRadiusMedium: CGFloat = 8
    /// 卡片圆角 12pt（卡片容器、设置区块）
    static let cornerRadiusCard: CGFloat = 12
    /// 大圆角 16pt（弹层顶部、大卡片）
    static let cornerRadiusLarge: CGFloat = 16

    // MARK: Padding
    /// 卡片标准内边距
    static let cardPadding: CGFloat = 16
    /// 紧凑卡片内边距
    static let cardPaddingCompact: CGFloat = 12
    /// 区块水平内边距
    static let sectionHorizontalPadding: CGFloat = 16
    /// 列表行水平内边距
    static let rowHorizontalPadding: CGFloat = 16

    // MARK: Spacing
    /// 标准间距 16pt
    static let standardSpacing: CGFloat = 16
    /// 紧凑间距 8pt
    static let compactSpacing: CGFloat = 8
    /// 微间距 4pt
    static let microSpacing: CGFloat = 4

    // MARK: Touch Targets
    /// 最小触控目标 44pt（HIG 要求）
    static let minTouchTarget: CGFloat = 44
    /// 紧凑触控目标 40pt（仅 expanded 工具栏等空间受限场景）
    static let compactTouchTarget: CGFloat = 40

    // MARK: Component Sizes
    /// 图标徽章尺寸 32pt
    static let iconBadgeSize: CGFloat = 32
    /// 图标徽章圆角 8pt
    static let iconBadgeCornerRadius: CGFloat = 8

    // MARK: Tab Bar
    /// 自定义 TabBar 底部预留高度
    static let bottomInsetForTabBar: CGFloat = 100

    // MARK: Reader
    /// 阅读器 compact 模式垂直内边距
    static let readerCompactVerticalPadding: CGFloat = 40
    /// 阅读器 regular/expanded 模式垂直内边距
    static let readerRegularVerticalPadding: CGFloat = 48
    /// 章节标题字号倍数（相对 readingFontSize）
    static let chapterTitleFontMultiplier: CGFloat = 1.2
}
