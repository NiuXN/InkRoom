import SwiftUI

struct ReaderSettingsPopover: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            fontSizeSection
            lineSpacingSection
            themeSection
        }
        .padding(16)
        .frame(width: 320)
        .background(Color.inkRoomCard)
    }
    
    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("字号")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.inkRoomTextSecondary)
            
            HStack {
                Button {
                    if settingsViewModel.readingFontSize > 12 {
                        settingsViewModel.readingFontSize -= 1
                    }
                } label: {
                    Text("A")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkRoomTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.inkRoomBackgroundElevated)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("减小字号")
                
                Slider(
                    value: Binding(
                        get: { Double(settingsViewModel.readingFontSize) },
                        set: { settingsViewModel.readingFontSize = Int($0) }
                    ),
                    in: 12...28,
                    step: 1
                )
                .tint(Color.inkRoomPrimary)
                .frame(width: 180)
                
                Button {
                    if settingsViewModel.readingFontSize < 28 {
                        settingsViewModel.readingFontSize += 1
                    }
                } label: {
                    Text("A")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.inkRoomTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.inkRoomBackgroundElevated)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("增大字号")
            }
        }
    }
    
    private var lineSpacingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("行距")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.inkRoomTextSecondary)
            
            HStack(spacing: 8) {
                ForEach([6, 10, 14], id: \.self) { spacing in
                    Button {
                        settingsViewModel.readingLineSpacing = spacing
                    } label: {
                        Text(spacing == 6 ? "紧凑" : spacing == 10 ? "标准" : "宽松")
                            .font(.system(size: 12))
                            .foregroundStyle(settingsViewModel.readingLineSpacing == spacing ? .white : Color.inkRoomTextSecondary)
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
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("主题")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.inkRoomTextSecondary)
            
            HStack(spacing: 10) {
                ForEach(ReadingSettings.ReaderTheme.allCases, id: \.self) { theme in
                    themeButton(theme)
                }
            }
        }
    }
    
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
        .accessibilityLabel("\(theme.rawValue)主题")
    }
}

#if os(iOS)
struct ReaderSettingsOverlay: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.inkRoomTextTertiary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                
                VStack(spacing: 16) {
                    fontSizeSection
                    themeSection
                }
                .padding(16)
                .padding(.bottom, safeAreaBottom)
            }
            .background(Color.inkRoomCard)
            .cornerRadius(16, corners: [.topLeft, .topRight])
        }
    }
    
    private var safeAreaBottom: CGFloat {
        return (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom) ?? 34
    }
    
    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("字号")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.inkRoomTextSecondary)
            
            HStack {
                Button {
                    if settingsViewModel.readingFontSize > 12 {
                        settingsViewModel.readingFontSize -= 1
                    }
                } label: {
                    Text("A")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkRoomTextPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.inkRoomBackgroundElevated)
                        .cornerRadius(8)
                }
                .accessibilityLabel("减小字号")
                
                Slider(
                    value: Binding(
                        get: { Double(settingsViewModel.readingFontSize) },
                        set: { settingsViewModel.readingFontSize = Int($0) }
                    ),
                    in: 12...28,
                    step: 1
                )
                .tint(Color.inkRoomPrimary)
                
                Button {
                    if settingsViewModel.readingFontSize < 28 {
                        settingsViewModel.readingFontSize += 1
                    }
                } label: {
                    Text("A")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.inkRoomTextPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.inkRoomBackgroundElevated)
                        .cornerRadius(8)
                }
                .accessibilityLabel("增大字号")
            }
        }
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("主题")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.inkRoomTextSecondary)
            
            HStack(spacing: 12) {
                ForEach(ReadingSettings.ReaderTheme.allCases, id: \.self) { theme in
                    themeButton(theme)
                }
            }
        }
    }
    
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
        .accessibilityLabel("\(theme.rawValue)主题")
    }
}
#endif
