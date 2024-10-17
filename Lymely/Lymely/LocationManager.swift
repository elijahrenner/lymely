//
//  LocationManager.swift
//  Lymely
//
//  Created by Elijah Renner on 9/30/24.
//

import SwiftUI
import MapboxMaps
import CoreLocation

/// A class that manages location services for the app.
/// It provides real-time updates of the user's location and handles location-related permissions.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// The Core Location manager used to retrieve the user's location.
    private let locationManager = CLLocationManager()
    
    /// The current location of the user, published for observers.
    @Published var userLocation: CLLocationCoordinate2D?
    
    /// Initializes the LocationManager and sets up location services.
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    /// Called when new location data is available.
    /// - Parameters:
    ///   - manager: The location manager object that generated the update event.
    ///   - locations: An array of CLLocation objects containing the location data.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
        }
    }
    
    /// Called when an error occurs in location services.
    /// - Parameters:
    ///   - manager: The location manager object that encountered the error.
    ///   - error: The error that occurred.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed: \(error.localizedDescription)")
    }
}
