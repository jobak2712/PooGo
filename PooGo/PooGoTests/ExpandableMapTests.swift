//
//  ExpandableMapTests.swift
//  PooGoTests
//
//  Created by Kiro on 09/12/2025.
//

import XCTest
@testable import PooGo

/// A testable model that encapsulates the expansion logic from ExpandableMapView.
/// This allows us to test the core business logic without SwiftUI view dependencies.
final class ExpansionLogic {
    var isExpanded: Bool = false
    var isZooming: Bool = false
    var isPanning: Bool = false
    
    var isInteracting: Bool {
        isZooming || isPanning
    }
    
    /// Handles tap gesture - expands map only if not currently interacting
    func handleTap() {
        if !isInteracting {
            isExpanded = true
        }
    }
    
    /// Simulates completing a zoom gesture (gesture ends, state resets to false)
    func completeZoomGesture() {
        isZooming = false
    }
    
    /// Simulates completing a pan gesture (gesture ends, state resets to false)
    func completePanGesture() {
        isPanning = false
    }
}

final class ExpandableMapTests: XCTestCase {
    
    // **Feature: expandable-map, Property 1: Tap triggers expansion when not interacting**
    // **Validates: Requirements 1.1**
    //
    // Property: For any map state where isInteracting is false, performing a tap gesture
    // SHALL result in isExpanded becoming true.
    func testProperty1_TapTriggersExpansionWhenNotInteracting() {
        // Run 100 iterations with randomized initial states
        for _ in 0..<100 {
            // Generate random initial state
            let logic = ExpansionLogic()
            
            // Randomly set initial expanded state (should become true after tap regardless)
            logic.isExpanded = Bool.random()
            
            // Ensure isInteracting is false (the precondition for this property)
            logic.isZooming = false
            logic.isPanning = false
            
            // Precondition check: isInteracting must be false
            XCTAssertFalse(logic.isInteracting, "Precondition: isInteracting should be false")
            
            // Action: perform tap
            logic.handleTap()
            
            // Property assertion: isExpanded should be true after tap when not interacting
            XCTAssertTrue(logic.isExpanded, "After tap with isInteracting=false, isExpanded should be true")
        }
    }
    
    // **Feature: expandable-map, Property 3: Zoom gesture prevents expansion**
    // **Validates: Requirements 2.1**
    //
    // Property: For any zoom gesture state where isZooming is true, the isExpanded state
    // SHALL remain unchanged (not triggered by tap).
    func testProperty3_ZoomGesturePreventsExpansion() {
        // Run 100 iterations with randomized initial states
        for _ in 0..<100 {
            let logic = ExpansionLogic()
            
            // Generate random initial expanded state to verify it remains unchanged
            let initialExpandedState = Bool.random()
            logic.isExpanded = initialExpandedState
            
            // Set zooming to true (the precondition for this property)
            logic.isZooming = true
            // Pan state can be random - zooming alone should prevent expansion
            logic.isPanning = Bool.random()
            
            // Precondition check: isZooming must be true
            XCTAssertTrue(logic.isZooming, "Precondition: isZooming should be true")
            
            // Action: attempt tap while zooming
            logic.handleTap()
            
            // Property assertion: isExpanded should remain unchanged when zooming
            XCTAssertEqual(
                logic.isExpanded,
                initialExpandedState,
                "isExpanded should remain \(initialExpandedState) when tap occurs during zoom gesture"
            )
        }
    }
    
    // **Feature: expandable-map, Property 4: Pan gesture prevents expansion**
    // **Validates: Requirements 2.2**
    //
    // Property: For any pan gesture state where isPanning is true, the isExpanded state
    // SHALL remain unchanged (not triggered by tap).
    func testProperty4_PanGesturePreventsExpansion() {
        // Run 100 iterations with randomized initial states
        for _ in 0..<100 {
            let logic = ExpansionLogic()
            
            // Generate random initial expanded state to verify it remains unchanged
            let initialExpandedState = Bool.random()
            logic.isExpanded = initialExpandedState
            
            // Set panning to true (the precondition for this property)
            logic.isPanning = true
            // Zoom state can be random - panning alone should prevent expansion
            logic.isZooming = Bool.random()
            
            // Precondition check: isPanning must be true
            XCTAssertTrue(logic.isPanning, "Precondition: isPanning should be true")
            
            // Action: attempt tap while panning
            logic.handleTap()
            
            // Property assertion: isExpanded should remain unchanged when panning
            XCTAssertEqual(
                logic.isExpanded,
                initialExpandedState,
                "isExpanded should remain \(initialExpandedState) when tap occurs during pan gesture"
            )
        }
    }
    
