//
//  SupabaseService.swift
//  PooGo
//
//  Created by Kiro on 10/12/2025.
//

import Foundation

// MARK: - Supabase Configuration

struct SupabaseConfig {
    static let projectURL = "https://hqbmaskiflyfzuzyvgda.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxYm1hc2tpZmx5Znp1enl2Z2RhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzNzE0OTEsImV4cCI6MjA4MDk0NzQ5MX0.UKnk_f7ua9hvIG1nBBHcvFwQHH2CejTB2EgXpNTw4Ug"
}

// MARK: - Cloud Toilet Rating Model

struct CloudToiletRating: Codable {
    let toilet_id: String
    let latitude: Double
    let longitude: Double
    var toilet_name: String?
    var upvotes: Int
    var downvotes: Int
    var not_toilet_count: Int
    var is_blacklisted: Bool
    var cumulative_score: Double
    var created_at: String?
    var updated_at: String?
}

// MARK: - Feature Flag Model

struct FeatureFlag: Codable {
    let flag_name: String
    let is_enabled: Bool
    let description: String?
    var updated_at: String?
}

// MARK: - Discovered Toilet Model

struct DiscoveredToilet: Codable {
    let toilet_id: String
    let latitude: Double
    let longitude: Double
    let toilet_name: String
    let address: String?
    let source: String  // "apple_maps", "user_added"
    var discovery_count: Int
    var created_at: String?
    var updated_at: String?
}

// MARK: - Search Request Model (logs user searches)

struct SearchLocationItem: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
}

struct SearchRequest: Codable {
    let user_email: String
    let search_latitude: Double
    let search_longitude: Double
    let locations: [SearchLocationItem]
    let locations_count: Int
    var created_at: String?
}

// MARK: - Supabase Service

class SupabaseService {
    static let shared = SupabaseService()
    
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    
    // Feature flags cache (refreshed on app launch)
    private var featureFlags: [String: Bool] = [:]
    private let featureFlagsKey = "cached_feature_flags"
    
    private init() {
        self.baseURL = URL(string: SupabaseConfig.projectURL)!
        self.apiKey = SupabaseConfig.anonKey
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
        
        // Load cached flags immediately, then refresh from cloud
        loadCachedFeatureFlags()
        refreshFeatureFlags()
    }
    
    // MARK: - Feature Flags
    
    /// Check if a feature is enabled
    func isFeatureEnabled(_ flagName: String, defaultValue: Bool = false) -> Bool {
        return featureFlags[flagName] ?? defaultValue
    }
    
