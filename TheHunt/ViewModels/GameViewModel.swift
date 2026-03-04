import Foundation
import Observation
import UIKit

@Observable
@MainActor
class GameViewModel {
    // MARK: - State

    var gamePhase: GamePhase = .welcome
    var team: Team?
    var huntData: HuntData?
    var currentLocationIndex: Int = 0
    var revealedTiers: Set<ClueTier> = [.hard]
    var locationStartTime: Date?
    var showArrivalCelebration = false
    var showLeaderboard = false
    var leaderboardEntries: [LeaderboardEntry] = []
    var distanceToTarget: Double?
    var errorMessage: String?

    // MARK: - Services

    let locationManager = LocationManager()

    @ObservationIgnored
    private let dataService = HuntDataService()

    // MARK: - Tasks

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?

    @ObservationIgnored
    private var arrivalMonitorTask: Task<Void, Never>?

    @ObservationIgnored
    private var distanceUpdateTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var currentTargetLocation: HuntLocation? {
        guard let huntData, currentLocationIndex < huntData.locations.count else { return nil }
        return huntData.locations.sorted(by: { $0.order < $1.order })[currentLocationIndex]
    }

    var huntProgress: String {
        guard let huntData else { return "" }
        return "\(currentLocationIndex + 1) of \(huntData.locations.count)"
    }

    var isHuntFinished: Bool {
        guard let huntData else { return false }
        return currentLocationIndex >= huntData.locations.count
    }

    var secondsSinceLocationStart: TimeInterval {
        guard let start = locationStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Actions

    func loadHuntData() {
        do {
            huntData = try dataService.loadHuntData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTeam(name: String, playerNames: [String]) {
        let players = playerNames
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { Player(name: $0) }
        team = Team(name: name, players: players)
        loadHuntData()
        gamePhase = .lobby
    }

    func startHunt() {
        gamePhase = .active
        locationManager.requestAuthorization()
        locationManager.startUpdates()
        startNewLocation()
    }

    func advanceToNextLocation() {
        showArrivalCelebration = false
        currentLocationIndex += 1

        if isHuntFinished {
            locationManager.stopUpdates()
            cancelAllTasks()
            generateLeaderboard()
            gamePhase = .completed
        } else {
            startNewLocation()
        }
    }

    // MARK: - Private Methods

    private func startNewLocation() {
        revealedTiers = [.hard]
        locationStartTime = Date()
        startClueRevealTimer()
        startArrivalMonitoring()
        startDistanceUpdates()
    }

    private func startClueRevealTimer() {
        timerTask?.cancel()

        guard let hunt = huntData?.hunt else { return }

        timerTask = Task {
            // Wait for medium reveal
            try? await Task.sleep(for: .seconds(hunt.mediumRevealMinutes * 60))
            guard !Task.isCancelled else { return }
            revealedTiers.insert(.medium)

            // Wait for easy reveal
            let additionalWait = (hunt.easyRevealMinutes - hunt.mediumRevealMinutes) * 60
            try? await Task.sleep(for: .seconds(additionalWait))
            guard !Task.isCancelled else { return }
            revealedTiers.insert(.easy)
        }
    }

    private func startArrivalMonitoring() {
        arrivalMonitorTask?.cancel()

        arrivalMonitorTask = Task {
            while !Task.isCancelled {
                guard let currentTarget = currentTargetLocation else { break }
                if locationManager.isWithinRadius(
                    of: currentTarget.clLocation,
                    radius: currentTarget.arrivalRadiusMeters
                ) {
                    handleArrival(at: currentTarget)
                    break
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func startDistanceUpdates() {
        distanceUpdateTask?.cancel()

        distanceUpdateTask = Task {
            while !Task.isCancelled {
                guard let currentTarget = currentTargetLocation else { break }
                distanceToTarget = locationManager.distanceToTarget(currentTarget.clLocation)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func handleArrival(at location: HuntLocation) {
        // Determine the easiest (highest value) clue tier revealed
        let currentTier = revealedTiers.max() ?? .hard

        let points = ScoringEngine.calculateScore(
            maxPoints: huntData?.hunt.maxPointsPerLocation ?? 100,
            clueTier: currentTier,
            secondsElapsed: secondsSinceLocationStart
        )

        let completed = CompletedLocation(
            locationID: location.id,
            hardestClueUsed: currentTier,
            arrivalTime: Date(),
            locationStartTime: locationStartTime ?? Date(),
            pointsAwarded: points
        )

        team?.completedLocations.append(completed)

        // Stop current monitoring tasks
        timerTask?.cancel()
        arrivalMonitorTask?.cancel()
        distanceUpdateTask?.cancel()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        showArrivalCelebration = true
    }

    private func cancelAllTasks() {
        timerTask?.cancel()
        arrivalMonitorTask?.cancel()
        distanceUpdateTask?.cancel()
    }

    func generateLeaderboard() {
        guard let team else { return }

        // Real team entry
        var entries: [LeaderboardEntry] = [
            LeaderboardEntry(
                teamName: team.name,
                score: team.totalScore,
                locationsCompleted: team.completedLocations.count
            )
        ]

        // Mock competitor entries for demonstration
        let mockTeams = [
            ("The Scholars", 0.85),
            ("Cam Runners", 0.70),
            ("Punting Pros", 0.55),
            ("Bridge Crew", 0.40),
        ]
        let locationCount = huntData?.locations.count ?? 5
        let maxPossible = (huntData?.hunt.maxPointsPerLocation ?? 100) * locationCount

        for (name, factor) in mockTeams {
            let mockScore = Int(Double(maxPossible) * factor * Double.random(in: 0.8...1.0))
            let mockLocations = min(locationCount, Int(Double(locationCount) * factor) + 1)
            entries.append(
                LeaderboardEntry(teamName: name, score: mockScore, locationsCompleted: mockLocations)
            )
        }

        leaderboardEntries = entries
    }
}
