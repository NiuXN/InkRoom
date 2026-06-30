import Foundation
import AVFoundation
import MediaPlayer

#if os(iOS)
import UIKit
#endif

@MainActor
class TTSService: NSObject, ObservableObject {
    static let shared = TTSService()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentUtteranceText: String = ""
    @Published var currentSentenceRange: NSRange?
    @Published var currentBookTitle: String = ""
    @Published var currentChapterTitle: String = ""
    @Published var remainingTime: TimeInterval = 0
    
    private var currentUtterance: AVSpeechUtterance?
    private var timerTask: Task<Void, Never>?
    
    var onSentenceChange: ((NSRange, String) -> Void)?
    var onSpeechFinish: (() -> Void)?
    var onSpeechStart: (() -> Void)?
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    
    // Cached voices to avoid repeated system calls
    private var cachedVoices: [AVSpeechSynthesisVoice] = []
    private var cachedChineseVoices: [AVSpeechSynthesisVoice] = []
    private var voicesLoaded = false
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
        setupRemoteCommandCenter()
        preloadVoices()
    }
    
    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPaused == true {
                    self?.resume()
                } else if self?.isSpeaking == true {
                    self?.pause()
                }
            }
            return .success
        }
        
        // Enable scrubbing on lock screen / control center
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent,
                  let utterance = self.currentUtterance else { return .commandFailed }
            
            let targetTime = positionEvent.positionTime
            let totalDuration = utterance.speechString.count > 0 ? Float(utterance.speechString.count) * 0.05 : 1.0 // rough estimate
            
            // AVSpeechSynthesizer doesn't support direct seeking, but we can stop and restart from position
            // This is a limitation of AVSpeechSynthesizer - we update now playing info to reflect position
            self.updateNowPlayingInfo(playbackPosition: targetTime)
            return .success
        }
    }
    
    private func preloadVoices() {
        Task.detached(priority: .utility) { [weak self] in
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            let voices = allVoices.filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("en") }
            let chineseVoices = voices.filter { $0.language.hasPrefix("zh") }
            
            await MainActor.run {
                self?.cachedVoices = voices
                self?.cachedChineseVoices = chineseVoices
                self?.voicesLoaded = true
            }
        }
    }
    
    func speak(text: String, voiceIdentifier: String? = nil, rate: Float = 0.5, pitchMultiplier: Float = 1.0) {
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = 1.0
        
        if let voiceIdentifier = voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        }
        
        currentUtterance = utterance
        currentUtteranceText = text
        synthesizer.speak(utterance)
        updateNowPlayingInfo()
    }
    
    func pause() {
        guard isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        onPause?()
        updateNowPlayingInfo()
    }
    
    func resume() {
        guard isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
        onResume?()
        updateNowPlayingInfo()
    }
    
    func stop() {
        stopTimer()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isPaused = false
        currentSentenceRange = nil
        currentUtterance = nil
        clearNowPlayingInfo()
    }
    
    func startTimer(minutes: Int) {
        stopTimer()
        remainingTime = TimeInterval(minutes * 60)
        timerTask = Task {
            while remainingTime > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                remainingTime -= 1
                if remainingTime <= 0 {
                    stop()
                    break
                }
            }
        }
    }
    
    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        remainingTime = 0
    }
    
    func setBookInfo(title: String, chapter: String) {
        currentBookTitle = title
        currentChapterTitle = chapter
        updateNowPlayingInfo()
    }
    
    private func updateNowPlayingInfo(playbackPosition: TimeInterval? = nil) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentChapterTitle.isEmpty ? "听书" : currentChapterTitle
        info[MPMediaItemPropertyAlbumTitle] = currentBookTitle
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPaused ? 0.0 : 1.0
        
        if let utterance = currentUtterance {
            // Estimate duration based on text length and rate
            let estimatedDuration = TimeInterval(utterance.speechString.count) * 0.05 / Double(utterance.rate)
            info[MPMediaItemPropertyPlaybackDuration] = estimatedDuration
            if let position = playbackPosition {
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func availableVoices() -> [AVSpeechSynthesisVoice] {
        if voicesLoaded {
            return cachedVoices
        }
        return AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("zh") || voice.language.hasPrefix("en")
        }
    }
    
    func chineseVoices() -> [AVSpeechSynthesisVoice] {
        if voicesLoaded {
            return cachedChineseVoices
        }
        return availableVoices().filter { $0.language.hasPrefix("zh") }
    }
}

extension TTSService: @preconcurrency AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
            self.isPaused = false
            self.onSpeechStart?()
            self.updateNowPlayingInfo()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.isPaused = false
            self.currentSentenceRange = nil
            self.currentUtterance = nil
            self.onSpeechFinish?()
            self.clearNowPlayingInfo()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPaused = true
            self.onPause?()
            self.updateNowPlayingInfo()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPaused = false
            self.onResume?()
            self.updateNowPlayingInfo()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // AVSpeechUtterance 非 Sendable，不能跨 actor 传递。
        // 在 nonisolated 上下文先提取所需 Sendable 数据，再切到 MainActor。
        let text = utterance.speechString
        let rate = utterance.rate
        Task { @MainActor in
            self.currentSentenceRange = characterRange
            if let range = Range(characterRange, in: text) {
                let sentence = String(text[range])
                self.onSentenceChange?(characterRange, sentence)
            }
            // Update lock screen progress periodically
            let progress = Double(characterRange.location) / Double(text.count)
            let estimatedDuration = TimeInterval(text.count) * 0.05 / Double(rate)
            let elapsedTime = estimatedDuration * progress
            self.updateNowPlayingInfo(playbackPosition: elapsedTime)
        }
    }
}