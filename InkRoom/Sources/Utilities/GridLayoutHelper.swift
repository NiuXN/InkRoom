import SwiftUI

enum GridLayoutHelper {
    static func columnCount(
        availableWidth: CGFloat,
        cardWidth: CGFloat = 140,
        spacing: CGFloat = 16,
        padding: CGFloat = 32,
        minColumns: Int = 2,
        maxColumns: Int = 8
    ) -> Int {
        let available = max(0, availableWidth - padding)
        let count = max(minColumns, Int((available + spacing) / (cardWidth + spacing)))
        return min(count, maxColumns)
    }

    static func columnCount(
        for sizeClass: LayoutSizeClass,
        cardMinWidth: CGFloat = 160
    ) -> Int {
        switch sizeClass {
        case .compact: return 2
        case .regular: return 3
        case .expanded: return 4
        }
    }
}

private struct ViewWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func readWidth(_ width: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ViewWidthKey.self, value: geometry.size.width)
            }
        }
        .onPreferenceChange(ViewWidthKey.self) { width.wrappedValue = $0 }
    }
}
