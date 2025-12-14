# Design Document: Expandable Map

## Overview

This feature adds an expandable map capability to the DirectionsView in PooGo. Users can tap on the mini map to expand it to full screen for a better view of the route, while zoom and pan gestures are preserved for map navigation without triggering expansion. All interactions remain within the PooGo app.

The implementation uses SwiftUI gesture recognition to distinguish between tap gestures (which trigger expansion) and navigation gestures (zoom/pan which interact with the map content).

## Architecture

The feature follows the existing SwiftUI architecture pattern in PooGo:

```
┌─────────────────────────────────────────────────────────┐
│                    DirectionsView                        │
│  ┌─────────────────────────────────────────────────┐    │
│  │              ExpandableMapView                   │    │
│  │  ┌─────────────────────────────────────────┐    │    │
│  │  │    Map (MapKit SwiftUI)                 │    │    │
│  │  │    - Route polyline                     │    │    │
│  │  │    - User location annotation           │    │    │
│  │  │    - Destination annotation             │    │    │
│  │  └─────────────────────────────────────────┘    │    │
│  │                                                  │    │
│  │  Gesture Recognition:                           │    │
│  │  - TapGesture → expand to full screen          │    │
│  │  - MagnificationGesture → zoom (no expand)     │    │
│  │  - DragGesture → pan (no expand)               │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │           FullScreenMapView (Sheet)              │    │
│  │  - Same map content                              │    │
│  │  - Close button overlay                          │    │
│  │  - Full gesture support                          │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. ExpandableMapView

A new SwiftUI view component that wraps the existing Map and adds tap-to-expand functionality.

```swift
struct ExpandableMapView: View {
    // Input
    let route: MKRoute
    let destination: ToiletDestination
    let cameraPosition: Binding<MapCameraPosition>
    let userLocation: CLLocation?
    
    // State
    @State private var isExpanded: Bool = false
    @State private var isInteracting: Bool = false
    
    // Methods
    func handleTap() -> Void  // Expands map if not interacting
}
```

### 2. FullScreenMapView

A full screen overlay view displaying the expanded map.

```swift
struct FullScreenMapView: View {
    // Input
    let route: MKRoute
    let destination: ToiletDestination
    let userLocation: CLLocation?
    let onClose: () -> Void
    
    // State
    @State private var cameraPosition: MapCameraPosition
}
```

### 3. GestureState Tracking

Track whether the user is actively performing navigation gestures to prevent tap expansion during map interaction.

```swift
// Interaction state
@GestureState private var isZooming: Bool = false
@GestureState private var isPanning: Bool = false

var isInteracting: Bool {
    isZooming || isPanning
}
```

## Data Models

No new data models required. The feature uses existing models:

- `MKRoute` - Route information from MapKit
- `ToiletDestination` - Destination details (name, coordinate, address)
- `MapCameraPosition` - Camera position state for the map
- `CLLocation` - User location

## Correctness Properties


*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Based on the prework analysis, the following properties can be tested:

### Property 1: Tap triggers expansion when not interacting

*For any* map state where `isInteracting` is false, performing a tap gesture SHALL result in `isExpanded` becoming true.

**Validates: Requirements 1.1**

### Property 2: Data consistency between mini and full screen maps

*For any* route and destination combination, the FullScreenMapView SHALL receive the same route, userLocation, and destination values as the ExpandableMapView.

**Validates: Requirements 1.2**

### Property 3: Zoom gesture prevents expansion

*For any* zoom gesture state where `isZooming` is true, the `isExpanded` state SHALL remain unchanged (not triggered by tap).

**Validates: Requirements 2.1**

### Property 4: Pan gesture prevents expansion

*For any* pan gesture state where `isPanning` is true, the `isExpanded` state SHALL remain unchanged (not triggered by tap).

**Validates: Requirements 2.2**

### Property 5: Gesture completion preserves map dimensions

*For any* map state (mini or full screen), completing a navigation gesture SHALL not change the `isExpanded` state.

**Validates: Requirements 2.3**

### Property 6: Full screen map displays required annotations

*For any* route and destination, the FullScreenMapView SHALL include the route polyline, user location annotation (when available), and destination annotation.

**Validates: Requirements 3.3**

## Error Handling

| Scenario | Handling |
|----------|----------|
| User location unavailable | Display map without user location marker; route and destination still shown |
| Route not yet calculated | Show loading state; disable tap-to-expand until route is available |
| Gesture recognition conflict | Prioritize navigation gestures over tap; only expand on clean tap |

## Testing Strategy

### Property-Based Testing

The project will use Swift's built-in XCTest framework with custom property-based testing patterns. Since Swift doesn't have a widely-adopted PBT library like QuickCheck, we'll implement lightweight property tests that generate multiple test cases.

**Testing Framework**: XCTest with parameterized test patterns

**Property Test Configuration**: Each property test should run with at least 100 iterations using randomized inputs.

**Property Test Annotation Format**: Each test must include a comment in this format:
```swift
// **Feature: expandable-map, Property {number}: {property_text}**
```

### Unit Tests

Unit tests will cover:
- ExpandableMapView initialization with various route/destination combinations
- Gesture state transitions
- FullScreenMapView close button functionality
- View state management

### Test Structure

```
PooGoTests/
├── ExpandableMapTests.swift       # Property and unit tests for ExpandableMapView
└── FullScreenMapTests.swift       # Tests for FullScreenMapView
```
