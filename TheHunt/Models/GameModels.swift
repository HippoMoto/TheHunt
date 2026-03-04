import Foundation

enum GamePhase: Equatable {
    case welcome
    case lobby
    case active
    case completed
}

enum ClueTier: Int, Comparable, CaseIterable, Hashable {
    case hard = 3
    case medium = 2
    case easy = 1

    static func < (lhs: ClueTier, rhs: ClueTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .hard: "Hard"
        case .medium: "Medium"
        case .easy: "Easy"
        }
    }

    var multiplier: Double {
        switch self {
        case .hard: 1.0
        case .medium: 0.6
        case .easy: 0.3
        }
    }
}

@Observable
class Team: Identifiable {
    let id: UUID
    var name: String
    var players: [Player]
    var completedLocations: [CompletedLocation]
    var currentLocationIndex: Int

    var totalScore: Int {
        completedLocations.reduce(0) { $0 + $1.pointsAwarded }
    }

    init(name: String, players: [Player] = []) {
        self.id = UUID()
        self.name = name
        self.players = players
        self.completedLocations = []
        self.currentLocationIndex = 0
    }
}

struct Player: Identifiable {
    let id: UUID
    var name: String

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}

struct CompletedLocation: Identifiable {
    let id: UUID
    let locationID: String
    let hardestClueUsed: ClueTier
    let arrivalTime: Date
    let locationStartTime: Date
    let pointsAwarded: Int

    init(locationID: String, hardestClueUsed: ClueTier, arrivalTime: Date, locationStartTime: Date, pointsAwarded: Int) {
        self.id = UUID()
        self.locationID = locationID
        self.hardestClueUsed = hardestClueUsed
        self.arrivalTime = arrivalTime
        self.locationStartTime = locationStartTime
        self.pointsAwarded = pointsAwarded
    }
}

struct LeaderboardEntry: Identifiable {
    let id: UUID
    let teamName: String
    let score: Int
    let locationsCompleted: Int

    init(teamName: String, score: Int, locationsCompleted: Int) {
        self.id = UUID()
        self.teamName = teamName
        self.score = score
        self.locationsCompleted = locationsCompleted
    }
}

struct ScoringEngine {
    static func calculateScore(
        maxPoints: Int,
        clueTier: ClueTier,
        secondsElapsed: TimeInterval,
        maxTimeSeconds: TimeInterval = 900
    ) -> Int {
        let tierMultiplier = clueTier.multiplier
        let timeFraction = max(0, min(1, 1.0 - (secondsElapsed / maxTimeSeconds) * 0.9))
        let score = Double(maxPoints) * tierMultiplier * timeFraction
        return max(Int(score.rounded()), 1)
    }
}
