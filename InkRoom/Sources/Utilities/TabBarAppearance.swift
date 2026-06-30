import SwiftUI
#if os(iOS)
import UIKit
#endif

enum TabBarAppearance {
    static func configure() {
        #if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.inkRoomBackgroundElevated)

        let normalColor = UIColor(Color.inkRoomTextTertiary)
        let selectedColor = UIColor(Color.inkRoomPrimary)

        [appearance.stackedLayoutAppearance,
         appearance.inlineLayoutAppearance,
         appearance.compactInlineLayoutAppearance].forEach { item in
            item.normal.iconColor = normalColor
            item.normal.titleTextAttributes = [.foregroundColor: normalColor]
            item.selected.iconColor = selectedColor
            item.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = normalColor
        #endif
    }
}

struct TabBarStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(.inkRoomPrimary)
            #if os(iOS)
            .toolbarBackground(Color.inkRoomBackgroundElevated, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            #endif
    }
}

extension View {
    func inkRoomTabBarStyle() -> some View {
        modifier(TabBarStyleModifier())
    }
}
