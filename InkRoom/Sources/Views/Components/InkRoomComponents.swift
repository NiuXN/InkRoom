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
            case .primary: return .white
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
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(style.backgroundColor)
            .cornerRadius(12)
        }
    }
}

struct InkRoomIconButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    init(_ icon: String, size: CGFloat = 20, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.inkRoomTextPrimary)
                .frame(width: 44, height: 44)
        }
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

#Preview {
    VStack(spacing: 20) {
        InkRoomButton("开始阅读", icon: "book.open") {}
        InkRoomButton("导入书籍", icon: "plus", style: .secondary) {}
        InkRoomButton("取消", style: .ghost) {}

        ProgressBar(progress: 0.68)
            .frame(width: 200)
    }
    .padding()
}
