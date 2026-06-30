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
    @State private var tocTab: ReaderTocTab = .chapters
    @State private var searchText: String = ""
    @State private var searchResults: [ReaderSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var pageBoundaryHit: Int = 0
    @State private var ttsAutoAdvanceTrigger: Int = 0

    private var isScrollMode: Bool {
        settingsViewModel.pageTurnStyle == .scroll
    }

    init(book: Book) {
        self.book = book
        _readerVM = StateObject(wrappedValue: ReaderViewModel(book: book))
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
        }
        .onChange(of: ttsAutoAdvanceTrigger) { _, _ in
            if readerVM.currentPage < readerVM.activeBook.totalPages {
                _ = readerVM.nextPage(isScrollMode: isScrollMode)
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
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
                    ReaderCompactHeader(
                        book: book,
                        currentPage: readerVM.currentPage,
                        totalPages: readerVM.activeBook.totalPages,
                        isBookmarked: readerVM.isCurrentPageBookmarked,
                        textColor: textColor,
                        backgroundColor: backgroundColor,
                        onToggleBookmark: toggleBookmark,
                        onShowToc: { showToc = true }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
                
                ReaderContentView(
                    readerVM: readerVM,
                    ttsService: ttsService,
                    isScrollMode: isScrollMode,
                    textColor: textColor,
                    onPrevPage: prevPage,
                    onNextPage: nextPage,
                    onToggleHeader: { showHeader.toggle() }
                )
                
                Spacer()

                if ttsService.isSpeaking || ttsService.isPaused || showTTSPanel {
                    ReaderTTSCompactPanel(
                        ttsService: ttsService,
                        textColor: textColor,
                        showExtended: $showTTSPanel,
                        onPrevPage: prevPage,
                        onNextPage: nextPage,
                        onStart: startTTS,
                        onPause: pauseTTS,
                        onResume: resumeTTS,
                        onRestart: startTTS
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                ReaderCompactBottomBar(
                    currentPage: readerVM.currentPage,
                    totalPages: readerVM.activeBook.totalPages,
                    isSpeaking: ttsService.isSpeaking,
                    textColor: textColor,
                    backgroundColor: backgroundColor,
                    onPrevPage: prevPage,
                    onNextPage: nextPage,
                    onToggleTTS: toggleTTS,
                    onShowSettings: { showSettings = true }
                )
            }

            if showToc {
                tocOverlay
            }

            #if os(iOS)
            if showSettings {
                ReaderSettingsOverlay(isPresented: $showSettings)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
        #if os(macOS)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsPopover()
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
            ReaderTOCSidebar(
                readerVM: readerVM,
                tocTab: $tocTab,
                searchText: $searchText,
                searchResults: $searchResults,
                isSearching: $isSearching,
                onNavigateToPage: navigateToPage,
                onDeleteBookmark: { bookmark in
                    Task {
                        await libraryViewModel.removeBookmark(bookmark)
                        await readerVM.loadBookmarks()
                        await readerVM.checkCurrentPageBookmark()
                    }
                }
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ReaderExpandedToolbar(
                        book: book,
                        currentPage: readerVM.currentPage,
                        totalPages: readerVM.activeBook.totalPages,
                        isBookmarked: readerVM.isCurrentPageBookmarked,
                        isSpeaking: ttsService.isSpeaking,
                        textColor: textColor,
                        showSettings: $showSettings,
                        onToggleBookmark: toggleBookmark,
                        onToggleTTS: toggleTTS
                    )

                    ReaderContentView(
                        readerVM: readerVM,
                        ttsService: ttsService,
                        isScrollMode: isScrollMode,
                        textColor: textColor,
                        onPrevPage: prevPage,
                        onNextPage: nextPage,
                        onToggleHeader: { showHeader.toggle() }
                    )
                    .frame(maxWidth: .infinity)

                    if ttsService.isSpeaking || ttsService.isPaused {
                        ReaderTTSExpandedPanel(
                            ttsService: ttsService,
                            textColor: textColor,
                            onPrevPage: prevPage,
                            onNextPage: nextPage,
                            onStart: startTTS,
                            onPause: pauseTTS,
                            onResume: resumeTTS,
                            onRestart: startTTS
                        )
                    }

                    ReaderExpandedBottomBar(
                        currentPage: readerVM.currentPage,
                        totalPages: readerVM.activeBook.totalPages,
                        textColor: textColor,
                        backgroundColor: backgroundColor,
                        onPrevPage: prevPage,
                        onNextPage: nextPage
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var tocOverlay: some View {
        ZStack(alignment: .trailing) {
            Button {
                withAnimation { showToc = false }
            } label: {
                Color.black.opacity(0.4).ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭目录")

            VStack(spacing: 0) {
                HStack {
                    Text("目录")
                        .font(.inkRoomTitle)
                        .foregroundStyle(Color.inkRoomTextPrimary)

                    Spacer()

                    Button {
                        withAnimation {
                            showToc = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkRoomTextTertiary)
                            .frame(width: LayoutMetrics.minTouchTarget, height: LayoutMetrics.minTouchTarget)
                    }
                    .accessibilityLabel("关闭目录")
                }
                .padding(.horizontal, 16)

                ReaderTOCSidebar(
                    readerVM: readerVM,
                    tocTab: $tocTab,
                    searchText: $searchText,
                    searchResults: $searchResults,
                    isSearching: $isSearching,
                    onNavigateToPage: { page in
                        navigateToPage(page)
                        withAnimation {
                            showToc = false
                        }
                    },
                    onDeleteBookmark: { bookmark in
                        Task {
                            await libraryViewModel.removeBookmark(bookmark)
                            await readerVM.loadBookmarks()
                            await readerVM.checkCurrentPageBookmark()
                        }
                    }
                )
            }
            .frame(width: 280)
            .frame(maxHeight: .infinity)
            .background(Color.inkRoomCard)
        }
    }

    // MARK: - Common
    private var backgroundColor: Color {
        Color(hex: settingsViewModel.readerTheme.backgroundColor) ?? .readerBackgroundLight
    }

    private var textColor: Color {
        Color(hex: settingsViewModel.readerTheme.textColor) ?? Color.inkRoomTextPrimary
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

    private func toggleBookmark() {
        Task {
            await readerVM.toggleBookmark(
                pageText: readerVM.pageText,
                chapterTitle: readerVM.currentChapterTitle
            )
        }
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
            ttsService.startTimer(minutes: settingsViewModel.ttsTimerMinutes)
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
