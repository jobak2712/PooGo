# PooGo - iOS App

A lightweight iOS app that detects shake gestures and helps you find the nearest public toilet using Apple Maps.

## Features

- **Shake Detection**: Uses the device accelerometer to detect shake gestures
- **Vibration Feedback**: Triple vibration alert when shake is detected or button is tapped
- **Toilet Finder**: Automatically searches for nearby public toilets using Apple Maps
- **One-Tap Navigation**: Get directions to the nearest toilet with a single tap
- **Manual Trigger**: Big "I Need to Poo!" button for manual activation
- **Minimal UI**: Clean, distraction-free interface

## Technical Stack

- **Language**: Swift
- **Framework**: SwiftUI
- **APIs**: CoreMotion (accelerometer), MapKit (maps), CoreLocation (GPS)
- **Minimum iOS**: 17.0

## Project Structure

```
PooGo/
├── PooGo/
│   ├── PooAlertApp.swift          # App entry point
│   ├── ContentView.swift           # Main UI with button and shake detection
│   ├── MapView.swift               # Map view with toilet search
│   ├── ShakeDetector.swift         # Accelerometer shake detection logic
│   ├── HapticFeedback.swift        # Vibration feedback
│   └── Assets.xcassets/            # App icons and assets
├── PooGoTests/                     # Unit tests
├── PooGoUITests/                   # UI tests
└── PooGo.xcodeproj/               # Xcode project file
```

## Required Permissions

The app requires the following permissions in `Info.plist`:

- **NSLocationWhenInUseUsageDescription**: "Poo Alert needs your location to find nearby toilets"
- **NSMotionUsageDescription**: "Poo Alert uses motion detection to sense when you shake your phone"

These are automatically configured in the Xcode project.

## Building and Running

### Prerequisites

- macOS with Xcode 15.0 or later
- iOS 17.0 or later device/simulator

### Steps

1. **Open the project**:
   ```bash
   cd PooGo
   open PooGo.xcodeproj
   ```

2. **Select target and device**:
   - In Xcode, select "PooGo" as the target
   - Choose your device or simulator from the device dropdown

3. **Build and run**:
   - Press `Cmd + R` or click the Play button
   - The app will build and launch on your device/simulator

4. **Grant permissions**:
   - When prompted, allow location access
   - Allow motion access

## Usage

### Automatic Shake Detection
1. Launch the app
2. Shake your device vigorously
3. The app will vibrate and display the map with nearby toilets
4. Tap "Get Directions" to open Apple Maps with navigation

### Manual Trigger
1. Tap the large "I Need to Poo!" button
2. The app will vibrate and display the map
3. Tap "Get Directions" to navigate

## How It Works

### Shake Detection
- Monitors accelerometer data continuously
- Detects when acceleration magnitude exceeds 3.0 G
- Implements 1-second cooldown to prevent multiple triggers
- Provides haptic feedback on detection

### Toilet Search
- Uses MapKit's local search API
- Searches for "public toilet" within 5km radius
- Sorts results by distance
- Displays up to 5 nearest results on map

### Navigation
- Tapping "Get Directions" opens Apple Maps
- Automatically sets driving directions to selected toilet
- User can switch to walking/transit modes in Maps

## Customization

### Adjust Shake Sensitivity
Edit `ShakeDetector.swift`:
```swift
private let shakeThreshold: Double = 3.0  // Increase for less sensitivity
```

### Change Search Radius
Edit `MapView.swift`:
```swift
span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)  // Adjust span
```

### Modify Search Keywords
Edit `MapView.swift`:
```swift
request.naturalLanguageQuery = "public toilet"  // Change search term
```

## Troubleshooting

### Map not showing
- Ensure location permission is granted in Settings > Poo Alert > Location
- Check that device has internet connection

### Shake not detected
- Ensure motion permission is granted
- Try shaking more vigorously
- Check that shake threshold isn't too high

### No toilets found
- You may be in a remote area
- Try expanding the search radius in MapView.swift
- Manually search in Apple Maps

## Notes

- The app works best on physical devices (simulator shake detection is limited)
- Location services must be enabled for toilet search
- Internet connection required for map and search functionality
- Vibration feedback requires a device with haptic engine

## License

MIT License - Feel free to modify and distribute
