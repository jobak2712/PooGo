//
//  LocationService.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import Foundation
import CoreLocation
import MapKit
import Combine

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isPrefetching = false
    @Published var isLiveTrackingEnabled = false
    
    private let locationManager = CLLocationManager()
    private var prefetchTimer: Timer?
    private let prefetchInterval: TimeInterval = 300 // 5 minutes
    
    // Standard vs Live tracking settings
    private let standardDistanceFilter: CLLocationDistance = 100
    private let liveDistanceFilter: CLLocationDistance = 5
    private let standardAccuracy = kCLLocationAccuracyHundredMeters
    private let liveAccuracy = kCLLocationAccuracyBest
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = standardAccuracy
        locationManager.distanceFilter = standardDistanceFilter
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    // MARK: - Public Methods
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startMonitoring() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
        startPrefetchTimer()
    }
    
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        stopPrefetchTimer()
    }
    
    /// Enables live tracking mode for navigation (updates every 5m with best accuracy)
    func startLiveTracking() {
        isLiveTrackingEnabled = true
        locationManager.desiredAccuracy = liveAccuracy
        locationManager.distanceFilter = liveDistanceFilter
        locationManager.startUpdatingLocation()
    }
    
    /// Disables live tracking and returns to standard mode (updates every 100m)
    func stopLiveTracking() {
        isLiveTrackingEnabled = false
        locationManager.desiredAccuracy = standardAccuracy
        locationManager.distanceFilter = standardDistanceFilter
    }
    
    func requestSingleLocation(completion: @escaping (CLLocation?) -> Void) {
        // If we have a recent location (within 30 seconds), use it immediately
        if let location = currentLocation,
           -location.timestamp.timeIntervalSinceNow < 30 {
            completion(location)
            return
        }
        
        // Start continuous updates for better accuracy on cold start
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        // Use longer timeout for cold GPS start (10 seconds)
        let timeout: TimeInterval = currentLocation == nil ? 10.0 : 5.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.locationManager.stopUpdatingLocation()
            completion(self?.currentLocation)
        }
    }
    
    // MARK: - Prefetching
    
    private func startPrefetchTimer() {
        stopPrefetchTimer()
        prefetchTimer = Timer.scheduledTimer(withTimeInterval: prefetchInterval, repeats: true) { [weak self] _ in
            self?.prefetchNearbyToilets()
        }
        // Initial prefetch
        prefetchNearbyToilets()
    }
    
    private func stopPrefetchTimer() {
        prefetchTimer?.invalidate()
        prefetchTimer = nil
    }
    
    func prefetchNearbyToilets() {
        guard let location = currentLocation else { return }
        guard !isPrefetching else { return }
        
        isPrefetching = true
        
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        
        // Search for public toilets, restaurants, transport hubs, parks, and facilities
        let queries = [
            "public toilet restroom washroom WC",
            "McDonald's", "KFC", "Burger King", "Starbucks",
            "fast food restaurant",
            "railway station", "train station", "bus station",
            "public park", "park toilet",
            "shopping centre", "supermarket",
            "library", "leisure centre"
        ]
        
        var allResults: [MKMapItem] = []
        let group = DispatchGroup()
        let resultsLock = NSLock()
        
        for query in queries {
            group.enter()
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            
            let search = MKLocalSearch(request: request)
            search.start { response, _ in
                defer { group.leave() }
                
                if let items = response?.mapItems {
                    resultsLock.lock()
                    allResults.append(contentsOf: items)
                    resultsLock.unlock()
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.isPrefetching = false
            
            if !allResults.isEmpty {
                ToiletCache.shared.cacheToilets(allResults, near: location)
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startMonitoring()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // In live tracking mode, always update location
        if isLiveTrackingEnabled {
            currentLocation = location
            return
        }
        
        // Standard mode: Only update if moved significantly (50m+)
        if let current = currentLocation {
            let distance = location.distance(from: current)
            if distance < 50 { return }
        }
        
        currentLocation = location
        
        // Prefetch if moved more than 500m
        if let lastCached = ToiletCache.shared.lastKnownLocation {
            let lastLocation = CLLocation(latitude: lastCached.latitude, longitude: lastCached.longitude)
            if location.distance(from: lastLocation) > 500 {
                prefetchNearbyToilets()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location error handled silently
    }
}
