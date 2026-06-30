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
    
    var onSentenceChange: ((NSRange, String) -> Void)?
    var onSpeechFinish: (() -> Void)?
    var onSpeechStart: (() -> Void)?
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
        setupRemoteCommandCenter()
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
        
        currentUtteranceText = text
        synthesizer.speak(utterance)
        updateNowPlayingInfo()
    }
    
    func pause() {
        guard isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        onPause?()
    }
    
    func resume() {
        guard isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
        onResume?()
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isPaused = false
        currentSentenceRange = nil
        clearNowPlayingInfo()
    }
    
    func setBookInfo(title: String, chapter: String) {
        currentBookTitle = title
        currentChapterTitle = chapter
        updateNowPlayingInfo()
    }
    
    private func updateNowPlayingInfo() {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = currentChapterTitle.isEmpty ? "听书" : currentChapterTitle
        info[MPMediaItemPropertyAlbumTitle] = currentBookTitle
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPaused ? 0.0 : 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("zh") || voice.language.hasPrefix("en")
        }
    }
    
    func chineseVoices() -> [AVSpeechSynthesisVoice] {
        availableVoices().filter { $0.language.hasPrefix("zh") }
    }
}

extension TTSService: AVSpeechSynthesizerDelegate {
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
        Task { @MainActor in
            self.currentSentenceRange = characterRange
            let text = utterance.speechString
            if let range = Range(characterRange, in: text) {
                let sentence = String(text[range])
                self.onSentenceChange?(characterRange, sentence)
            }
        }
    }
}
