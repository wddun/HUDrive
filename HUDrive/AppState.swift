//
//  AppState.swift
//  HUDrive
//

import Foundation

/// Shared singleton that owns all core services.
class AppState {
    static let shared = AppState()

    let locationManager: LocationManager
    let voiceGuidance: VoiceGuidanceService
    let navigationManager: NavigationManager

    private init() {
        locationManager = LocationManager()
        voiceGuidance = VoiceGuidanceService()
        navigationManager = NavigationManager(
            locationManager: locationManager,
            voiceGuidance: voiceGuidance
        )
    }
}
