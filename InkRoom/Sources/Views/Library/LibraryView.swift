import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.layoutSizeClass) private var sizeClass
    @State private var showImport = false
    @State private var bookToDelete: Book?
    @State private var showDeleteConfirmation = false
    @State private var favoriteTrigger: Int = 0
    @State private var deleteTrigger: Int = 0
    @State private var contentWidth: CGFloat = 0
    @State private var showError = false
    @State private var cachedColumnCount: Int = 2
    @Binding var selectedBook: Book?

    init(selectedBook: Binding<Book?>? = nil) {
        self._selectedBook = selectedBook ?? .constant(nil)
    }

    var body: some View {
        Group {
            if sizeClass == .expanded {
                expandedLibrary
            } else {
                standardLibrary
            }
        }
        .sensoryFeedback(.selection, trigger: favoriteTrigger)
        .sensoryFeedback(.impact(weight: .heavy), trigger: deleteTrigger)
        .background(Color.inkRoomBackground)
        .navigationTitle("书架")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                sortMenu
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showImport = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                }
                .accessibilityLabel("导入书籍")
            }
        }
        .sheet(isPresented: $showImport) {
            ImportView()
        }
        .navigationDestination(item: $selectedBook) { book in
            BookDetailView(book: book)
        }
        .alert("删除书籍", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                bookToDelete = nil
            }
            Button("删除", role: .destructive) {
                if let book = bookToDelete {
                    deleteTrigger += 1
                    Task {
                        await viewModel.deleteBook(book)
                    }
                    if selectedBook?.id == book.id {
                        selectedBook = nil
                    }
                    bookToDelete = nil
                }
            }
        } message: {
            if let book = bookToDelete {
                Text("确定要删除《\(book.title)》吗？此操作不可撤销。")
            }
        }
        .onChange(of: viewModel.errorMessage) { _, message in
            showError = message != nil
        }
        .alert("操作失败", isPresented: $showError) {
            Button("确定", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Standard Layout (iPhone / narrow)
    private var standardLibrary: some View {
        VStack(spacing: 0) {
            searchBar
            groupTabs
            bookContent
        }
    }

    // MARK: - Expanded Layout (iPad / macOS / wide)
    private var expandedLibrary: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                searchBar
                    .padding(.bottom, 8)
                groupTabs
                Spacer(minLength: 0)
            }
            .frame(width: 280)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .background(Color.inkRoomBackgroundElevated.opacity(0.5))

            Divider()

            bookContent
                .frame(maxWidth: .infinity)
        }
    }

    private var searchBar: some View {
        InkRoomSearchBar(text: $viewModel.searchText, placeholder: "搜索书名或作者")
    }

    private var groupTabs: some View {
        VStack(alignment: .leading, spacing: 6) {
            if sizeClass == .expanded {
                ForEach(BookGroup.allCases) { group in
                    Button {
                        withAnimation {
                            viewModel.selectedGroup = group
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: groupIcon(for: group))
                                .font(.inkRoomBody)
                                .frame(width: 22)
                            Text(group.rawValue)
                                .font(.inkRoomBodyEmphasized)
                            Spacer()
                            Text("\(bookCount(for: group))")
                                .font(.inkRoomFootnote)
                                .foregroundStyle(Color.inkRoomTextTertiary)
                        }
                        .foregroundStyle(viewModel.selectedGroup == group ? Color.inkRoomPrimary : Color.inkRoomTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedGroup == group ?
                            Color.inkRoomPrimary.opacity(0.12) : Color.clear
                        )
                        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusMedium))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(BookGroup.allCases) { group in
                            InkRoomChipButton(
                                title: group.rawValue,
                                isSelected: viewModel.selectedGroup == group,
                                accessibilityLabel: group.rawValue
                            ) {
                                withAnimation {
                                    viewModel.selectedGroup = group
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, 12)
            }
        }
    }

    private func groupIcon(for group: BookGroup) -> String {
        group.icon
    }

    private func bookCount(for group: BookGroup) -> Int {
        viewModel.groupBookCounts[group] ?? 0
    }

    private var bookContent: some View {
        Group {
            if viewModel.isLoading {
                loadingState
            } else if viewModel.filteredBooks.isEmpty {
                if viewModel.books.isEmpty {
                    emptyState
                } else {
                    noResultsState
                }
            } else if viewModel.viewMode == .list {
                listContent
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if sizeClass != .expanded {
                            HStack(spacing: 8) {
                                sortMenuCompact
                                Spacer()
                                viewModeToggle
                            }
                            .padding(.horizontal, 16)
                        }

                        adaptiveGridView
                    }
                    .padding(.vertical, 16)
                    .readWidth($contentWidth)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.filteredBooks.isEmpty)
        .refreshable {
            await viewModel.loadData()
        }
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                sortMenuCompact
                Spacer()
                viewModeToggle
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            List {
                ForEach(viewModel.filteredBooks) { book in
                    Button {
                        selectedBook = book
                    } label: {
                        BookCard(book: book, viewMode: .list)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                bookToDelete = book
                                showDeleteConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }

                            Button {
                                favoriteTrigger += 1
                                Task {
                                    await viewModel.toggleFavorite(for: book)
                                }
                            } label: {
                                Label(book.isFavorite ? "取消收藏" : "收藏", systemImage: book.isFavorite ? "heart.slash" : "heart")
                            }
                            .tint(Color.inkRoomPrimary)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    @ViewBuilder
    private func bookContextMenu(for book: Book) -> some View {
        Button {
            ContextMenuDismiss.run {
                favoriteTrigger += 1
                Task {
                    await viewModel.toggleFavorite(for: book)
                }
            }
        } label: {
            Label(book.isFavorite ? "取消收藏" : "收藏", systemImage: book.isFavorite ? "heart.slash" : "heart")
        }

        Divider()

        Button(role: .destructive) {
            ContextMenuDismiss.run {
                bookToDelete = book
                showDeleteConfirmation = true
            }
        } label: {
            Label("删除", systemImage: "trash")
        }
    }

    private var noResultsState: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            iconSize: 48,
            title: "没有匹配的书籍",
            message: "试试调整搜索词或切换分组",
            actionTitle: viewModel.searchText.isEmpty ? nil : "清除搜索",
            action: viewModel.searchText.isEmpty ? nil : { viewModel.searchText = "" }
        )
    }

    private var loadingState: some View {
        LoadingStateView(text: "正在加载书架...")
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isImporting {
            LoadingStateView(text: "正在导入...")
        } else {
            EmptyStateView(
                icon: "books.vertical",
                iconSize: sizeClass == .compact ? 48 : 64,
                title: "书架空空如也",
                message: "开启你的阅读之旅",
                actionTitle: "导入书籍",
                action: { showImport = true }
            )
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(BookSortOption.allCases) { option in
                Button {
                    viewModel.setSortOption(option)
                } label: {
                    HStack {
                        Label(option.rawValue, systemImage: option.icon)
                        if viewModel.sortOption == option {
                            Spacer()
                            Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16, weight: .medium))
        }
        .accessibilityLabel("排序：\(viewModel.sortOption.rawValue)，\(viewModel.sortOrderLabel)")
    }

    private var sortMenuCompact: some View {
        Menu {
            ForEach(BookSortOption.allCases) { option in
                Button {
                    viewModel.setSortOption(option)
                } label: {
                    if viewModel.sortOption == option {
                        Label(
                            "\(option.rawValue)（\(viewModel.sortOrderLabel)）",
                            systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                        )
                    } else {
                        Label(option.rawValue, systemImage: option.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.inkRoomSubheadline)
                Text(viewModel.sortOption.rawValue)
                    .font(.inkRoomSubheadline)
                Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.inkRoomTextSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.inkRoomBackgroundElevated)
            .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusMedium))
        }
    }

    private var viewModeToggle: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation {
                    viewModel.viewMode = .grid
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 16))
                    .foregroundStyle(viewModel.viewMode == .grid ? Color.inkRoomPrimary : Color.inkRoomTextTertiary)
                    .padding(8)
            }
            .accessibilityLabel("网格视图")
            .accessibilityAddTraits(viewModel.viewMode == .grid ? .isSelected : [])

            Button {
                withAnimation {
                    viewModel.viewMode = .list
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
                    .foregroundStyle(viewModel.viewMode == .list ? Color.inkRoomPrimary : Color.inkRoomTextTertiary)
                    .padding(8)
            }
            .accessibilityLabel("列表视图")
            .accessibilityAddTraits(viewModel.viewMode == .list ? .isSelected : [])
        }
        .background(Color.inkRoomBackgroundElevated)
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusMedium))
    }

    private var adaptiveGridView: some View {
        // Cache column count calculation - only recalculate when width or size class changes
        let columns = cachedColumnCount
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
            ForEach(viewModel.filteredBooks) { book in
                Button {
                    selectedBook = book
                } label: {
                    BookCard(book: book, viewMode: .grid)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    bookContextMenu(for: book)
                }
            }
        }
        .padding(.horizontal, sizeClass == .expanded ? 24 : 16)
        .onChange(of: contentWidth) { _, newWidth in
            updateColumnCount(width: newWidth)
        }
        .onChange(of: sizeClass) { _, _ in
            updateColumnCount(width: contentWidth)
        }
        .onAppear {
            updateColumnCount(width: contentWidth)
        }
    }

    private func updateColumnCount(width: CGFloat) {
        let newCount = GridLayoutHelper.columnCount(
            availableWidth: width > 0 ? width : 390,
            cardWidth: 140,
            spacing: 16,
            padding: sizeClass == .expanded ? 48 : 32
        )
        if newCount != cachedColumnCount {
            cachedColumnCount = newCount
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryViewModel())
}
