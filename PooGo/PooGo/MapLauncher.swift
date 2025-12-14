//
//  MapLauncher.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import Combine
import CoreLocation
import Foundation
import MapKit
import UIKit

enum MapLauncherState: Equatable {
    case idle
    case searching
    case found(ToiletDestination)
    case error(String)
}

class MapLauncher: NSObject, ObservableObject {
    static let shared = MapLauncher()

    @Published var state: MapLauncherState = .idle
    @Published var isSearching = false
    @Published var currentDestination: ToiletDestination?

    private var isProcessing = false
    
    // MARK: - Search Tier Configuration
    // Tier 1: Quick search for nearby free toilets (500m, 3 queries)
    // Tier 2: Expanded search including facilities (2km, 6 queries)
    // Tier 3: Full search including restaurants (10km, 10 queries)
    
    private struct SearchTier {
        let radius: Double
        let queries: [String]
    }
    
    private let searchTiers: [SearchTier] = [
        // Tier 1: Quick - Actual toilets only (500m)
        SearchTier(radius: 500, queries: [
            "public toilet",
            "restroom",
            "WC",
            "toilettes",
            "トイレ",
            "화장실"
        ]),
        // Tier 2: Expanded - Reliable toilet locations (1km)
        SearchTier(radius: 1000, queries: [
            "public toilet restroom WC",
            "train station",
            "railway station",
            "bus station",
            "shopping centre mall",
            "supermarket Tesco Sainsbury Asda",
            "library",
            "hospital"
        ]),
        // Tier 3: Full - More locations (2km)
        SearchTier(radius: 2000, queries: [
            "public toilet",
            "station",
            "shopping centre",
            "supermarket",
            "McDonald's KFC Burger King",
            "Starbucks Costa Coffee",
            "park",
            "library",
            "hospital",
            "hotel"
        ])
    ]
    
    // Maximum acceptable distance (5km / ~60 min walk)
    private let maxAcceptableDistance: Double = 5000
    
    // Cache freshness threshold (30 minutes)
    private let cacheFreshnessThreshold: TimeInterval = 1800
    
    // Track last search location to avoid unnecessary cache refreshes
    private var lastSearchLocation: CLLocation?
    private let minimumMovementForRefresh: Double = 100 // Only refresh if moved 100m+
    
    // Store the last selected result to ensure consistency
    private var lastSelectedDestination: ToiletDestination?
    private var lastSelectedLocation: CLLocation?
    private let consistencyRadius: Double = 50 // Return same result if within 50m of last search

    private override init() {
        super.init()
    }

    static func openNearestToilet() {
        shared.findAndOpenNearestToilet()
    }

    private func findAndOpenNearestToilet() {
        guard !isProcessing else { return }
        isProcessing = true

        DispatchQueue.main.async {
            self.state = .searching
            self.isSearching = true
        }
        
        print("🔎 [MapLauncher] Starting toilet search...")

        // Get current location - if nil, wait for GPS to warm up
        if let currentLocation = LocationService.shared.currentLocation {
            print("📍 [MapLauncher] Have location: \(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)")
            proceedWithLocation(currentLocation)
        } else {
            print("⏳ [MapLauncher] No location yet, waiting for GPS...")
            // Start location updates and wait
            LocationService.shared.startMonitoring()
            waitForLocationThenSearch(attempts: 0, maxAttempts: 10)
        }
    }
    
