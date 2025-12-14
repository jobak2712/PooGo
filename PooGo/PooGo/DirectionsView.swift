//
//  DirectionsView.swift
//  PooGo
//
//  Created by Abiodun Olorode on 06/12/2025.
//

import CoreLocation
import MapKit
import SwiftUI

struct DirectionsView: View {
    let destination: ToiletDestination
    let onClose: () -> Void

    @StateObject private var locationService = LocationService.shared
    @State private var route: MKRoute?
    @State private var steps: [MKRoute.Step] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var lastRouteCalculationLocation: CLLocation?
    @State private var showFeedbackSheet = false
    @State private var feedbackSubmitted = false
    @State private var feedbackType: FeedbackType?
    @State private var toiletScore: ToiletReliabilityScore?
    
    // Recalculate route if user moves more than 30m from last calculation point
    private let routeRecalculationThreshold: Double = 30

    private var totalDistance: String {
        guard let route = route else { return "" }
        if route.distance < 1000 {
            return "\(Int(route.distance))m"
        } else {
            return String(format: "%.1fkm", route.distance / 1000)
        }
    }

    private var estimatedTime: String {
        guard let route = route else { return "" }
        let minutes = Int(route.expectedTravelTime / 60)
        if minutes < 1 {
            return "< 1 min"
        } else if minutes == 1 {
            return "1 min"
        } else {
            return "\(minutes) mins"
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    PressableButton(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.42))
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Dynamic header based on state
                HStack(spacing: 8) {
                    if errorMessage != nil {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        Text("Connection Issue")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    } else if isLoading {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                        Text("Getting directions...")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                        Text("Toilet found!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 12)

                // Mini Map with tap-to-expand functionality
                if let route = route {
                    ExpandableMapView(
                        route: route,
                        destination: destination,
                        cameraPosition: $cameraPosition,
                        userLocation: locationService.currentLocation
                    )
                    .padding(.horizontal, 16)
                }

                // Toilet Info Card
                if route != nil {
                    VStack(spacing: 12) {
                        // Toilet name
                        HStack(spacing: 10) {
                            Image(systemName: "toilet.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))

                            Text(destination.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()
                        }

                        // Address if available
                        if let address = destination.address {
                            HStack(spacing: 10) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.52))

                                Text(address)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.62))
                                    .lineLimit(1)

                                Spacer()
                            }
                        }

                        // Distance & Time
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                                Text(totalDistance)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                                Text(estimatedTime)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // Feedback Module
                if route != nil && !feedbackSubmitted {
                    ToiletFeedbackModule(
                        onThumbsUp: {
                            // Record positive feedback
                            ToiletReliabilityService.shared.recordPositiveFeedback(
                                latitude: destination.latitude,
                                longitude: destination.longitude,
                                toiletName: destination.name
                            )
                            // Fetch updated score to show counts
                            toiletScore = ToiletReliabilityService.shared.getScore(
                                latitude: destination.latitude,
                                longitude: destination.longitude
                            )
                            withAnimation(.easeOut(duration: 0.3)) {
                                feedbackSubmitted = true
                            }
                            HapticFeedback.vibrate()
                        },
                        onThumbsDown: {
                            showFeedbackSheet = true
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                } else if feedbackSubmitted {
                    // Thank you message with rating counts
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                            Text("Thanks for your feedback!")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.62))
                        }
                        
                        // Show rating counts
                        if let score = toiletScore {
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                                    Text("\(score.totalPositive)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
                                    Text("\(score.totalNegative)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 12)
                }

                // Divider
                Rectangle()
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.22))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Directions List
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(tint: Color(red: 0.1, green: 0.74, blue: 0.61)))
                        .scaleEffect(1.5)
                    Text("Calculating route...")
                        .foregroundColor(.gray)
                        .padding(.top, 12)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 20) {
                        // Offline icon with background
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        
                        VStack(spacing: 8) {
                            Text("No Internet Connection")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Check your connection and try again")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.62))
                                .multilineTextAlignment(.center)
                        }
                        
                        // Toilet info card (still show the destination)
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "toilet.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                                Text(destination.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                            }
                            if let address = destination.address {
                                HStack {
                                    Image(systemName: "mappin")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.52))
                                    Text(address)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.52))
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                        .cornerRadius(10)
                        .padding(.horizontal, 32)

