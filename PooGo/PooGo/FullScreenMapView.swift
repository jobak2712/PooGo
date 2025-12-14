//
//  FullScreenMapView.swift
//  PooGo
//
//  Created by Kiro on 09/12/2025.
//

import CoreLocation
import MapKit
import SwiftUI

/// A full screen map view displaying the route, user location, and destination.
/// Provides a close button to return to the DirectionsView.
struct FullScreenMapView: View {
    // MARK: - Input Properties
    
    let route: MKRoute
    let destination: ToiletDestination
    let userLocation: CLLocation?
    let onClose: () -> Void
    
    // MARK: - State
    
    @State private var cameraPosition: MapCameraPosition
    
    // MARK: - Initialization
    
    init(route: MKRoute, destination: ToiletDestination, userLocation: CLLocation?, onClose: @escaping () -> Void) {
        self.route = route
        self.destination = destination
        self.userLocation = userLocation
        self.onClose = onClose
        
        // Initialize camera position to show the full route
        let rect = route.polyline.boundingMapRect
        _cameraPosition = State(initialValue: .rect(rect.insetBy(dx: -rect.width * 0.1, dy: -rect.height * 0.1)))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Full screen map
            mapContent
                .ignoresSafeArea()
            
            // Close button overlay
            closeButton
                .padding(.top, 60)
                .padding(.leading, 16)
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
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            
            // Destination annotation with toilet icon
            Annotation(destination.name, coordinate: destination.coordinate) {
                Image(systemName: "toilet.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color(red: 0.1, green: 0.74, blue: 0.61))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }
    
    // MARK: - Close Button
    
    @ViewBuilder
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.32))
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
    }
}
