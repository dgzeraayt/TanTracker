import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var city: String?

    var onUpdate: ((CLLocationCoordinate2D, String?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorization = manager.authorizationStatus
    }

    func request() {
        #if DEBUG
        // Capture d'écran : pas de pop-up système qui masque l'UI à vérifier.
        if ProcessInfo.processInfo.environment["SOLA_SCREEN"] != nil { return }
        #endif
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        Task { @MainActor in
            authorization = m.authorizationStatus
            if m.authorizationStatus == .authorizedWhenInUse || m.authorizationStatus == .authorizedAlways {
                m.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        Task { @MainActor in
            coordinate = loc.coordinate
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(loc)
            if let pm = placemarks?.first {
                let name = [pm.locality, pm.country].compactMap { $0 }.joined(separator: ", ")
                city = name.isEmpty ? nil : name
            }
            onUpdate?(loc.coordinate, city)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) { }
}