                        // Primary action: Open in Apple Maps (most reliable in emergency)
                        PressableButton(action: {
                            openInAppleMaps()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Open in Apple Maps")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.1, green: 0.74, blue: 0.61))
                            .cornerRadius(25)
                            .shadow(color: Color(red: 0.1, green: 0.74, blue: 0.61).opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 40)
                        
                        // Secondary action: Try again
                        PressableButton(action: {
                            errorMessage = nil
                            isLoading = true
                            calculateRoute()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14))
                                Text("Try Again")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                        }
                    }
                    Spacer()
                } else if steps.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 40))
                            .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                        Text("Head towards your destination")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("Distance: \(totalDistance)")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                DirectionStepRow(
                                    step: step,
                                    isFirst: index == 0,
                                    isLast: index == steps.count - 1
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            // Enable live tracking for navigation
            locationService.startLiveTracking()
            calculateRoute()
        }
        .onDisappear {
            // Disable live tracking when leaving navigation
            locationService.stopLiveTracking()
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            // Recalculate route if user moved significantly
            guard let newLocation = newLocation,
                  let lastLocation = lastRouteCalculationLocation else { return }
            
            let distance = newLocation.distance(from: lastLocation)
            if distance > routeRecalculationThreshold {
                recalculateRouteQuietly()
            }
        }
        .sheet(isPresented: $showFeedbackSheet) {
            NegativeFeedbackSheet(
                toiletName: destination.name,
                onSubmit: { feedback in
                    // Record negative feedback with reason
                    ToiletReliabilityService.shared.recordNegativeFeedback(
                        latitude: destination.latitude,
                        longitude: destination.longitude,
                        toiletName: destination.name,
                        reason: feedback.reason?.rawValue ?? "Unknown"
                    )
                    // Fetch updated score to show counts
                    toiletScore = ToiletReliabilityService.shared.getScore(
                        latitude: destination.latitude,
                        longitude: destination.longitude
                    )
                    showFeedbackSheet = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        feedbackSubmitted = true
                    }
                    HapticFeedback.vibrate()
                },
                onCancel: {
                    showFeedbackSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func openInAppleMaps() {
        let coordinate = destination.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = destination.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
    
    private func calculateRoute() {
        guard let userLocation = locationService.currentLocation else {
            errorMessage = "Could not get your location"
            isLoading = false
            return
        }

        lastRouteCalculationLocation = userLocation

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(
            placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    errorMessage = "Could not calculate route: \(error.localizedDescription)"
                    return
                }

                guard let route = response?.routes.first else {
                    errorMessage = "No route found"
                    return
                }

                self.route = route
                self.steps = route.steps.filter { !$0.instructions.isEmpty }

                let rect = route.polyline.boundingMapRect
                cameraPosition = .rect(rect.insetBy(dx: -rect.width * 0.1, dy: -rect.height * 0.1))
            }
        }
    }
    
    /// Recalculates route without showing loading indicator (for live updates)
    private func recalculateRouteQuietly() {
        guard let userLocation = locationService.currentLocation else { return }
        
        lastRouteCalculationLocation = userLocation
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        request.destination = MKMapItem(
            placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            DispatchQueue.main.async {
                guard error == nil, let newRoute = response?.routes.first else { return }
                
                self.route = newRoute
                self.steps = newRoute.steps.filter { !$0.instructions.isEmpty }
                
                // Don't update camera position during live tracking to avoid jarring movements
            }
        }
    }
}

// MARK: - Direction Step Row

struct DirectionStepRow: View {
    let step: MKRoute.Step
    let isFirst: Bool
    let isLast: Bool

    private var distanceText: String {
        if step.distance < 1000 {
            return "\(Int(step.distance))m"
        } else {
            return String(format: "%.1fkm", step.distance / 1000)
        }
    }

    private var iconName: String {
        let instructions = step.instructions.lowercased()
        if isFirst {
            return "location.fill"
        } else if isLast {
            return "toilet.fill"
        } else if instructions.contains("left") {
            return "arrow.turn.up.left"
        } else if instructions.contains("right") {
            return "arrow.turn.up.right"
        } else if instructions.contains("straight") || instructions.contains("continue") {
            return "arrow.up"
        } else {
            return "chevron.forward"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.1, green: 0.74, blue: 0.61))
                        .frame(width: 36, height: 36)

                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                if !isLast {
                    Rectangle()
                        .fill(Color(red: 0.25, green: 0.25, blue: 0.27))
                        .frame(width: 2, height: 44)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(distanceText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))

                Text(step.instructions)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
            .padding(.bottom, isLast ? 0 : 20)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pressable Button with haptic-like visual feedback

struct PressableButton<Content: View>: View {
    let action: () -> Void
    let content: () -> Content
    
    @State private var isPressed = false
    
    init(action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }
    
