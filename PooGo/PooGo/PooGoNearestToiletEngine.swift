//
//  PooGoNearestToiletEngine.swift
//  PooGo
//
//  Simplified, deterministic toilet finder engine
//

import Combine
import CoreLocation
import Foundation
import MapKit
import os.log
import UIKit

private let logger = Logger(subsystem: "com.abiodun.PooGo", category: "ToiletEngine")

final class PooGoNearestToiletEngine: NSObject, ObservableObject, CLLocationManagerDelegate {
    // MARK: - Singleton

    static let shared = PooGoNearestToiletEngine()

    // MARK: - Published State

    @Published var isSearching = false
    @Published var currentDestination: ToiletDestination?
    @Published var errorMessage: String?
    @Published var isLocationReady = false  // True when we have a usable location
    @Published var searchStatus: String = ""  // Current search phase for UI feedback
    
    // Debug tracking
    private var debugLog: [String] = []
    private func log(_ message: String) {
        logger.info("\(message)")
        debugLog.append(message)
    }

    // MARK: - Location

    private let locationManager = CLLocationManager()
    private var locationCompletion: ((CLLocation?) -> Void)?
    private var currentLocation: CLLocation?

    // Best-effort location captured while waiting for a precise fix
    private var bestEffortLocation: CLLocation?

    // Accurate location gating
    private let acceptableHorizontalAccuracy: CLLocationAccuracy = 50 // meters
    private let recentLocationAge: TimeInterval = 10 // seconds
    private let coldStartTimeout: TimeInterval = 15 // longer timeout for cold GPS
    private let warmStartTimeout: TimeInterval = 8 // shorter timeout when GPS is warm
    private var locationTimeoutTimer: Timer?
    private var hasHadSuccessfulFix = false  // Track if GPS has ever gotten a fix

    // MARK: - Search / Cache

    private var lastSelectedDestination: ToiletDestination?
    private var lastSelectedLocation: CLLocation?
    private let consistencyRadius: CLLocationDistance = 50  // meters
    private let maxAcceptableDistance: CLLocationDistance = 15000  // 15km
    
    // "Find Another" - track skipped toilets for current session
    private var skippedToiletIds: Set<String> = []

    // MARK: - Init

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // MARK: - Pre-warm Location (call on app launch)
    
    /// Call this early (e.g., on app launch) to start warming up GPS
    func prewarmLocation() {
        let status = locationManager.authorizationStatus
        
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
        
        // Stop after we get a good fix or after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + coldStartTimeout) { [weak self] in
            guard let self = self else { return }
            // Only stop if we're not actively searching
            if self.locationCompletion == nil {
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
    
    // Called when authorization changes - start prewarming if newly authorized
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            prewarmLocation()
        }
    }

    // MARK: - Permissions

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    // MARK: - Request Single Fresh Location

    func requestSingleLocation(completion: @escaping (CLLocation?) -> Void) {
        // If we have a recent and accurate location, use it immediately
        if let location = currentLocation, isGood(location) {
            completion(location)
            return
        }
        
        // If we have any recent location (even less accurate), use it for warm start
        if let location = currentLocation, -location.timestamp.timeIntervalSinceNow < 30 {
            // We have a somewhat recent location - use shorter timeout
            startLocationRequest(completion: completion, timeout: warmStartTimeout)
            return
        }

        // Cold start - use longer timeout to let GPS warm up
        startLocationRequest(completion: completion, timeout: coldStartTimeout)
    }
    
