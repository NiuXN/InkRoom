import SwiftUI

struct ReaderContentView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @Environment(\.layoutSizeClass) private var sizeClass
    @Environment(\.isLandscape) private var isLandscape
    
    @ObservedObject var readerVM: ReaderViewModel
    @ObservedObject var ttsService: TTSService
    
    let isScrollMode: Bool
    let textColor: Color
    let onPrevPage: () -> Void
    let onNextPage: () -> Void
    let onToggleHeader: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let maxWidth = contentMaxWidth(for: geometry.size.width)
            
            ZStack {
                if isScrollMode {
                    scrollContentView(maxWidth: maxWidth)
                } else {
                    pageContentView(maxWidth: maxWidth)
                }
                
                if !isScrollMode {
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if settingsViewModel.pageTurnStyle == .tap || settingsViewModel.pageTurnStyle == .swipe {
                                    onPrevPage()
                                }
                            }
                        
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    onToggleHeader()
                                }
                            }
                        
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if settingsViewModel.pageTurnStyle == .tap || settingsViewModel.pageTurnStyle == .swipe {
                                    onNextPage()
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
                        .foregroundStyle(textColor)
                        .padding(.bottom, 8)
                }
                
                if ttsService.isSpeaking && settingsViewModel.ttsHighlightEnabled,
                   let range = ttsService.currentSentenceRange,
                   let textRange = Range(range, in: readerVM.pageText) {
                    Text(highlightedText(original: readerVM.pageText, range: textRange))
                        .foregroundStyle(textColor)
                } else {
                    Text(readerVM.pageText)
                        .foregroundStyle(textColor)
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
                        ForEach(Array(readerVM.chapters.enumerated()), id: \.element.id) { index, chapter in
                            VStack(alignment: .leading, spacing: CGFloat(settingsViewModel.readingLineSpacing)) {
                                Text(chapter.title)
                                    .font(.system(size: CGFloat(settingsViewModel.readingFontSize) * 1.2, weight: .bold))
                                    .foregroundStyle(textColor)
                                    .padding(.top, index == 0 ? 0 : 24)
                                    .padding(.bottom, 8)
                                
                                Text(readerVM.chapterDisplayText(at: index))
                                    .font(.system(size: CGFloat(settingsViewModel.readingFontSize)))
                                    .foregroundStyle(textColor)
                                    .lineSpacing(CGFloat(settingsViewModel.readingLineSpacing))
                                    .tracking(CGFloat(settingsViewModel.readingLetterSpacing) * 0.1)
                            }
                            .id("chapter-\(index)")
                            .background(
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
    
    private func shouldTrackFrame(for chapterIndex: Int) -> Bool {
        let currentIndex = readerVM.currentChapterIndex
        return abs(chapterIndex - currentIndex) <= 2
    }
    
    private func highlightedText(original: String, range: Range<String.Index>) -> AttributedString {
        var attributed = AttributedString(original)
        if let attrRange = attributed.range(of: String(original[range])) {
            var highlightColor = Color.inkRoomPrimary
            attributed[attrRange].foregroundColor = highlightColor
            attributed[attrRange].font = .system(size: CGFloat(settingsViewModel.readingFontSize), weight: .semibold)
        }
        return attributed
    }
}
