import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.layoutSizeClass) private var sizeClass
    @State private var selectedCategory: Category?
    @State private var showAddCategory = false
    @State private var categoryToDelete: Category?
    @State private var showDeleteConfirmation = false
    @State private var isEditingCategories = false
    @State private var selectedBook: Book?
    @State private var contentWidth: CGFloat = 0
    @State private var showError = false
    @State private var deleteTrigger = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                    Text("共 \(viewModel.books.count) 本书 · \(viewModel.categories.count) 个分类")
                        .font(.inkRoomFootnote)
                        .foregroundStyle(Color.inkRoomTextTertiary)
                        .padding(.top, 8)

                    let columns = GridLayoutHelper.columnCount(
                        availableWidth: contentWidth > 0 ? contentWidth : 390,
                        cardWidth: sizeClass == .compact ? 160 : 200,
                        spacing: 12,
                        padding: contentPadding * 2,
                        minColumns: 2,
                        maxColumns: 4
                    )
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columns), spacing: 12) {
                        ForEach(viewModel.categories) { category in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    guard !isEditingCategories else { return }
                                    selectedCategory = category
                                } label: {
                                    CategoryCard(category: category)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        ContextMenuDismiss.run {
                                            confirmDelete(category)
                                        }
                                    } label: {
                                        Label("删除分类", systemImage: "trash")
                                    }
                                }

                                if isEditingCategories {
                                    Button {
                                        confirmDelete(category)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 22))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(Color.inkRoomOnPrimary, .red)
                                    }
                                    .accessibilityLabel("删除分类")
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }

                        addCategoryButton
                            .onTapGesture {
                                showAddCategory = true
                            }
                    }
                    .padding(.horizontal, contentPadding)

                    uncategorizedSection
            }
            .padding(.bottom, LayoutMetrics.bottomInsetForTabBar)
            .readWidth($contentWidth)
        }
        .refreshable {
            await viewModel.loadData()
        }
        .background(Color.inkRoomBackground)
        .navigationTitle("分类")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .sensoryFeedback(.impact(weight: .medium), trigger: deleteTrigger)
        .toolbar {
                ToolbarItem(placement: .automatic) {
                    if !viewModel.categories.isEmpty {
                        Button(isEditingCategories ? "完成" : "编辑") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isEditingCategories.toggle()
                            }
                        }
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("新建分类")
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView { newCategory in
                    Task {
                        await viewModel.addCategory(newCategory)
                    }
                }
            }
            .alert("删除分类", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {
                    categoryToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteTrigger += 1
                        Task {
                            await viewModel.deleteCategory(category)
                        }
                        categoryToDelete = nil
                        if isEditingCategories, viewModel.categories.isEmpty {
                            isEditingCategories = false
                        }
                    }
                }
            } message: {
                if let category = categoryToDelete {
                    Text("确定要删除「\(category.name)」吗？分类内的书籍不会被删除。")
                }
            }
            .navigationDestination(item: $selectedCategory) { category in
                CategoryDetailView(category: category)
            }
            .navigationDestination(item: $selectedBook) { book in
                BookDetailView(book: book)
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

    private func confirmDelete(_ category: Category) {
        categoryToDelete = category
        showDeleteConfirmation = true
    }

    private var addCategoryButton: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .fill(Color.inkRoomTextTertiary.opacity(0.4))
                    .frame(width: 40, height: 40)

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.inkRoomTextTertiary)
            }

            Text("新建分类")
                .font(.inkRoomBodyEmphasized)
                .foregroundStyle(Color.inkRoomTextTertiary)

            Spacer()
        }
        .padding(LayoutMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.inkRoomCard.opacity(0.5))
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
        .overlay {
            RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusCard)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .fill(Color.inkRoomTextTertiary.opacity(0.2))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showAddCategory = true
        }
        #if os(iOS)
        .hoverEffect(.lift)
        #endif
    }

    private var contentPadding: CGFloat {
        sizeClass == .compact ? 16 : 24
    }

    private var uncategorizedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("未分类")
                .font(.inkRoomSubheadline)
                .foregroundStyle(Color.inkRoomTextSecondary)
                .padding(.horizontal, contentPadding)

            // Books with no categories OR books whose categories were deleted
            let validCategoryIds = Set(viewModel.categories.map { $0.id })
            let uncategorizedBooks = viewModel.books.filter { book in
                book.categoryIds.isEmpty || 
                !book.categoryIds.contains(where: { validCategoryIds.contains($0) })
            }

            if uncategorizedBooks.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    iconSize: 40,
                    title: "暂无未分类书籍",
                    message: ""
                )
                .padding(.horizontal, contentPadding)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(uncategorizedBooks) { book in
                            Button {
                                selectedBook = book
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    CoverImageView(coverURL: book.coverImageURL, title: book.title, isGrid: true)
                                        .frame(width: 80, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: LayoutMetrics.cornerRadiusSmall))

                                    Text(book.title)
                                        .font(.inkRoomFootnoteEmphasized)
                                        .foregroundStyle(Color.inkRoomTextPrimary)
                                        .lineLimit(1)
                                }
                                .frame(width: 80)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, contentPadding)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct CategoryCard: View {
    let category: Category

    var categoryColor: Color {
        Color(hex: category.colorHex) ?? Color.inkRoomPrimary
    }

    var body: some View {
        HStack(spacing: 12) {
            IconBadgeView(
                icon: category.iconName,
                iconSize: 18,
                badgeSize: 40,
                color: categoryColor,
                background: categoryColor.opacity(0.15)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.inkRoomBodyEmphasized)
                    .foregroundStyle(Color.inkRoomTextPrimary)
                    .lineLimit(1)

                Text("\(category.bookIds.count)本")
                    .font(.inkRoomCaption)
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkRoomTextTertiary)
        }
        .padding(LayoutMetrics.cardPadding)
        .background(Color.inkRoomCard)
        .clipShape(.rect(cornerRadius: LayoutMetrics.cornerRadiusCard))
        .shadow(color: Color.inkRoomShadow(opacity: 0.03), radius: 2, y: 1)
    }
}