    private func startLocationRequest(completion: @escaping (CLLocation?) -> Void, timeout: TimeInterval) {
        // Reset best-effort
        bestEffortLocation = nil

        locationCompletion = completion
        // Start high-accuracy updates until we get a good fix
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()

        // Safety timeout
        locationTimeoutTimer?.invalidate()
        locationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.locationManager.stopUpdatingLocation()
            self.locationTimeoutTimer = nil
            // Prefer the best effort we captured during updates
            if let best = self.bestEffortLocation {
                completion(best)
            } else if let last = self.currentLocation {
                completion(last)
            } else {
                completion(nil)
            }
            self.locationCompletion = nil
        }
    }

    // MARK: - CLLocationManager Delegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Always keep the latest
        guard let location = locations.last else {
            locationCompletion?(nil)
            locationCompletion = nil
            return
        }

        currentLocation = location
        
        // Mark location as ready once we have any valid location
        if location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 500 {
            if !isLocationReady {
                DispatchQueue.main.async {
                    self.isLocationReady = true
                }
            }
        }

        // Update best-effort if it's the first or if it's better (newer and/or more accurate)
        if bestEffortLocation == nil {
            bestEffortLocation = location
        } else if let best = bestEffortLocation {
            let isNewer = location.timestamp > best.timestamp
            let isMoreAccurate = location.horizontalAccuracy > 0 && (best.horizontalAccuracy <= 0 || location.horizontalAccuracy < best.horizontalAccuracy)
            if isNewer || isMoreAccurate {
                bestEffortLocation = location
            }
        }

        // Only finish when we have a recent, accurate fix
        if isGood(location) {
            hasHadSuccessfulFix = true
            locationTimeoutTimer?.invalidate()
            locationTimeoutTimer = nil
            locationManager.stopUpdatingLocation()
            locationCompletion?(location)
            locationCompletion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationTimeoutTimer?.invalidate()
        locationTimeoutTimer = nil
        locationManager.stopUpdatingLocation()
        bestEffortLocation = nil
        locationCompletion?(nil)
        locationCompletion = nil
    }

    // MARK: - Public: Find Nearest Toilet

    func findNearestToilet(completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        // Reset skipped toilets for fresh search
        skippedToiletIds.removeAll()
        findToiletInternal(completion: completion)
    }
    
    /// Find another toilet (skips previously shown results)
    func findAnotherToilet(skipping current: ToiletDestination?, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        // Add current toilet to skip list
        if let current = current {
            let toiletId = "\(current.latitude),\(current.longitude)"
            skippedToiletIds.insert(toiletId)
            log("🔄 Finding another toilet, skipping: \(current.name)")
        }
        
        // Clear consistency cache so we don't get the same result
        lastSelectedDestination = nil
        
        findToiletInternal(completion: completion)
    }
    
    private func findToiletInternal(completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        isSearching = true
        errorMessage = nil
        searchStatus = "Getting your location..."
        debugLog = []  // Reset debug log
        
        log("🔎 Starting toilet search...")
        log("📍 Current location: \(currentLocation?.coordinate.latitude ?? 0), \(currentLocation?.coordinate.longitude ?? 0)")
        log("📍 Has had successful fix: \(hasHadSuccessfulFix)")
        log("📍 Auth status: \(locationManager.authorizationStatus.rawValue)")
        log("📍 Skipping \(skippedToiletIds.count) toilets")
        
        // If we don't have any location yet and GPS is cold, wait for it to warm up
        if currentLocation == nil && !hasHadSuccessfulFix {
            log("⏳ No location yet, waiting for GPS to warm up...")
            searchStatus = "Warming up GPS..."
            // Start location updates immediately
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            
            // Wait for location with polling
            waitForLocation(attempts: 0, maxAttempts: 10, completion: completion)
        } else {
            proceedWithSearch(completion: completion)
        }
    }
    
    /// Polls for location every 0.5 seconds, up to maxAttempts times
    private func waitForLocation(attempts: Int, maxAttempts: Int, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        if let location = currentLocation {
            log("✅ Got location after \(attempts) attempts: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            proceedWithSearch(completion: completion)
            return
        }
        
        if attempts >= maxAttempts {
            log("⏱️ Gave up waiting for location after \(attempts) attempts")
            proceedWithSearch(completion: completion)
            return
        }
        
        // Wait 0.5 seconds and try again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.waitForLocation(attempts: attempts + 1, maxAttempts: maxAttempts, completion: completion)
        }
    }
    
    private func proceedWithSearch(completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        searchStatus = "Getting your location..."
        requestSingleLocation { [weak self] location in
            guard let self = self else { return }
            
            guard let location = location else {
                self.log("❌ Could not get location - nil returned")
                self.isSearching = false
                self.searchStatus = ""
                self.errorMessage = "Could not get location"
                completion(.failure(NSError(domain: "PooGo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not get location"])))
                return
            }
            
            self.searchStatus = "Searching nearby..."
            self.log("📍 Got location: \(location.coordinate.latitude), \(location.coordinate.longitude) (accuracy: \(Int(location.horizontalAccuracy))m)")

            // If the fix is still coarse, do a one-time retry to let GPS warm up
            let isAccurate = self.isGood(location) || location.horizontalAccuracy <= 150
            if !isAccurate {
                self.log("⚠️ Location accuracy poor (\(Int(location.horizontalAccuracy))m), retrying...")
                self.requestSingleLocation { [weak self] retry in
                    guard let self = self else { return }
                    let finalLocation = retry ?? location
                    self.log("📍 Final location: \(finalLocation.coordinate.latitude), \(finalLocation.coordinate.longitude)")
                    self.findAndOpenNearestToilet(from: finalLocation, completion: completion)
                }
            } else {
                self.findAndOpenNearestToilet(from: location, completion: completion)
            }
        }
    }

    // MARK: - Find Nearest Toilet (Internal)

    private func findAndOpenNearestToilet(from location: CLLocation, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        // Phase 0: Consistency check - return same result if user hasn't moved
        if let lastDest = lastSelectedDestination,
           let lastLoc = lastSelectedLocation,
           location.distance(from: lastLoc) < consistencyRadius
        {
            finishWithResult(lastDest, completion: completion)
            return
        }

        // Phase 1: Quick restroom-only search (POI category) before cache
        log("🚽 Quick POI search...")
        quickRestroomSearch(from: location) { [weak self] poiResult in
            guard let self = self else { return }
                    if let destination = poiResult {
                // Cache for consistency
                self.lastSelectedDestination = destination
                self.lastSelectedLocation = location
                self.finishWithResult(destination, completion: completion)
                return
            }

            // If POI search found nothing, consider cache next (only if reasonably close)
            if let cached = ToiletCache.shared.getNearestCachedToilet(from: location) {
                let cachedDistance = CLLocation(latitude: cached.latitude, longitude: cached.longitude).distance(from: location)
                if cachedDistance <= 1500 { // only trust cache within 1.5km
                    let destination = ToiletDestination(
                        name: cached.name,
                        latitude: cached.latitude,
                        longitude: cached.longitude,
                        address: cached.address
                    )
                    self.lastSelectedDestination = destination
                    self.lastSelectedLocation = location
                    self.finishWithResult(destination, completion: completion)
                    return
                }
            }

            // Phase 2: Perform fresh search
            self.performTieredSearch(from: location, completion: completion)
        }
    }

    // MARK: - Tiered Search

    private func performTieredSearch(from location: CLLocation, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        performTieredSearchWithRetry(from: location, attempt: 1, completion: completion)
    }
    
    private func performTieredSearchWithRetry(from location: CLLocation, attempt: Int, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        // More comprehensive search queries for better coverage
        let searchQueries = [
            "public toilet",
            "restroom", 
            "WC",
            "bathroom",
            "toilet",
            "lavatory",
            "toilettes",  // French
            "public convenience"
        ]
        
        log("🔍 Search attempt \(attempt) from: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        executeSearchQueries(searchQueries, radius: maxAcceptableDistance, from: location) { [weak self] results in
            guard let self = self else { return }

            self.log("🔍 Search attempt \(attempt): \(results.count) results")

            // If no results and this is first attempt, retry after a short delay
            // MKLocalSearch sometimes needs a "warm up" on first call
            if results.isEmpty && attempt < 3 {
                self.log("🔄 Retrying search (attempt \(attempt + 1))...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.performTieredSearchWithRetry(from: location, attempt: attempt + 1, completion: completion)
                }
                return
            }
            
            // If still no results after retries, try a broader "facilities" search
            if results.isEmpty && attempt >= 3 {
                self.log("🔄 Trying facilities search...")
                self.performBroadFacilitiesSearch(from: location, completion: completion)
                return
            }

            // Save raw results to Supabase (for analytics)
            self.saveSearchToSupabase(results: results, location: location)

            // Filter and sort
            let filtered = self.filterResults(results, from: location)

            let sorted = self.sortResults(filtered, from: location)

            if let best = sorted.first, let bestLocation = best.placemark.location {
                let destination = ToiletDestination(
                    name: best.name ?? "Public Toilet",
                    latitude: bestLocation.coordinate.latitude,
                    longitude: bestLocation.coordinate.longitude,
                    address: self.formatAddress(for: best)
                )



                // Cache for consistency
                self.lastSelectedDestination = destination
                self.lastSelectedLocation = location

                // Also cache in ToiletCache
                ToiletCache.shared.cacheToilets(sorted, near: location)

                self.finishWithResult(destination, completion: completion)
            } else {
                // Fallback to cache
                if let cached = ToiletCache.shared.getNearestCachedToilet(from: location) {
                    let destination = ToiletDestination(
                        name: cached.name,
                        latitude: cached.latitude,
                        longitude: cached.longitude,
                        address: cached.address
                    )
                    self.finishWithResult(destination, completion: completion)
                } else {
                    self.finishWithError("No toilets found within 15 km", completion: completion)
                }
            }
        }
    }
    
    /// Broader search for facilities that typically have toilets (shopping centers, stations, etc.)
    private func performBroadFacilitiesSearch(from location: CLLocation, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        let facilityQueries = [
            "shopping centre",
            "train station",
            "bus station", 
            "supermarket",
            "McDonald's",
            "Starbucks",
            "library",
            "hospital"
        ]
        
        executeSearchQueries(facilityQueries, radius: maxAcceptableDistance, from: location) { [weak self] results in
            guard let self = self else { return }
            

            
            let filtered = self.filterResults(results, from: location)
            let sorted = self.sortResults(filtered, from: location)
            
            if let best = sorted.first, let bestLocation = best.placemark.location {
                let destination = ToiletDestination(
                    name: best.name ?? "Facility with Toilet",
                    latitude: bestLocation.coordinate.latitude,
                    longitude: bestLocation.coordinate.longitude,
                    address: self.formatAddress(for: best)
                )
                
                self.lastSelectedDestination = destination
                self.lastSelectedLocation = location
                ToiletCache.shared.cacheToilets(sorted, near: location)
                self.finishWithResult(destination, completion: completion)
            } else if let cached = ToiletCache.shared.getNearestCachedToilet(from: location) {
                let destination = ToiletDestination(
                    name: cached.name,
                    latitude: cached.latitude,
                    longitude: cached.longitude,
                    address: cached.address
                )
                self.finishWithResult(destination, completion: completion)
            } else {
                // Last resort: try simple "toilet" search with larger radius
                self.performLastResortSearch(from: location, completion: completion)
            }
        }
    }
    
    /// Last resort: simple "toilet" search with large radius
    private func performLastResortSearch(from location: CLLocation, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 20000,  // 20km radius
            longitudinalMeters: 20000
        )
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "toilet"
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            guard let self = self else { return }
            
            if let items = response?.mapItems,
               let best = items.min(by: { a, b in
                   guard let la = a.placemark.location, let lb = b.placemark.location else { return false }
                   return la.distance(from: location) < lb.distance(from: location)
               }),
               let bestLoc = best.placemark.location {
                let destination = ToiletDestination(
                    name: best.name ?? "Toilet",
                    latitude: bestLoc.coordinate.latitude,
                    longitude: bestLoc.coordinate.longitude,
                    address: self.formatAddress(for: best)
                )
                self.finishWithResult(destination, completion: completion)
            } else {
                self.finishWithError("No toilets found within 15 km", completion: completion)
            }
        }
    }

    // MARK: - Execute MKLocalSearch

    private func executeSearchQueries(
        _ queries: [String],
        radius: Double,
        from location: CLLocation,
        completion: @escaping ([MKMapItem]) -> Void
    ) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius,
            longitudinalMeters: radius
        )

        var allResults: [MKMapItem] = []
        var queryResults: [String: Int] = [:]
        let group = DispatchGroup()
        let resultsLock = NSLock()

        for query in queries {
            group.enter()

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region

            let search = MKLocalSearch(request: request)
            search.start { response, error in
                defer { group.leave() }

                if let error = error {
                    resultsLock.lock()
                    queryResults[query] = -1  // Error
                    resultsLock.unlock()
                }

                if let items = response?.mapItems {
                    resultsLock.lock()
                    queryResults[query] = items.count
                    allResults.append(contentsOf: items)
                    resultsLock.unlock()
                } else {
                    resultsLock.lock()
                    if queryResults[query] == nil {
                        queryResults[query] = 0
                    }
                    resultsLock.unlock()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            // Log results per query
            let summary = queryResults.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            self?.log("📊 Query results: \(summary)")
            completion(allResults)
        }
    }

    // MARK: - Filtering

    private func filterResults(_ results: [MKMapItem], from location: CLLocation) -> [MKMapItem] {
        return results.filter { item in
            guard let loc = item.placemark.location else { return false }

            // Reject if too far away (allow 300m GPS jitter)
            let distance = loc.distance(from: location)
            if distance > maxAcceptableDistance + 300 {
                return false
            }

            // Reject gas/petrol stations
            let name = item.name?.lowercased() ?? ""
            if name.contains("petrol") || name.contains("gas station") || name.contains("filling station") {
                return false
            }

            // Reject blacklisted toilets (only if we have alternatives)
            let isBlacklisted = ToiletReliabilityService.shared.shouldHideToilet(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude
            )
            if isBlacklisted && results.count > 3 {
                return false
            }
            
            // Skip toilets user has already seen ("Find Another" feature)
            let toiletId = "\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
            if skippedToiletIds.contains(toiletId) {
                return false
            }

            return true
        }
    }

    /// Fast path: Use POI category `.restroom` within ~2km and pick the closest
    private func quickRestroomSearch(from location: CLLocation, completion: @escaping (ToiletDestination?) -> Void) {
        quickRestroomSearchWithRetry(from: location, attempt: 1, completion: completion)
    }
    
    private func quickRestroomSearchWithRetry(from location: CLLocation, attempt: Int, completion: @escaping (ToiletDestination?) -> Void) {
        if #available(iOS 13.0, *) {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
            let request = MKLocalSearch.Request()
            request.resultTypes = .pointOfInterest
            if #available(iOS 13.0, *) {
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restroom])
            }
            // No naturalLanguageQuery needed when using POI filter
            request.region = region
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, error in
                guard let self = self else {
                    completion(nil)
                    return
                }
                
                let itemCount = response?.mapItems.count ?? 0
                
                // If error or no results on first attempt, retry once
                if (error != nil || itemCount == 0) && attempt < 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.quickRestroomSearchWithRetry(from: location, attempt: attempt + 1, completion: completion)
                    }
                    return
                }
                
                guard let items = response?.mapItems, !items.isEmpty else {
                    completion(nil)
                    return
                }
                // Choose nearest by actual distance
                let best = items.min { a, b in
                    guard let la = a.placemark.location, let lb = b.placemark.location else { return false }
                    return la.distance(from: location) < lb.distance(from: location)
                }
                if let best, let bestLoc = best.placemark.location {
                    let dest = ToiletDestination(
                        name: best.name ?? "Public Toilet",
                        latitude: bestLoc.coordinate.latitude,
                        longitude: bestLoc.coordinate.longitude,
                        address: self.formatAddress(for: best)
                    )
                    completion(dest)
                } else {
                    completion(nil)
                }
            }
        } else {
            completion(nil)
        }
    }

    // MARK: - Sorting (Deterministic)

    private func sortResults(_ results: [MKMapItem], from location: CLLocation) -> [MKMapItem] {
        return results.sorted { item1, item2 in
            guard let loc1 = item1.placemark.location,
                  let loc2 = item2.placemark.location
            else { return false }

            let d1 = loc1.distance(from: location)
            let d2 = loc2.distance(from: location)

            // Primary: distance (with 10m tolerance)
            if abs(d1 - d2) > 10 {
                return d1 < d2
            }

            // Secondary: prefer actual toilet facilities
            let isToilet1 = isLikelyToiletFacility(item1)
            let isToilet2 = isLikelyToiletFacility(item2)
            if isToilet1 != isToilet2 {
                return isToilet1
            }

            // Tertiary: alphabetical by name
            let name1 = item1.name ?? ""
            let name2 = item2.name ?? ""
            if name1 != name2 {
                return name1 < name2
            }

            // Final: coordinates for absolute determinism
            if loc1.coordinate.latitude != loc2.coordinate.latitude {
                return loc1.coordinate.latitude < loc2.coordinate.latitude
            }
            return loc1.coordinate.longitude < loc2.coordinate.longitude
        }
    }

    private func isLikelyToiletFacility(_ item: MKMapItem) -> Bool {
        // Use Apple's POI category if available
        if #available(iOS 14.0, *) {
            if item.pointOfInterestCategory == .restroom {
                return true
            }
        }

        // Fallback: check name for toilet keywords (multilingual)
        let keywords = [
            "toilet", "restroom", "bathroom", "wc", "lavatory", "loo",
            "toilettes", "baño", "toilette", "トイレ", "화장실", "厕所", "卫生间"
        ]
        let name = item.name?.lowercased() ?? ""
        return keywords.contains { name.contains($0) }
    }

    // MARK: - Result Handling

    private func finishWithResult(_ destination: ToiletDestination, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        DispatchQueue.main.async {
            self.isSearching = false
            self.searchStatus = ""
            self.currentDestination = destination
            self.errorMessage = nil
            completion(.success(destination))
        }
    }

    private func finishWithError(_ message: String, completion: @escaping (Result<ToiletDestination, Error>) -> Void) {
        // Log debug info for troubleshooting but don't show to user
        logger.error("Search failed: \(message)")
        for logEntry in debugLog.suffix(10) {
            logger.debug("\(logEntry)")
        }
        
        // Try cache fallback before giving up (critical for offline/poor network)
        if let userLocation = currentLocation ?? lastSelectedLocation,
           let cached = ToiletCache.shared.getNearestCachedToilet(from: userLocation) {
            log("📦 Using cached toilet as fallback: \(cached.name)")
            let destination = ToiletDestination(
                name: cached.name,
                latitude: cached.latitude,
                longitude: cached.longitude,
                address: cached.address
            )
            finishWithResult(destination, completion: completion)
            return
        }
        
        DispatchQueue.main.async {
            self.isSearching = false
            self.errorMessage = message
            completion(.failure(NSError(domain: "PooGo", code: 2, userInfo: [NSLocalizedDescriptionKey: message])))
        }
    }

    // MARK: - Supabase Integration

    private func saveSearchToSupabase(results: [MKMapItem], location: CLLocation) {
        let locations: [SearchLocationItem] = results.compactMap { item in
            guard let loc = item.placemark.location else { return nil }
            return SearchLocationItem(
                name: item.name ?? "Unknown",
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                address: formatAddress(for: item)
            )
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "anonymous"
        let userEmail = "anonymous_\(deviceId.prefix(8))"

        SupabaseService.shared.saveSearchRequest(
            userEmail: userEmail,
            searchLatitude: location.coordinate.latitude,
            searchLongitude: location.coordinate.longitude,
            locations: locations
        )
    }

    // MARK: - Helpers

    private func formatAddress(for item: MKMapItem) -> String? {
        let placemark = item.placemark
        var components: [String] = []

        if let subThoroughfare = placemark.subThoroughfare {
            components.append(subThoroughfare)
        }
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let postalCode = placemark.postalCode {
            components.append(postalCode)
        }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    private func isGood(_ location: CLLocation) -> Bool {
        let age = -location.timestamp.timeIntervalSinceNow
        let accurateEnough = location.horizontalAccuracy > 0 && location.horizontalAccuracy <= acceptableHorizontalAccuracy
        let recentEnough = age <= recentLocationAge
        return accurateEnough && recentEnough
    }

    private func debugPrintLocation(_ prefix: String, _ location: CLLocation?) {
        guard let l = location else { return }
        let age = -l.timestamp.timeIntervalSinceNow
        logger.debug("\(prefix): (lat: \(l.coordinate.latitude), lon: \(l.coordinate.longitude)), acc: \(Int(l.horizontalAccuracy))m, age: \(String(format: "%.1f", age))s")
    }

    // MARK: - Clear State

    func clearDestination() {
        currentDestination = nil
        errorMessage = nil
        // Keep lastSelectedDestination for consistency
    }

    func clearAll() {
        currentDestination = nil
        errorMessage = nil
        lastSelectedDestination = nil
        lastSelectedLocation = nil
    }
}

