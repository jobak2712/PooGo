//
//  SplashView.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var sparkleRotation: Double = 0
    @State private var sparkleScale: CGFloat = 0
    
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.98, green: 0.96, blue: 0.93)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated Icon
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 120)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 0.75, blue: 0.85), Color(red: 0.1, green: 0.74, blue: 0.61)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(28)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                    
                    Image(systemName: "toilet.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color(red: 0.1, green: 0.74, blue: 0.61))
                        .clipShape(Circle())
                        .offset(x: 10, y: -10)
                        .scaleEffect(sparkleScale)
                        .rotationEffect(.degrees(sparkleRotation))
                }
                
                // Title
                HStack(spacing: 4) {
                    Text("PooGo")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.black)
                    
                    Circle()
                        .fill(Color(red: 0.1, green: 0.74, blue: 0.61))
                        .frame(width: 12, height: 12)
                        .offset(y: -10)
                }
                .opacity(titleOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Icon bounce in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Sparkle animation
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            sparkleScale = 1.0
        }
        
        withAnimation(.linear(duration: 1.0).delay(0.3)) {
            sparkleRotation = 360
        }
        
        // Title fade in
        withAnimation(.easeIn(duration: 0.4).delay(0.4)) {
            titleOpacity = 1.0
        }
        
        // Complete after animations (reduced from 1.8s for urgency)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onComplete()
        }
    }
}

#Preview {
    SplashView(onComplete: {})
}
