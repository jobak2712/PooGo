//
//  MapView.swift
//  PooGo
//
//  Created by Abiodun Olorode on 03/12/2025.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

@MainActor
fileprivate class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    
    override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationAccess() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.requestLocation()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
}

struct MapView: View {
    @Binding var isPresented: Bool
    @State private var isSearching = true
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text("Nearest Toilet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            Spacer()
            
            // Searching State
            if isSearching {
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.0))
                            .frame(width: 8, height: 8)
                        
                        Text("Searching nearby")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                    .cornerRadius(20)
                    
                    Spacer()
                    
                    Image(systemName: "location.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.0))
                    
                    Text("Finding nearest toilet...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("Using your current location")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .onAppear {
                    locationManager.requestLocationAccess()
                }
                .onChange(of: locationManager.userLocation) {
                    if locationManager.userLocation != nil {
                        isSearching = false
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Button(action: { MapLauncher.openNearestToilet() }) {
                        HStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 18))
                            
                            Text("Open in Maps")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 1.0, green: 0.55, blue: 0.0))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.0))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Turn-by-turn navigation")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Text("Get walking or driving directions to the nearest public toilet")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
                .frame(height: 40)
        }
        .background(Color(red: 0.98, green: 0.96, blue: 0.93))
        .ignoresSafeArea()
    }
}

#Preview {
    MapView(isPresented: .constant(true))
}
