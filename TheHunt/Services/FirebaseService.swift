import Foundation
import FirebaseDatabase

enum FirebaseServiceError: LocalizedError {
    case writeFailed(Error)
    case readFailed(Error)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let e): "Write failed: \(e.localizedDescription)"
        case .readFailed(let e): "Read failed: \(e.localizedDescription)"
        }
    }
}

actor FirebaseService {
    private var _dbRef: DatabaseReference?

    private var dbRef: DatabaseReference {
        if let ref = _dbRef { return ref }
        let ref = Database.database().reference()
        _dbRef = ref
        return ref
    }

    private var eventListenerHandle: DatabaseHandle?
    private var teamsListenerHandle: DatabaseHandle?
    private var eventListenerQuery: DatabaseQuery?
    private var teamsListenerRef: DatabaseReference?

    // MARK: - Path Helpers

    private func huntRef(_ huntID: String) -> DatabaseReference {
        dbRef.child("hunts").child(huntID)
    }

    private func teamsRef(_ huntID: String) -> DatabaseReference {
        huntRef(huntID).child("teams")
    }

    private func eventsRef(_ huntID: String) -> DatabaseReference {
        huntRef(huntID).child("events")
    }

    private func evidenceRef(_ huntID: String) -> DatabaseReference {
        huntRef(huntID).child("evidence")
    }

    // MARK: - Team Registration

    func registerTeam(huntID: String, teamID: String, teamData: [String: Any]) async throws {
        do {
            try await teamsRef(huntID).child(teamID).setValue(teamData)
        } catch {
            throw FirebaseServiceError.writeFailed(error)
        }
    }

    // MARK: - Team Progress

    func updateTeamProgress(huntID: String, teamID: String, updates: [String: Any]) async throws {
        do {
            try await teamsRef(huntID).child(teamID).updateChildValues(updates)
        } catch {
            throw FirebaseServiceError.writeFailed(error)
        }
    }

    func recordCompletedLocation(
        huntID: String,
        teamID: String,
        completed: CompletedLocation
    ) async throws {
        let data: [String: Any] = [
            "locationID": completed.locationID,
            "pointsAwarded": completed.pointsAwarded,
            "arrivalTime": completed.arrivalTime.timeIntervalSince1970
        ]
        do {
            try await teamsRef(huntID)
                .child(teamID)
                .child("completedLocations")
                .child(completed.id.uuidString)
                .setValue(data)
        } catch {
            throw FirebaseServiceError.writeFailed(error)
        }
    }

    // MARK: - Evidence Submission

    func submitEvidence(
        huntID: String,
        teamID: String,
        locationID: String,
        answer: String
    ) async throws {
        let key = "\(teamID)_\(locationID)"
        let data: [String: Any] = [
            "teamId": teamID,
            "locationId": locationID,
            "answer": answer,
            "status": "approved",
            "submittedAt": Date().timeIntervalSince1970
        ]
        do {
            try await evidenceRef(huntID).child(key).setValue(data)
        } catch {
            throw FirebaseServiceError.writeFailed(error)
        }
    }

    // MARK: - Game Events

    func broadcastEvent(huntID: String, event: GameEvent) async throws {
        do {
            try await eventsRef(huntID).childByAutoId().setValue(event.toDict())
        } catch {
            throw FirebaseServiceError.writeFailed(error)
        }
    }

    // MARK: - Real-Time Listeners

    func observeEvents(huntID: String, excludingTeamID: String) -> AsyncStream<GameEvent> {
        let query: DatabaseQuery = self.eventsRef(huntID)
            .queryOrdered(byChild: "timestamp")
            .queryStarting(atValue: Date().timeIntervalSince1970)

        self.eventListenerQuery = query

        let (stream, continuation) = AsyncStream<GameEvent>.makeStream()

        let handle = query.observe(.childAdded) { snapshot in
            guard
                let dict = snapshot.value as? [String: Any],
                let event = GameEvent.fromDict(id: snapshot.key, dict)
            else { return }

            if event.teamID != excludingTeamID {
                continuation.yield(event)
            }
        }

        self.eventListenerHandle = handle

        continuation.onTermination = { _ in
            query.removeObserver(withHandle: handle)
        }

        return stream
    }

    func observeLeaderboard(
        huntID: String,
        currentTeamID: String
    ) -> AsyncStream<[LeaderboardEntry]> {
        let ref = self.teamsRef(huntID)
        self.teamsListenerRef = ref

        let (stream, continuation) = AsyncStream<[LeaderboardEntry]>.makeStream()

        let handle = ref.observe(.value) { snapshot in
            var entries: [LeaderboardEntry] = []
            for child in snapshot.children {
                guard
                    let snap = child as? DataSnapshot,
                    let dict = snap.value as? [String: Any],
                    let name = dict["name"] as? String,
                    let score = dict["totalScore"] as? Int,
                    let locationsCompleted = dict["locationsCompleted"] as? Int
                else { continue }

                let avatarDict = dict["avatar"] as? [String: String] ?? [:]
                let avatar = TeamAvatar.fromDict(avatarDict)

                entries.append(LeaderboardEntry(
                    teamID: snap.key,
                    teamName: name,
                    avatar: avatar,
                    score: score,
                    locationsCompleted: locationsCompleted,
                    isCurrentTeam: snap.key == currentTeamID
                ))
            }

            entries.sort { a, b in
                if a.locationsCompleted != b.locationsCompleted {
                    return a.locationsCompleted > b.locationsCompleted
                }
                return a.score > b.score
            }

            continuation.yield(entries)
        }

        self.teamsListenerHandle = handle

        continuation.onTermination = { _ in
            ref.removeObserver(withHandle: handle)
        }

        return stream
    }

    // MARK: - Team Data Fetch

    func fetchTeamData(huntID: String, teamID: String) async throws -> [String: Any]? {
        do {
            let snapshot = try await teamsRef(huntID).child(teamID).getData()
            return snapshot.value as? [String: Any]
        } catch {
            throw FirebaseServiceError.readFailed(error)
        }
    }

    // MARK: - Cleanup

    func removeAllListeners() {
        if let handle = eventListenerHandle, let query = eventListenerQuery {
            query.removeObserver(withHandle: handle)
        }
        if let handle = teamsListenerHandle, let ref = teamsListenerRef {
            ref.removeObserver(withHandle: handle)
        }
        eventListenerHandle = nil
        teamsListenerHandle = nil
        eventListenerQuery = nil
        teamsListenerRef = nil
    }
}
