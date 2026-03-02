//
//  HUDriveApp.swift
//  HUDrive
//
//  Created by William Dunning on 2/24/26.
//

import SwiftUI

/// AppDelegate to control supported orientations dynamically
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return OrientationManager.supportedOrientations
    }
}

@main
struct HUDriveApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
