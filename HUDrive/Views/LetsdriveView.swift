//
//  LetsdriveView.swift
//  HUDrive
//

import SwiftUI
import UIKit

/// Full-screen animated overlay shown when a route is ready and navigation begins.
struct LetsdriveView: View {
    let destinationName: String

    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var glowRadius: CGFloat = 8
    @State private var pulse1Scale: CGFloat = 1.0
    @State private var pulse2Scale: CGFloat = 1.0
    @State private var pulse1Opacity: Double = 0.25
    @State private var pulse2Opacity: Double = 0.15
    @State private var linesOffset: CGFloat = 0
    @State private var linesOpacity: Double = 0

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            // Subtle cyan radial glow in the center
            RadialGradient(
                colors: [Color.cyan.opacity(0.18), Color.clear],
                center: .center,
                startRadius: 40,
                endRadius: 260
            )
            .ignoresSafeArea()

            // Speed-lines decorating the background
            speedLines

            // Pulse rings behind the icon
            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(pulse1Opacity), lineWidth: 1.5)
                    .frame(width: 170, height: 170)
                    .scaleEffect(pulse1Scale)

                Circle()
                    .stroke(Color.cyan.opacity(pulse2Opacity), lineWidth: 1)
                    .frame(width: 170, height: 170)
                    .scaleEffect(pulse2Scale)

                // Car icon
                Image(systemName: "car.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, Color(red: 0, green: 0.75, blue: 1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .cyan.opacity(0.7), radius: glowRadius, x: 0, y: 0)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
            }
            .frame(width: 170, height: 170)
            .offset(y: -40)

            // Text block
            VStack(spacing: 6) {
                Spacer()
                    .frame(height: UIScreen.main.bounds.height * 0.52)

                Text("LET'S DRIVE")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(6)
                    .shadow(color: .cyan.opacity(0.4), radius: 8)
                    .opacity(textOpacity)

                if !destinationName.isEmpty {
                    Text("TO  \(destinationName.uppercased())")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.85))
                        .tracking(3)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 48)
                        .opacity(textOpacity)
                }

                Spacer()
            }
        }
        .onAppear { runEntrance() }
        .transition(.opacity.combined(with: .scale(scale: 1.04)))
    }

    // MARK: - Speed lines

    private var speedLines: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) * 30.0
                    let length = CGFloat.random(in: 60...180)
                    let x = geo.size.width / 2 + cos(angle * .pi / 180) * (geo.size.width * 0.42)
                    let y = geo.size.height / 2 + sin(angle * .pi / 180) * (geo.size.height * 0.42)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.0), Color.cyan.opacity(0.22), Color.cyan.opacity(0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: length, height: 1)
                        .rotationEffect(.degrees(angle))
                        .position(x: x + linesOffset * cos(angle * .pi / 180),
                                  y: y + linesOffset * sin(angle * .pi / 180))
                        .opacity(linesOpacity)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Animations

    private func runEntrance() {
        // Car icon pops in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        // Glow pulse
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            glowRadius = 24
        }

        // Pulse rings
        withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
            pulse1Scale = 1.7
            pulse1Opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse2Scale = 1.9
                pulse2Opacity = 0
            }
        }

        // Text fades in
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            textOpacity = 1.0
        }

        // Speed lines shoot out
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            linesOffset = 60
            linesOpacity = 1.0
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.7)) {
            linesOpacity = 0
        }
    }
}

#Preview {
    LetsdriveView(destinationName: "Apple Park")
        .preferredColorScheme(.dark)
}
