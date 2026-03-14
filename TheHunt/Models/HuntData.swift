import Foundation
import CoreLocation

struct HuntData: Codable {
    let hunt: Hunt
    let locations: [HuntLocation]
}

struct Hunt: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let startTime: Date
    let mediumRevealMinutes: Int
    let easyRevealMinutes: Int
    let maxPointsPerLocation: Int
}

struct HuntLocation: Codable, Identifiable {
    let id: String
    let name: String
    let order: Int
    let latitude: Double
    let longitude: Double
    let arrivalRadiusMeters: Double
    let clues: ClueSet
    let evidenceChallenge: EvidenceChallenge

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct ClueSet: Codable {
    let hard: String
    let medium: String
    let easy: String
}

struct EvidenceChallenge: Codable {
    let instruction: String
    let question: String
}