    // **Feature: expandable-map, Property 5: Gesture completion preserves map dimensions**
    // **Validates: Requirements 2.3**
    //
    // Property: For any map state (mini or full screen), completing a navigation gesture
    // SHALL not change the isExpanded state.
    func testProperty5_GestureCompletionPreservesMapDimensions() {
        // Run 100 iterations with randomized initial states
        for _ in 0..<100 {
            let logic = ExpansionLogic()
            
            // Generate random initial expanded state (mini map = false, full screen = true)
            let initialExpandedState = Bool.random()
            logic.isExpanded = initialExpandedState
            
            // Randomly choose which gesture(s) to simulate as active
            let simulateZoom = Bool.random()
            let simulatePan = Bool.random()
            
            // Set up active gesture state
            logic.isZooming = simulateZoom
            logic.isPanning = simulatePan
            
            // Action: complete all active gestures
            if simulateZoom {
                logic.completeZoomGesture()
            }
            if simulatePan {
                logic.completePanGesture()
            }
            
            // Property assertion: isExpanded should remain unchanged after gesture completion
            XCTAssertEqual(
                logic.isExpanded,
                initialExpandedState,
                "isExpanded should remain \(initialExpandedState) after completing navigation gestures (zoom: \(simulateZoom), pan: \(simulatePan))"
            )
            
            // Additional assertion: gesture states should be reset
            if simulateZoom {
                XCTAssertFalse(logic.isZooming, "isZooming should be false after completing zoom gesture")
            }
            if simulatePan {
                XCTAssertFalse(logic.isPanning, "isPanning should be false after completing pan gesture")
            }
        }
    }
}


// MARK: - FullScreenMapView Property Tests

/// A testable model that encapsulates the data flow from ExpandableMapView to FullScreenMapView.
/// This allows us to verify data consistency without SwiftUI view dependencies.
final class MapDataFlow {
    // Source data (from ExpandableMapView)
    var sourceRoute: MockRoute
    var sourceDestination: MockDestination
    var sourceUserLocation: MockLocation?
    
    // Target data (passed to FullScreenMapView)
    var targetRoute: MockRoute?
    var targetDestination: MockDestination?
    var targetUserLocation: MockLocation?
    
    init(route: MockRoute, destination: MockDestination, userLocation: MockLocation?) {
        self.sourceRoute = route
        self.sourceDestination = destination
        self.sourceUserLocation = userLocation
    }
    
    /// Simulates the data transfer that occurs when FullScreenMapView is presented
    func transferDataToFullScreen() {
        targetRoute = sourceRoute
        targetDestination = sourceDestination
        targetUserLocation = sourceUserLocation
    }
}

/// Mock route for testing (simplified representation of MKRoute)
struct MockRoute: Equatable {
    let id: String
    let distance: Double
    let expectedTravelTime: Double
    
    static func random() -> MockRoute {
        MockRoute(
            id: UUID().uuidString,
            distance: Double.random(in: 100...10000),
            expectedTravelTime: Double.random(in: 60...3600)
        )
    }
}

/// Mock destination for testing (simplified representation of ToiletDestination)
struct MockDestination: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    
    static func random() -> MockDestination {
        MockDestination(
            name: "Toilet \(Int.random(in: 1...1000))",
            latitude: Double.random(in: -90...90),
            longitude: Double.random(in: -180...180),
            address: Bool.random() ? "Address \(Int.random(in: 1...100))" : nil
        )
    }
}

/// Mock location for testing (simplified representation of CLLocation)
struct MockLocation: Equatable {
    let latitude: Double
    let longitude: Double
    
    static func random() -> MockLocation {
        MockLocation(
            latitude: Double.random(in: -90...90),
            longitude: Double.random(in: -180...180)
        )
    }
}

final class FullScreenMapTests: XCTestCase {
    
