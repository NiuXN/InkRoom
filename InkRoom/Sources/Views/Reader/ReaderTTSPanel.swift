import SwiftUI

struct ReaderTTSCompactPanel: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @ObservedObject var ttsService: TTSService
    
    let textColor: Color
    @Binding var showExtended: Bool
    
    var onPrevPage: () -> Void
    var onNextPage: () -> Void
    var onStart: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onRestart: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            mainControls
            
            if showExtended {
                Divider()
                    .background(textColor.opacity(0.1))
                
                extendedControls
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
    
    private var mainControls: some View {
        HStack(spacing: 12) {
            Button {
                onPrevPage()
                if ttsService.isSpeaking || ttsService.isPaused {
                    Task {
                        try? await Task.sleep(for: .milliseconds(100))
                        onRestart()
                    }
                }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(textColor)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("上一页")
            
            Button {
                if ttsService.isPaused {
                    onResume()
                } else if ttsService.isSpeaking {
                    onPause()
                } else {
                    onStart()
                }
            } label: {
                Image(systemName: ttsService.isSpeaking && !ttsService.isPaused ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.inkRoomPrimary)
                    .frame(width: 56, height: 56)
            }
            .accessibilityLabel(ttsService.isSpeaking && !ttsService.isPaused ? "暂停朗读" : "开始朗读")
            
            Button {
                onNextPage()
                if ttsService.isSpeaking || ttsService.isPaused {
                    Task {
                        try? await Task.sleep(for: .milliseconds(100))
                        onRestart()
                    }
                }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(textColor)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("下一页")
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("听书")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(textColor)
                
                if ttsService.remainingTime > 0 {
                    Text(timeString(from: ttsService.remainingTime))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkRoomPrimary)
                }
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showExtended.toggle()
                }
            } label: {
                Image(systemName: showExtended ? "chevron.down.circle" : "chevron.up.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(textColor)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(showExtended ? "收起听书设置" : "展开听书设置")
        }
    }
    
    private var extendedControls: some View {
        VStack(spacing: 12) {
            rateSlider
            
            timerButtons
            
            highlightToggle
        }
    }
    
    private var rateSlider: some View {
        HStack(spacing: 12) {
            Text("语速")
                .font(.system(size: 13))
                .foregroundStyle(textColor.opacity(0.7))
                .frame(width: 40, alignment: .leading)
            
            Slider(
                value: Binding(
                    get: { settingsViewModel.ttsRate },
                    set: { settingsViewModel.ttsRate = $0 }
                ),
                in: 0.3...0.8,
                step: 0.05
            )
            .tint(Color.inkRoomPrimary)
            .onChange(of: settingsViewModel.ttsRate) { _, _ in
                if ttsService.isSpeaking {
                    Task {
                        try? await Task.sleep(for: .milliseconds(50))
                        onRestart()
                    }
                }
            }
            
            Text(String(format: "%.0f%%", settingsViewModel.ttsRate * 200))
                .font(.system(size: 12))
                .foregroundStyle(textColor.opacity(0.7))
                .frame(width: 40)
        }
    }
    
    private var timerButtons: some View {
        HStack(spacing: 8) {
            Text("定时")
                .font(.system(size: 13))
                .foregroundStyle(textColor.opacity(0.7))
                .frame(width: 40, alignment: .leading)
            
            ForEach([0, 15, 30, 60], id: \.self) { minutes in
                Button {
                    settingsViewModel.ttsTimerMinutes = minutes
                    if minutes > 0 && (ttsService.isSpeaking || ttsService.isPaused) {
                        ttsService.startTimer(minutes: minutes)
                    } else if minutes == 0 {
                        ttsService.stopTimer()
                    }
                } label: {
                    Text(minutes == 0 ? "不定时" : "\(minutes)分钟")
                        .font(.system(size: 12))
                        .foregroundStyle(
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
    }
    
    private var highlightToggle: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { settingsViewModel.ttsHighlightEnabled },
                set: { settingsViewModel.ttsHighlightEnabled = $0 }
            )) {
                Text("朗读高亮")
                    .font(.system(size: 13))
                    .foregroundStyle(textColor.opacity(0.7))
            }
            .tint(Color.inkRoomPrimary)
            
            Spacer()
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ReaderTTSExpandedPanel: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @ObservedObject var ttsService: TTSService
    
    let textColor: Color
    
    var onPrevPage: () -> Void
    var onNextPage: () -> Void
    var onStart: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    var onRestart: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                onPrevPage()
                if ttsService.isSpeaking || ttsService.isPaused {
                    Task {
                        try? await Task.sleep(for: .milliseconds(100))
                        onRestart()
                    }
                }
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(textColor)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("上一页")
            
            Button {
                if ttsService.isPaused {
                    onResume()
                } else if ttsService.isSpeaking {
                    onPause()
                } else {
                    onStart()
                }
            } label: {
                Image(systemName: ttsService.isSpeaking && !ttsService.isPaused ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.inkRoomPrimary)
            }
            .accessibilityLabel(ttsService.isSpeaking && !ttsService.isPaused ? "暂停朗读" : "开始朗读")
            
            Button {
                onNextPage()
                if ttsService.isSpeaking || ttsService.isPaused {
                    Task {
                        try? await Task.sleep(for: .milliseconds(100))
                        onRestart()
                    }
                }
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(textColor)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("下一页")
            
            Text("听书")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(textColor)
                .padding(.leading, 4)
            
            if ttsService.remainingTime > 0 {
                Text(timeString(from: ttsService.remainingTime))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkRoomPrimary)
            }
            
            Spacer()
            
            rateControl
            
            timerMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.inkRoomCard)
    }
    
    private var rateControl: some View {
        HStack(spacing: 4) {
            Text("语速")
                .font(.system(size: 12))
                .foregroundStyle(textColor.opacity(0.6))
            
            Slider(
                value: Binding(
                    get: { settingsViewModel.ttsRate },
                    set: { settingsViewModel.ttsRate = $0 }
                ),
                in: 0.3...0.8,
                step: 0.05
            )
            .tint(Color.inkRoomPrimary)
            .frame(width: 100)
            .onChange(of: settingsViewModel.ttsRate) { _, _ in
                if ttsService.isSpeaking {
                    Task {
                        try? await Task.sleep(for: .milliseconds(50))
                        onRestart()
                    }
                }
            }
        }
    }
    
    private var timerMenu: some View {
        Menu {
            Picker("定时停止", selection: Binding(
                get: { settingsViewModel.ttsTimerMinutes },
                set: { newValue in
                    settingsViewModel.ttsTimerMinutes = newValue
                    if newValue > 0 && (ttsService.isSpeaking || ttsService.isPaused) {
                        ttsService.startTimer(minutes: newValue)
                    } else if newValue == 0 {
                        ttsService.stopTimer()
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
                .foregroundStyle(textColor)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel("定时停止")
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
