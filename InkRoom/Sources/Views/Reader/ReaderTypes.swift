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

#if os(iOS)
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
#else
extension View {
    func cornerRadius(_ radius: CGFloat, corners: some Any) -> some View {
        self.cornerRadius(radius)
    }
}
#endif
