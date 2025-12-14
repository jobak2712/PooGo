//
//  PooGoApp.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import SwiftUI

@main
struct PooGoApp: App {
    @State private var showSplash = true
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboarding_complete")
    
    init() {
        // Start location service if already authorized
        if UserDefaults.standard.bool(forKey: "onboarding_complete") {
            LocationService.shared.startMonitoring()
            // Pre-warm GPS immediately to avoid cold start delays
            PooGoNearestToiletEngine.shared.prewarmLocation()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isOnboardingComplete {
                    ContentView()
                        .onAppear {
                            LocationService.shared.startMonitoring()
                            // Pre-warm GPS when view appears (in case init was missed)
                            PooGoNearestToiletEngine.shared.prewarmLocation()
                        }
                } else {
                    OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                }
                
                // Splash overlay
                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }
}
