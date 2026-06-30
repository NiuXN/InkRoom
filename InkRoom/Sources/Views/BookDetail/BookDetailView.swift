import SwiftUI

struct BookDetailView: View {
    let book: Book
    @EnvironmentObject var viewModel: LibraryViewModel
    @Environment(\.layoutSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var showReader = false
    @State private var showCategoryPicker = false
    @State private var isFavorite: Bool
    @State private var showDeleteConfirmation = false

    init(book: Book) {
        self.book = book
        _isFavorite = State(initialValue: book.isFavorite)
    }

    var body: some View {
        Group {
            if sizeClass == .compact {
                compactDetail
            } else {
                expandedDetail
            }
        }
        .sensoryFeedback(.selection, trigger: isFavorite)
        .background(Color.inkRoomBackground)
        .onChange(of: viewModel.books) { _, books in
            if let updated = books.first(where: { $0.id == book.id }) {
                isFavorite = updated.isFavorite
            } else {
                dismiss()
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    isFavorite.toggle()
                    viewModel.toggleFavorite(for: currentBook)
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(isFavorite ? .inkRoomPrimary : .inkRoomTextTertiary)
                }
            }

            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        showCategoryPicker = true
                    } label: {
                        Label("添加到分类", systemImage: "folder.badge.plus")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除书籍", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.inkRoomTextTertiary)
                }
            }
        }
        .sheet(isPresented: $showCategoryPicker) {
            categoryPickerView
        }
        .alert("删除书籍", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                viewModel.deleteBook(currentBook)
                dismiss()
            }
        } message: {
            Text("确定要删除《\(book.title)》吗？此操作不可撤销。")
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showReader) {
            ReaderView(book: currentBook)
        }
        #else
        .sheet(isPresented: $showReader) {
            ReaderView(book: currentBook)
                .frame(minWidth: 800, minHeight: 600)
        }
        #endif
    }

    // MARK: - Compact Layout (iPhone)
    private var compactDetail: some View {
        ScrollView {
            VStack(spacing: 24) {
                coverSection
                infoSection
                progressSection
                actionButtons
                detailsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Expanded Layout (iPad / macOS)
    private var expandedDetail: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 32) {
                VStack(spacing: 20) {
                    coverSectionLarge
                    actionButtons
                }
                .frame(width: 280)

                VStack(alignment: .leading, spacing: 24) {
                    infoSectionLeading
                    progressSection
                    detailsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(32)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
    }

    private func coverView(width: CGFloat, height: CGFloat, shadowRadius: CGFloat, shadowY: CGFloat, cornerRadius: CGFloat = 12) -> some View {
        CoverImageView(coverURL: currentBook.coverImageURL, title: currentBook.title, isGrid: true)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.1), radius: shadowRadius, y: shadowY)
    }

    private var coverSection: some View {
        VStack(spacing: 16) {
            coverView(width: 160, height: 220, shadowRadius: 12, shadowY: 4)
                .padding(.top, 24)

            Text(currentBook.author)
                .font(.system(size: 15))
                .foregroundColor(.inkRoomTextSecondary)
        }
    }

    private var coverSectionLarge: some View {
        VStack(spacing: 16) {
            coverView(width: 220, height: 300, shadowRadius: 16, shadowY: 6, cornerRadius: 16)
                .padding(.top, 8)

            Text(currentBook.author)
                .font(.system(size: 16))
                .foregroundColor(.inkRoomTextSecondary)
        }
    }

    private var infoSection: some View {
        VStack(spacing: 8) {
            Text(currentBook.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.inkRoomTextPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Label("\(currentBook.totalPages) 页", systemImage: "doc.text")
                Label(wordCountText, systemImage: "character")
            }
            .font(.system(size: 13))
            .foregroundColor(.inkRoomTextTertiary)
        }
    }

    private var infoSectionLeading: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentBook.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.inkRoomTextPrimary)

            Text(currentBook.author)
                .font(.system(size: 16))
                .foregroundColor(.inkRoomTextSecondary)

            HStack(spacing: 20) {
                Label("\(currentBook.totalPages) 页", systemImage: "doc.text")
                Label(wordCountText, systemImage: "character")
            }
            .font(.system(size: 14))
            .foregroundColor(.inkRoomTextTertiary)
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("阅读进度")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.inkRoomTextSecondary)

                Spacer()

                Text("\(Int(currentBook.readingProgress * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.inkRoomPrimary)
            }

            ProgressBar(progress: currentBook.readingProgress, height: 4)

            if currentBook.isStarted {
                HStack {
                    Text("第 \(max(1, currentBook.currentPage)) / \(currentBook.totalPages) 页")
                        .font(.system(size: 12))
                        .foregroundColor(.inkRoomTextTertiary)

                    Spacer()

                    if let lastRead = currentBook.lastReadDate {
                        Text(lastRead.formatted(.relative(presentation: .named)))
                            .font(.system(size: 12))
                            .foregroundColor(.inkRoomTextTertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.inkRoomCard)
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            InkRoomButton(currentBook.isStarted ? "继续阅读" : "开始阅读", icon: "book.fill") {
                showReader = true
            }
            .frame(maxWidth: .infinity)

            Button {
                showCategoryPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                    Text("添加到分类")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.inkRoomTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.inkRoomBackgroundElevated)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("简介")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.inkRoomTextPrimary)

            if let description = currentBook.bookDescription, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomTextSecondary)
                    .lineSpacing(4)
            } else {
                Text("暂无简介内容")
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomTextTertiary)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category Picker
    private var categoryPickerView: some View {
        NavigationStack {
            List {
                ForEach(viewModel.categories) { category in
                    Button {
                        toggleCategory(category)
                    } label: {
                        HStack {
                            Label {
                                Text(category.name)
                            } icon: {
                                Image(safeSystemName: category.iconName)
                                    .foregroundColor(Color(hex: category.colorHex) ?? .inkRoomPrimary)
                            }

                            Spacer()

                            if isBookInCategory(category) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.inkRoomPrimary)
                            }
                        }
                        .foregroundColor(.inkRoomTextPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .scrollContentBackground(.hidden)
            .background(Color.inkRoomBackground)
            .navigationTitle("添加到分类")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        showCategoryPicker = false
                    }
                }
            }
        }
        .frame(minWidth: 320, minHeight: 400)
    }

    private var currentBook: Book {
        viewModel.books.first(where: { $0.id == book.id }) ?? book
    }

    private var wordCountText: String {
        let totalWords = currentBook.totalPages * AppConfig.charsPerPage
        let wanZi = Double(totalWords) / 10000.0
        let formatted = wanZi.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", wanZi)
            : String(format: "%.1f", wanZi)
        return "约 \(formatted) 万字"
    }

    private func isBookInCategory(_ category: Category) -> Bool {
        currentBook.categoryIds.contains(category.id)
    }

    private func toggleCategory(_ category: Category) {
        if isBookInCategory(category) {
            viewModel.removeBookFromCategory(currentBook, category: category)
        } else {
            viewModel.addBookToCategory(currentBook, category: category)
        }
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: Book(
            title: "人间草木",
            author: "汪曾祺",
            totalPages: 256,
            currentPage: 175,
            lastReadDate: Date(),
            isFavorite: true
        ))
        .environmentObject(LibraryViewModel())
    }
}
