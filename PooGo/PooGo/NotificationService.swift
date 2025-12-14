//
//  NotificationService.swift
//  PooGo
//
//  Created by Abiodun Olorode on 06/12/2025.
//

import Foundation
import UserNotifications
import CoreLocation
import Combine

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var pendingToiletDestination: ToiletDestination?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
        }
    }
    
    func sendToiletFoundNotification(toilet: ToiletDestination, distance: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🚻 Toilet Found!"
        content.body = "\(toilet.name) is \(distance)m away. Tap for directions."
        content.sound = .default
        content.categoryIdentifier = "TOILET_FOUND"
        content.userInfo = [
            "toiletName": toilet.name,
            "latitude": toilet.latitude,
            "longitude": toilet.longitude
        ]
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        // Store destination for when user taps
        DispatchQueue.main.async {
            self.pendingToiletDestination = toilet
        }
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func setupNotificationActions() {
        let getDirectionsAction = UNNotificationAction(
            identifier: "GET_DIRECTIONS",
            title: "Get Directions",
            options: [.foreground]
        )
        
        let category = UNNotificationCategory(
            identifier: "TOILET_FOUND",
            actions: [getDirectionsAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        
        if let name = userInfo["toiletName"] as? String,
           let lat = userInfo["latitude"] as? Double,
           let lon = userInfo["longitude"] as? Double {
            
            let destination = ToiletDestination(name: name, latitude: lat, longitude: lon)
            
            await MainActor.run {
                self.pendingToiletDestination = destination
                // Post notification to show directions
                NotificationCenter.default.post(name: .showDirections, object: destination)
            }
        }
    }
}

extension Notification.Name {
    static let showDirections = Notification.Name("showDirections")
}
