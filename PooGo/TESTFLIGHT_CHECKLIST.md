# PooGo TestFlight Preparation

## Current App Info
- **Version:** 1.0
- **Build:** 1
- **Bundle ID:** PooGO.PooGo
- **Development Team:** L3JZHZU9W4
- **Last Verified:** December 11, 2025

## Latest Features (v1.0)
- ✅ 1-2 tap toilet finder
- ✅ Tiered search (500m → 2km → 10km)
- ✅ Free toilets prioritized
- ✅ Live location tracking during navigation
- ✅ Expandable map view
- ✅ Feedback module (thumbs up/down)
- ✅ Reliability scoring system with decay formula
- ✅ "Not a toilet" blacklist (global sync)
- ✅ Global localized search (10 languages)
- ✅ Nigerian-specific support (Shoprite, filling stations, etc.)
- ✅ Supabase cloud sync (ratings shared globally)
- ✅ Show rating counts after feedback (👍 12 👎 3)
- ✅ Feature flags system (remote feature control)
- ✅ Crowdsourced toilet discovery (behind feature flag)

---

## Pre-Upload Checklist

### ✅ Already Configured
- [x] Location permission description (NSLocationWhenInUseUsageDescription)
- [x] Motion permission description (NSMotionUsageDescription)
- [x] Notification permission description (NSUserNotificationsUsageDescription)
- [x] App icon (1024x1024 in Assets.xcassets)
- [x] Privacy descriptions in build settings
- [x] Automatic code signing enabled
- [x] Development team configured
- [x] Release build verified ✅

### 📋 Before Uploading to TestFlight

1. **In Xcode, verify:**
   - Signing & Capabilities → Select your Team
   - Bundle Identifier is unique (currently: PooGO.PooGo)
   - Version: 1.0, Build: 1

2. **Archive the app:**
   - Select "Any iOS Device" as destination
   - Product → Archive
   - Wait for archive to complete

3. **Upload to App Store Connect:**
   - Window → Organizer
   - Select the archive → Distribute App
   - Choose "App Store Connect" → Upload
   - Follow prompts (automatic signing recommended)

---

## App Store Connect Setup

### Required Before TestFlight Review

1. **App Information:**
   - App Name: PooGo
   - Subtitle: Find the nearest toilet instantly
   - Category: Navigation or Utilities
   - Content Rights: Does not contain third-party content

2. **Privacy Policy URL:**
   - Required for TestFlight
   - Create a simple privacy policy page stating:
     - Location data is used only to find nearby toilets
     - Data stays on device
     - No personal data is collected or shared

3. **App Description:**
   ```
   PooGo helps you find the nearest public toilet in seconds.
   
   • ONE TAP to find the nearest toilet
   • Walking directions appear instantly
   • Prioritizes FREE toilets (stations, parks, malls)
   • Rate toilets to help others (thumbs up/down)
   • Works globally in 10+ languages
   • Nigerian support: Shoprite, SPAR, filling stations
   
   Your location stays private and is never shared.
   ```

4. **Keywords:**
   ```
   toilet, restroom, bathroom, WC, loo, public toilet, toilet finder, nearby toilet, emergency toilet
   ```

5. **Screenshots:**
   - Home screen
   - Directions screen with route
   - Required sizes: iPhone 6.7" and 6.5" displays

---

## TestFlight Beta Testing

### Internal Testing (Immediate)
- Add up to 100 internal testers via App Store Connect
- No review required
- Available immediately after upload

### External Testing (Requires Review)
- Add up to 10,000 external testers
- Requires Beta App Review (usually 24-48 hours)
- Need: Test description, feedback email, privacy policy

---

## Build Commands

```bash
# Clean build folder
cd PooGo
xcodebuild clean -project PooGo.xcodeproj -scheme PooGo

# Build for release
xcodebuild -project PooGo.xcodeproj -scheme PooGo -configuration Release -destination 'generic/platform=iOS' archive -archivePath ./build/PooGo.xcarchive
```

Or simply use Xcode: **Product → Archive**

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Missing provisioning profile | Xcode → Signing → Enable "Automatically manage signing" |
| Icon missing | Ensure AppIcon has 1024x1024 image |
| Privacy description missing | Check Info.plist has all NS*UsageDescription keys |
| Build number conflict | Increment CURRENT_PROJECT_VERSION in project settings |

---

## Ready to Upload! 🚀

1. Open `PooGo.xcodeproj` in Xcode
2. Select your development team
3. Product → Archive
4. Distribute App → App Store Connect → Upload
