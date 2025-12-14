# Requirements Document

## Introduction

This feature enables users to expand the mini map in the DirectionsView to full screen by tapping on it. The expansion should only occur on a simple tap gesture, not when the user is actively interacting with the map through zoom (pinch) or pan (drag) gestures. All map interactions remain within the PooGo app, providing a seamless in-app experience without redirecting to external map applications.

## Glossary

- **Mini Map**: The compact map view (170px height) displayed in DirectionsView showing the route to the nearest toilet
- **Full Screen Map**: An expanded view of the map that covers the entire screen, displayed within the PooGo app
- **Tap Gesture**: A single, quick touch on the screen without movement
- **Zoom Gesture**: A pinch gesture using two fingers to scale the map in or out
- **Pan Gesture**: A drag gesture using one finger to move the map view
- **Navigation Gestures**: Collective term for zoom and pan gestures used to interact with map content
- **In-App Map**: Map functionality provided natively within PooGo using MapKit, without launching external applications

## Requirements

### Requirement 1

**User Story:** As a user, I want to tap on the mini map to expand it to full screen within the app, so that I can see the route and destination more clearly without leaving PooGo.

#### Acceptance Criteria

1. WHEN a user performs a single tap on the Mini Map THEN the system SHALL expand the map to full screen view within the PooGo app
2. WHEN the Full Screen Map is displayed THEN the system SHALL show the same route, user location, and destination annotations as the Mini Map
3. WHEN the Full Screen Map is displayed THEN the system SHALL provide a close button to return to the DirectionsView
4. WHEN the Full Screen Map is displayed THEN the system SHALL keep the user within the PooGo app

### Requirement 2

**User Story:** As a user, I want to zoom and pan the map without triggering expansion, so that I can explore the route details at the current map size.

#### Acceptance Criteria

1. WHILE a user performs a Zoom Gesture on the Mini Map THEN the system SHALL scale the map view without triggering expansion
2. WHILE a user performs a Pan Gesture on the Mini Map THEN the system SHALL move the map view without triggering expansion
3. WHEN a user completes Navigation Gestures THEN the system SHALL maintain the current map dimensions

### Requirement 3

**User Story:** As a user, I want the full screen map to support all standard map interactions within the app, so that I can explore the route in detail.

#### Acceptance Criteria

1. WHEN the Full Screen Map is displayed THEN the system SHALL support zoom gestures for scaling the map
2. WHEN the Full Screen Map is displayed THEN the system SHALL support pan gestures for moving the map view
3. WHEN the Full Screen Map is displayed THEN the system SHALL maintain the route polyline, user location marker, and destination annotation visibility
4. WHEN the user interacts with the Full Screen Map THEN the system SHALL handle all interactions within the PooGo app
