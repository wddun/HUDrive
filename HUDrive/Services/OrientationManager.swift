//
//  OrientationManager.swift
//  HUDrive
//

import UIKit
import Combine

/// Manages app orientation — portrait for search, landscape for HUD navigation
class OrientationManager: ObservableObject {
    
    /// The currently allowed orientations
    static var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown
    
    /// Lock to landscape (for HUD mode)
    static func lockLandscape() {
        supportedOrientations = .landscape
        rotateToLandscape()
    }
    
    /// Allow portrait (for search/setup)
    static func allowPortrait() {
        supportedOrientations = .allButUpsideDown
        // Don't force rotation — let the user hold it however they want
    }
    
    /// Lock to portrait
    static func lockPortrait() {
        supportedOrientations = .portrait
        rotateToPortrait()
    }
    
    private static func rotateToLandscape() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
        scene.requestGeometryUpdate(geometryPreferences) { error in
            print("Orientation update error: \(error.localizedDescription)")
        }
    }
    
    private static func rotateToPortrait() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
        scene.requestGeometryUpdate(geometryPreferences) { error in
            print("Orientation update error: \(error.localizedDescription)")
        }
    }
}
