//
//  ToiletSearchTests.swift
//  PooGoTests
//
//  Tests for toilet search functionality
//

import XCTest
import MapKit
import CoreLocation
@testable import PooGo

final class ToiletSearchTests: XCTestCase {
    
    // Test location: Central London (near Big Ben) - known to have many toilets
    let testLocation = CLLocation(latitude: 51.5007, longitude: -0.1246)
    
    // Test location: Dartford, UK (from user's screenshot)
    let dartfordLocation = CLLocation(latitude: 51.4462, longitude: 0.2146)
    
    /// Test that MKLocalSearch returns results for "toilet" query
    func testBasicToiletSearch() async throws {
        let expectation = XCTestExpectation(description: "Search completes")
        
        let region = MKCoordinateRegion(
            center: testLocation.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "toilet"
        request.region = region
        
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            if let error = error {
                print("❌ Search error: \(error.localizedDescription)")
                XCTFail("Search failed with error: \(error.localizedDescription)")
            }
            
            let count = response?.mapItems.count ?? 0
            print("✅ Basic toilet search returned \(count) results")
            
            if let items = response?.mapItems {
                for (index, item) in items.prefix(5).enumerated() {
                    print("  \(index + 1). \(item.name ?? "Unknown") - \(item.placemark.location?.coordinate ?? CLLocationCoordinate2D())")
                }
            }
            
            XCTAssertGreaterThan(count, 0, "Should find at least one toilet")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    /// Test POI restroom search
    func testRestroomPOISearch() async throws {
        let expectation = XCTestExpectation(description: "POI search completes")
        
        let region = MKCoordinateRegion(
            center: testLocation.coordinate,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        
        let request = MKLocalSearch.Request()
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restroom])
        request.region = region
        
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            if let error = error {
                print("⚠️ POI search error: \(error.localizedDescription)")
            }
            
            let count = response?.mapItems.count ?? 0
            print("✅ POI restroom search returned \(count) results")
            
            if let items = response?.mapItems {
                for (index, item) in items.prefix(5).enumerated() {
                    print("  \(index + 1). \(item.name ?? "Unknown")")
                }
            }
            
            // POI search might return 0 in some areas, that's OK
            print("POI search completed with \(count) results")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    /// Test multiple queries in parallel (like the app does)
    func testMultipleQueriesSearch() async throws {
        let expectation = XCTestExpectation(description: "Multiple queries complete")
        
        let queries = ["public toilet", "restroom", "WC", "bathroom"]
        let region = MKCoordinateRegion(
            center: testLocation.coordinate,
            latitudinalMeters: 15000,
            longitudinalMeters: 15000
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
            search.start { response, error in
                defer { group.leave() }
                
                if let error = error {
                    print("⚠️ Search error for '\(query)': \(error.localizedDescription)")
                }
                
                let count = response?.mapItems.count ?? 0
                print("  Query '\(query)': \(count) results")
                
                if let items = response?.mapItems {
                    resultsLock.lock()
                    allResults.append(contentsOf: items)
                    resultsLock.unlock()
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Total results from all queries: \(allResults.count)")
            XCTAssertGreaterThan(allResults.count, 0, "Should find toilets with at least one query")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
    }
    
    /// Test search at Dartford location (user's actual location)
    func testDartfordSearch() async throws {
        let expectation = XCTestExpectation(description: "Dartford search completes")
        
        let region = MKCoordinateRegion(
            center: dartfordLocation.coordinate,
            latitudinalMeters: 15000,
            longitudinalMeters: 15000
        )
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "toilet"
        request.region = region
        
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            if let error = error {
                print("❌ Dartford search error: \(error.localizedDescription)")
            }
            
            let count = response?.mapItems.count ?? 0
            print("✅ Dartford toilet search returned \(count) results")
            
            if let items = response?.mapItems {
                for (index, item) in items.prefix(10).enumerated() {
                    let distance = item.placemark.location?.distance(from: self.dartfordLocation) ?? 0
                    print("  \(index + 1). \(item.name ?? "Unknown") - \(Int(distance))m away")
                }
            }
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    /// Test that simulates cold start - run search twice quickly
    func testColdStartBehavior() async throws {
        let expectation1 = XCTestExpectation(description: "First search")
        let expectation2 = XCTestExpectation(description: "Second search")
        
        let region = MKCoordinateRegion(
            center: testLocation.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        
        // First search (cold)
        let request1 = MKLocalSearch.Request()
        request1.naturalLanguageQuery = "public toilet"
        request1.region = region
        
        let search1 = MKLocalSearch(request: request1)
        var firstCount = 0
        
        search1.start { response, error in
            firstCount = response?.mapItems.count ?? 0
            print("🥶 First (cold) search: \(firstCount) results")
            if let error = error {
                print("  Error: \(error.localizedDescription)")
            }
            expectation1.fulfill()
        }
        
        await fulfillment(of: [expectation1], timeout: 10.0)
        
        // Wait 1 second
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Second search (warm)
        let request2 = MKLocalSearch.Request()
        request2.naturalLanguageQuery = "public toilet"
        request2.region = region
        
        let search2 = MKLocalSearch(request: request2)
        
        search2.start { response, error in
            let secondCount = response?.mapItems.count ?? 0
            print("🔥 Second (warm) search: \(secondCount) results")
            
            print("\n📊 Comparison:")
            print("  First search:  \(firstCount) results")
            print("  Second search: \(secondCount) results")
            
            if firstCount == 0 && secondCount > 0 {
                print("  ⚠️ CONFIRMED: Cold start issue - first search returns 0, second returns results!")
            } else if firstCount > 0 && secondCount > 0 {
                print("  ✅ Both searches returned results - no cold start issue")
            }
            
            expectation2.fulfill()
        }
        
        await fulfillment(of: [expectation2], timeout: 10.0)
    }
}
