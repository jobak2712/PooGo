//
//  ToiletReliabilityService.swift
//  PooGo
//
//  Created by Kiro on 09/12/2025.
//

import Combine
import CoreLocation
import Foundation

// MARK: - Feedback Record

struct ToiletFeedbackRecord: Codable, Identifiable {
    let id: UUID
    let toiletId: String  // Unique identifier based on coordinates
    let latitude: Double
    let longitude: Double
    let toiletName: String
    let isPositive: Bool
    let reason: String?  // For negative feedback
    let timestamp: Date
    
    init(
        toiletId: String,
        latitude: Double,
        longitude: Double,
        toiletName: String,
        isPositive: Bool,
        reason: String? = nil
    ) {
        self.id = UUID()
        self.toiletId = toiletId
        self.latitude = latitude
        self.longitude = longitude
        self.toiletName = toiletName
        self.isPositive = isPositive
        self.reason = reason
        self.timestamp = Date()
    }
}

// MARK: - Reliability Score

struct ToiletReliabilityScore: Codable {
    let toiletId: String
    let latitude: Double
    let longitude: Double
    var toiletName: String
    var totalPositive: Int
    var totalNegative: Int
    var recentPositive: Int  // Last 7 days
    var recentNegative: Int  // Last 7 days
    var lastUpdated: Date
    var isUncertain: Bool  // Marked when downvote spike detected
    var cumulativeScore: Double  // Running score using decay formula
    
    /// Reliability score - cumulative score with decay
    /// Formula: newScore = oldScore × 0.95 + (upvotes × +10) + (downvotes × -20)
    /// Starts at 50 (neutral), can go negative or above 100
    var score: Double {
        return cumulativeScore
    }
    
    /// Normalized score from 0.0 to 1.0 for compatibility
    var normalizedScore: Double {
        // Map cumulative score to 0-1 range
        // Score of 0 = 0.5, Score of 100 = 1.0, Score of -100 = 0.0
        let normalized = (cumulativeScore + 100) / 200
        return max(0, min(1, normalized))
    }
    
    /// Human-readable reliability status
    var status: ReliabilityStatus {
        if isUncertain { return .uncertain }
        if cumulativeScore >= 70 { return .reliable }
        if cumulativeScore >= 30 { return .mixed }
        return .unreliable
    }
}

enum ReliabilityStatus: String {
    case reliable = "Reliable"
    case mixed = "Mixed Reviews"
    case unreliable = "Unreliable"
    case uncertain = "Uncertain"
    
    var emoji: String {
        switch self {
        case .reliable: return "✅"
        case .mixed: return "⚠️"
        case .unreliable: return "❌"
        case .uncertain: return "❓"
        }
    }
}


// MARK: - Reliability Service

class ToiletReliabilityService: ObservableObject {
    static let shared = ToiletReliabilityService()
    
    @Published var scores: [String: ToiletReliabilityScore] = [:]
    
    private let feedbackKey = "toilet_feedback_records"
    private let scoresKey = "toilet_reliability_scores"
    private let blacklistKey = "toilet_blacklist"
    private let notToiletCountsKey = "not_toilet_counts"
    private let recentDays: TimeInterval = 7 * 24 * 60 * 60  // 7 days
    private let downvoteSpikeThreshold = 3  // 3+ downvotes in recent period = uncertain
    private let blacklistThreshold = 2  // 2+ "Not a toilet" reports = permanent blacklist
    
    // Blacklisted toilet IDs (permanently hidden)
    private var blacklist: Set<String> = []
    // Count of "Not a toilet" reports per location
    private var notToiletCounts: [String: Int] = [:]
    
    private init() {
        loadScores()
        loadBlacklist()
        cleanupOldFeedback()
        syncFromCloud()  // Fetch global blacklist on startup
    }
    
    // MARK: - Cloud Sync
    
