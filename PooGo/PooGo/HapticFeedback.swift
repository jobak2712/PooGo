//
//  HapticFeedback.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import UIKit

struct HapticFeedback {
    static func vibrate() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            impactFeedback.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            impactFeedback.impactOccurred()
        }
    }
}