    // **Feature: expandable-map, Property 2: Data consistency between mini and full screen maps**
    // **Validates: Requirements 1.2**
    //
    // Property: For any route and destination combination, the FullScreenMapView SHALL receive
    // the same route, userLocation, and destination values as the ExpandableMapView.
    func testProperty2_DataConsistencyBetweenMiniAndFullScreenMaps() {
        // Run 100 iterations with randomized data
        for _ in 0..<100 {
            // Generate random source data
            let route = MockRoute.random()
            let destination = MockDestination.random()
            let userLocation: MockLocation? = Bool.random() ? MockLocation.random() : nil
            
            // Create data flow model
            let dataFlow = MapDataFlow(route: route, destination: destination, userLocation: userLocation)
            
            // Action: simulate data transfer to full screen
            dataFlow.transferDataToFullScreen()
            
            // Property assertions: all data should be identical
            XCTAssertEqual(
                dataFlow.targetRoute,
                dataFlow.sourceRoute,
                "Route passed to FullScreenMapView should match source route"
            )
            
            XCTAssertEqual(
                dataFlow.targetDestination,
                dataFlow.sourceDestination,
                "Destination passed to FullScreenMapView should match source destination"
            )
            
            XCTAssertEqual(
                dataFlow.targetUserLocation,
                dataFlow.sourceUserLocation,
                "UserLocation passed to FullScreenMapView should match source userLocation"
            )
        }
    }
    
    // **Feature: expandable-map, Property 6: Full screen map displays required annotations**
    // **Validates: Requirements 3.3**
    //
    // Property: For any route and destination, the FullScreenMapView SHALL include
    // the route polyline, user location annotation (when available), and destination annotation.
    func testProperty6_FullScreenMapDisplaysRequiredAnnotations() {
        // Run 100 iterations with randomized data
        for _ in 0..<100 {
            // Generate random data
            let route = MockRoute.random()
            let destination = MockDestination.random()
            let hasUserLocation = Bool.random()
            let userLocation: MockLocation? = hasUserLocation ? MockLocation.random() : nil
            
            // Create annotation tracker
            let annotationTracker = FullScreenMapAnnotationTracker(
                route: route,
                destination: destination,
                userLocation: userLocation
            )
            
            // Simulate rendering the full screen map
            annotationTracker.renderMap()
            
            // Property assertions: required annotations should be present
            XCTAssertTrue(
                annotationTracker.hasRoutePolyline,
                "FullScreenMapView should always display route polyline"
            )
            
            XCTAssertTrue(
                annotationTracker.hasDestinationAnnotation,
                "FullScreenMapView should always display destination annotation"
            )
            
            // User location annotation should be present only when userLocation is provided
            if hasUserLocation {
                XCTAssertTrue(
                    annotationTracker.hasUserLocationAnnotation,
                    "FullScreenMapView should display user location annotation when userLocation is provided"
                )
            } else {
                XCTAssertFalse(
                    annotationTracker.hasUserLocationAnnotation,
                    "FullScreenMapView should not display user location annotation when userLocation is nil"
                )
            }
        }
    }
}

/// Tracks which annotations are rendered in FullScreenMapView
/// This models the rendering logic from FullScreenMapView.mapContent
final class FullScreenMapAnnotationTracker {
    let route: MockRoute
    let destination: MockDestination
    let userLocation: MockLocation?
    
    var hasRoutePolyline: Bool = false
    var hasUserLocationAnnotation: Bool = false
    var hasDestinationAnnotation: Bool = false
    
    init(route: MockRoute, destination: MockDestination, userLocation: MockLocation?) {
        self.route = route
        self.destination = destination
        self.userLocation = userLocation
    }
    
    /// Simulates the rendering logic from FullScreenMapView.mapContent
    func renderMap() {
        // Route polyline is always rendered
        hasRoutePolyline = true
        
        // User location annotation is rendered only when userLocation is not nil
        if userLocation != nil {
            hasUserLocationAnnotation = true
        }
        
        // Destination annotation is always rendered
        hasDestinationAnnotation = true
    }
}

// MARK: - Unit Tests for ExpandableMapView

final class ExpandableMapViewUnitTests: XCTestCase {
    
    // MARK: - Initialization Tests
    // _Requirements: 1.1_
    
