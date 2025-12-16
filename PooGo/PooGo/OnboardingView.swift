//
//  OnboardingView.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var isButtonPressed = false

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.96, blue: 0.93)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App Icon
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
                        .frame(width: 100, height: 100)

                    Image(systemName: "toilet.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                }
                .shadow(
                    color: Color(red: 0.1, green: 0.74, blue: 0.61).opacity(0.3), radius: 16, y: 8)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

                Spacer().frame(height: 28)

                // App Name
                HStack(spacing: 4) {
                    Text("PooGo")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)

                    Circle()
                        .fill(Color(red: 0.1, green: 0.74, blue: 0.61))
                        .frame(width: 10, height: 10)
                        .offset(y: -12)
                }

                Spacer().frame(height: 12)

                // Tagline
                Text("Find the nearest toilet\nin seconds.")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer().frame(height: 48)

                // Location explanation card
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.1, green: 0.74, blue: 0.61).opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Location access needed")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)

                            Text("To find toilets near you")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                        }

                        Spacer()
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .padding(.horizontal, 32)

                Spacer().frame(height: 32)

                // Continue Button
                Button(action: completeOnboarding) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .semibold))

                        Text("Continue")
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
                    .shadow(
                        color: Color(red: 0.1, green: 0.74, blue: 0.61).opacity(isButtonPressed ? 0.2 : 0.4),
                        radius: isButtonPressed ? 4 : 12, y: isButtonPressed ? 2 : 6)
                    .shadow(
                        color: .black.opacity(0.1), radius: isButtonPressed ? 2 : 6,
                        y: isButtonPressed ? 1 : 3)
                    .scaleEffect(isButtonPressed ? 0.97 : 1.0)
                    .brightness(isButtonPressed ? -0.03 : 0)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 32)
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

                Spacer().frame(height: 16)

                // Privacy note
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                    Text("Your location stays private")
                        .font(.system(size: 13))
                }
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))

                Spacer()
                Spacer()
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_complete")
        LocationService.shared.requestPermission()
        
        // Request permission on the engine too and start pre-warming GPS
        PooGoNearestToiletEngine.shared.requestPermission()
        
        // Give a moment for permission dialog, then start warming GPS
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            PooGoNearestToiletEngine.shared.prewarmLocation()
        }

        withAnimation(.easeOut(duration: 0.3)) {
            isOnboardingComplete = true
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
