//
//  ToiletDestination.swift
//  PooGo
//
//  Created by Abiodun Olorode on 06/12/2025.
//

import Foundation
import CoreLocation

struct ToiletDestination: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    
    init(name: String, latitude: Double, longitude: Double, address: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
