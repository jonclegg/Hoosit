import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var lastKnownLocation: CLLocation?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = 10
        self.locationManager.requestWhenInUseAuthorization()
        
        // Add notification observers for app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedToBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func appMovedToBackground() {
        locationManager.stopUpdatingLocation()
        lastKnownLocation = currentLocation
    }
    
    @objc func appBecameActive() {
        locationManager.startUpdatingLocation()
        // Force an immediate location update if we have authorization
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
            
            // If this is significantly different from our last location, update it
            if let lastLocation = lastKnownLocation {
                let distance = location.distance(from: lastLocation)
                if distance > 100 { // 100 meters threshold
                    lastKnownLocation = location
                }
            } else {
                lastKnownLocation = location
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
            // Request an immediate location update
            manager.requestLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        // If it's a timeout error, try requesting location again
        if (error as? CLError)?.code == .locationUnknown {
            manager.requestLocation()
        }
    }
    
    var locationStatus: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "Please allow location access"
        case .restricted, .denied:
            return "Location access denied"
        case .authorizedWhenInUse, .authorizedAlways:
            return ""
        @unknown default:
            return "Unknown location status"
        }
    }
    
    // Helper method to force a location update
    func refreshLocation() {
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
}