struct CategoryDetailView: View {
    let category: Category
    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.layoutSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBook: Book?
    @State private var showDeleteConfirmation = false

    private var liveCategory: Category {
        viewModel.categories.first(where: { $0.id == category.id }) ?? category
    }

    var categoryBooks: [Book] {
        viewModel.books.filter { liveCategory.bookIds.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    IconBadgeView(
                        icon: liveCategory.iconName,
                        iconSize: 24,
                        badgeSize: 56,
                        color: Color(hex: liveCategory.colorHex) ?? Color.inkRoomPrimary,
                        background: Color(hex: liveCategory.colorHex)?.opacity(0.15) ?? Color.inkRoomPrimaryLight
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(liveCategory.name)
                            .font(.inkRoomLargeTitle)
                            .foregroundStyle(Color.inkRoomTextPrimary)

                        Text("\(categoryBooks.count) 本书")
                            .font(.inkRoomSubheadlineRegular)
                            .foregroundStyle(Color.inkRoomTextTertiary)
                    }

                    Spacer()
                }
                .padding(.horizontal, contentPadding)
                .padding(.top, 8)

                if categoryBooks.isEmpty {
                    EmptyStateView(
                        icon: "books.vertical",
                        iconSize: 40,
                        title: "该分类暂无书籍",
                        message: "在书籍详情页可将书籍加入此分类"
                    )
                    .padding(.horizontal, contentPadding)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(categoryBooks) { book in
                            Button {
                                selectedBook = book
                            } label: {
                                BookCard(book: book, viewMode: .list)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, contentPadding)
                }
            }
            .padding(.bottom, LayoutMetrics.bottomInsetForTabBar)
            .frame(maxWidth: detailMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color.inkRoomBackground)
        .navigationTitle(liveCategory.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .medium))
                }
                .accessibilityLabel("删除分类")
            }
        }
        .alert("删除分类", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                Task {
                    await viewModel.deleteCategory(liveCategory)
                }
                dismiss()
            }
        } message: {
            Text("确定要删除「\(liveCategory.name)」吗？分类内的书籍不会被删除。")
        }
        .onChange(of: viewModel.categories) { _, categories in
            if !categories.contains(where: { $0.id == category.id }) {
                dismiss()
            }
        }
        .navigationDestination(item: $selectedBook) { book in
            BookDetailView(book: book)
        }
    }

    private var contentPadding: CGFloat {
        sizeClass == .compact ? 16 : 24
    }

    private var detailMaxWidth: CGFloat? {
        switch sizeClass {
        case .compact:
            return nil
        case .regular:
            return 720
        case .expanded:
            return 800
        }
    }
}

#Preview {
    CategoriesView()
        .environmentObject(LibraryViewModel())
}
