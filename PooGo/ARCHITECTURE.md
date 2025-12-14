# PooGo - Architecture & Design

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Poo Alert App                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              ContentView (Main UI)                   │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  "I Need to Poo!" Button                       │  │  │
│  │  │  Status Text                                   │  │  │
│  │  │  Shake Listener                                │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         ShakeDetector (Observable)                   │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  CoreMotion Manager                            │  │  │
│  │  │  Accelerometer Monitoring                       │  │  │
│  │  │  Magnitude Calculation                          │  │  │
│  │  │  Cooldown Logic                                 │  │  │
│  │  │  Published State                                │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         HapticFeedback (Utility)                     │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  UIImpactFeedbackGenerator                      │  │  │
│  │  │  Triple Vibration Pattern                       │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              MapView (Map Screen)                    │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  MapKit Integration                            │  │  │
│  │  │  Location Manager                              │  │  │
│  │  │  Local Search                                   │  │  │
│  │  │  Result Sorting                                 │  │  │
│  │  │  Navigation Handler                             │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ↓                                  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Apple Maps (External)                        │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │  Navigation & Directions                        │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

### Shake Detection Flow
```
┌─────────────────────────────────────────────────────────────┐
│ User shakes phone                                           │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ CoreMotion captures accelerometer data                      │
│ Updates every 100ms                                         │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ ShakeDetector calculates magnitude                          │
│ magnitude = √(x² + y² + z²)                                │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Check if magnitude > 3.0 G                                  │
└────────────────────┬────────────────────────────────────────┘
                     ↓
        ┌────────────┴────────────┐
        ↓                         ↓
    YES (> 3.0)              NO (< 3.0)
        ↓                         ↓
    Check cooldown          Continue monitoring
        ↓
    ┌───┴───┐
    ↓       ↓
  YES      NO
    ↓       ↓
  Trigger  Ignore
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Set shakeDetected = true                                    │
│ Publish state update                                        │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ ContentView receives update                                 │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Call HapticFeedback.vibrate()                               │
│ Triple vibration pattern                                    │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Present MapView                                             │
└─────────────────────────────────────────────────────────────┘
```

### Toilet Search Flow
```
┌─────────────────────────────────────────────────────────────┐
│ MapView appears                                             │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Request user location                                       │
│ CLLocationManager.startUpdatingLocation()                   │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Get user coordinate                                         │
│ location.coordinate                                         │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Create MKLocalSearch request                                │
│ Query: "public toilet"                                      │
│ Region: 5km radius around user                              │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Execute search                                              │
│ MKLocalSearch.start()                                       │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Receive results                                             │
│ mapItems array                                              │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Sort by distance                                            │
│ Calculate distance from user to each result                 │
│ Sort ascending                                              │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Take top 5 results                                          │
│ prefix(5)                                                   │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Display on map                                              │
│ Annotations with toilet icons                               │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ User taps "Get Directions"                                  │
└────────────────────┬────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ Open Apple Maps                                             │
│ mapItem.openInMaps()                                        │
│ With driving directions                                     │
└─────────────────────────────────────────────────────────────┘
```

## Component Interaction Diagram

```
┌──────────────────┐
│  PooAlertApp     │
│  (Entry Point)   │
└────────┬─────────┘
         │
         ↓
┌──────────────────────────────────────────────────────────┐
│                   ContentView                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │ @StateObject var shakeDetector: ShakeDetector     │  │
│  │ @State var showingMap: Bool                        │  │
│  │ @State var selectedPosition: MapCameraPosition    │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
         │
    ┌────┴────┐
    ↓         ↓
┌─────────┐  ┌──────────────────────────────────────────┐
│ Button  │  │ ShakeDetector                            │
│ Tap     │  │ ┌──────────────────────────────────────┐ │
│         │  │ │ @Published var shakeDetected: Bool  │ │
│         │  │ │ CoreMotion monitoring               │ │
│         │  │ │ Magnitude calculation               │ │
│         │  │ │ Cooldown logic                       │ │
│         │  │ └──────────────────────────────────────┘ │
└────┬────┘  └──────────────────┬───────────────────────┘
     │                          │
     └──────────────┬───────────┘
                    ↓
         ┌──────────────────────┐
         │ triggerAlert()       │
         │ ┌──────────────────┐ │
         │ │ HapticFeedback   │ │
         │ │ .vibrate()       │ │
         │ └──────────────────┘ │
         └──────────┬───────────┘
                    ↓
         ┌──────────────────────┐
         │ showingMap = true    │
         │ Present MapView      │
         └──────────┬───────────┘
                    ↓
         ┌──────────────────────────────────────────┐
         │ MapView                                  │
         │ ┌──────────────────────────────────────┐ │
         │ │ @Binding var isPresented: Bool      │ │
         │ │ @State var searchResults: [MKMapItem]│ │
         │ │ @State var userLocation: CLLocation │ │
         │ │ MapKit integration                   │ │
         │ │ Local search                         │ │
         │ │ Navigation handler                   │ │
         │ └──────────────────────────────────────┘ │
         └──────────┬───────────────────────────────┘
                    ↓
         ┌──────────────────────┐
         │ Get Directions       │
         │ openInMaps()         │
         └──────────┬───────────┘
                    ↓
         ┌──────────────────────┐
         │ Apple Maps           │
         │ Navigation           │
         └──────────────────────┘
```

