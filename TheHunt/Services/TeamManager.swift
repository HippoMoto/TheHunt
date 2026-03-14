import Foundation
import Observation
import FirebaseAuth
import FirebaseDatabase

@Observable
@MainActor
class TeamManager {
    // MARK: - Published Properties

    var currentTeam: FirebaseTeam?
    var memberProfiles: [UserProfile] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - Private

    @ObservationIgnored
    private var dbRef: DatabaseReference { Database.database().reference() }

    @ObservationIgnored
    private var teamListenerHandle: DatabaseHandle?

    @ObservationIgnored
    private var teamListenerRef: DatabaseReference?

    @ObservationIgnored
    private var memberListenerHandles: [DatabaseHandle] = []

    @ObservationIgnored
    private var memberListenerRefs: [DatabaseReference] = []

    private var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Create Team

    func createTeam(name: String) async {
        guard let uid = currentUID else {
            errorMessage = "Not signed in."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let joinCode = try await generateUniqueJoinCode()
            let teamId = dbRef.child("teams").childByAutoId().key ?? UUID().uuidString

            let team = FirebaseTeam(
                id: teamId,
                name: name,
                joinCode: joinCode,
                creatorUid: uid,
                members: [uid],
                status: "waiting",
                createdAt: Date()
            )

            // Write team document
            try await dbRef.child("teams").child(teamId).setValue(team.toDict())

            // Index join code for lookup
            try await dbRef.child("joinCodes").child(joinCode).setValue(teamId)

            // Update user's teamId
            try await dbRef.child("users").child(uid).child("teamId").setValue(teamId)

            currentTeam = team
            errorMessage = nil
            listenToTeam(teamId: teamId)
        } catch {
            errorMessage = "Failed to create team: \(error.localizedDescription)"
        }
    }

    // MARK: - Join Team by Code

    func joinTeamByCode(_ code: String) async {
        guard let uid = currentUID else {
            errorMessage = "Not signed in."
            return
        }

        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespaces)

