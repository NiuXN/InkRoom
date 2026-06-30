import SwiftUI

struct InkRoomButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case ghost

        var backgroundColor: Color {
            switch self {
            case .primary: return .inkRoomPrimary
            case .secondary: return .inkRoomPrimaryLight
            case .ghost: return .clear
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary: return .inkRoomOnPrimary
            case .secondary: return .inkRoomPrimary
            case .ghost: return .inkRoomPrimary
            }
        }
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(safeSystemName: icon)
                        .font(.inkRoomBodyEmphasized)
                }
                Text(title)
                    .font(.inkRoomBodyEmphasized)
            }
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, LayoutMetrics.sectionHorizontalPadding)
            .padding(.vertical, 12)
            .background(style.backgroundColor)
            .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
        }
    }
}

struct InkRoomIconButton: View {
    let icon: String
    let size: CGFloat
    let accessibilityLabel: String?
    let action: () -> Void

    init(_ icon: String, size: CGFloat = 20, accessibilityLabel: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(safeSystemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(Color.inkRoomTextPrimary)
                .frame(width: LayoutMetrics.minTouchTarget, height: LayoutMetrics.minTouchTarget)
        }
        .accessibilityLabel(accessibilityLabel ?? "")
    }
}

struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.inkRoomPrimaryMuted)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.inkRoomPrimary)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - InkRoomCardStyle
/// 卡片样式 ViewModifier，统一 padding + 背景 + 圆角
struct InkRoomCardModifier: ViewModifier {
    var padding: CGFloat = LayoutMetrics.cardPadding
    var background: Color = Color.inkRoomCard
    var cornerRadius: CGFloat = LayoutMetrics.cornerRadiusCard

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

extension View {
    /// 应用标准卡片样式（padding 16 + inkRoomCard 背景 + 圆角 12）
    func inkRoomCard(
        padding: CGFloat = LayoutMetrics.cardPadding,
        background: Color = Color.inkRoomCard,
        cornerRadius: CGFloat = LayoutMetrics.cornerRadiusCard
    ) -> some View {
        modifier(InkRoomCardModifier(
            padding: padding,
            background: background,
            cornerRadius: cornerRadius
        ))
    }
}

// MARK: - EmptyStateView
/// 统一的空状态视图
struct EmptyStateView: View {
    let icon: String
    var iconSize: CGFloat = 48
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(safeSystemName: icon)
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(Color.inkRoomTextTertiary)

            Text(title)
                .font(.inkRoomTitle)
                .foregroundStyle(Color.inkRoomTextPrimary)

            Text(message)
                .font(.inkRoomSubheadlineRegular)
                .foregroundStyle(Color.inkRoomTextSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                InkRoomButton(actionTitle, icon: nil, style: .secondary, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 48)
    }
}

// MARK: - LoadingStateView
/// 统一的加载状态视图
struct LoadingStateView: View {
    var text: String = "加载中…"

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.1)
            Text(text)
                .font(.inkRoomSubheadlineRegular)
                .foregroundStyle(Color.inkRoomTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - InkRoomChipButton
/// 选中态 chip 按钮，统一阅读器/设置页中的"紧凑/标准/宽松"等选择按钮样式
struct InkRoomChipButton: View {
    let title: String
    let isSelected: Bool
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.inkRoomFootnoteEmphasized)
                .foregroundStyle(isSelected ? Color.inkRoomOnPrimary : Color.inkRoomTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.inkRoomPrimary : Color.inkRoomBackgroundElevated)
                .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - IconBadgeView
/// 圆形图标徽章：Circle 背景 + 居中 Image，用于设置行/列表项前缀
struct IconBadgeView: View {
    let icon: String
    var iconSize: CGFloat = 16
    var badgeSize: CGFloat = LayoutMetrics.iconBadgeSize
    var color: Color = Color.inkRoomPrimary
    var background: Color = Color.inkRoomPrimaryLight

    var body: some View {
        ZStack {
            Circle()
                .fill(background)
                .frame(width: badgeSize, height: badgeSize)

            Image(safeSystemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

// MARK: - InkRoomSearchBar
/// 统一搜索栏样式
struct InkRoomSearchBar: View {
    @Binding var text: String
    var placeholder: String = "搜索"
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(safeSystemName: "magnifyingglass")
                .font(.inkRoomSubheadline)
                .foregroundStyle(Color.inkRoomTextTertiary)

            TextField(placeholder, text: $text)
                .font(.inkRoomBody)
                .foregroundStyle(Color.inkRoomTextPrimary)
                .submitLabel(.search)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(safeSystemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.inkRoomTextTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.inkRoomBackgroundElevated)
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusMedium))
    }
}

#Preview {
    VStack(spacing: 20) {
        InkRoomButton("开始阅读", icon: "book.fill") {}
        InkRoomButton("导入书籍", icon: "plus", style: .secondary) {}
        InkRoomButton("取消", style: .ghost) {}

        ProgressBar(progress: 0.68)
            .frame(width: 200)

        InkRoomChipButton(title: "紧凑", isSelected: true) {}
        InkRoomChipButton(title: "标准", isSelected: false) {}

        IconBadgeView(icon: "gear")

        EmptyStateView(
            icon: "books.vertical",
            title: "书架为空",
            message: "导入你的第一本书，开始阅读之旅",
            actionTitle: "导入书籍"
        ) {}
        .frame(height: 300)
    }
    .padding()
}
