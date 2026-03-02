//
//  VoiceGuidanceService.swift
//  HUDrive
//

import Foundation
import AVFoundation
import CoreLocation
import Combine

class VoiceGuidanceService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isEnabled: Bool = false {
        didSet {
            if !isEnabled {
                synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }
    
    /// Track which announcements have been made for the current step
    /// to avoid repeating the same announcement
    private var announcedThresholds: Set<AnnouncementThreshold> = []
    private var currentStepIndex: Int = -1
    
    enum AnnouncementThreshold: Hashable {
        case approaching  // ~1000 ft / 300m
        case imminent     // ~500 ft / 150m
        case now          // ~100 ft / 30m
        case arrived
    }
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }
    
    /// Announce a navigation instruction based on distance
    func announceIfNeeded(instruction: String, distance: CLLocationDistance, stepIndex: Int) {
        guard isEnabled else { return }
        
        // Reset thresholds when we advance to a new step
        if stepIndex != currentStepIndex {
            currentStepIndex = stepIndex
            announcedThresholds.removeAll()
        }
        
        let threshold = thresholdForDistance(distance)
        
        guard let threshold = threshold, !announcedThresholds.contains(threshold) else { return }
        
        announcedThresholds.insert(threshold)
        
        let message: String
        switch threshold {
        case .approaching:
            let distText = formatDistance(distance)
            message = "In \(distText), \(instruction)"
        case .imminent:
            let distText = formatDistance(distance)
            message = "In \(distText), \(instruction)"
        case .now:
            message = "\(instruction) now"
        case .arrived:
            message = "You have arrived at your destination"
        }
        
        speak(message)
    }
    
    /// Announce route start
    func announceRouteStart(instruction: String, distance: CLLocationDistance) {
        guard isEnabled else { return }
        let distText = formatDistance(distance)
        speak("Starting navigation. \(instruction) in \(distText)")
    }
    
    /// Announce arrival
    func announceArrival() {
        guard isEnabled else { return }
        speak("You have arrived at your destination")
    }
    
    private func thresholdForDistance(_ distance: CLLocationDistance) -> AnnouncementThreshold? {
        switch distance {
        case 0..<40:
            return .now
        case 40..<200:
            return .imminent
        case 200..<400:
            return .approaching
        default:
            return nil
        }
    }
    
    /// Cached premium voice — resolved on first use
    private var _preferredVoice: AVSpeechSynthesisVoice?
    private var voiceResolved = false
    
    private var preferredVoice: AVSpeechSynthesisVoice? {
        if !voiceResolved {
            voiceResolved = true
            _preferredVoice = findBestVoice()
        }
        return _preferredVoice
    }
    
    /// Find the best available voice — prefer premium/enhanced Siri voices
    private func findBestVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let enUSVoices = allVoices.filter { $0.language == "en-US" }
        
        // Priority 1: Premium voices (highest quality, Siri-like)
        if let premium = enUSVoices.first(where: { $0.quality == .premium }) {
            return premium
        }
        
        // Priority 2: Enhanced voices (good quality)
        if let enhanced = enUSVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        
        // Priority 3: Any en-US voice
        return AVSpeechSynthesisVoice(language: "en-US")
    }
    
    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .word)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.prefersAssistiveTechnologySettings = false
        
        synthesizer.speak(utterance)
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let feet = meters * 3.28084
        if feet < 528 { // less than 0.1 mile
            let rounded = Int(round(feet / 50) * 50)
            return "\(max(50, rounded)) feet"
        } else {
            let miles = meters / 1609.34
            if miles < 10 {
                return String(format: "%.1f miles", miles)
            } else {
                return String(format: "%.0f miles", miles)
            }
        }
    }
    
    func reset() {
        synthesizer.stopSpeaking(at: .immediate)
        announcedThresholds.removeAll()
        currentStepIndex = -1
    }
}

extension VoiceGuidanceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Utterance completed
    }
}