    /// Sync blacklisted toilets from cloud on app startup
    private func syncFromCloud() {
        SupabaseService.shared.fetchBlacklistedToilets { [weak self] cloudRatings in
            DispatchQueue.main.async {
                for rating in cloudRatings {
                    self?.blacklist.insert(rating.toilet_id)
                    self?.notToiletCounts[rating.toilet_id] = rating.not_toilet_count
                }
                self?.saveBlacklist()
                if !cloudRatings.isEmpty {
                    print("☁️ Synced \(cloudRatings.count) blacklisted toilets from cloud")
                }
            }
        }
    }
    
    /// Sync nearby ratings from cloud (call when searching)
    func syncNearbyRatings(latitude: Double, longitude: Double) {
        SupabaseService.shared.fetchNearbyRatings(latitude: latitude, longitude: longitude) { [weak self] cloudRatings in
            DispatchQueue.main.async {
                for rating in cloudRatings {
                    // Update local blacklist
                    if rating.is_blacklisted {
                        self?.blacklist.insert(rating.toilet_id)
                    }
                    
                    // Update local scores if cloud has more data
                    if let localScore = self?.scores[rating.toilet_id] {
                        let cloudTotal = rating.upvotes + rating.downvotes
                        let localTotal = localScore.totalPositive + localScore.totalNegative
                        
                        // Use cloud data if it has more feedback
                        if cloudTotal > localTotal {
                            self?.scores[rating.toilet_id] = ToiletReliabilityScore(
                                toiletId: rating.toilet_id,
                                latitude: rating.latitude,
                                longitude: rating.longitude,
                                toiletName: rating.toilet_name ?? "Unknown",
                                totalPositive: rating.upvotes,
                                totalNegative: rating.downvotes,
                                recentPositive: 0,
                                recentNegative: 0,
                                lastUpdated: Date(),
                                isUncertain: false,
                                cumulativeScore: rating.cumulative_score
                            )
                        }
                    } else {
                        // No local data - use cloud data
                        self?.scores[rating.toilet_id] = ToiletReliabilityScore(
                            toiletId: rating.toilet_id,
                            latitude: rating.latitude,
                            longitude: rating.longitude,
                            toiletName: rating.toilet_name ?? "Unknown",
                            totalPositive: rating.upvotes,
                            totalNegative: rating.downvotes,
                            recentPositive: 0,
                            recentNegative: 0,
                            lastUpdated: Date(),
                            isUncertain: false,
                            cumulativeScore: rating.cumulative_score
                        )
                    }
                }
                self?.saveScores()
                self?.saveBlacklist()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Generate a unique toilet ID based on coordinates (rounded to ~10m precision)
    func toiletId(latitude: Double, longitude: Double) -> String {
        let latRounded = (latitude * 10000).rounded() / 10000
        let lonRounded = (longitude * 10000).rounded() / 10000
        return "\(latRounded),\(lonRounded)"
    }
    
    /// Record positive feedback (thumbs up)
    func recordPositiveFeedback(
        latitude: Double,
        longitude: Double,
        toiletName: String
    ) {
        let id = toiletId(latitude: latitude, longitude: longitude)
        let record = ToiletFeedbackRecord(
            toiletId: id,
            latitude: latitude,
            longitude: longitude,
            toiletName: toiletName,
            isPositive: true
        )
        
        saveFeedbackRecord(record)
        updateScore(for: id, latitude: latitude, longitude: longitude, toiletName: toiletName, isPositive: true)
        
        // Sync to cloud (helps all users)
        SupabaseService.shared.recordUpvote(toiletId: id, latitude: latitude, longitude: longitude, toiletName: toiletName)
    }
    
    /// Record negative feedback (thumbs down)
    func recordNegativeFeedback(
        latitude: Double,
        longitude: Double,
        toiletName: String,
        reason: String
    ) {
        let id = toiletId(latitude: latitude, longitude: longitude)
        let record = ToiletFeedbackRecord(
            toiletId: id,
            latitude: latitude,
            longitude: longitude,
            toiletName: toiletName,
            isPositive: false,
            reason: reason
        )
        
        saveFeedbackRecord(record)
        updateScore(for: id, latitude: latitude, longitude: longitude, toiletName: toiletName, isPositive: false)
        
        // Check for "Not a Toilet" - track and potentially blacklist
        let isNotToilet = reason == "Not a Toilet"
        if isNotToilet {
            trackNotToiletReport(for: id)
        }
        
        // Sync to cloud (helps all users)
        SupabaseService.shared.recordDownvote(toiletId: id, latitude: latitude, longitude: longitude, toiletName: toiletName, isNotToilet: isNotToilet)
    }
    
    /// Check if a location is permanently blacklisted
    func isBlacklisted(latitude: Double, longitude: Double) -> Bool {
        let id = toiletId(latitude: latitude, longitude: longitude)
        return blacklist.contains(id)
    }
    
    /// Get reliability score for a toilet
    func getScore(latitude: Double, longitude: Double) -> ToiletReliabilityScore? {
        let id = toiletId(latitude: latitude, longitude: longitude)
        return scores[id]
    }
    
    /// Get reliability adjustment for sorting (higher = better)
    /// Returns a value to adjust distance-based sorting in meters
    func getReliabilityAdjustment(latitude: Double, longitude: Double) -> Double {
        guard let score = getScore(latitude: latitude, longitude: longitude) else {
            return 0  // No feedback = neutral
        }
        
        // Uncertain toilets get penalized heavily
        if score.isUncertain {
            return -50
        }
        
        // Use cumulative score directly as distance adjustment
        // Score of 50 (neutral) = 0 adjustment
        // Score of 100+ = +50m adjustment (prioritize)
        // Score of 0 or below = -50m adjustment (deprioritize)
        let adjustment = (score.cumulativeScore - 50) / 2
        return max(-50, min(50, adjustment))
    }
    
    /// Check if a toilet should be hidden due to very poor reliability or blacklist
    func shouldHideToilet(latitude: Double, longitude: Double) -> Bool {
        let id = toiletId(latitude: latitude, longitude: longitude)
        
        // Always hide blacklisted toilets (confirmed "Not a Toilet")
        if blacklist.contains(id) {
            return true
        }
        
        guard let score = getScore(latitude: latitude, longitude: longitude) else {
            return false
        }
        
        // Hide if cumulative score is very negative AND has enough feedback
        let totalFeedback = score.totalPositive + score.totalNegative
        return score.cumulativeScore < -20 && totalFeedback >= 5
    }
    
    // MARK: - Private Methods
    
    private func updateScore(
        for toiletId: String,
        latitude: Double,
        longitude: Double,
        toiletName: String,
        isPositive: Bool
    ) {
        var score = scores[toiletId] ?? ToiletReliabilityScore(
            toiletId: toiletId,
            latitude: latitude,
            longitude: longitude,
            toiletName: toiletName,
            totalPositive: 0,
            totalNegative: 0,
            recentPositive: 0,
            recentNegative: 0,
            lastUpdated: Date(),
            isUncertain: false,
            cumulativeScore: 50  // Start neutral
        )
        
        // Update totals
        if isPositive {
            score.totalPositive += 1
            score.recentPositive += 1
        } else {
            score.totalNegative += 1
            score.recentNegative += 1
        }
        
        // Apply new scoring formula: newScore = oldScore × 0.95 + (upvotes × +10) + (downvotes × -20)
        let decayedScore = score.cumulativeScore * 0.95
        let feedbackDelta = isPositive ? 10.0 : -20.0
        score.cumulativeScore = decayedScore + feedbackDelta
        
        score.toiletName = toiletName
        score.lastUpdated = Date()
        
        // Check for downvote spike
        if score.recentNegative >= downvoteSpikeThreshold {
            score.isUncertain = true
        }
        
        // Clear uncertain flag if recent feedback improves
        if score.recentPositive > score.recentNegative * 2 {
            score.isUncertain = false
        }
        
        scores[toiletId] = score
        saveScores()
    }
    
    private func saveFeedbackRecord(_ record: ToiletFeedbackRecord) {
        var records = loadFeedbackRecords()
        records.append(record)
        
        // Keep only last 1000 records
        if records.count > 1000 {
            records = Array(records.suffix(1000))
        }
        
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: feedbackKey)
        }
    }
    
    private func loadFeedbackRecords() -> [ToiletFeedbackRecord] {
        guard let data = UserDefaults.standard.data(forKey: feedbackKey),
              let records = try? JSONDecoder().decode([ToiletFeedbackRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    private func saveScores() {
        if let data = try? JSONEncoder().encode(scores) {
            UserDefaults.standard.set(data, forKey: scoresKey)
        }
    }
    
    private func loadScores() {
        guard let data = UserDefaults.standard.data(forKey: scoresKey),
              let loadedScores = try? JSONDecoder().decode([String: ToiletReliabilityScore].self, from: data) else {
            return
        }
        scores = loadedScores
        recalculateRecentCounts()
    }
    
    /// Recalculate recent counts based on actual feedback records
    private func recalculateRecentCounts() {
        let records = loadFeedbackRecords()
        let cutoffDate = Date().addingTimeInterval(-recentDays)
        
        // Reset recent counts
        for key in scores.keys {
            scores[key]?.recentPositive = 0
            scores[key]?.recentNegative = 0
        }
        
        // Count recent feedback
        for record in records where record.timestamp > cutoffDate {
            if var score = scores[record.toiletId] {
                if record.isPositive {
                    score.recentPositive += 1
                } else {
                    score.recentNegative += 1
                }
                scores[record.toiletId] = score
            }
        }
        
        // Update uncertain flags
        for key in scores.keys {
            if let score = scores[key] {
                var updatedScore = score
                updatedScore.isUncertain = score.recentNegative >= downvoteSpikeThreshold
                if score.recentPositive > score.recentNegative * 2 {
                    updatedScore.isUncertain = false
                }
                scores[key] = updatedScore
            }
        }
        
        saveScores()
    }
    
    /// Remove feedback older than 90 days
    private func cleanupOldFeedback() {
        let cutoffDate = Date().addingTimeInterval(-90 * 24 * 60 * 60)
        var records = loadFeedbackRecords()
        records = records.filter { $0.timestamp > cutoffDate }
        
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: feedbackKey)
        }
    }
    
    // MARK: - Blacklist Management
    
    /// Track "Not a Toilet" report and blacklist if threshold reached
    private func trackNotToiletReport(for toiletId: String) {
        let currentCount = notToiletCounts[toiletId] ?? 0
        let newCount = currentCount + 1
        notToiletCounts[toiletId] = newCount
        
        // Blacklist if threshold reached
        if newCount >= blacklistThreshold {
            blacklist.insert(toiletId)
            print("🚫 Blacklisted toilet: \(toiletId) after \(newCount) 'Not a Toilet' reports")
        }
        
        saveBlacklist()
    }
    
    private func loadBlacklist() {
        // Load blacklist
        if let data = UserDefaults.standard.data(forKey: blacklistKey),
           let loaded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            blacklist = loaded
        }
        
        // Load "Not a toilet" counts
        if let data = UserDefaults.standard.data(forKey: notToiletCountsKey),
           let loaded = try? JSONDecoder().decode([String: Int].self, from: data) {
            notToiletCounts = loaded
        }
    }
    
    private func saveBlacklist() {
        if let data = try? JSONEncoder().encode(blacklist) {
            UserDefaults.standard.set(data, forKey: blacklistKey)
        }
        if let data = try? JSONEncoder().encode(notToiletCounts) {
            UserDefaults.standard.set(data, forKey: notToiletCountsKey)
        }
    }
}
