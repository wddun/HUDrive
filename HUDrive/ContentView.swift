//
//  ContentView.swift
//  HUDrive
//

import SwiftUI
import MapKit
import Combine

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var voiceGuidance = VoiceGuidanceService()
    @State private var navigationManager: NavigationManager?
    
    @State private var showSearch = false
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    
    var body: some View {
        Group {
            if let navManager = navigationManager {
                mainContent(navManager: navManager)
            } else {
                Color.black
                    .overlay(
                        ProgressView()
                            .tint(.cyan)
                    )
            }
        }
        .onAppear {
            let navManager = NavigationManager(
                locationManager: locationManager,
                voiceGuidance: voiceGuidance
            )
            navigationManager = navManager
            locationManager.requestAuthorization()
            // Start in portrait-friendly mode
            OrientationManager.allowPortrait()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
    
    @ViewBuilder
    private func mainContent(navManager: NavigationManager) -> some View {
        ZStack {
            // Main content layer (flipped only when navigating in landscape)
            Group {
                if navManager.isNavigating && !showSearch {
                    // NAVIGATING: Side-by-side layout (landscape)
                    HStack(spacing: 0) {
                        // LEFT: Big turn-by-turn panel
                        NavigationBannerView(navigationManager: navManager)
                            .frame(width: UIScreen.main.bounds.width * 0.35)
                        
                        // Gradient transition edge
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 30)
                        .allowsHitTesting(false)
                        
                        // RIGHT: Map with dark overlay + info bar at top
                        ZStack(alignment: .top) {
                            MapViewRepresentable(
                                locationManager: locationManager,
                                navigationManager: navManager
                            )
                            
                            // Dark filter overlay to dim the map
                            Color.black.opacity(0.45)
                                .allowsHitTesting(false)
                            
                            // ETA / Time / Distance at the top of the map
                            NavigationInfoBar(navigationManager: navManager)
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    // NOT NAVIGATING / SEARCHING: Full map (portrait or landscape)
                    ZStack {
                        MapViewRepresentable(
                            locationManager: locationManager,
                            navigationManager: navManager
                        )
                        .ignoresSafeArea()
                        
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
            }
            // HUD MIRROR FLIP — only when navigating and search is closed
            .rotation3DEffect(
                .degrees(navManager.isNavigating && !showSearch ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.easeInOut(duration: 0.4), value: navManager.isNavigating && !showSearch)
            
            // Speed display when not navigating (not flipped)
            if !navManager.isNavigating {
                VStack {
                    Spacer()
                    SpeedDisplayView(speed: locationManager.speed)
                        .padding(.bottom, 40)
                }
            }
            
            // Controls overlay (not flipped)
            if showControls && !showSearch {
                controlsOverlay(navManager: navManager)
            }
            
            // Search overlay (not flipped, works in portrait)
            if showSearch {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissSearch(navManager: navManager)
                    }
                
                SearchBarView(
                    navigationManager: navManager,
                    locationManager: locationManager,
                    onDismiss: {
                        dismissSearch(navManager: navManager)
                    }
                )
            }
            
            // Error display (not flipped)
            if let error = navManager.errorMessage, !showSearch {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.8).cornerRadius(8))
                        .padding(.bottom, 80)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            resetControlsTimer()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.screen.brightness = 1.0
            }
            resetControlsTimer()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        // React to navigation state changes for orientation
        .onChange(of: navManager.isNavigating) { _, isNavigating in
            if isNavigating {
                OrientationManager.lockLandscape()
            } else {
                OrientationManager.allowPortrait()
            }
        }
    }
    
    private func showSearchOverlay() {
        // Allow portrait when searching
        OrientationManager.allowPortrait()
        withAnimation {
            showSearch = true
        }
    }
    
    private func dismissSearch(navManager: NavigationManager) {
        withAnimation {
            showSearch = false
        }
        // If navigating, go back to landscape
        if navManager.isNavigating {
            OrientationManager.lockLandscape()
        }
    }
    
    @ViewBuilder
    private func controlsOverlay(navManager: NavigationManager) -> some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
                    // Search / New destination
                    controlButton(icon: "magnifyingglass", color: .cyan) {
                        showSearchOverlay()
                    }
                    
                    // Voice toggle
                    controlButton(
                        icon: voiceGuidance.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        color: voiceGuidance.isEnabled ? .cyan : .white.opacity(0.5)
                    ) {
                        voiceGuidance.isEnabled.toggle()
                    }
                    
                    // End navigation
                    if navManager.isNavigating {
                        controlButton(icon: "xmark", color: .red) {
                            navManager.stopNavigation()
                            OrientationManager.allowPortrait()
                        }
                    }
                    
                    // Recenter map
                    controlButton(icon: "location.fill", color: .white.opacity(0.7)) {
                        navManager.objectWillChange.send()
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            Spacer()
        }
        .transition(.opacity)
    }
    
    private func controlButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

#Preview {
    ContentView()
}
