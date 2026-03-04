import CoreLocation
import Observation

@Observable
class LocationManager {
    var currentLocation: CLLocation?
    var authorizationDenied = false
    var isReceivingUpdates = false

    @ObservationIgnored
    private let manager = CLLocationManager()

    @ObservationIgnored
    private var updateTask: Task<Void, Never>?

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        guard updateTask == nil else { return }
        updateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isReceivingUpdates = true
            do {
                for try await update in CLLocationUpdate.liveUpdates(.otherNavigation) {
                    if update.authorizationDenied || update.authorizationDeniedGlobally {
                        self.authorizationDenied = true
                        break
                    }
                    if !update.authorizationRequestInProgress, let location = update.location {
                        self.currentLocation = location
                    }
                }
            } catch {
                // Task was cancelled or location updates ended
            }
            self.isReceivingUpdates = false
        }
    }

    func stopUpdates() {
        updateTask?.cancel()
        updateTask = nil
        isReceivingUpdates = false
    }

    func distanceToTarget(_ target: CLLocation) -> Double? {
        guard let current = currentLocation else { return nil }
        return current.distance(from: target)
    }

    func isWithinRadius(of target: CLLocation, radius: Double) -> Bool {
        guard let distance = distanceToTarget(target) else { return false }
        return distance <= radius
    }
}