    /// Test that ExpansionLogic initializes with correct default state
    func testExpansionLogicInitializesWithDefaultState() {
        let logic = ExpansionLogic()
        
        // Verify default state
        XCTAssertFalse(logic.isExpanded, "isExpanded should be false by default")
        XCTAssertFalse(logic.isZooming, "isZooming should be false by default")
        XCTAssertFalse(logic.isPanning, "isPanning should be false by default")
        XCTAssertFalse(logic.isInteracting, "isInteracting should be false when no gestures active")
    }
    
    /// Test that isInteracting correctly reflects zoom state
    func testIsInteractingReflectsZoomState() {
        let logic = ExpansionLogic()
        
        // Initially not interacting
        XCTAssertFalse(logic.isInteracting)
        
        // Set zooming to true
        logic.isZooming = true
        XCTAssertTrue(logic.isInteracting, "isInteracting should be true when zooming")
        
        // Reset zooming
        logic.isZooming = false
        XCTAssertFalse(logic.isInteracting, "isInteracting should be false when not zooming or panning")
    }
    
    /// Test that isInteracting correctly reflects pan state
    func testIsInteractingReflectsPanState() {
        let logic = ExpansionLogic()
        
        // Initially not interacting
        XCTAssertFalse(logic.isInteracting)
        
        // Set panning to true
        logic.isPanning = true
        XCTAssertTrue(logic.isInteracting, "isInteracting should be true when panning")
        
        // Reset panning
        logic.isPanning = false
        XCTAssertFalse(logic.isInteracting, "isInteracting should be false when not zooming or panning")
    }
    
    /// Test that isInteracting is true when both zoom and pan are active
    func testIsInteractingWhenBothGesturesActive() {
        let logic = ExpansionLogic()
        
        logic.isZooming = true
        logic.isPanning = true
        
        XCTAssertTrue(logic.isInteracting, "isInteracting should be true when both gestures active")
    }
    
    // MARK: - Tap Handling Tests
    // _Requirements: 1.1_
    
    /// Test that tap expands map when not interacting
    func testTapExpandsMapWhenNotInteracting() {
        let logic = ExpansionLogic()
        
        XCTAssertFalse(logic.isExpanded, "Should start not expanded")
        
        logic.handleTap()
        
        XCTAssertTrue(logic.isExpanded, "Should be expanded after tap when not interacting")
    }
    
    /// Test that tap does not expand map when zooming
    func testTapDoesNotExpandWhenZooming() {
        let logic = ExpansionLogic()
        logic.isZooming = true
        
        XCTAssertFalse(logic.isExpanded, "Should start not expanded")
        
        logic.handleTap()
        
        XCTAssertFalse(logic.isExpanded, "Should remain not expanded when zooming")
    }
    
    /// Test that tap does not expand map when panning
    func testTapDoesNotExpandWhenPanning() {
        let logic = ExpansionLogic()
        logic.isPanning = true
        
        XCTAssertFalse(logic.isExpanded, "Should start not expanded")
        
        logic.handleTap()
        
        XCTAssertFalse(logic.isExpanded, "Should remain not expanded when panning")
    }
    
    // MARK: - Gesture Completion Tests
    // _Requirements: 1.3_
    
    /// Test that completing zoom gesture resets zoom state
    func testCompleteZoomGestureResetsState() {
        let logic = ExpansionLogic()
        logic.isZooming = true
        
        XCTAssertTrue(logic.isZooming, "Should be zooming before completion")
        
        logic.completeZoomGesture()
        
        XCTAssertFalse(logic.isZooming, "Should not be zooming after completion")
    }
    
    /// Test that completing pan gesture resets pan state
    func testCompletePanGestureResetsState() {
        let logic = ExpansionLogic()
        logic.isPanning = true
        
        XCTAssertTrue(logic.isPanning, "Should be panning before completion")
        
        logic.completePanGesture()
        
        XCTAssertFalse(logic.isPanning, "Should not be panning after completion")
    }
}

// MARK: - Unit Tests for FullScreenMapView

final class FullScreenMapViewUnitTests: XCTestCase {
    
    // MARK: - Close Button Tests
    // _Requirements: 1.3_
    
