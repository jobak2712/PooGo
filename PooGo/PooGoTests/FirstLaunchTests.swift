//
//  FirstLaunchTests.swift
//  PooGoTests
//
//  Tests that simulate first launch behavior
//

import XCTest
import MapKit
import CoreLocation
@testable import PooGo

final class FirstLaunchTests: XCTestCase {
    
    /// Test the full search flow with a simulated location
    func testSearchWithSimulatedLocation() async throws {
        let expectation = XCTestExpectation(description: "Search completes")
        
        // Simulate Dartford, UK location
        let testLocation = CLLocation(latitude: 51.4462, longitude: 0.2146)
        
        print("🧪 Testing search from Dartford, UK")
        print("📍 Location: \(testLocation.coordinate.latitude), \(testLocation.coordinate.longitude)")
        
        // Test the search queries directly
        let queries = ["public toilet", "restroom", "WC", "bathroom", "toilet"]
        let region = MKCoordinateRegion(
            center: testLocation.coordinate,
            latitudinalMeters: 15000,
            longitudinalMeters: 15000
        )
        
        var totalResults = 0
        let group = DispatchGroup()
        
        for query in queries {
            group.enter()
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                defer { group.leave() }
                
                let count = response?.mapItems.count ?? 0
                print("  Query '\(query)': \(count) results")
                
                if let error = error {
                    print("    Error: \(error.localizedDescription)")
                }
                
                totalResults += count
            }
        }
        
        group.notify(queue: .main) {
            print("\n📊 Total results: \(totalResults)")
            
            if totalResults > 0 {
                print("✅ Search would succeed on first launch!")
            } else {
                print("❌ Search would fail - no results found")
            }
            
            XCTAssertGreaterThan(totalResults, 0, "Should find toilets near Dartford")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
    
    /// Test POI restroom search specifically
    func testPOIRestroomSearch() async throws {
        let expectation = XCTestExpectation(description: "POI search completes")
        
        let testLocation = CLLocation(latitude: 51.4462, longitude: 0.2146)
        
        print("🚽 Testing POI restroom search from Dartford")
        
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
            let count = response?.mapItems.count ?? 0
            print("  POI restroom results: \(count)")
            
            if let items = response?.mapItems {
                for (i, item) in items.prefix(5).enumerated() {
                    let dist = item.placemark.location?.distance(from: testLocation) ?? 0
                    print("    \(i+1). \(item.name ?? "Unknown") - \(Int(dist))m")
                }
            }
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    /// Test that simulates rapid consecutive searches (like first launch then retry)
    func testRapidConsecutiveSearches() async throws {
        let expectation = XCTestExpectation(description: "Both searches complete")
        
        let testLocation = CLLocation(latitude: 51.4462, longitude: 0.2146)
        let region = MKCoordinateRegion(
            center: testLocation.coordinate,
            latitudinalMeters: 15000,
            longitudinalMeters: 15000
        )
        
        print("🔄 Testing rapid consecutive searches...")
        
        // First search (simulating cold start)
        let request1 = MKLocalSearch.Request()
        request1.naturalLanguageQuery = "toilet"
        request1.region = region
        
        var firstCount = 0
        var secondCount = 0
        
        let search1 = MKLocalSearch(request: request1)
        search1.start { response, error in
            firstCount = response?.mapItems.count ?? 0
            print("  First search: \(firstCount) results")
            
            // Immediately start second search
            let request2 = MKLocalSearch.Request()
            request2.naturalLanguageQuery = "toilet"
            request2.region = region
            
            let search2 = MKLocalSearch(request: request2)
            search2.start { response2, error2 in
                secondCount = response2?.mapItems.count ?? 0
                print("  Second search: \(secondCount) results")
                
                print("\n📊 Comparison:")
                print("  First:  \(firstCount)")
                print("  Second: \(secondCount)")
                
                if firstCount == 0 && secondCount > 0 {
                    print("  ⚠️ COLD START ISSUE DETECTED!")
                } else if firstCount > 0 {
                    print("  ✅ First search succeeded")
                }
                
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 20.0)
    }
}
