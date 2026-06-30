import SwiftUI

struct ReaderTOCSidebar: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @ObservedObject var readerVM: ReaderViewModel
    
    @Binding var tocTab: ReaderTocTab
    @Binding var searchText: String
    @Binding var searchResults: [ReaderSearchResult]
    @Binding var isSearching: Bool
    
    var onNavigateToPage: (Int) -> Void
    var onDeleteBookmark: (Bookmark) -> Void
    
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            
            Divider()
            
            switch tocTab {
            case .chapters:
                chaptersList
            case .bookmarks:
                bookmarksList
            case .search:
                searchPanel
            }
        }
        .background(Color.inkRoomBackground)
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "目录", tab: .chapters)
            tabButton(title: "书签", tab: .bookmarks)
            tabButton(title: "搜索", tab: .search)
        }
        .padding(.horizontal, 16)
    }
    
    private func tabButton(title: String, tab: ReaderTocTab) -> some View {
        let isSelected = tocTab == tab
        return Button {
            tocTab = tab
        } label: {
            Text(title)
                .font(.inkRoomHeadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.inkRoomTextPrimary : Color.inkRoomTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var chaptersList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(readerVM.chapters) { chapter in
                    chapterRow(chapter)
                }
            }
        }
    }
    
    private func chapterRow(_ chapter: Chapter) -> some View {
        let isCurrentChapter = readerVM.currentPage >= chapter.startPage && readerVM.currentPage <= chapter.endPage
        return Button {
            onNavigateToPage(chapter.startPage)
        } label: {
            HStack {
                Text(chapter.title)
                    .font(.inkRoomHeadline)
                    .foregroundStyle(Color.inkRoomTextPrimary)
                    .fontWeight(isCurrentChapter ? .semibold : .regular)
                
                Spacer()
                
                if isCurrentChapter {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.inkRoomPrimary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isCurrentChapter ?
            Color.inkRoomPrimary.opacity(0.08) : Color.clear
        )
        .accessibilityValue(isCurrentChapter ? "当前章节" : "")
        .id("toc-chapter-\(chapter.id)")
    }
    
    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if readerVM.bookmarks.isEmpty {
                    EmptyStateView(icon: "bookmark", title: "暂无书签", message: "添加书签后会显示在这里")
                } else {
                    ForEach(readerVM.bookmarks) { bookmark in
                        bookmarkRow(bookmark)
                    }
                }
            }
        }
    }
    
    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onNavigateToPage(bookmark.page)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(bookmark.chapterTitle)
                        .font(.inkRoomBodyEmphasized)
                        .foregroundStyle(Color.inkRoomTextPrimary)
                        .lineLimit(2)
                    
                    Text(bookmark.content)
                        .font(.inkRoomFootnote)
                        .foregroundStyle(Color.inkRoomTextTertiary)
                        .lineLimit(2)
                    
                    Text("第 \(bookmark.page) 页")
                        .font(.inkRoomCaption)
                        .foregroundStyle(Color.inkRoomTextTertiary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            
            Button {
                onDeleteBookmark(bookmark)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkRoomTextTertiary)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("删除书签")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var searchPanel: some View {
        VStack(spacing: 0) {
            searchBar
            
            if isSearching {
                LoadingStateView(text: "搜索中…")
            } else if searchResults.isEmpty {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: searchText.isEmpty ? "搜索正文" : "无搜索结果",
                    message: searchText.isEmpty ? "输入关键词开始查找" : "试试其他关键词"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        Text("共 \(searchResults.count) 个结果")
                            .font(.inkRoomFootnote)
                            .foregroundStyle(Color.inkRoomTextTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        
                        ForEach(searchResults) { result in
                            searchResultRow(result)
                        }
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        InkRoomSearchBar(text: $searchText, placeholder: "搜索内容") {
            scheduleSearch(immediate: true)
        }
        .onChange(of: searchText) { _, _ in
            scheduleSearch()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func searchResultRow(_ result: ReaderSearchResult) -> some View {
        Button {
            onNavigateToPage(result.page)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(result.chapterTitle)
                    .font(.inkRoomBodyEmphasized)
                    .foregroundStyle(Color.inkRoomTextPrimary)
                    .lineLimit(2)
                
                result.attributedContext
                    .font(.inkRoomFootnote)
                    .lineLimit(2)
                
                Text("第 \(result.page) 页")
                    .font(.inkRoomCaption)
                    .foregroundStyle(Color.inkRoomTextTertiary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            searchResults = []
            isSearching = false
            return
        }
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(for: .milliseconds(300))
            }
            if Task.isCancelled { return }
            await performSearch(query: query)
        }
    }
    
    private func performSearch(query: String) async {
        await MainActor.run { isSearching = true }
        
        var results: [ReaderSearchResult] = []
        let charsPerPage = AppConfig.charsPerPage
        let maxResults = 200
        
        if let filePath = readerVM.activeBook.filePath {
            do {
                let fileURL = URL(fileURLWithPath: filePath)
                let parsedBook = try await BookParserService.shared.parseBook(from: fileURL)
                
                let chapterStartPages = readerVM.chapters.map { $0.startPage }
                
                for (index, chapter) in parsedBook.chapters.enumerated() {
                    if Task.isCancelled { break }
                    let content = chapter.content
                    var searchRange = content.startIndex..<content.endIndex
                    
                    let chapterStartPage = index < chapterStartPages.count ? chapterStartPages[index] : 1
                    
                    while let range = content.range(of: query, options: .caseInsensitive, range: searchRange) {
                        let lowerBound = content.index(
                            range.lowerBound,
                            offsetBy: -20,
                            limitedBy: content.startIndex
                        ) ?? content.startIndex
                        let upperBound = content.index(
                            range.upperBound,
                            offsetBy: 20,
                            limitedBy: content.endIndex
                        ) ?? content.endIndex
                        
                        var context = String(content[lowerBound..<upperBound])
                            .replacingOccurrences(of: "\n", with: " ")
                            .replacingOccurrences(of: "\r", with: " ")
                        if lowerBound != content.startIndex { context = "…" + context }
                        if upperBound != content.endIndex { context += "…" }
                        
                        let offsetInChapter = content.distance(from: content.startIndex, to: range.lowerBound)
                        let page = chapterStartPage + (offsetInChapter / charsPerPage)
                        
                        results.append(ReaderSearchResult(
                            chapterIndex: index,
                            chapterTitle: chapter.title,
                            context: context,
                            page: page,
                            attributedContext: ReaderSearchResult.highlightedContext(context, query: query)
                        ))
                        
                        if results.count >= maxResults { break }
                        searchRange = range.upperBound..<content.endIndex
                    }
                    
                    if results.count >= maxResults { break }
                }
            } catch {
                print("Search failed: \(error)")
            }
        }
        
        await MainActor.run {
            searchResults = results
            isSearching = false
        }
    }
}

extension ReaderSearchResult {
    static func highlightedContext(_ context: String, query: String) -> Text {
        guard !query.isEmpty,
              let range = context.range(of: query, options: .caseInsensitive) else {
            return Text(context)
                .foregroundStyle(Color.inkRoomTextTertiary)
        }
        return Text(context[context.startIndex..<range.lowerBound])
            .foregroundStyle(Color.inkRoomTextTertiary)
            + Text(context[range])
                .foregroundStyle(Color.inkRoomPrimary)
                .fontWeight(.semibold)
            + Text(context[range.upperBound..<context.endIndex])
                .foregroundStyle(Color.inkRoomTextTertiary)
    }
}