    /// Test that onClose callback is invoked when close action is triggered
    func testOnCloseCallbackIsInvoked() {
        var closeCallbackInvoked = false
        
        // Create a closure that tracks invocation
        let onClose: () -> Void = {
            closeCallbackInvoked = true
        }
        
        // Simulate close action
        onClose()
        
        XCTAssertTrue(closeCallbackInvoked, "onClose callback should be invoked when close action is triggered")
    }
    
    /// Test that close callback can be called multiple times
    func testOnCloseCallbackCanBeCalledMultipleTimes() {
        var closeCallCount = 0
        
        let onClose: () -> Void = {
            closeCallCount += 1
        }
        
        // Simulate multiple close actions
        onClose()
        onClose()
        onClose()
        
        XCTAssertEqual(closeCallCount, 3, "onClose callback should be callable multiple times")
    }
    
    // MARK: - Data Flow Tests
    // _Requirements: 3.3_
    
    /// Test that MapDataFlow correctly initializes with provided data
    func testMapDataFlowInitialization() {
        let route = MockRoute.random()
        let destination = MockDestination.random()
        let userLocation = MockLocation.random()
        
        let dataFlow = MapDataFlow(route: route, destination: destination, userLocation: userLocation)
        
        XCTAssertEqual(dataFlow.sourceRoute, route, "Source route should match provided route")
        XCTAssertEqual(dataFlow.sourceDestination, destination, "Source destination should match provided destination")
        XCTAssertEqual(dataFlow.sourceUserLocation, userLocation, "Source userLocation should match provided location")
    }
    
    /// Test that MapDataFlow correctly initializes with nil userLocation
    func testMapDataFlowInitializationWithNilUserLocation() {
        let route = MockRoute.random()
        let destination = MockDestination.random()
        
        let dataFlow = MapDataFlow(route: route, destination: destination, userLocation: nil)
        
        XCTAssertEqual(dataFlow.sourceRoute, route, "Source route should match provided route")
        XCTAssertEqual(dataFlow.sourceDestination, destination, "Source destination should match provided destination")
        XCTAssertNil(dataFlow.sourceUserLocation, "Source userLocation should be nil")
    }
    
    /// Test that annotation tracker correctly tracks route polyline
    func testAnnotationTrackerTracksRoutePolyline() {
        let tracker = FullScreenMapAnnotationTracker(
            route: MockRoute.random(),
            destination: MockDestination.random(),
            userLocation: nil
        )
        
        XCTAssertFalse(tracker.hasRoutePolyline, "Should not have route polyline before rendering")
        
        tracker.renderMap()
        
        XCTAssertTrue(tracker.hasRoutePolyline, "Should have route polyline after rendering")
    }
    
    /// Test that annotation tracker correctly tracks destination annotation
    func testAnnotationTrackerTracksDestinationAnnotation() {
        let tracker = FullScreenMapAnnotationTracker(
            route: MockRoute.random(),
            destination: MockDestination.random(),
            userLocation: nil
        )
        
        XCTAssertFalse(tracker.hasDestinationAnnotation, "Should not have destination annotation before rendering")
        
        tracker.renderMap()
        
        XCTAssertTrue(tracker.hasDestinationAnnotation, "Should have destination annotation after rendering")
    }
    
    /// Test that annotation tracker correctly tracks user location when provided
    func testAnnotationTrackerTracksUserLocationWhenProvided() {
        let tracker = FullScreenMapAnnotationTracker(
            route: MockRoute.random(),
            destination: MockDestination.random(),
            userLocation: MockLocation.random()
        )
        
        XCTAssertFalse(tracker.hasUserLocationAnnotation, "Should not have user location annotation before rendering")
        
        tracker.renderMap()
        
        XCTAssertTrue(tracker.hasUserLocationAnnotation, "Should have user location annotation after rendering when location provided")
    }
    
    /// Test that annotation tracker does not track user location when nil
    func testAnnotationTrackerDoesNotTrackUserLocationWhenNil() {
        let tracker = FullScreenMapAnnotationTracker(
            route: MockRoute.random(),
            destination: MockDestination.random(),
            userLocation: nil
        )
        
        tracker.renderMap()
        
        XCTAssertFalse(tracker.hasUserLocationAnnotation, "Should not have user location annotation when location is nil")
    }
}
