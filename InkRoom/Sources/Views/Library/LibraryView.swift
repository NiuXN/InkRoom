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
                Button {
                    showImport = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                }
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
                    viewModel.deleteBook(book)
                    bookToDelete = nil
                }
            }
        } message: {
            if let book = bookToDelete {
                Text("确定要删除《\(book.title)》吗？此操作不可撤销。")
            }
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.inkRoomTextTertiary)
            TextField("搜索书名或作者", text: $viewModel.searchText)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.inkRoomBackgroundElevated)
        .cornerRadius(10)
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
                                .font(.system(size: 14))
                                .frame(width: 22)
                            Text(group.rawValue)
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(bookCount(for: group))")
                                .font(.system(size: 12))
                                .foregroundColor(.inkRoomTextTertiary)
                        }
                        .foregroundColor(viewModel.selectedGroup == group ? .inkRoomPrimary : .inkRoomTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedGroup == group ?
                            Color.inkRoomPrimary.opacity(0.12) : Color.clear
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BookGroup.allCases) { group in
                            Button {
                                withAnimation {
                                    viewModel.selectedGroup = group
                                }
                            } label: {
                                Text(group.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(viewModel.selectedGroup == group ? .white : .inkRoomTextSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        viewModel.selectedGroup == group ?
                                        Color.inkRoomPrimary : Color.inkRoomBackgroundElevated
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
            }
        }
    }

    private func groupIcon(for group: BookGroup) -> String {
        group.icon
    }

    private func bookCount(for group: BookGroup) -> Int {
        BookFilter.count(in: viewModel.books, for: group)
    }

    private var bookContent: some View {
        Group {
            if viewModel.isLoading {
                loadingState
            } else if viewModel.filteredBooks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if sizeClass != .expanded {
                            HStack {
                                Spacer()
                                viewModeToggle
                            }
                            .padding(.horizontal, 16)
                        }

                        if viewModel.viewMode == .grid {
                            adaptiveGridView
                        } else {
                            listView
                        }
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

    private var loadingState: some View {
        VStack(spacing: 12) {
            Spacer()

            ProgressView()
                .tint(.inkRoomPrimary)
                .scaleEffect(1.2)

            Text("正在加载书架...")
                .font(.system(size: 14))
                .foregroundColor(.inkRoomTextTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: sizeClass == .compact ? 48 : 64))
                .foregroundColor(.inkRoomPrimary.opacity(0.5))

            Text("书架空空如也")
                .font(.system(size: sizeClass == .compact ? 17 : 20, weight: .medium))
                .foregroundColor(.inkRoomTextPrimary)

            Text("开启你的阅读之旅")
                .font(.system(size: sizeClass == .compact ? 14 : 15))
                .foregroundColor(.inkRoomTextTertiary)

            InkRoomButton("导入书籍", icon: "plus") {
                showImport = true
            }
            .padding(.top, 8)

            Spacer()
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
                    .foregroundColor(viewModel.viewMode == .grid ? .inkRoomPrimary : .inkRoomTextTertiary)
                    .padding(8)
            }

            Button {
                withAnimation {
                    viewModel.viewMode = .list
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16))
                    .foregroundColor(viewModel.viewMode == .list ? .inkRoomPrimary : .inkRoomTextTertiary)
                    .padding(8)
            }
        }
        .background(Color.inkRoomBackgroundElevated)
        .cornerRadius(8)
    }

    private var adaptiveGridView: some View {
        let columns = GridLayoutHelper.columnCount(
            availableWidth: contentWidth > 0 ? contentWidth : 390,
            cardWidth: 140,
            spacing: 16,
            padding: sizeClass == .expanded ? 48 : 32
        )
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
            ForEach(viewModel.filteredBooks) { book in
                Button {
                    selectedBook = book
                } label: {
                    BookCard(book: book, viewMode: .grid)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        favoriteTrigger += 1
                        viewModel.toggleFavorite(for: book)
                    } label: {
                        Label(book.isFavorite ? "取消收藏" : "收藏", systemImage: book.isFavorite ? "heart.slash" : "heart")
                    }

                    Divider()

                    Button(role: .destructive) {
                        bookToDelete = book
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.filteredBooks.count)
        }
        .padding(.horizontal, sizeClass == .expanded ? 24 : 16)
    }

    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.filteredBooks) { book in
                Button {
                    selectedBook = book
                } label: {
                    BookCard(book: book, viewMode: .list)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        bookToDelete = book
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }

                    Button {
                        favoriteTrigger += 1
                        viewModel.toggleFavorite(for: book)
                    } label: {
                        Label(book.isFavorite ? "取消收藏" : "收藏", systemImage: book.isFavorite ? "heart.slash" : "heart")
                    }
                    .tint(.inkRoomPrimary)
                }
                .contextMenu {
                    Button {
                        favoriteTrigger += 1
                        viewModel.toggleFavorite(for: book)
                    } label: {
                        Label(book.isFavorite ? "取消收藏" : "收藏", systemImage: book.isFavorite ? "heart.slash" : "heart")
                    }

                    Divider()

                    Button(role: .destructive) {
                        bookToDelete = book
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.filteredBooks.count)
        }
        .padding(.horizontal, sizeClass == .expanded ? 24 : 16)
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryViewModel())
}
