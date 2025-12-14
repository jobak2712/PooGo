# PooGo - Quick Start Guide

## One-Minute Setup

### 1. Open in Xcode
```bash
cd PooGo
open PooGo.xcodeproj
```

### 2. Select Device
- Choose your iPhone or simulator from the device dropdown (top of Xcode window)

### 3. Build & Run
- Press `Cmd + R` or click the Play button
- Wait for the app to build and launch

### 4. Grant Permissions
- Tap "Allow" when prompted for location access
- Tap "Allow" when prompted for motion access

## Using the App

### Method 1: Shake Detection
1. Shake your phone vigorously
2. App vibrates 3 times
3. Map appears with nearby toilets
4. Tap "Get Directions" to navigate

### Method 2: Manual Button
1. Tap the big "I Need to Poo!" button
2. App vibrates 3 times
3. Map appears with nearby toilets
4. Tap "Get Directions" to navigate

## Troubleshooting

**Map not showing?**
- Check Settings > Poo Alert > Location is set to "While Using"
- Ensure you have internet connection

**Shake not working?**
- Use a physical device (simulator shake is limited)
- Shake more vigorously
- Check Settings > Poo Alert > Motion is allowed

**No toilets found?**
- You may be in a remote area
- Try a different location
- Check internet connection

## File Structure

```
PooGo/
├── PooGo/
│   ├── PooAlertApp.swift       ← App entry point
│   ├── ContentView.swift        ← Main screen with button
│   ├── MapView.swift            ← Toilet finder map
│   ├── ShakeDetector.swift      ← Shake detection logic
│   └── HapticFeedback.swift     ← Vibration feedback
└── README.md                    ← Full documentation
```

## Key Features

✅ Shake detection using accelerometer  
✅ Triple vibration feedback  
✅ Automatic toilet search  
✅ One-tap navigation to Maps  
✅ Manual trigger button  
✅ Minimal, clean UI  

## Next Steps

- Customize shake sensitivity in `ShakeDetector.swift` (line 14)
- Change search keywords in `MapView.swift` (line 68)
- Adjust search radius in `MapView.swift` (line 70)

Enjoy! 🚽
