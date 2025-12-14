//
//  ContentView.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var shakeDetector = ShakeDetector()
    @StateObject private var toiletEngine = PooGoNearestToiletEngine.shared
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDirections = false
    @State private var showLocationDenied = false
    @State private var isButtonPressed = false
    @State private var currentDestination: ToiletDestination?

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.96, blue: 0.93)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App Icon with soft shadow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.75, blue: 0.85),
                                    Color(red: 0.1, green: 0.74, blue: 0.61),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "toilet.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }
                .shadow(color: Color(red: 0.1, green: 0.74, blue: 0.61).opacity(0.3), radius: 12, y: 6)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                Spacer().frame(height: 24)

                // App Name
                HStack(spacing: 4) {
                    Text("PooGo")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)

                    Circle()
                        .fill(Color(red: 0.1, green: 0.74, blue: 0.61))
                        .frame(width: 8, height: 8)
                        .offset(y: -10)
                }

                Spacer().frame(height: 8)

                // Tagline
                Text("Find relief, fast.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))

                Spacer().frame(height: 48)

                // Primary Button with press animation
                Button(action: triggerSearch) {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Find Nearest Toilet")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.75, blue: 0.85),
                                Color(red: 0.1, green: 0.74, blue: 0.61),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(28)
                    .shadow(color: Color(red: 0.1, green: 0.74, blue: 0.61).opacity(isButtonPressed ? 0.2 : 0.4), radius: isButtonPressed ? 4 : 12, y: isButtonPressed ? 2 : 6)
                    .shadow(color: .black.opacity(0.1), radius: isButtonPressed ? 2 : 6, y: isButtonPressed ? 1 : 3)
                    .scaleEffect(isButtonPressed ? 0.97 : 1.0)
                    .brightness(isButtonPressed ? -0.03 : 0)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 40)
                .disabled(toiletEngine.isSearching)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            withAnimation(.easeOut(duration: 0.1)) {
                                isButtonPressed = true
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.15)) {
                                isButtonPressed = false
                            }
                        }
                )

                Spacer().frame(height: 24)

                // Shake hint
                HStack(spacing: 6) {
                    Text("or")
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65))

                    ShakePhoneIcon()
                        .frame(width: 20, height: 20)

                    Text("shake your phone")
                        .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65))
                }
                .font(.system(size: 14, weight: .regular))

                Spacer()
                Spacer()
            }

            // Loading Overlay
            if toiletEngine.isSearching {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: Color(red: 0.1, green: 0.74, blue: 0.61))
                        )
                        .scaleEffect(1.5)

                    Text(toiletEngine.searchStatus.isEmpty ? "Finding nearest toilet..." : toiletEngine.searchStatus)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .animation(.easeInOut(duration: 0.2), value: toiletEngine.searchStatus)
                }
                .padding(32)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.08), radius: 24, y: 8)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            }
        }
        .onReceive(shakeDetector.$shakeDetected) { detected in
            if detected && !toiletEngine.isSearching && !showDirections {
                HapticFeedback.vibrate()
                triggerSearch()
            }
        }
        .alert("Notice", isPresented: $showError) {
            Button("Open in Apple Maps") {
                if let url = URL(string: "maps://?q=public+toilet") {
                    UIApplication.shared.open(url)
                }
                toiletEngine.clearDestination()
            }
            Button("OK", role: .cancel) {
                toiletEngine.clearDestination()
            }
        } message: {
            Text(errorMessage.isEmpty ? "No toilets found within 15 km" : errorMessage)
        }
        .alert("Location Required", isPresented: $showLocationDenied) {
            Button("Open Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("PooGo needs location access to find toilets near you. Please enable it in Settings.")
        }
        .fullScreenCover(isPresented: $showDirections) {
            if let destination = currentDestination {
                DirectionsView(
                    destination: destination,
                    onClose: {
                        showDirections = false
                        toiletEngine.clearDestination()
                        currentDestination = nil
                    }
                )
            }
        }
    }

    private func triggerSearch() {
        let status = toiletEngine.authorizationStatus
        if status == .denied || status == .restricted {
            showLocationDenied = true
            return
        }

        HapticFeedback.vibrate()
        
        toiletEngine.findNearestToilet { result in
            switch result {
            case .success(let destination):
                currentDestination = destination
                showDirections = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Animated Shake Phone Icon

struct ShakePhoneIcon: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Phone body
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color(red: 0.65, green: 0.65, blue: 0.65), lineWidth: 1.5)
                .frame(width: 12, height: 18)

            // Screen
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.65, green: 0.65, blue: 0.65).opacity(0.3))
                .frame(width: 8, height: 12)
        }
        .rotationEffect(.degrees(rotation), anchor: .bottom)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.15)
                    .repeatForever(autoreverses: true)
                    .delay(2)
            ) {
                rotation = 8
            }
        }
    }
}

#Preview {
    ContentView()
}