    /// Polls for location every 0.5 seconds
    private func waitForLocationThenSearch(attempts: Int, maxAttempts: Int) {
        if let location = LocationService.shared.currentLocation {
            print("✅ [MapLauncher] Got location after \(attempts) attempts")
            proceedWithLocation(location)
            return
        }
        
        if attempts >= maxAttempts {
            print("⏱️ [MapLauncher] Timeout waiting for location, requesting fresh...")
            // Fall back to requesting single location
            LocationService.shared.requestSingleLocation { [weak self] location in
                guard let self = self else { return }
                if let location = location {
                    self.proceedWithLocation(location)
                } else {
                    self.handleError("Could not get location")
                }
            }
            return
        }
        
        // Wait 0.5 seconds and try again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.waitForLocationThenSearch(attempts: attempts + 1, maxAttempts: maxAttempts)
        }
    }
    
    private func proceedWithLocation(_ currentLocation: CLLocation) {
        // PHASE 0: Return same result if user hasn't moved much (consistency guarantee)
        if let lastDestination = lastSelectedDestination,
           let lastLocation = lastSelectedLocation,
           currentLocation.distance(from: lastLocation) < consistencyRadius {
            // User is in same spot - return the same toilet for consistency
            DispatchQueue.main.async {
                self.currentDestination = lastDestination
                self.state = .found(lastDestination)
                self.isSearching = false
            }
            resetProcessing()
            return
        }
        
        // PHASE 1: Check cache first for instant results
        if let cachedResult = getCachedToiletIfFresh(from: currentLocation) {
            // Show cached result immediately
            showResult(cachedResult, from: currentLocation)
            
            // Only refresh cache if user moved significantly from last search
            if shouldRefreshCache(from: currentLocation) {
                refreshCacheInBackground(from: currentLocation)
            }
            
            // Update last search location
            lastSearchLocation = currentLocation
            return
        }
        
        // PHASE 2-4: Tiered search
        lastSearchLocation = currentLocation
        performTieredSearch(from: currentLocation)
    }
    
    /// Determines if cache should be refreshed based on movement from last search
    private func shouldRefreshCache(from currentLocation: CLLocation) -> Bool {
        guard let lastLocation = lastSearchLocation else {
            // No previous search - should refresh
            return true
        }
        
        let distance = currentLocation.distance(from: lastLocation)
        return distance >= minimumMovementForRefresh
    }
    
    /// Returns cached toilet if within 500m and cache is fresh (< 30 min old)
    private func getCachedToiletIfFresh(from location: CLLocation) -> CachedToilet? {
        let nearbyToilets = ToiletCache.shared.getCachedToilets(within: 500, from: location)
        
        // Find first non-expired toilet that's also fresh enough
        for toilet in nearbyToilets {
            let cacheAge = Date().timeIntervalSince(toilet.cachedAt)
            if cacheAge < cacheFreshnessThreshold {
                return toilet
            }
        }
        return nil
    }
    
    /// Shows result from cached toilet
    private func showResult(_ cached: CachedToilet, from location: CLLocation) {
        let destination = ToiletDestination(
            name: cached.name,
            latitude: cached.latitude,
            longitude: cached.longitude,
            address: cached.address
        )
        
        // Store for consistency on repeated searches
        lastSelectedDestination = destination
        lastSelectedLocation = location
        
        DispatchQueue.main.async {
            self.currentDestination = destination
            self.state = .found(destination)
            self.isSearching = false
        }
        resetProcessing()
    }
    
    /// Refreshes cache in background without blocking UI
    private func refreshCacheInBackground(from location: CLLocation) {
        DispatchQueue.global(qos: .utility).async {
            // Run a quick Tier 1 search to refresh cache
            let tier = self.searchTiers[0]
            self.executeSearchQueries(tier.queries, radius: tier.radius, from: location) { results in
                if !results.isEmpty {
                    ToiletCache.shared.cacheToilets(results, near: location)
                }
            }
        }
    }

    /// Performs tiered search: starts with small radius/few queries, expands if needed
    private func performTieredSearch(from location: CLLocation, tierIndex: Int = 0, retryCount: Int = 0) {
        guard tierIndex < searchTiers.count else {
            // All tiers exhausted - retry entire search if this is first attempt
            // MKLocalSearch sometimes needs a "warm up" on first call
            if retryCount < 2 {
                print("🔄 All tiers empty, retrying entire search (attempt \(retryCount + 2))...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.performTieredSearch(from: location, tierIndex: 0, retryCount: retryCount + 1)
                }
                return
            }
            
            // All retries exhausted - try cache as last resort
            if let cached = ToiletCache.shared.getNearestCachedToilet(from: location) {
                let destination = ToiletDestination(
                    name: cached.name,
                    latitude: cached.latitude,
                    longitude: cached.longitude,
                    address: cached.address
                )
                
                // Store for consistency
                lastSelectedDestination = destination
                lastSelectedLocation = location
                
                DispatchQueue.main.async {
                    self.currentDestination = destination
                    self.state = .found(destination)
                    self.isSearching = false
                }
                resetProcessing()
                return
            }
            handleError("No toilets found nearby")
            return
        }
        
        let tier = searchTiers[tierIndex]
        
        executeSearchQueries(tier.queries, radius: tier.radius, from: location) { [weak self] results in
            guard let self = self else { return }
            
            if results.isEmpty {
                // No results in this tier - try next tier
                self.performTieredSearch(from: location, tierIndex: tierIndex + 1, retryCount: retryCount)
                return
            }
            
            // STEP 1: Save RAW search results to Supabase (before any processing)
            // This logs the unmodified Apple Maps response for analytics
            self.saveSearchRequest(rawResults: results, searchLocation: location)
            
            // STEP 2: Process results (remove duplicates)
            let uniqueResults = self.removeDuplicates(from: results, userLocation: location)
            
            // Cache results
            ToiletCache.shared.cacheToilets(uniqueResults, near: location)
            
            // Save discovered toilets to cloud (for crowdsourcing)
            self.saveAllDiscoveredToilets(uniqueResults)
            
            // Filter out:
            // 1. Results too far away (> 5km)
            // 2. Toilets with very poor reliability
            // 3. Gas stations / petrol stations (unreliable toilet access)
            let filteredResults = uniqueResults.filter { item in
                guard let loc = item.placemark.location else { return false }
                
                // Reject if too far away
                let distance = loc.distance(from: location)
                if distance > self.maxAcceptableDistance {
                    return false
                }
                
                // Reject gas/petrol stations (small kiosks, often no public toilet)
                let name = (item.name ?? "").lowercased()
                if name.contains("petrol") || name.contains("gas station") || name.contains("filling station") {
                    // Only reject if it's JUST a petrol station, not a supermarket with petrol
                    if !name.contains("tesco") && !name.contains("sainsbury") && !name.contains("asda") &&
                       !name.contains("morrisons") && !name.contains("waitrose") {
                        return false
                    }
                }
                
                // Reject blacklisted toilets
                return !ToiletReliabilityService.shared.shouldHideToilet(
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude
                )
            }
            
            // Sort by distance (DETERMINISTIC)
            // Primary: actual distance from user
            // Secondary: prefer dedicated toilet facilities
            // Tertiary: coordinates for absolute determinism
            let sorted = filteredResults.sorted { item1, item2 in
                guard let loc1 = item1.placemark.location,
                      let loc2 = item2.placemark.location else {
                    return false
                }
                
                let d1 = loc1.distance(from: location)
                let d2 = loc2.distance(from: location)
                
                // Primary sort: distance (with 10m tolerance for "same distance")
                if abs(d1 - d2) > 10 {
                    return d1 < d2
                }
                
                // Secondary sort: prefer dedicated toilet facilities
                let isToilet1 = self.isLikelyToiletFacility(item1)
                let isToilet2 = self.isLikelyToiletFacility(item2)
                if isToilet1 != isToilet2 {
                    return isToilet1  // Prefer actual toilets
                }
                
                // Tertiary sort: alphabetical by name
                let name1 = item1.name ?? ""
                let name2 = item2.name ?? ""
                if name1 != name2 {
                    return name1 < name2
                }
                
                // Final tie-breaker: coordinates (absolute determinism)
                if loc1.coordinate.latitude != loc2.coordinate.latitude {
                    return loc1.coordinate.latitude < loc2.coordinate.latitude
                }
                return loc1.coordinate.longitude < loc2.coordinate.longitude
            }
            
            if let nearest = sorted.first, let toiletLocation = nearest.placemark.location {
                let displayName = self.formatDisplayName(for: nearest)
                let address = self.formatAddress(for: nearest)
                
                let destination = ToiletDestination(
                    name: displayName,
                    latitude: toiletLocation.coordinate.latitude,
                    longitude: toiletLocation.coordinate.longitude,
                    address: address
                )
                
                // Store for consistency on repeated searches
                self.lastSelectedDestination = destination
                self.lastSelectedLocation = location
                
                DispatchQueue.main.async {
                    self.currentDestination = destination
                    self.state = .found(destination)
                    self.isSearching = false
                }
                self.resetProcessing()
            } else {
                // Results exist but no valid location - try next tier
                self.performTieredSearch(from: location, tierIndex: tierIndex + 1)
            }
        }
    }
    
    /// Executes search queries in parallel and returns combined results
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
        
        group.notify(queue: .main) {
            completion(allResults)
        }
    }
    
    func clearDestination() {
        currentDestination = nil
        state = .idle
        // Note: We intentionally keep lastSelectedDestination so that
        // if user taps again from same spot, they get the same result
    }
    
    /// Save RAW search request to Supabase (unmodified Apple Maps results)
    private func saveSearchRequest(rawResults: [MKMapItem], searchLocation: CLLocation) {
        // Run in background to not block UI
        DispatchQueue.global(qos: .utility).async {
            // Convert MKMapItems to SearchLocationItems
            let locations: [SearchLocationItem] = rawResults.compactMap { item in
                guard let loc = item.placemark.location else { return nil }
                return SearchLocationItem(
                    name: item.name ?? "Unknown",
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude,
                    address: self.formatAddress(for: item)
                )
            }
            
            // Get user email (or anonymous identifier)
            let userEmail = self.getUserEmail()
            
            // Save to Supabase (feature flag checked inside)
            SupabaseService.shared.saveSearchRequest(
                userEmail: userEmail,
                searchLatitude: searchLocation.coordinate.latitude,
                searchLongitude: searchLocation.coordinate.longitude,
                locations: locations
            )
        }
    }
    
    /// Get user email or anonymous ID
    private func getUserEmail() -> String {
        // Check if user has set an email in UserDefaults
        if let email = UserDefaults.standard.string(forKey: "user_email"), !email.isEmpty {
            return email
        }
        // Return anonymous identifier based on device
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "anonymous"
        return "anonymous_\(deviceId.prefix(8))"
    }
    
    /// Save all discovered toilets to cloud (runs in background, behind feature flag)
    private func saveAllDiscoveredToilets(_ items: [MKMapItem]) {
        // Run in background to not block UI
        DispatchQueue.global(qos: .utility).async {
            for item in items {
                guard let location = item.placemark.location else { continue }
                
                let toiletId = ToiletReliabilityService.shared.toiletId(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                
                let address = self.formatAddress(for: item)
                
                SupabaseService.shared.saveDiscoveredToilet(
                    toiletId: toiletId,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    name: item.name ?? "Unknown Toilet",
                    address: address
                )
            }
        }
    }
    
    /// Check if item is likely a dedicated toilet facility (works with any language)
    private func isLikelyToiletFacility(_ item: MKMapItem) -> Bool {
        // Use Apple's POI category if available (language-independent)
        if let category = item.pointOfInterestCategory {
            // iOS 14+ has .restroom category
            if #available(iOS 14.0, *) {
                if category == .restroom {
                    return true
                }
            }
        }
        
        // Fallback: check name for toilet keywords in multiple languages
        let name = (item.name ?? "").lowercased()
        let toiletKeywords = [
            // English
            "toilet", "restroom", "washroom", "lavatory", "loo", "wc", "public convenience",
            // French
            "toilettes", "sanitaires", "wc public",
            // Spanish
            "baño", "aseo", "servicio",
            // German
            "toilette", "wc", "klo",
            // Italian
            "bagno", "gabinetto",
            // Portuguese
            "banheiro", "sanitário",
            // Japanese
            "トイレ", "お手洗い", "化粧室",
            // Korean
            "화장실", "변소",
            // Chinese
            "厕所", "卫生间", "洗手间"
        ]
        
        return toiletKeywords.contains { name.contains($0) }
    }
    
    /// Determines if a location is likely free-to-use (public toilet, park, station, library)
    /// vs requires purchase (restaurant, cafe)
    private func isFreeToilet(_ item: MKMapItem) -> Bool {
        let name = (item.name ?? "").lowercased()
        let category = item.pointOfInterestCategory
        
        // Definitely free: public toilets, parks, stations, libraries, public facilities
        // Includes Nigerian supermarkets (Shoprite, SPAR, Hubmart) and filling stations
        let freeKeywords = [
            "toilet", "restroom", "washroom", "wc", "lavatory", "loo",
            "station", "terminal", "airport", "motor park",
            "park", "garden",
            "library", "museum",
            "hospital", "clinic",
            "shopping centre", "shopping center", "mall", "plaza",
            "supermarket", "tesco", "sainsbury", "asda", "waitrose", "aldi", "lidl",
            "shoprite", "spar", "hubmart", "justrite",  // Nigerian supermarkets
            "filling station", "petrol station",  // Nigerian term
            "leisure centre", "sports centre", "community centre",
            "hotel", "guest house"
        ]
        
        for keyword in freeKeywords {
            if name.contains(keyword) { return true }
        }
        
        // Check category
        if category == .park || category == .hospital || category == .library ||
           category == .publicTransport || category == .airport {
            return true
        }
        
        // Restaurants/cafes are NOT free (require purchase)
        // Includes Nigerian fast food chains
        let paidKeywords = [
            "mcdonald", "kfc", "burger king", "starbucks", "subway", "wendy",
            "taco bell", "pizza hut", "costa", "pret", "cafe", "coffee",
            "restaurant", "diner", "eatery",
            "chicken republic", "mr biggs", "tantalizers", "sweet sensation"  // Nigerian chains
        ]
        
        for keyword in paidKeywords {
            if name.contains(keyword) { return false }
        }
        
        if category == .restaurant || category == .cafe || category == .foodMarket {
            return false
        }
        
        // Default: assume free (benefit of doubt)
        return true
    }
    
    /// Removes duplicates with smart selection:
    /// 1. Sort by distance first (closest first)
    /// 2. Within 50m clusters, prefer free toilets over paid options
    /// 3. Deterministic tie-breaking by name
    private func removeDuplicates(from items: [MKMapItem], userLocation: CLLocation) -> [MKMapItem] {
        // Step 1: Sort by distance (closest first), then by name for determinism
        let sorted = items
            .filter { $0.placemark.location != nil }
            .sorted { item1, item2 in
                let d1 = item1.placemark.location!.distance(from: userLocation)
                let d2 = item2.placemark.location!.distance(from: userLocation)
                
                if abs(d1 - d2) > 1.0 {  // More than 1m difference
                    return d1 < d2
                }
                // Tie-break by name for determinism
                return (item1.name ?? "") < (item2.name ?? "")
            }
        
        // Step 2: Smart deduplication - within 50m, prefer free toilets
        var unique: [MKMapItem] = []
        
        for item in sorted {
            let itemLocation = item.placemark.location!
            let itemIsFree = isFreeToilet(item)
            
            // Check if there's already a location within 50m
            if let existingIndex = unique.firstIndex(where: { existing in
                guard let existingLocation = existing.placemark.location else { return false }
                return itemLocation.distance(from: existingLocation) < 50
            }) {
                // There's a nearby existing item - decide which to keep
                let existing = unique[existingIndex]
                let existingIsFree = isFreeToilet(existing)
                
                // If current item is free and existing is paid, replace with free option
                if itemIsFree && !existingIsFree {
                    unique[existingIndex] = item
                }
                // Otherwise keep existing (it was closer or same priority)
            } else {
                // No nearby duplicate - add this item
                unique.append(item)
            }
        }
        
        return unique
    }
    
    private func formatDisplayName(for item: MKMapItem) -> String {
        let name = item.name ?? "Toilet"
        let nameLower = name.lowercased()
        
        // Check if it's a transport hub
        let transportKeywords = ["station", "terminal", "airport", "metro", "underground", "tube"]
        let isTransport = transportKeywords.contains { nameLower.contains($0) }
        if isTransport {
            return "\(name) 🚉🚻"
        }
        
        // Check if it's a park
        let isPark = nameLower.contains("park") || item.pointOfInterestCategory == .park
        if isPark {
            return "\(name) 🌳🚻"
        }
        
        // Check if it's a shopping center
        let shoppingKeywords = ["mall", "shopping", "supermarket", "tesco", "sainsbury", "asda", "waitrose", "aldi", "lidl"]
        let isShopping = shoppingKeywords.contains { nameLower.contains($0) }
        if isShopping {
            return "\(name) 🛒🚻"
        }
        
        // Check if it's a known restaurant
        let restaurantKeywords = ["mcdonald", "kfc", "burger king", "starbucks", "subway", "wendy", "taco bell", "pizza hut", "costa", "pret", "cafe", "coffee"]
        let isRestaurant = restaurantKeywords.contains { nameLower.contains($0) } ||
            item.pointOfInterestCategory == .restaurant || item.pointOfInterestCategory == .cafe
        if isRestaurant {
            return "\(name) 🍔🚻"
        }
        
        // Check if it's a public facility
        let facilityKeywords = ["library", "centre", "center", "hospital", "museum"]
        let isFacility = facilityKeywords.contains { nameLower.contains($0) }
        if isFacility {
            return "\(name) 🏛🚻"
        }
        
        return name
    }
    
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

    private func openAppleMapsDirections(to destination: CLLocationCoordinate2D, name: String?) {
        DispatchQueue.main.async {
            // Use URL scheme for more direct navigation experience
            let encodedName = (name ?? "Toilet").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Toilet"
            let urlString = "maps://?daddr=\(destination.latitude),\(destination.longitude)&dirflg=w&t=m&q=\(encodedName)"
            
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback to MKMapItem
                let placemark = MKPlacemark(coordinate: destination)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = name ?? "Public Toilet"
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
                ])
            }
        }
    }

    private func openFallbackSearch() {
        DispatchQueue.main.async {
            if let url = URL(string: "maps://?q=public+toilet") {
                UIApplication.shared.open(url)
            }
        }
    }

    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            self.state = .error(message)
            self.isSearching = false
        }
        // Don't auto-reset on error - let user dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessing = false
        }
    }

    private func resetProcessing() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessing = false
        }
    }
}
