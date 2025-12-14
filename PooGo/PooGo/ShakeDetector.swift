//
//  ShakeDetector.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import Foundation
import CoreMotion
import Combine

class ShakeDetector: NSObject, ObservableObject {
    @Published var shakeDetected = false
    
    private let motionManager = CMMotionManager()
    private let shakeThreshold: Double = 2.5  // Slightly higher to avoid false positives
    private let cooldownInterval: Double = 1.5  // Longer cooldown to prevent double triggers
    private var lastShakeTime: Date = Date.distantPast
    private var shakeCount = 0
    private let requiredShakes = 2  // Require 2 quick shakes for more reliable detection
    private var shakeWindow: Date = Date.distantPast
    
    override init() {
        super.init()
        startAccelerometerUpdates()
    }
    
    private func startAccelerometerUpdates() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.02  // Faster sampling for better detection
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let acceleration = data?.acceleration else { return }
            
            // Calculate magnitude (subtract gravity ~1.0)
            let magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
            
            let now = Date()
            
            // Check if we're in cooldown
            if now.timeIntervalSince(self.lastShakeTime) < self.cooldownInterval {
                return
            }
            
            if magnitude > self.shakeThreshold {
                // Reset shake count if too much time passed since last shake
                if now.timeIntervalSince(self.shakeWindow) > 0.5 {
                    self.shakeCount = 0
                }
                
                self.shakeWindow = now
                self.shakeCount += 1
                
                // Trigger only after required number of shakes
                if self.shakeCount >= self.requiredShakes {
                    self.lastShakeTime = now
                    self.shakeCount = 0
                    self.shakeDetected = true
                    
                    // Reset after a longer delay to ensure SwiftUI catches it
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.shakeDetected = false
                    }
                }
            }
        }
    }
    
    deinit {
        motionManager.stopAccelerometerUpdates()
    }
}
