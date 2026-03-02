//
//  NavigationBannerView.swift
//  HUDrive
//

import SwiftUI
import MapKit
import CoreLocation

/// Full-height side panel showing the next turn instruction prominently
struct NavigationBannerView: View {
    @ObservedObject var navigationManager: NavigationManager
    
    var body: some View {
        ZStack {
            // Solid dark background
            Color.black
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main maneuver area
                VStack(spacing: 16) {
                    // Maneuver icon — big and bold
                    Image(systemName: navigationManager.currentManeuverIcon)
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan.opacity(0.4), radius: 12, x: 0, y: 0)
                    
                    // Distance to maneuver — huge text
                    Text(navigationManager.formattedDistanceToManeuver)
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    // Instruction text
                    if let step = navigationManager.currentStep {
                        Text(step.instructions)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 12)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
        }
    }
}

/// ETA / Time / Distance bar that sits on top of the map side
struct NavigationInfoBar: View {
    @ObservedObject var navigationManager: NavigationManager
    
    var body: some View {
        HStack(spacing: 0) {
            infoBlock(value: navigationManager.formattedETA, label: "ETA")
            
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 32)
            
            infoBlock(value: navigationManager.formattedRemainingTime, label: "TIME")
            
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 1, height: 32)
            
            infoBlock(value: navigationManager.formattedRemainingDistance, label: "DIST")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            Color.black.opacity(0.75)
                .blur(radius: 1)
        )
    }
    
    private func infoBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Speed Display (shown when not navigating)

struct SpeedDisplayView: View {
    let speed: CLLocationSpeed // meters per second
    
    private var mph: Int {
        max(0, Int(speed * 2.23694))
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(mph)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("MPH")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(24)
        .background(
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 160, height: 160)
        )
    }
}
