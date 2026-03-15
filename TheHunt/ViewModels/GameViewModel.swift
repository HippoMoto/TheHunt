import Foundation
import Observation
import UIKit

@Observable
@MainActor
class GameViewModel {
    // MARK: - State

    var gamePhase: GamePhase = .authenticating
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

    // Evidence challenge state
    var showEvidenceChallenge = false
    var isSubmittingEvidence = false
    var pendingEvidenceLocation: HuntLocation?

    // Event banner state
    var currentBanner: GameEvent?
    var bannerQueue: [GameEvent] = []

    // MARK: - Services

    let locationManager = LocationManager()

    @ObservationIgnored
    private let dataService = HuntDataService()

    @ObservationIgnored
    private lazy var firebaseService = FirebaseService()

    @ObservationIgnored
    private var authViewModel: AuthViewModel?

    @ObservationIgnored
    private var teamManager: TeamManager?

    // MARK: - Constants

    private var huntID: String { huntData?.hunt.id ?? "cambridge_hunt_001" }

    // MARK: - Tasks

    @ObservationIgnored
    private var timerTask: Task<Void, Never>?

    @ObservationIgnored
    private var arrivalMonitorTask: Task<Void, Never>?

    @ObservationIgnored
    private var distanceUpdateTask: Task<Void, Never>?

    @ObservationIgnored
    private var eventListenerTask: Task<Void, Never>?

    @ObservationIgnored
    private var leaderboardListenerTask: Task<Void, Never>?

    @ObservationIgnored
    private var bannerDismissTask: Task<Void, Never>?

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

    // MARK: - Auth

    func onAuthReady(authViewModel: AuthViewModel, teamManager: TeamManager? = nil) {
        self.authViewModel = authViewModel
        self.teamManager = teamManager

        guard let profile = authViewModel.userProfile else {
            gamePhase = .welcome
            return
        }

        // Check if user has an existing team
        if let teamID = profile.teamId {
            Task {
                await restoreTeamState(teamID: teamID, huntID: huntID)
            }
        } else {
            gamePhase = .welcome
        }
    }

    private func restoreTeamState(teamID: String, huntID: String) async {
        do {
            guard let teamData = try await firebaseService.fetchTeamData(
                huntID: huntID, teamID: teamID
            ) else {
                gamePhase = .welcome
                return
            }

            let name = teamData["name"] as? String ?? "Unknown"
            let avatarDict = teamData["avatar"] as? [String: String] ?? [:]
            let avatar = TeamAvatar.fromDict(avatarDict)
            let locationIndex = teamData["currentLocationIndex"] as? Int ?? 0

            let restoredTeam = Team(name: name, players: [], avatar: avatar)
            restoredTeam.currentLocationIndex = locationIndex
            team = restoredTeam

            loadHuntData()
            currentLocationIndex = locationIndex

            if let huntData, locationIndex >= huntData.locations.count {
                gamePhase = .completed
            } else {
                gamePhase = .lobby
            }
        } catch {
            errorMessage = "Failed to restore team: \(error.localizedDescription)"
            gamePhase = .welcome
        }
    }

    // MARK: - Actions

