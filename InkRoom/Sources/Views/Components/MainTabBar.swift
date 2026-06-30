import SwiftUI

struct MainTabBar: View {
    @Binding var selectedTab: ContentView.AppSection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentView.AppSection.allCases) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = section
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: section.icon)
                            .font(.system(size: 20, weight: selectedTab == section ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)

                        Text(section.rawValue)
                            .font(.inkRoomCaptionEmphasized)
                    }
                    .foregroundStyle(selectedTab == section ? Color.inkRoomPrimary : Color.inkRoomTextTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == section ? .isSelected : [])
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            Color.inkRoomBackgroundElevated
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Divider()
                }
        }
    }
}

#if os(iOS)
struct SwipeableTabContainer<Content: View>: View {
    @Binding var selectedTab: ContentView.AppSection
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                content()
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            MainTabBar(selectedTab: $selectedTab)
        }
        .tint(Color.inkRoomPrimary)
    }
}
#endif