    var body: some View {
        content()
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .brightness(isPressed ? -0.05 : 0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                action()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Feedback Types

enum FeedbackType: String, CaseIterable {
    case thumbsUp = "good"
    case thumbsDown = "bad"
}

enum NegativeFeedbackReason: String, CaseIterable, Identifiable {
    case closed = "Toilet Closed"
    case locked = "Locked / Staff Only"
    case dirty = "Dirty / Unusable"
    case notToilet = "Not a Toilet"
    case requiresPayment = "Requires Payment"
    case notAccessible = "Not Wheelchair Accessible"
    case noBabyChange = "No Baby Change"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .closed: return "door.left.hand.closed"
        case .locked: return "lock.fill"
        case .dirty: return "exclamationmark.triangle.fill"
        case .notToilet: return "xmark.circle.fill"
        case .requiresPayment: return "creditcard.fill"
        case .notAccessible: return "figure.roll"
        case .noBabyChange: return "figure.and.child.holdinghands"
        }
    }
}

struct ToiletFeedback {
    var reason: NegativeFeedbackReason?
    var note: String = ""
    var hasPhoto: Bool = false
}

// MARK: - Feedback Module (Thumbs Up/Down)

struct ToiletFeedbackModule: View {
    let onThumbsUp: () -> Void
    let onThumbsDown: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Text("How was this toilet?")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.52))
            
            HStack(spacing: 16) {
                // Thumbs Up
                PressableButton(action: onThumbsUp) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 16))
                        Text("Good")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.1, green: 0.74, blue: 0.61))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.1, green: 0.74, blue: 0.61).opacity(0.15))
                    .cornerRadius(20)
                }
                
                // Thumbs Down
                PressableButton(action: onThumbsDown) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.system(size: 16))
                        Text("Bad")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.15))
                    .cornerRadius(20)
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.15, green: 0.15, blue: 0.17))
        .cornerRadius(12)
    }
}

// MARK: - Negative Feedback Sheet

struct NegativeFeedbackSheet: View {
    let toiletName: String
    let onSubmit: (ToiletFeedback) -> Void
    let onCancel: () -> Void
    
    @State private var selectedReason: NegativeFeedbackReason?
    @State private var noteText: String = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Report an issue")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(toiletName)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.52))
                                .lineLimit(1)
                        }
                        .padding(.top, 8)
                        
                        // Reason Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What was the problem?")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(NegativeFeedbackReason.allCases) { reason in
                                    ReasonButton(
                                        reason: reason,
                                        isSelected: selectedReason == reason,
                                        action: {
                                            withAnimation(.easeOut(duration: 0.15)) {
                                                selectedReason = reason
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Optional Photo
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add a photo (optional)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if let image = selectedImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 120)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(12)
                                    
                                    Button(action: { selectedImage = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .padding(8)
                                }
                            } else {
                                Button(action: { showImagePicker = true }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 18))
                                        Text("Take Photo")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.52))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 80)
                                    .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(red: 0.25, green: 0.25, blue: 0.27), style: StrokeStyle(lineWidth: 1, dash: [6]))
                                    )
                                }
                            }
                        }
                        
                        // Optional Note
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional notes (optional)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            TextField("Tell us more...", text: $noteText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(12)
                                .frame(minHeight: 80, alignment: .topLeading)
                                .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                                .cornerRadius(12)
                                .lineLimit(3...6)
                        }
                        
                        Spacer(minLength: 20)
                        
                        // Submit Button
                        Button(action: {
                            let feedback = ToiletFeedback(
                                reason: selectedReason,
                                note: noteText,
                                hasPhoto: selectedImage != nil
                            )
                            onSubmit(feedback)
                        }) {
                            Text("Submit Feedback")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    selectedReason != nil
                                        ? Color(red: 0.1, green: 0.74, blue: 0.61)
                                        : Color(red: 0.3, green: 0.3, blue: 0.32)
                                )
                                .cornerRadius(12)
                        }
                        .disabled(selectedReason == nil)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.52))
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

// MARK: - Reason Button

struct ReasonButton: View {
    let reason: NegativeFeedbackReason
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: reason.icon)
                    .font(.system(size: 14))
                
                Text(reason.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : Color(red: 0.6, green: 0.6, blue: 0.62))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                    ? Color(red: 0.9, green: 0.3, blue: 0.3)
                    : Color(red: 0.15, green: 0.15, blue: 0.17)
            )
            .cornerRadius(10)
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    DirectionsView(
        destination: ToiletDestination(
            name: "King's Cross Station 🚉🚻",
            latitude: 51.5309,
            longitude: -0.1233,
            address: "Euston Road, London, N1C 4QP"
        ),
        onClose: {}
    )
}