    func loadHuntData() {
        do {
            huntData = try dataService.loadHuntData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // TODO: Reconcile with TeamManager.createTeam() — this is a separate code path
    // that registers with FirebaseService (hunt teams) rather than the teams collection.
    // The TeamManager path is the primary one for team management features.
    func createTeam(name: String, playerNames: [String], avatar: TeamAvatar = .none) {
        Task {
            // Claim team name atomically
            if let authViewModel {
                let claimed = await authViewModel.claimTeamName(
                    name, teamID: UUID().uuidString
                )
                guard claimed else {
                    errorMessage = "That team name is already taken. Please choose another."
                    return
                }
            }

            let players = playerNames
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { Player(name: $0) }
            let newTeam = Team(name: name, players: players, avatar: avatar)
            team = newTeam
            loadHuntData()
            gamePhase = .lobby

            // Register team with Firebase
            let teamData: [String: Any] = [
                "name": newTeam.name,
                "avatar": newTeam.avatar.toDict(),
                "currentLocationIndex": 0,
                "totalScore": 0,
                "locationsCompleted": 0,
                "joinedAt": Date().timeIntervalSince1970
            ]
            do {
                try await firebaseService.registerTeam(
                    huntID: huntID,
                    teamID: newTeam.id.uuidString,
                    teamData: teamData
                )
                // Record user's team membership
                authViewModel?.updateUserTeamId(newTeam.id.uuidString)
            } catch {
                errorMessage = "Failed to register team: \(error.localizedDescription)"
            }
        }
    }

    func startHunt() {
        // Lock team roster before starting
        if let teamManager {
            Task { await teamManager.lockTeamForHunt() }
        }

        gamePhase = .active
        locationManager.requestAuthorization()
        locationManager.startUpdates()
        startNewLocation()
        startEventListener()
        startLeaderboardListener()
    }

    func advanceToNextLocation() {
        showArrivalCelebration = false
        currentLocationIndex += 1
        team?.currentLocationIndex = currentLocationIndex

        if isHuntFinished {
            locationManager.stopUpdates()
            cancelAllTasks()
            gamePhase = .completed

            // Broadcast hunt completed event
            broadcastEvent(type: .huntCompleted, locationName: nil)
        } else {
            startNewLocation()
        }
    }

    // MARK: - Evidence Challenge

    func submitEvidence(answer: String) {
        guard let location = pendingEvidenceLocation, let team else { return }
        isSubmittingEvidence = true

        Task {
            do {
                try await firebaseService.submitEvidence(
                    huntID: huntID,
                    teamID: team.id.uuidString,
                    locationID: location.id,
                    answer: answer
                )
                broadcastEvent(type: .evidenceSubmitted, locationName: location.name)
            } catch {
                errorMessage = "Failed to submit evidence: \(error.localizedDescription)"
            }

            isSubmittingEvidence = false
            showEvidenceChallenge = false
            pendingEvidenceLocation = nil
            showArrivalCelebration = true
        }
    }

    func skipEvidence() {
        showEvidenceChallenge = false
        pendingEvidenceLocation = nil
        showArrivalCelebration = true
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
            broadcastEvent(type: .clueUnlockedMedium, locationName: currentTargetLocation?.name)

            // Wait for easy reveal
            let additionalWait = (hunt.easyRevealMinutes - hunt.mediumRevealMinutes) * 60
            try? await Task.sleep(for: .seconds(additionalWait))
            guard !Task.isCancelled else { return }
            revealedTiers.insert(.easy)
            broadcastEvent(type: .clueUnlockedEasy, locationName: currentTargetLocation?.name)
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

        // Update Firebase with progress
        Task {
            guard let team else { return }
            let updates: [String: Any] = [
                "currentLocationIndex": team.currentLocationIndex,
                "totalScore": team.totalScore,
                "locationsCompleted": team.completedLocations.count
            ]
            do {
                try await firebaseService.updateTeamProgress(
                    huntID: huntID,
                    teamID: team.id.uuidString,
                    updates: updates
                )
                try await firebaseService.recordCompletedLocation(
                    huntID: huntID,
                    teamID: team.id.uuidString,
                    completed: completed
                )
            } catch {
                errorMessage = "Failed to update progress: \(error.localizedDescription)"
            }
        }

        // Broadcast arrival event
        broadcastEvent(type: .arrivedAtLocation, locationName: location.name)

        // Show evidence challenge instead of celebration directly
        pendingEvidenceLocation = location
        showEvidenceChallenge = true
    }

    // MARK: - Event Broadcasting

    private func broadcastEvent(type: GameEventType, locationName: String?) {
        guard let team else { return }
        let event = GameEvent(
            id: UUID().uuidString,
            teamID: team.id.uuidString,
            teamName: team.name,
            avatar: team.avatar,
            eventType: type,
            locationName: locationName,
            timestamp: Date()
        )
        Task {
            do {
                try await firebaseService.broadcastEvent(huntID: huntID, event: event)
            } catch {
                // Non-critical failure, don't show error to user
            }
        }
    }

    // MARK: - Real-Time Listeners

    private func startEventListener() {
        guard let team else { return }
        eventListenerTask?.cancel()

        eventListenerTask = Task {
            let stream = await firebaseService.observeEvents(
                huntID: huntID,
                excludingTeamID: team.id.uuidString
            )
            for await event in stream {
                guard !Task.isCancelled else { break }
                bannerQueue.append(event)
                showNextBannerIfNeeded()
            }
        }
    }

    private func showNextBannerIfNeeded() {
        guard currentBanner == nil, !bannerQueue.isEmpty else { return }
        currentBanner = bannerQueue.removeFirst()

        bannerDismissTask?.cancel()
        bannerDismissTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            currentBanner = nil
            // Show next banner if any queued
            if !bannerQueue.isEmpty {
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                showNextBannerIfNeeded()
            }
        }
    }

    func dismissBanner() {
        bannerDismissTask?.cancel()
        currentBanner = nil
        if !bannerQueue.isEmpty {
            Task {
                try? await Task.sleep(for: .seconds(0.3))
                showNextBannerIfNeeded()
            }
        }
    }

    private func startLeaderboardListener() {
        guard let team else { return }
        leaderboardListenerTask?.cancel()

        leaderboardListenerTask = Task {
            let stream = await firebaseService.observeLeaderboard(
                huntID: huntID,
                currentTeamID: team.id.uuidString
            )
            for await entries in stream {
                guard !Task.isCancelled else { break }
                leaderboardEntries = entries
            }
        }
    }

    // MARK: - Cleanup

    private func cancelAllTasks() {
        timerTask?.cancel()
        arrivalMonitorTask?.cancel()
        distanceUpdateTask?.cancel()
        eventListenerTask?.cancel()
        leaderboardListenerTask?.cancel()
        bannerDismissTask?.cancel()

        Task {
            await firebaseService.removeAllListeners()
        }
    }

    #if DEBUG
    func debugSimulateArrival() {
        guard let currentTarget = currentTargetLocation else { return }
        handleArrival(at: currentTarget)
    }
    #endif
}