    /// Refresh feature flags from cloud
    func refreshFeatureFlags() {
        let endpoint = "/rest/v1/feature_flags?select=*"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                let flags = try JSONDecoder().decode([FeatureFlag].self, from: data)
                DispatchQueue.main.async {
                    for flag in flags {
                        self?.featureFlags[flag.flag_name] = flag.is_enabled
                    }
                    self?.cacheFeatureFlags()
                }
            } catch {
                // Feature flags decode error handled silently
            }
        }.resume()
    }
    
    private func loadCachedFeatureFlags() {
        if let data = UserDefaults.standard.data(forKey: featureFlagsKey),
           let cached = try? JSONDecoder().decode([String: Bool].self, from: data) {
            featureFlags = cached
        }
    }
    
    private func cacheFeatureFlags() {
        if let data = try? JSONEncoder().encode(featureFlags) {
            UserDefaults.standard.set(data, forKey: featureFlagsKey)
        }
    }
    
    // MARK: - Search Request Logging
    
    /// Save a search request with all raw results (before filtering)
    func saveSearchRequest(
        userEmail: String,
        searchLatitude: Double,
        searchLongitude: Double,
        locations: [SearchLocationItem]
    ) {
        // Check feature flag first (default to TRUE for now to ensure it works)
        let flagEnabled = isFeatureEnabled("save_search_requests", defaultValue: true)
        guard flagEnabled else {
            return
        }
        
        let endpoint = "/rest/v1/search_requests"
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            return
        }
        
        let searchRequest = SearchRequest(
            user_email: userEmail,
            search_latitude: searchLatitude,
            search_longitude: searchLongitude,
            locations: locations,
            locations_count: locations.count,
            created_at: nil
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONEncoder().encode(searchRequest)
        } catch {
            return
        }
        
        session.dataTask(with: request) { _, _, _ in
            // Response handled silently
        }.resume()
    }
    
    // MARK: - Discovered Toilets
    
    /// Save a discovered toilet to cloud (called when search finds a toilet)
    func saveDiscoveredToilet(toiletId: String, latitude: Double, longitude: Double, name: String, address: String?) {
        // Check feature flag first
        guard isFeatureEnabled("save_discovered_toilets", defaultValue: false) else { return }
        
        // Check if toilet already exists
        fetchDiscoveredToilet(toiletId: toiletId) { [weak self] existing in
            if let existing = existing {
                // Increment discovery count
                self?.updateDiscoveredToilet(toiletId: toiletId, discoveryCount: existing.discovery_count + 1)
            } else {
                // Insert new discovered toilet
                self?.insertDiscoveredToilet(
                    toiletId: toiletId,
                    latitude: latitude,
                    longitude: longitude,
                    name: name,
                    address: address
                )
            }
        }
    }
    
    /// Fetch nearby discovered toilets from cloud
    func fetchNearbyDiscoveredToilets(latitude: Double, longitude: Double, completion: @escaping ([DiscoveredToilet]) -> Void) {
        let latMin = (latitude * 100).rounded() / 100 - 0.02
        let latMax = (latitude * 100).rounded() / 100 + 0.02
        let lonMin = (longitude * 100).rounded() / 100 - 0.02
        let lonMax = (longitude * 100).rounded() / 100 + 0.02
        
        let endpoint = "/rest/v1/discovered_toilets?latitude=gte.\(latMin)&latitude=lte.\(latMax)&longitude=gte.\(lonMin)&longitude=lte.\(lonMax)&select=*"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }
            
            do {
                let toilets = try JSONDecoder().decode([DiscoveredToilet].self, from: data)
                completion(toilets)
            } catch {
                completion([])
            }
        }.resume()
    }
    
    private func fetchDiscoveredToilet(toiletId: String, completion: @escaping (DiscoveredToilet?) -> Void) {
        let endpoint = "/rest/v1/discovered_toilets?toilet_id=eq.\(toiletId)&select=*"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                let toilets = try JSONDecoder().decode([DiscoveredToilet].self, from: data)
                completion(toilets.first)
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    private func insertDiscoveredToilet(toiletId: String, latitude: Double, longitude: Double, name: String, address: String?) {
        let endpoint = "/rest/v1/discovered_toilets"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else { return }
        
        let toilet = DiscoveredToilet(
            toilet_id: toiletId,
            latitude: latitude,
            longitude: longitude,
            toilet_name: name,
            address: address,
            source: "apple_maps",
            discovery_count: 1,
            created_at: nil,
            updated_at: nil
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONEncoder().encode(toilet)
        } catch {
            return
        }
        
        session.dataTask(with: request) { _, _, _ in
            // Response handled silently
        }.resume()
    }
    
    private func updateDiscoveredToilet(toiletId: String, discoveryCount: Int) {
        let endpoint = "/rest/v1/discovered_toilets?toilet_id=eq.\(toiletId)"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else { return }
        
        let updateData: [String: Any] = [
            "discovery_count": discoveryCount,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            return
        }
        
        session.dataTask(with: request) { _, _, _ in }.resume()
    }
    
    // MARK: - Public Methods
    
    /// Fetch rating for a specific toilet from cloud
    func fetchRating(toiletId: String, completion: @escaping (CloudToiletRating?) -> Void) {
        let endpoint = "/rest/v1/toilet_ratings?toilet_id=eq.\(toiletId)&select=*"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        session.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                let ratings = try JSONDecoder().decode([CloudToiletRating].self, from: data)
                completion(ratings.first)
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    /// Fetch all blacklisted toilets (for initial sync)
    func fetchBlacklistedToilets(completion: @escaping ([CloudToiletRating]) -> Void) {
        let endpoint = "/rest/v1/toilet_ratings?is_blacklisted=eq.true&select=*"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }
            
            do {
                let ratings = try JSONDecoder().decode([CloudToiletRating].self, from: data)
                completion(ratings)
            } catch {
                completion([])
            }
        }.resume()
    }
    
    /// Fetch nearby toilet ratings (within ~1km based on coordinate rounding)
    func fetchNearbyRatings(latitude: Double, longitude: Double, completion: @escaping ([CloudToiletRating]) -> Void) {
        // Round to 2 decimal places for rough area query (~1km precision)
        let latMin = (latitude * 100).rounded() / 100 - 0.01
        let latMax = (latitude * 100).rounded() / 100 + 0.01
        let lonMin = (longitude * 100).rounded() / 100 - 0.01
        let lonMax = (longitude * 100).rounded() / 100 + 0.01
        
        let endpoint = "/rest/v1/toilet_ratings?latitude=gte.\(latMin)&latitude=lte.\(latMax)&longitude=gte.\(lonMin)&longitude=lte.\(lonMax)&select=*"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }
            
            do {
                let ratings = try JSONDecoder().decode([CloudToiletRating].self, from: data)
                completion(ratings)
            } catch {
                completion([])
            }
        }.resume()
    }

    
    /// Record upvote (sync to cloud)
    func recordUpvote(toiletId: String, latitude: Double, longitude: Double, toiletName: String) {
        // First try to fetch existing rating
        fetchRating(toiletId: toiletId) { [weak self] existing in
            if let existing = existing {
                // Update existing
                self?.updateRating(
                    toiletId: toiletId,
                    upvotes: existing.upvotes + 1,
                    downvotes: existing.downvotes,
                    notToiletCount: existing.not_toilet_count,
                    cumulativeScore: existing.cumulative_score * 0.95 + 10
                )
            } else {
                // Insert new
                self?.insertRating(
                    toiletId: toiletId,
                    latitude: latitude,
                    longitude: longitude,
                    toiletName: toiletName,
                    upvotes: 1,
                    downvotes: 0,
                    notToiletCount: 0,
                    cumulativeScore: 60  // 50 + 10
                )
            }
        }
    }
    
    /// Record downvote (sync to cloud)
    func recordDownvote(toiletId: String, latitude: Double, longitude: Double, toiletName: String, isNotToilet: Bool) {
        fetchRating(toiletId: toiletId) { [weak self] existing in
            if let existing = existing {
                let newNotToiletCount = isNotToilet ? existing.not_toilet_count + 1 : existing.not_toilet_count
                let shouldBlacklist = newNotToiletCount >= 2
                
                self?.updateRating(
                    toiletId: toiletId,
                    upvotes: existing.upvotes,
                    downvotes: existing.downvotes + 1,
                    notToiletCount: newNotToiletCount,
                    cumulativeScore: existing.cumulative_score * 0.95 - 20,
                    isBlacklisted: shouldBlacklist
                )
            } else {
                // First "not toilet" report doesn't blacklist yet (needs 2+ reports)
                self?.insertRating(
                    toiletId: toiletId,
                    latitude: latitude,
                    longitude: longitude,
                    toiletName: toiletName,
                    upvotes: 0,
                    downvotes: 1,
                    notToiletCount: isNotToilet ? 1 : 0,
                    cumulativeScore: 30,  // 50 - 20
                    isBlacklisted: false
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func insertRating(
        toiletId: String,
        latitude: Double,
        longitude: Double,
        toiletName: String,
        upvotes: Int,
        downvotes: Int,
        notToiletCount: Int,
        cumulativeScore: Double,
        isBlacklisted: Bool = false
    ) {
        let endpoint = "/rest/v1/toilet_ratings"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else { return }
        
        let rating = CloudToiletRating(
            toilet_id: toiletId,
            latitude: latitude,
            longitude: longitude,
            toilet_name: toiletName,
            upvotes: upvotes,
            downvotes: downvotes,
            not_toilet_count: notToiletCount,
            is_blacklisted: isBlacklisted,
            cumulative_score: cumulativeScore,
            created_at: nil,
            updated_at: nil
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONEncoder().encode(rating)
        } catch {
            return
        }
        
        session.dataTask(with: request) { _, _, _ in
            // Response handled silently
        }.resume()
    }
    
    private func updateRating(
        toiletId: String,
        upvotes: Int,
        downvotes: Int,
        notToiletCount: Int,
        cumulativeScore: Double,
        isBlacklisted: Bool = false
    ) {
        let endpoint = "/rest/v1/toilet_ratings?toilet_id=eq.\(toiletId)"
        
        guard let url = URL(string: endpoint, relativeTo: baseURL) else { return }
        
        let updateData: [String: Any] = [
            "upvotes": upvotes,
            "downvotes": downvotes,
            "not_toilet_count": notToiletCount,
            "cumulative_score": cumulativeScore,
            "is_blacklisted": isBlacklisted,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue(apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            return
        }
        
        session.dataTask(with: request) { _, _, _ in
            // Response handled silently
        }.resume()
    }
}