        guard normalizedCode.count == 6 else {
            errorMessage = "Join code must be 6 characters."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Check user isn't already on a team
            let userSnap = try await fetchSnapshot(at: dbRef.child("users").child(uid).child("teamId"))
            if let existingTeamId = userSnap.value as? String, !existingTeamId.isEmpty {
                errorMessage = "You're already on a team. Leave your current team first."
                return
            }

            // Look up team ID from join code index
            let codeSnap = try await fetchSnapshot(at: dbRef.child("joinCodes").child(normalizedCode))
            guard let teamId = codeSnap.value as? String else {
                errorMessage = "No team found with that code."
                return
            }

            // Fetch the team
            let teamSnap = try await fetchSnapshot(at: dbRef.child("teams").child(teamId))
            guard
                let dict = teamSnap.value as? [String: Any],
                let team = FirebaseTeam.fromDict(id: teamId, dict)
            else {
                errorMessage = "Team not found."
                return
            }

            guard team.status == "waiting" else {
                errorMessage = "This team is no longer accepting members."
                return
            }

            // Add user to members array
            var updatedMembers = team.members
            if !updatedMembers.contains(uid) {
                updatedMembers.append(uid)
            }
            try await dbRef.child("teams").child(teamId).child("members").setValue(updatedMembers)

            // Update user's teamId
            try await dbRef.child("users").child(uid).child("teamId").setValue(teamId)

            var updatedTeam = team
            updatedTeam.members = updatedMembers
            currentTeam = updatedTeam
            errorMessage = nil
            listenToTeam(teamId: teamId)
        } catch {
            errorMessage = "Failed to join team: \(error.localizedDescription)"
        }
    }

    // MARK: - Leave Team

    func leaveTeam() async {
        guard let uid = currentUID, let team = currentTeam else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let updatedMembers = team.members.filter { $0 != uid }

            if updatedMembers.isEmpty {
                // Last member — delete the team and join code index
                try await dbRef.child("teams").child(team.id).removeValue()
                try await dbRef.child("joinCodes").child(team.joinCode).removeValue()
            } else {
                // Remove from members
                try await dbRef.child("teams").child(team.id).child("members").setValue(updatedMembers)

                // If creator is leaving, transfer to next member
                if team.creatorUid == uid {
                    let newCreator = updatedMembers[0]
                    try await dbRef.child("teams").child(team.id).child("creatorUid").setValue(newCreator)
                }
            }

            // Clear user's teamId
            try await dbRef.child("users").child(uid).child("teamId").removeValue()

            removeAllListeners()
            currentTeam = nil
            memberProfiles = []
            errorMessage = nil
        } catch {
            errorMessage = "Failed to leave team: \(error.localizedDescription)"
        }
    }

    // MARK: - Listen to Team

    func listenToTeam(teamId: String) {
        removeTeamListener()

        let ref = dbRef.child("teams").child(teamId)
        teamListenerRef = ref

        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self else { return }
                guard
                    let dict = snapshot.value as? [String: Any],
                    let team = FirebaseTeam.fromDict(id: teamId, dict)
                else {
                    self.currentTeam = nil
                    self.memberProfiles = []
                    return
                }

                self.currentTeam = team
                self.listenToMembers(uids: team.members)
            }
        }
        teamListenerHandle = handle
    }

    // MARK: - Listen to Members

    private func listenToMembers(uids: [String]) {
        removeMemberListeners()

        for uid in uids {
            let ref = dbRef.child("users").child(uid)
            memberListenerRefs.append(ref)

            let handle = ref.observe(.value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self else { return }
                    guard
                        let dict = snapshot.value as? [String: Any],
                        let profile = UserProfile.fromDict(uid: uid, dict)
                    else { return }

                    if let index = self.memberProfiles.firstIndex(where: { $0.uid == uid }) {
                        self.memberProfiles[index] = profile
                    } else {
                        self.memberProfiles.append(profile)
                    }

                    // Remove profiles for members no longer in the team
                    if let team = self.currentTeam {
                        self.memberProfiles.removeAll { !team.members.contains($0.uid) }
                    }
                }
            }
            memberListenerHandles.append(handle)
        }
    }

    // MARK: - Restore from User Profile

    func restoreTeamIfNeeded(teamId: String?) {
        guard let teamId, !teamId.isEmpty else {
            currentTeam = nil
            memberProfiles = []
            return
        }
        listenToTeam(teamId: teamId)
    }

    // MARK: - Cleanup

    private func removeTeamListener() {
        if let handle = teamListenerHandle, let ref = teamListenerRef {
            ref.removeObserver(withHandle: handle)
        }
        teamListenerHandle = nil
        teamListenerRef = nil
    }

    private func removeMemberListeners() {
        for (handle, ref) in zip(memberListenerHandles, memberListenerRefs) {
            ref.removeObserver(withHandle: handle)
        }
        memberListenerHandles.removeAll()
        memberListenerRefs.removeAll()
    }

    func removeAllListeners() {
        removeTeamListener()
        removeMemberListeners()
    }

    // MARK: - Join Code Generation

    private func generateUniqueJoinCode() async throws -> String {
        let charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no I/O/0/1 to avoid confusion
        for _ in 0..<10 {
            var code = ""
            for _ in 0..<6 {
                let index = Int.random(in: 0..<charset.count)
                code.append(charset[charset.index(charset.startIndex, offsetBy: index)])
            }

            // Check uniqueness
            let snap = try await fetchSnapshot(at: dbRef.child("joinCodes").child(code))
            if !snap.exists() {
                return code
            }
        }
        throw NSError(domain: "TeamManager", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not generate a unique join code. Please try again."
        ])
    }

    // MARK: - Firebase Helper

    /// Fetches a snapshot using observeSingleEvent instead of getData(),
    /// which works reliably even when the client is briefly offline at startup.
    private func fetchSnapshot(at ref: DatabaseReference) async throws -> DataSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            ref.observeSingleEvent(of: .value, with: { snapshot in
                continuation.resume(returning: snapshot)
            }, withCancel: { error in
                continuation.resume(throwing: error)
            })
        }
    }
}
