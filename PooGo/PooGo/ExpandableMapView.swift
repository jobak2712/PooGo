//
//  ExpandableMapView.swift
//  PooGo
//
//  Created by Kiro on 09/12/2025.
//

import CoreLocation
import MapKit
import SwiftUI

/// A map view that can be tapped to expand to full screen.
/// Zoom and pan gestures are preserved for map navigation without triggering expansion.
struct ExpandableMapView: View {
    // MARK: - Input Properties
    
    let route: MKRoute
    let destination: ToiletDestination
    @Binding var cameraPosition: MapCameraPosition
    let userLocation: CLLocation?
    
    // MARK: - State
    
    @State private var isExpanded: Bool = false
    @GestureState private var isZooming: Bool = false
    @GestureState private var isPanning: Bool = false
    
    // MARK: - Computed Properties
    
    /// Returns true if the user is actively interacting with the map via zoom or pan gestures
    var isInteracting: Bool {
        isZooming || isPanning
    }
    
    // MARK: - Body
    
    var body: some View {
        mapContent
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .gesture(
                TapGesture()
                    .onEnded {
                        handleTap()
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($isZooming) { _, state, _ in
                        state = true
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .updating($isPanning) { _, state, _ in
                        state = true
                    }
            )
            .sheet(isPresented: $isExpanded) {
                FullScreenMapView(
                    route: route,
                    destination: destination,
                    userLocation: userLocation,
                    onClose: {
                        isExpanded = false
                    }
                )
            }
    }
    
    // MARK: - Map Content
    
    @ViewBuilder
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // Route polyline
            MapPolyline(route.polyline)
                .stroke(Color(red: 0.0, green: 0.85, blue: 0.7), lineWidth: 5)
            
            // User location annotation
            if let userLoc = userLocation {
                Annotation("You", coordinate: userLoc.coordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            
            // Destination annotation with toilet icon
            Annotation(destination.name, coordinate: destination.coordinate) {
                Image(systemName: "toilet.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color(red: 0.1, green: 0.74, blue: 0.61))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
        }
    }
    
    // MARK: - Actions
    
    /// Handles tap gesture - expands map only if not currently interacting
    func handleTap() {
        if !isInteracting {
            isExpanded = true
        }
    }
}
