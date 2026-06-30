import SwiftUI

enum ReaderTocTab {
    case chapters
    case bookmarks
    case search
}

struct ReaderSearchResult: Identifiable {
    let id = UUID()
    let chapterIndex: Int
    let chapterTitle: String
    let context: String
    let page: Int
    let attributedContext: Text
}

/// 跨平台圆角集合，替代 UIRectCorner
struct RectCornerSet: OptionSet, Sendable {
    let rawValue: Int

    static let topLeft = RectCornerSet(rawValue: 1 << 0)
    static let bottomLeft = RectCornerSet(rawValue: 1 << 1)
    static let bottomRight = RectCornerSet(rawValue: 1 << 2)
    static let topRight = RectCornerSet(rawValue: 1 << 3)
    static let allCorners: RectCornerSet = [.topLeft, .bottomLeft, .bottomRight, .topRight]
}

/// 跨平台指定角圆角的 Shape，使用 CGPath 实现，兼容 iOS/macOS
struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: RectCornerSet

    func path(in rect: CGRect) -> Path {
        let cgPath = CGMutablePath()

        let tl = corners.contains(.topLeft) ? radius : 0
        let tr = corners.contains(.topRight) ? radius : 0
        let bl = corners.contains(.bottomLeft) ? radius : 0
        let br = corners.contains(.bottomRight) ? radius : 0

        // 角度（弧度）：0=右，π/2=下，π=左，3π/2=上
        // 起点：左上角圆角之后
        cgPath.move(to: CGPoint(x: rect.minX, y: rect.minY + tl))

        // 左上角圆角（若启用）：从 π(左) 到 3π/2(上)
        if tl > 0 {
            cgPath.addArc(
                center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                radius: tl,
                startAngle: .pi,
                endAngle: .pi * 1.5,
                clockwise: false
            )
        }

        // 顶边 -> 右上角
        cgPath.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))

        // 右上角：从 3π/2(上) 到 2π(右)
        if tr > 0 {
            cgPath.addArc(
                center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                radius: tr,
                startAngle: .pi * 1.5,
                endAngle: .pi * 2,
                clockwise: false
            )
        }

        // 右边 -> 右下角
        cgPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))

        // 右下角：从 0(右) 到 π/2(下)
        if br > 0 {
            cgPath.addArc(
                center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                radius: br,
                startAngle: 0,
                endAngle: .pi / 2,
                clockwise: false
            )
        }

        // 底边 -> 左下角
        cgPath.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))

        // 左下角：从 π/2(下) 到 π(左)
        if bl > 0 {
            cgPath.addArc(
                center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                radius: bl,
                startAngle: .pi / 2,
                endAngle: .pi,
                clockwise: false
            )
        }

        cgPath.closeSubpath()
        return Path(cgPath)
    }
}

extension View {
    /// 仅对指定角应用圆角（跨平台）
    func cornerRadius(_ radius: CGFloat, corners: RectCornerSet) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}
