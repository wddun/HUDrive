//
//  ContentView.swift
//  HUDrive
//

import SwiftUI
import MapKit
import Combine

struct ContentView: View {
    // All managers come from the shared singleton so CarPlay sees the same state.
    @ObservedObject private var locationManager   = AppState.shared.locationManager
    @ObservedObject private var voiceGuidance     = AppState.shared.voiceGuidance
    @ObservedObject private var navigationManager = AppState.shared.navigationManager

    @State private var showSearch    = false
    @State private var showControls  = true
    @State private var showLetsDrive = false
    @State private var controlsTimer: Timer?

    var body: some View {
        mainContent
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    scene.screen.brightness = 1.0
                }
                locationManager.requestAuthorization()
                OrientationManager.allowPortrait()
                resetControlsTimer()
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .preferredColorScheme(.dark)
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
            // Lock landscape when navigation starts, portrait when it stops
            .onChange(of: navigationManager.isNavigating) { _, isNavigating in
                if isNavigating {
                    OrientationManager.lockLandscape()
                } else {
                    OrientationManager.allowPortrait()
                }
            }
            // Show "Let's Drive" when the route first loads
            .onChange(of: navigationManager.route) { _, newRoute in
                if newRoute != nil && navigationManager.isNavigating && !showLetsDrive {
                    withAnimation(.easeIn(duration: 0.25)) { showLetsDrive = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                        withAnimation(.easeOut(duration: 0.45)) { showLetsDrive = false }
                    }
                }
            }
    }

    // MARK: - Main layout

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // ── Map layer (flipped when navigating in HUD mode) ──
            Group {
                if navigationManager.isNavigating && !showSearch {
                    HStack(spacing: 0) {
                        NavigationBannerView(navigationManager: navigationManager)
                            .frame(width: UIScreen.main.bounds.width * 0.35)

                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 30)
                        .allowsHitTesting(false)

                        ZStack(alignment: .top) {
                            MapViewRepresentable(
                                locationManager: locationManager,
                                navigationManager: navigationManager
                            )

                            Color.black.opacity(0.45)
                                .allowsHitTesting(false)

                            NavigationInfoBar(navigationManager: navigationManager)
                        }
                    }
                    .ignoresSafeArea()
                } else {
                    ZStack {
                        MapViewRepresentable(
                            locationManager: locationManager,
                            navigationManager: navigationManager
                        )
                        .ignoresSafeArea()

                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
            }
            .rotation3DEffect(
                .degrees(navigationManager.isNavigating && !showSearch ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.easeInOut(duration: 0.4),
                       value: navigationManager.isNavigating && !showSearch)

            // Speed display (portrait / not navigating)
            if !navigationManager.isNavigating {
                VStack {
                    Spacer()
                    SpeedDisplayView(speed: locationManager.speed)
                        .padding(.bottom, 40)
                }
            }

            // Controls overlay
            if showControls && !showSearch {
                controlsOverlay
            }

            // ── Search overlay ──
            if showSearch {
                // Opaque backdrop so map/HUD behind is barely visible
                Color.black.opacity(0.92)
                    .ignoresSafeArea()
                    .onTapGesture { dismissSearch() }

                // Search UI pinned to the top
                VStack {
                    SearchBarView(
                        navigationManager: navigationManager,
                        locationManager: locationManager,
                        onDismiss: { dismissSearch() }
                    )
                    Spacer()
                }
            }

            // Error banner
            if let error = navigationManager.errorMessage, !showSearch {
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

            // ── "Let's Drive" overlay ──
            if showLetsDrive {
                LetsdriveView(destinationName: navigationManager.destination?.name ?? "")
                    .zIndex(100)
                    .allowsHitTesting(false)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) { showControls.toggle() }
            resetControlsTimer()
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    controlButton(icon: "magnifyingglass", color: .cyan) {
                        showSearchOverlay()
                    }

                    controlButton(
                        icon: voiceGuidance.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                        color: voiceGuidance.isEnabled ? .cyan : .white.opacity(0.5)
                    ) {
                        voiceGuidance.isEnabled.toggle()
                    }

                    if navigationManager.isNavigating {
                        controlButton(icon: "xmark", color: .red) {
                            navigationManager.stopNavigation()
                            OrientationManager.allowPortrait()
                        }
                    }

                    controlButton(icon: "location.fill", color: .white.opacity(0.7)) {
                        navigationManager.objectWillChange.send()
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
                        .overlay(Circle().stroke(color.opacity(0.3), lineWidth: 1))
                )
        }
    }

    // MARK: - Search helpers

    private func showSearchOverlay() {
        // Lock to portrait so the keyboard/search can't be used sideways
        OrientationManager.lockPortrait()
        withAnimation { showSearch = true }
    }

    private func dismissSearch() {
        withAnimation { showSearch = false }
        if navigationManager.isNavigating {
            OrientationManager.lockLandscape()
        } else {
            OrientationManager.allowPortrait()
        }
    }

    // MARK: - Timer

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { showControls = false }
        }
    }
}

#Preview {
    ContentView()
}