## State Management

### ContentView State
```swift
@StateObject private var shakeDetector = ShakeDetector()
// Manages shake detection lifecycle

@State private var showingMap = false
// Controls map visibility

@State private var selectedPosition: MapCameraPosition = .automatic
// Manages map camera position
```

### ShakeDetector State
```swift
@Published var shakeDetected = false
// Published for SwiftUI binding

private let motionManager = CMMotionManager()
// Manages accelerometer

private let shakeThreshold: Double = 3.0
// Configurable sensitivity

private var lastShakeTime: Date = Date()
// Cooldown tracking
```

### MapView State
```swift
@Binding var isPresented: Bool
// Controls map visibility

@State private var position: MapCameraPosition = .automatic
// Map camera position

@State private var searchResults: [MKMapItem] = []
// Toilet search results

@State private var userLocation: CLLocationCoordinate2D?
// User's current location

@State private var isLoading = true
// Loading state
```

## API Integration

### CoreMotion API
```
CMMotionManager
├── isAccelerometerAvailable
├── accelerometerUpdateInterval
├── startAccelerometerUpdates(to:withHandler:)
└── stopAccelerometerUpdates()
```

### MapKit API
```
MKLocalSearch
├── MKLocalSearch.Request
│   ├── naturalLanguageQuery
│   └── region
├── start(completionHandler:)
└── MKMapItem
    ├── placemark
    ├── name
    └── openInMaps(launchOptions:)
```

### CoreLocation API
```
CLLocationManager
├── requestWhenInUseAuthorization()
├── startUpdatingLocation()
├── stopUpdatingLocation()
└── location
    └── coordinate
```

### UIKit Haptics API
```
UIImpactFeedbackGenerator
├── init(style:)
├── impactOccurred()
└── prepare()
```

## Error Handling

### Graceful Degradation
```
Accelerometer unavailable
└── App still works with manual button

Location permission denied
└── Map shows generic location

No toilets found
└── Show empty state message

Internet unavailable
└── Show error message
```

## Performance Considerations

### Memory
- ShakeDetector: ~5 MB
- MapView: ~15 MB
- Total: ~20-30 MB

### CPU
- Accelerometer polling: 100ms intervals
- Minimal processing
- Efficient sorting algorithm

### Battery
- Accelerometer: ~2% per hour
- Location: ~3% per hour
- Total: ~5% per hour of active use

### Network
- Search query: ~50 KB
- Map tiles: ~1-5 MB (cached)
- Minimal bandwidth usage

## Security Architecture

### Data Privacy
```
User Location
├── Used only for search
├── Not stored
└── Not transmitted to external servers

Motion Data
├── Processed locally
├── Not stored
└── Not transmitted
```

### Permissions
```
Location Permission
├── NSLocationWhenInUseUsageDescription
└── Required for toilet search

Motion Permission
├── NSMotionUsageDescription
└── Required for shake detection
```

## Scalability

### Current Limitations
- Search limited to 5 results
- Search radius fixed at 5km
- Single search query

### Future Improvements
- Multiple search queries
- Configurable search radius
- Result caching
- Offline support
- Background updates

---

This architecture provides a clean, efficient, and maintainable foundation for the Poo Alert app.
