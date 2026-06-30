import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @State private var selectedTab: AppSection = .library
    @State private var selectedBook: Book?
    @State private var showImport = false
    @Environment(\.layoutSizeClass) private var sizeClass

    enum AppSection: String, CaseIterable, Identifiable {
        case library = "书架"
        case categories = "分类"
        case statistics = "统计"
        case settings = "我的"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .library: return "book.open"
            case .categories: return "folders"
            case .statistics: return "chart.bar"
            case .settings: return "person"
            }
        }

        var sidebarIcon: String {
            switch self {
            case .library: return "books.vertical"
            case .categories: return "folder.fill"
            case .statistics: return "chart.bar.fill"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        Group {
            switch sizeClass {
            case .compact:
                compactLayout
            case .regular, .expanded:
                expandedLayout
            }
        }
        .sheet(isPresented: $showImport) {
            ImportView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .importBookNotification)) { _ in
            showImport = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsNotification)) { _ in
            #if os(macOS)
            // macOS 由 Settings Scene 处理 Cmd+,，无需在此响应
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            #else
            selectedTab = .settings
            #endif
        }
    }

    // MARK: - Compact Layout (iPhone, narrow windows)
    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LibraryView(selectedBook: $selectedBook)
            }
            .tabItem {
                Label(AppSection.library.rawValue, systemImage: AppSection.library.icon)
            }
            .tag(AppSection.library)

            NavigationStack {
                CategoriesView()
            }
            .tabItem {
                Label(AppSection.categories.rawValue, systemImage: AppSection.categories.icon)
            }
            .tag(AppSection.categories)

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label(AppSection.statistics.rawValue, systemImage: AppSection.statistics.icon)
            }
            .tag(AppSection.statistics)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppSection.settings.rawValue, systemImage: AppSection.settings.icon)
            }
            .tag(AppSection.settings)
        }
        .tint(Color.inkRoomPrimary)
    }

    // MARK: - Expanded Layout (iPad, macOS, wide windows)
    private var expandedLayout: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Color.inkRoomPrimary)
    }

    /// iOS 的 `List(selection:content:)` 要求 selection 为可选 Binding，
    /// 这里桥接非可选的 `selectedTab`（TabView 需要）与 sidebar 的可选需求。
    private var sidebarSelection: Binding<AppSection?> {
        Binding(
            get: { selectedTab },
            set: { if let newValue = $0 { selectedTab = newValue } }
        )
    }

    private var sidebarContent: some View {
        List(selection: sidebarSelection) {
            Section("浏览") {
                ForEach([AppSection.library, .categories]) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.sidebarIcon)
                            .foregroundColor(.inkRoomTextPrimary)
                    }
                    .tag(section)
                }
            }

            Section("个人") {
                NavigationLink(value: AppSection.statistics) {
                    Label(AppSection.statistics.rawValue, systemImage: AppSection.statistics.sidebarIcon)
                        .foregroundColor(.inkRoomTextPrimary)
                }
                .tag(AppSection.statistics)

                NavigationLink(value: AppSection.settings) {
                    Label(AppSection.settings.rawValue, systemImage: AppSection.settings.sidebarIcon)
                        .foregroundColor(.inkRoomTextPrimary)
                }
                .tag(AppSection.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("墨斋")
        .background(Color.inkRoomBackground)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .library:
            NavigationStack {
                LibraryView(selectedBook: $selectedBook)
            }
        case .categories:
            NavigationStack {
                CategoriesView()
            }
        case .statistics:
            NavigationStack {
                StatisticsView()
            }
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel())
        .environmentObject(SettingsViewModel())
}
