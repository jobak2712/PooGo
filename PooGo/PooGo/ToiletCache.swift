//
//  ToiletCache.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import Foundation
import MapKit
import CoreLocation
import Combine

struct CachedToilet: Codable, Identifiable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let cachedAt: Date
    
    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, address: String? = nil, cachedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.cachedAt = cachedAt
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > 86400 // 24 hours
    }
}

class ToiletCache: ObservableObject {
    static let shared = ToiletCache()
    
    @Published var cachedToilets: [CachedToilet] = []
    @Published var lastKnownLocation: CLLocationCoordinate2D?
    
    private let cacheKey = "cached_toilets"
    private let locationKey = "last_known_location"
    private let maxCacheSize = 50
    
    private init() {
        loadCache()
    }
    
    // MARK: - Cache Management
    
    func cacheToilets(_ mapItems: [MKMapItem], near location: CLLocation) {
        let newToilets = mapItems.compactMap { item -> CachedToilet? in
            guard let loc = item.placemark.location else { return nil }
            return CachedToilet(
                name: item.name ?? "Public Toilet",
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                address: formatAddress(for: item)
            )
        }
        
        // Merge with existing, remove duplicates
        var allToilets = cachedToilets.filter { !$0.isExpired }
        
        for newToilet in newToilets {
            let isDuplicate = allToilets.contains { existing in
                let distance = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                    .distance(from: CLLocation(latitude: newToilet.latitude, longitude: newToilet.longitude))
                return distance < 50 // Within 50 meters = duplicate
            }
            if !isDuplicate {
                allToilets.append(newToilet)
            }
        }
        
        // Keep only most recent
        if allToilets.count > maxCacheSize {
            allToilets = Array(allToilets.suffix(maxCacheSize))
        }
        
        cachedToilets = allToilets
        lastKnownLocation = location.coordinate
        saveCache()
    }
    
    func getNearestCachedToilet(from location: CLLocation) -> CachedToilet? {
        let validToilets = cachedToilets.filter { !$0.isExpired }
        
        return validToilets.min { t1, t2 in
            let d1 = CLLocation(latitude: t1.latitude, longitude: t1.longitude).distance(from: location)
            let d2 = CLLocation(latitude: t2.latitude, longitude: t2.longitude).distance(from: location)
            return d1 < d2
        }
    }
    
    func getCachedToilets(within radius: Double, from location: CLLocation) -> [CachedToilet] {
        cachedToilets.filter { toilet in
            !toilet.isExpired &&
            CLLocation(latitude: toilet.latitude, longitude: toilet.longitude).distance(from: location) <= radius
        }.sorted { t1, t2 in
            let d1 = CLLocation(latitude: t1.latitude, longitude: t1.longitude).distance(from: location)
            let d2 = CLLocation(latitude: t2.latitude, longitude: t2.longitude).distance(from: location)
            return d1 < d2
        }
    }
    
    // MARK: - Persistence
    
    private func saveCache() {
        if let data = try? JSONEncoder().encode(cachedToilets) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
        
        if let loc = lastKnownLocation {
            UserDefaults.standard.set([loc.latitude, loc.longitude], forKey: locationKey)
        }
    }
    
    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let toilets = try? JSONDecoder().decode([CachedToilet].self, from: data) {
            cachedToilets = toilets.filter { !$0.isExpired }
        }
        
        if let coords = UserDefaults.standard.array(forKey: locationKey) as? [Double], coords.count == 2 {
            lastKnownLocation = CLLocationCoordinate2D(latitude: coords[0], longitude: coords[1])
        }
    }
    
    func clearCache() {
        cachedToilets = []
        lastKnownLocation = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: locationKey)
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
}
