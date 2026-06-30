import SwiftUI

struct ReaderView: View {
    let book: Book
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.layoutSizeClass) private var sizeClass
    @Environment(\.isLandscape) private var isLandscape
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var ttsService = TTSService.shared
    @StateObject private var readerVM: ReaderViewModel

    @State private var showHeader = false
    @State private var showToc = false
    @State private var showSettings = false
    @State private var showTTSPanel = false
    @State private var tocTab: TocTab = .chapters
    @State private var ttsTimer: Timer?
    @State private var ttsRemainingTime: TimeInterval = 0
    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var pageBoundaryHit: Int = 0
    @State private var ttsAutoAdvanceTrigger: Int = 0

    private var isScrollMode: Bool {
        settingsViewModel.pageTurnStyle == .scroll
    }

    init(book: Book) {
        self.book = book
        _readerVM = StateObject(wrappedValue: ReaderViewModel(book: book))
    }

    enum TocTab {
        case chapters
        case bookmarks
        case search
    }

    struct SearchResult: Identifiable {
        let id = UUID()
        let chapterIndex: Int
        let chapterTitle: String
        let context: String
        let page: Int
    }

    var body: some View {
        Group {
            if sizeClass == .compact {
                compactReader
            } else {
                expandedReader
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: readerVM.isCurrentPageBookmarked)
        .sensoryFeedback(.warning, trigger: pageBoundaryHit)
        .onAppear {
            readerVM.attach(library: libraryViewModel)
            readerVM.onAppear(isScrollMode: isScrollMode)
            if readerVM.activeBook.filePath == nil {
                readerVM.applyDemoPageText(sampleText)
            }
            setupTTSService()
        }
        .onDisappear {
            readerVM.onDisappear()
            ttsService.onSpeechFinish = nil
            ttsService.stop()
            stopTTSTimer()
        }
        .onChange(of: ttsAutoAdvanceTrigger) { _, _ in
            if readerVM.currentPage < readerVM.activeBook.totalPages {
                _ = readerVM.nextPage(isScrollMode: isScrollMode)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    startTTS()
                }
            }
        }
    }

    // MARK: - Compact Reader (iPhone)
    private var compactReader: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showHeader {
                    compactHeader
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
                readerContent
                Spacer()

                if ttsService.isSpeaking || ttsService.isPaused || showTTSPanel {
                    ttsCompactPanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                compactBottomBar
            }

            if showToc {
                tocOverlay
            }

            #if os(iOS)
            if showSettings {
                settingsOverlay
            }
            #endif
        }
        #if os(macOS)
        .sheet(isPresented: $showSettings) {
            settingsPopover
                .frame(width: 360, height: 420)
        }
        #endif
        .contentShape(Rectangle())
        .gesture(
            settingsViewModel.pageTurnStyle == .swipe ?
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        nextPage()
                    } else if value.translation.width > 50 {
                        prevPage()
                    }
                } : nil
        )
    }

    // MARK: - Expanded Reader (iPad / macOS)
    private var expandedReader: some View {
        NavigationSplitView {
            tocSidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    expandedToolbar

                    readerContent
                        .frame(maxWidth: .infinity)

                    if ttsService.isSpeaking || ttsService.isPaused {
                        ttsExpandedPanel
                    }

                    expandedBottomBar
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var tocSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    tocTab = .chapters
                } label: {
                    Text("目录")
                        .font(.system(size: 15, weight: tocTab == .chapters ? .semibold : .regular))
                        .foregroundColor(tocTab == .chapters ? .inkRoomTextPrimary : .inkRoomTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Button {
                    tocTab = .bookmarks
                } label: {
                    Text("书签")
                        .font(.system(size: 15, weight: tocTab == .bookmarks ? .semibold : .regular))
                        .foregroundColor(tocTab == .bookmarks ? .inkRoomTextPrimary : .inkRoomTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Button {
                    tocTab = .search
                } label: {
                    Text("搜索")
                        .font(.system(size: 15, weight: tocTab == .search ? .semibold : .regular))
                        .foregroundColor(tocTab == .search ? .inkRoomTextPrimary : .inkRoomTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)

            Divider()

            if tocTab == .chapters {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(readerVM.chapters) { chapter in
                            tocRow(chapter)
                        }
                    }
                }
            } else if tocTab == .bookmarks {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if readerVM.bookmarks.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 32))
                                    .foregroundColor(.inkRoomTextTertiary)
                                Text("暂无书签")
                                    .font(.system(size: 13))
                                    .foregroundColor(.inkRoomTextTertiary)
                            }
                            .padding(.top, 48)
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(readerVM.bookmarks) { bookmark in
                                bookmarkRow(bookmark)
                            }
                        }
                    }
                }
            } else {
                searchPanel
            }
        }
        .background(Color.inkRoomBackground)
    }

    private var expandedToolbar: some View {
        HStack(spacing: 4) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)

                Text("第 \(readerVM.currentPage) / \(readerVM.activeBook.totalPages) 页")
                    .font(.system(size: 11))
                    .foregroundColor(textColor.opacity(0.6))
            }

            Spacer()

            Button {
                toggleBookmark()
            } label: {
                Image(systemName: readerVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(readerVM.isCurrentPageBookmarked ? .inkRoomPrimary : textColor)
                    .frame(width: 40, height: 40)
            }

            Button {
                toggleTTS()
            } label: {
                Image(systemName: ttsService.isSpeaking ? "headphones.circle.fill" : "headphones")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ttsService.isSpeaking ? .inkRoomPrimary : textColor)
                    .frame(width: 40, height: 40)
            }

            Menu {
                Button {
                    showSettings.toggle()
                } label: {
                    Label("阅读设置", systemImage: "textformat.size")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(textColor)
                    .frame(width: 40, height: 40)
            }
            .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                settingsPopover
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var expandedBottomBar: some View {
        VStack(spacing: 0) {
            ProgressBar(progress: readerVM.activeBook.totalPages > 0 ? Double(readerVM.currentPage) / Double(readerVM.activeBook.totalPages) : 0, height: 2)

            HStack {
                Button {
                    prevPage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("上一页")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(readerVM.currentPage > 1 ? textColor : textColor.opacity(0.3))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(textColor.opacity(0.08))
                    .cornerRadius(8)
                }
                .disabled(readerVM.currentPage <= 1)

                Spacer()

                Text("\(readerVM.currentPage) / \(readerVM.activeBook.totalPages)")
                    .font(.system(size: 13))
                    .foregroundColor(textColor.opacity(0.7))

                Spacer()

                Button {
                    nextPage()
                } label: {
                    HStack(spacing: 6) {
                        Text("下一页")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(readerVM.currentPage < readerVM.activeBook.totalPages ? textColor : textColor.opacity(0.3))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(textColor.opacity(0.08))
                    .cornerRadius(8)
                }
                .disabled(readerVM.currentPage >= readerVM.activeBook.totalPages)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .background(backgroundColor.opacity(0.95))
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Font Size
            VStack(alignment: .leading, spacing: 8) {
                Text("字号")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.inkRoomTextSecondary)

                HStack {
                    Button {
                        if settingsViewModel.readingFontSize > 12 {
                            settingsViewModel.readingFontSize -= 1
                        }
                    } label: {
                        Text("A")
                            .font(.system(size: 14))
                            .foregroundColor(.inkRoomTextPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.inkRoomBackgroundElevated)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Slider(
                        value: Binding(
                            get: { Double(settingsViewModel.readingFontSize) },
                            set: { settingsViewModel.readingFontSize = Int($0) }
                        ),
                        in: 12...28,
                        step: 1
                    )
                    .tint(.inkRoomPrimary)
                    .frame(width: 180)

                    Button {
                        if settingsViewModel.readingFontSize < 28 {
                            settingsViewModel.readingFontSize += 1
                        }
                    } label: {
                        Text("A")
                            .font(.system(size: 20))
                            .foregroundColor(.inkRoomTextPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.inkRoomBackgroundElevated)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Line Spacing
            VStack(alignment: .leading, spacing: 8) {
                Text("行距")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.inkRoomTextSecondary)

                HStack(spacing: 8) {
                    ForEach([6, 10, 14], id: \.self) { spacing in
                        Button {
                            settingsViewModel.readingLineSpacing = spacing
                        } label: {
                            Text(spacing == 6 ? "紧凑" : spacing == 10 ? "标准" : "宽松")
                                .font(.system(size: 12))
                                .foregroundColor(settingsViewModel.readingLineSpacing == spacing ? .white : .inkRoomTextSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    settingsViewModel.readingLineSpacing == spacing ?
                                    Color.inkRoomPrimary : Color.inkRoomBackgroundElevated
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Theme
            VStack(alignment: .leading, spacing: 8) {
                Text("主题")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.inkRoomTextSecondary)

                HStack(spacing: 10) {
                    ForEach(ReadingSettings.ReaderTheme.allCases, id: \.self) { theme in
                        themeButton(theme)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(Color.inkRoomCard)
    }

    // MARK: - Common
    private var backgroundColor: Color {
        Color(hex: settingsViewModel.readerTheme.backgroundColor) ?? .readerBackgroundLight
    }

    private var textColor: Color {
        Color(hex: settingsViewModel.readerTheme.textColor) ?? .inkRoomTextPrimary
    }

    private var safeAreaTop: CGFloat {
        #if os(iOS)
        return (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top) ?? 44
        #else
        return 0
        #endif
    }

    private var safeAreaBottom: CGFloat {
        #if os(iOS)
        return (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom) ?? 34
        #else
        return 0
        #endif
    }

    private var compactHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textColor)

                    Text("第 \(readerVM.currentPage) / \(readerVM.activeBook.totalPages) 页")
                        .font(.system(size: 11))
                        .foregroundColor(textColor.opacity(0.6))
                }

                Spacer()

                Button {
                    toggleBookmark()
                } label: {
                    Image(systemName: readerVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(readerVM.isCurrentPageBookmarked ? .inkRoomPrimary : textColor)
                        .frame(width: 44, height: 44)
                }

                Button {
                    showToc = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            ProgressBar(progress: readerVM.activeBook.totalPages > 0 ? Double(readerVM.currentPage) / Double(readerVM.activeBook.totalPages) : 0, height: 2)
                .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .padding(.top, safeAreaTop)
        .background(backgroundColor.opacity(0.95))
    }

    private var readerContent: some View {
        GeometryReader { geometry in
            let maxWidth = contentMaxWidth(for: geometry.size.width)

            ZStack {
                if settingsViewModel.pageTurnStyle == .scroll {
                    scrollContentView(maxWidth: maxWidth)
                } else {
                    pageContentView(maxWidth: maxWidth)
                }

                if settingsViewModel.pageTurnStyle != .scroll {
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if settingsViewModel.pageTurnStyle == .tap || settingsViewModel.pageTurnStyle == .swipe {
                                    prevPage()
                                }
                            }

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showHeader.toggle()
                                }
                            }

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if settingsViewModel.pageTurnStyle == .tap || settingsViewModel.pageTurnStyle == .swipe {
                                    nextPage()
                                }
                            }
                    }
                }
            }
        }
    }

    private func pageContentView(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(settingsViewModel.readingLineSpacing)) {
            if readerVM.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if !readerVM.currentChapterTitle.isEmpty {
                    Text(readerVM.currentChapterTitle)
                        .font(.system(size: CGFloat(settingsViewModel.readingFontSize) * 1.2, weight: .bold))
                        .foregroundColor(textColor)
                        .padding(.bottom, 8)
                }

                if ttsService.isSpeaking && settingsViewModel.ttsHighlightEnabled,
                   let range = ttsService.currentSentenceRange,
                   let textRange = Range(range, in: readerVM.pageText) {
                    Text(readerVM.pageText[readerVM.pageText.startIndex..<textRange.lowerBound])
                        .foregroundColor(textColor)
                    + Text(readerVM.pageText[textRange])
                        .foregroundColor(.inkRoomPrimary)
                        .fontWeight(.semibold)
                    + Text(readerVM.pageText[textRange.upperBound..<readerVM.pageText.endIndex])
                        .foregroundColor(textColor)
                } else {
                    Text(readerVM.pageText)
                        .foregroundColor(textColor)
                }
            }
        }
        .font(.system(size: CGFloat(settingsViewModel.readingFontSize)))
        .lineSpacing(CGFloat(settingsViewModel.readingLineSpacing))
        .tracking(CGFloat(settingsViewModel.readingLetterSpacing) * 0.1)
        .frame(maxWidth: maxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, sizeClass == .compact ? 40 : 48)
    }

    private func scrollContentView(maxWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: CGFloat(settingsViewModel.readingLineSpacing)) {
                    if readerVM.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        ForEach(Array(readerVM.chapters.enumerated()), id: \.offset) { index, chapter in
                            VStack(alignment: .leading, spacing: CGFloat(settingsViewModel.readingLineSpacing)) {
                                Text(chapter.title)
                                    .font(.system(size: CGFloat(settingsViewModel.readingFontSize) * 1.2, weight: .bold))
                                    .foregroundColor(textColor)
                                    .padding(.top, index == 0 ? 0 : 24)
                                    .padding(.bottom, 8)

                                Text(readerVM.chapterDisplayText(at: index))
                                    .font(.system(size: CGFloat(settingsViewModel.readingFontSize)))
                                    .foregroundColor(textColor)
                                    .lineSpacing(CGFloat(settingsViewModel.readingLineSpacing))
                                    .tracking(CGFloat(settingsViewModel.readingLetterSpacing) * 0.1)
                            }
                            .id("chapter-\(index)")
                            .background(
                                // Only track frames for chapters near the current reading position
                                // This reduces layout passes significantly for large books
                                Group {
                                    if shouldTrackFrame(for: index) {
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: ChapterFramePreferenceKey.self,
                                                value: [index: geo.frame(in: .named("readerScroll"))]
                                            )
                                        }
                                    }
                                }
                            )
                            .task(id: index) {
                                await readerVM.ensureChapterTextLoaded(at: index)
                            }
                        }
                    }
                }
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, sizeClass == .compact ? 40 : 48)
            }
            .coordinateSpace(name: "readerScroll")
            .onPreferenceChange(ChapterFramePreferenceKey.self) { frames in
                readerVM.updateFromScroll(frames: frames)
            }
            .onChange(of: readerVM.pendingScrollToPage) { _, page in
                guard let page else { return }
                let index = ScrollReadingPosition.chapterIndex(for: page, in: readerVM.chapters)
                withAnimation {
                    proxy.scrollTo("chapter-\(index)", anchor: .top)
                }
                readerVM.pendingScrollToPage = nil
            }
        }
    }

    private func contentMaxWidth(for availableWidth: CGFloat) -> CGFloat {
        switch sizeClass {
        case .compact:
            if isLandscape {
                return min(availableWidth - 96, 600)
            }
            return availableWidth - 48
        case .regular:
            return min(availableWidth - 96, 640)
        case .expanded:
            return min(availableWidth - 160, 720)
        }
    }

    private var compactBottomBar: some View {
        VStack(spacing: 0) {
            ProgressBar(progress: readerVM.activeBook.totalPages > 0 ? Double(readerVM.currentPage) / Double(readerVM.activeBook.totalPages) : 0, height: 2)

            HStack {
                Button {
                    prevPage()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一页")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(readerVM.currentPage > 1 ? textColor : textColor.opacity(0.3))
                }
                .disabled(readerVM.currentPage <= 1)

                Spacer()

                Button {
                    toggleTTS()
                } label: {
                    Image(systemName: ttsService.isSpeaking ? "headphones.circle.fill" : "headphones")
                        .font(.system(size: 20))
                        .foregroundColor(ttsService.isSpeaking ? .inkRoomPrimary : textColor)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 18))
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Button {
                    nextPage()
                } label: {
                    HStack(spacing: 4) {
                        Text("下一页")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(readerVM.currentPage < readerVM.activeBook.totalPages ? textColor : textColor.opacity(0.3))
                }
                .disabled(readerVM.currentPage >= readerVM.activeBook.totalPages)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, safeAreaBottom)
        .background(backgroundColor.opacity(0.95))
    }

    private var tocOverlay: some View {
        ZStack(alignment: .trailing) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showToc = false
                    }
                }

            VStack(spacing: 0) {
                HStack {
                    Text("目录")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.inkRoomTextPrimary)

                    Spacer()

                    Button {
                        withAnimation {
                            showToc = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundColor(.inkRoomTextTertiary)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)

                HStack(spacing: 0) {
                    Button {
                        tocTab = .chapters
                    } label: {
                        Text("目录")
                            .font(.system(size: 14, weight: tocTab == .chapters ? .semibold : .regular))
                            .foregroundColor(tocTab == .chapters ? .inkRoomTextPrimary : .inkRoomTextTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }

                    Button {
                        tocTab = .bookmarks
                    } label: {
                        Text("书签")
                            .font(.system(size: 14, weight: tocTab == .bookmarks ? .semibold : .regular))
                            .foregroundColor(tocTab == .bookmarks ? .inkRoomTextPrimary : .inkRoomTextTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }

                    Button {
                        tocTab = .search
                    } label: {
                        Text("搜索")
                            .font(.system(size: 14, weight: tocTab == .search ? .semibold : .regular))
                            .foregroundColor(tocTab == .search ? .inkRoomTextPrimary : .inkRoomTextTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 8)

                Divider()

                if tocTab == .chapters {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(readerVM.chapters) { chapter in
                                tocRow(chapter)
                            }
                        }
                    }
                } else if tocTab == .bookmarks {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if readerVM.bookmarks.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 32))
                                        .foregroundColor(.inkRoomTextTertiary)
                                    Text("暂无书签")
                                        .font(.system(size: 13))
                                        .foregroundColor(.inkRoomTextTertiary)
                                }
                                .padding(.top, 48)
                                .frame(maxWidth: .infinity)
                            } else {
                                ForEach(readerVM.bookmarks) { bookmark in
                                    bookmarkRow(bookmark)
                                }
                            }
                        }
                    }
                } else {
                    searchPanel
                }
            }
            .frame(width: 280)
            .frame(maxHeight: .infinity)
            .background(Color.inkRoomCard)
        }
    }

    private func tocRow(_ chapter: Chapter) -> some View {
        let isCurrentChapter = readerVM.currentPage >= chapter.startPage && readerVM.currentPage <= chapter.endPage
        return Button {
            navigateToPage(chapter.startPage)
            withAnimation {
                showToc = false
            }
        } label: {
            HStack {
                Text(chapter.title)
                    .font(.system(size: 15))
                    .foregroundColor(.inkRoomTextPrimary)
                    .fontWeight(isCurrentChapter ? .semibold : .regular)

                Spacer()

                if isCurrentChapter {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.inkRoomPrimary)
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
        .id("toc-chapter-\(chapter.id)")
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                navigateToPage(bookmark.page)
                withAnimation {
                    showToc = false
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(bookmark.chapterTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.inkRoomTextPrimary)
                        .lineLimit(1)

                    Text(bookmark.content)
                        .font(.system(size: 12))
                        .foregroundColor(.inkRoomTextTertiary)
                        .lineLimit(2)

                    Text("第 \(bookmark.page) 页")
                        .font(.system(size: 11))
                        .foregroundColor(.inkRoomTextTertiary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                libraryViewModel.removeBookmark(bookmark)
                loadBookmarks()
                checkCurrentPageBookmark()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomTextTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func loadBookmarks() {
        readerVM.loadBookmarks()
    }

    // MARK: - Search

    private var searchPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomTextTertiary)

                TextField("搜索内容", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(.inkRoomTextPrimary)
                    .submitLabel(.search)
                    .onSubmit {
                        scheduleSearch(immediate: true)
                    }
                    .onChange(of: searchText) { _, _ in
                        scheduleSearch()
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        isSearching = false
                        searchTask?.cancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.inkRoomTextTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.inkRoomBackgroundElevated)
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if isSearching {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.9)
                    Text("搜索中...")
                        .font(.system(size: 13))
                        .foregroundColor(.inkRoomTextTertiary)
                }
                .padding(.top, 48)
                .frame(maxWidth: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.inkRoomTextTertiary)
                    Text(searchText.isEmpty ? "输入关键词搜索" : "无搜索结果")
                        .font(.system(size: 13))
                        .foregroundColor(.inkRoomTextTertiary)
                }
                .padding(.top, 48)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        Text("共 \(searchResults.count) 个结果")
                            .font(.system(size: 12))
                            .foregroundColor(.inkRoomTextTertiary)
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

    private func searchResultRow(_ result: SearchResult) -> some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = result.context
        let contextText: Text
        if !query.isEmpty,
           let range = context.range(of: query, options: .caseInsensitive) {
            contextText = Text(context[context.startIndex..<range.lowerBound])
                .foregroundColor(.inkRoomTextTertiary)
                + Text(context[range])
                    .foregroundColor(.inkRoomPrimary)
                    .fontWeight(.semibold)
                + Text(context[range.upperBound..<context.endIndex])
                    .foregroundColor(.inkRoomTextTertiary)
        } else {
            contextText = Text(context)
                .foregroundColor(.inkRoomTextTertiary)
        }

        return Button {
            navigateToPage(result.page)
            withAnimation {
                showToc = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(result.chapterTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.inkRoomTextPrimary)
                    .lineLimit(1)

                contextText
                    .font(.system(size: 12))
                    .lineLimit(2)

                Text("第 \(result.page) 页")
                    .font(.system(size: 11))
                    .foregroundColor(.inkRoomTextTertiary.opacity(0.7))
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
        let delay: UInt64 = immediate ? 0 : 300_000_000
        searchTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            if Task.isCancelled { return }
            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        await MainActor.run { isSearching = true }

        var results: [SearchResult] = []
        let charsPerPage = AppConfig.charsPerPage
        let maxResults = 200

        if let filePath = readerVM.activeBook.filePath {
            do {
                let fileURL = URL(fileURLWithPath: filePath)
                let parsedBook = try await BookParserService.shared.parseBook(from: fileURL)

                // Use chapter's startPage from the chapters array for accurate page mapping
                // This ensures search results jump to the correct page even if chapter order differs
                let chapterStartPages = readerVM.chapters.map { $0.startPage }

                for (index, chapter) in parsedBook.chapters.enumerated() {
                    if Task.isCancelled { break }
                    let content = chapter.content
                    var searchRange = content.startIndex..<content.endIndex

                    // Get the start page for this chapter (default to 1 if not found)
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

                        // Calculate page based on chapter's start page + offset within chapter
                        let offsetInChapter = content.distance(from: content.startIndex, to: range.lowerBound)
                        let page = chapterStartPage + (offsetInChapter / charsPerPage)

                        results.append(SearchResult(
                            chapterIndex: index,
                            chapterTitle: chapter.title,
                            context: context,
                            page: page
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

    private func toggleBookmark() {
        readerVM.toggleBookmark(pageText: readerVM.pageText, chapterTitle: readerVM.currentChapterTitle)
    }

    private func checkCurrentPageBookmark() {
        readerVM.checkCurrentPageBookmark()
    }

    #if os(iOS)
    private var settingsOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showSettings = false
                    }
                }

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.inkRoomTextTertiary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("字号")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.inkRoomTextSecondary)

                        HStack {
                            Button {
                                if settingsViewModel.readingFontSize > 12 {
                                    settingsViewModel.readingFontSize -= 1
                                }
                            } label: {
                                Text("A")
                                    .font(.system(size: 14))
                                    .foregroundColor(.inkRoomTextPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.inkRoomBackgroundElevated)
                                    .cornerRadius(8)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(settingsViewModel.readingFontSize) },
                                    set: { settingsViewModel.readingFontSize = Int($0) }
                                ),
                                in: 12...28,
                                step: 1
                            )
                            .tint(.inkRoomPrimary)

                            Button {
                                if settingsViewModel.readingFontSize < 28 {
                                    settingsViewModel.readingFontSize += 1
                                }
                            } label: {
                                Text("A")
                                    .font(.system(size: 22))
                                    .foregroundColor(.inkRoomTextPrimary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.inkRoomBackgroundElevated)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("主题")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.inkRoomTextSecondary)

                        HStack(spacing: 12) {
                            ForEach(ReadingSettings.ReaderTheme.allCases, id: \.self) { theme in
                                themeButton(theme)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, safeAreaBottom)
            }
            .background(Color.inkRoomCard)
            .cornerRadius(16, corners: [.topLeft, .topRight])
        }
    }
    #endif

    private func themeButton(_ theme: ReadingSettings.ReaderTheme) -> some View {
        let isSelected = settingsViewModel.readerTheme == theme
        let bgColor = Color(hex: theme.backgroundColor) ?? .white

        return Button {
            settingsViewModel.readerTheme = theme
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(bgColor)
                .frame(width: 60, height: 40)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.inkRoomPrimary : Color.inkRoomTextTertiary.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func prevPage() {
        if !readerVM.prevPage(isScrollMode: isScrollMode) {
            pageBoundaryHit += 1
        }
    }

    private func nextPage() {
        if !readerVM.nextPage(isScrollMode: isScrollMode) {
            pageBoundaryHit += 1
        }
    }

    private func navigateToPage(_ page: Int) {
        readerVM.navigateToPage(page, isScrollMode: isScrollMode)
    }

    private func setupTTSService() {
        ttsService.onSpeechFinish = {
            Task { @MainActor in
                ttsAutoAdvanceTrigger += 1
            }
        }
    }

    private func toggleTTS() {
        if ttsService.isSpeaking || ttsService.isPaused {
            stopTTS()
        } else {
            startTTS()
        }
    }

    private func startTTS() {
        let text = readerVM.pageText
        guard !text.isEmpty else { return }

        let voiceId = settingsViewModel.ttsVoiceIdentifier.isEmpty ? nil : settingsViewModel.ttsVoiceIdentifier
        ttsService.setBookInfo(title: readerVM.activeBook.title, chapter: readerVM.currentChapterTitle)
        ttsService.speak(
            text: text,
            voiceIdentifier: voiceId,
            rate: Float(settingsViewModel.ttsRate),
            pitchMultiplier: Float(settingsViewModel.ttsPitch)
        )

        if settingsViewModel.ttsTimerMinutes > 0 {
            startTTSTimer(minutes: settingsViewModel.ttsTimerMinutes)
        }
    }

    private func pauseTTS() {
        ttsService.pause()
    }

    private func resumeTTS() {
        ttsService.resume()
    }

    private func stopTTS() {
        ttsService.stop()
        stopTTSTimer()
    }

    private func startTTSTimer(minutes: Int) {
        stopTTSTimer()
        ttsRemainingTime = TimeInterval(minutes * 60)
        ttsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                ttsRemainingTime -= 1
                if ttsRemainingTime <= 0 {
                    stopTTS()
                }
            }
        }
    }

    private func stopTTSTimer() {
        ttsTimer?.invalidate()
        ttsTimer = nil
        ttsRemainingTime = 0
    }

    private var ttsCompactPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    prevPage()
                    if ttsService.isSpeaking || ttsService.isPaused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            startTTS()
                        }
                    }
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 18))
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                }

                Button {
                    if ttsService.isPaused {
                        resumeTTS()
                    } else if ttsService.isSpeaking {
                        pauseTTS()
                    } else {
                        startTTS()
                    }
                } label: {
                    Image(systemName: ttsService.isSpeaking && !ttsService.isPaused ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.inkRoomPrimary)
                        .frame(width: 56, height: 56)
                }

                Button {
                    nextPage()
                    if ttsService.isSpeaking || ttsService.isPaused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            startTTS()
                        }
                    }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 18))
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("听书")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textColor)

                    if ttsRemainingTime > 0 {
                        Text(timeString(from: ttsRemainingTime))
                            .font(.system(size: 11))
                            .foregroundColor(.inkRoomPrimary)
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTTSPanel.toggle()
                    }
                } label: {
                    Image(systemName: showTTSPanel ? "chevron.down.circle" : "chevron.up.circle")
                        .font(.system(size: 18))
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                }
            }

            if showTTSPanel {
                Divider()
                    .background(textColor.opacity(0.1))

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("语速")
                            .font(.system(size: 13))
                            .foregroundColor(textColor.opacity(0.7))
                            .frame(width: 40, alignment: .leading)

                        Slider(
                            value: Binding(
                                get: { settingsViewModel.ttsRate },
                                set: { settingsViewModel.ttsRate = $0 }
                            ),
                            in: 0.3...0.8,
                            step: 0.05
                        )
                        .tint(.inkRoomPrimary)
                        .onChange(of: settingsViewModel.ttsRate) { _, _ in
                            if ttsService.isSpeaking {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    startTTS()
                                }
                            }
                        }

                        Text(String(format: "%.0f%%", settingsViewModel.ttsRate * 200))
                            .font(.system(size: 12))
                            .foregroundColor(textColor.opacity(0.7))
                            .frame(width: 40)
                    }

                    HStack(spacing: 8) {
                        Text("定时")
                            .font(.system(size: 13))
                            .foregroundColor(textColor.opacity(0.7))
                            .frame(width: 40, alignment: .leading)

                        ForEach([0, 15, 30, 60], id: \.self) { minutes in
                            Button {
                                settingsViewModel.ttsTimerMinutes = minutes
                                if minutes > 0 && (ttsService.isSpeaking || ttsService.isPaused) {
                                    startTTSTimer(minutes: minutes)
                                } else if minutes == 0 {
                                    stopTTSTimer()
                                }
                            } label: {
                                Text(minutes == 0 ? "不定时" : "\(minutes)分钟")
                                    .font(.system(size: 12))
                                    .foregroundColor(
                                        settingsViewModel.ttsTimerMinutes == minutes ?
                                        .white : textColor.opacity(0.7)
                                    )
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        settingsViewModel.ttsTimerMinutes == minutes ?
                                        Color.inkRoomPrimary : textColor.opacity(0.08)
                                    )
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { settingsViewModel.ttsHighlightEnabled },
                            set: { settingsViewModel.ttsHighlightEnabled = $0 }
                        )) {
                            Text("朗读高亮")
                                .font(.system(size: 13))
                                .foregroundColor(textColor.opacity(0.7))
                        }
                        .tint(.inkRoomPrimary)
                        .labelsHidden()

                        Text("朗读高亮")
                            .font(.system(size: 13))
                            .foregroundColor(textColor.opacity(0.7))

                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.inkRoomCard)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var ttsExpandedPanel: some View {
        HStack(spacing: 12) {
            Button {
                prevPage()
                if ttsService.isSpeaking || ttsService.isPaused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        startTTS()
                    }
                }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
                    .frame(width: 36, height: 36)
            }

            Button {
                if ttsService.isPaused {
                    resumeTTS()
                } else if ttsService.isSpeaking {
                    pauseTTS()
                } else {
                    startTTS()
                }
            } label: {
                Image(systemName: ttsService.isSpeaking && !ttsService.isPaused ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.inkRoomPrimary)
            }

            Button {
                nextPage()
                if ttsService.isSpeaking || ttsService.isPaused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        startTTS()
                    }
                }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
                    .frame(width: 36, height: 36)
            }

            Text("听书")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textColor)
                .padding(.leading, 4)

            if ttsRemainingTime > 0 {
                Text(timeString(from: ttsRemainingTime))
                    .font(.system(size: 12))
                    .foregroundColor(.inkRoomPrimary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text("语速")
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.6))

                Slider(
                    value: Binding(
                        get: { settingsViewModel.ttsRate },
                        set: { settingsViewModel.ttsRate = $0 }
                    ),
                    in: 0.3...0.8,
                    step: 0.05
                )
                .tint(.inkRoomPrimary)
                .frame(width: 100)
                .onChange(of: settingsViewModel.ttsRate) { _, _ in
                    if ttsService.isSpeaking {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            startTTS()
                        }
                    }
                }
            }

            Menu {
                Picker("定时停止", selection: Binding(
                    get: { settingsViewModel.ttsTimerMinutes },
                    set: { newValue in
                        settingsViewModel.ttsTimerMinutes = newValue
                        if newValue > 0 && (ttsService.isSpeaking || ttsService.isPaused) {
                            startTTSTimer(minutes: newValue)
                        } else if newValue == 0 {
                            stopTTSTimer()
                        }
                    }
                )) {
                    Text("不定时").tag(0)
                    Text("15分钟").tag(15)
                    Text("30分钟").tag(30)
                    Text("60分钟").tag(60)
                }
            } label: {
                Image(systemName: "timer")
                    .font(.system(size: 16))
                    .foregroundColor(textColor)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.inkRoomCard)
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Only track frames for chapters near the current reading position.
    /// This significantly reduces layout passes for large books with many chapters.
    private func shouldTrackFrame(for chapterIndex: Int) -> Bool {
        let currentIndex = readerVM.currentChapterIndex
        // Track current chapter and ±2 neighbors
        return abs(chapterIndex - currentIndex) <= 2
    }

    private var sampleText: String {
        """
        如果你来访，我不在，请和我门外的花坐一会儿。它们很温暖，我注视它们很多很多日子了。

        它们开得不茂盛，想起来什么说什么，没有话说时，尽管长着碧叶。

        你说我在做梦吗？人生如梦，我投入的却是真情。世界先爱了我，我不能不爱它。

        只记花开不记人，你在花里，如花在风中。

        那一年，花开得不是最好，可是还好，我遇见你。那一年，花开得好极了，好像专是为了你。那一年，花开得很迟，还好，有你。
        """
    }
}

// MARK: - Corner Radius Extension
#if os(iOS)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

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
#else
extension View {
    func cornerRadius(_ radius: CGFloat, corners: some Any) -> some View {
        self.cornerRadius(radius)
    }
}
#endif

#Preview {
    ReaderView(book: Book(
        title: "人间草木",
        author: "汪曾祺",
        totalPages: 256,
        currentPage: 1
    ))
    .environmentObject(SettingsViewModel())
    .environmentObject(LibraryViewModel())
}
