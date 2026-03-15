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

    // MARK: - Permission Helper

    /// Returns true if the current user can perform manager-level actions.
    /// When managementMode is .allMembers, all members get manager powers
    /// except for delete-team and toggle-management-mode.
    func currentUserCanManage(restrictedAction: Bool = false) -> Bool {
        guard let uid = currentUID, let team = currentTeam else { return false }
        if uid == team.creatorUid { return true }
        if restrictedAction { return false }
        return team.managementMode == .allMembers
    }

    // MARK: - Create Team

    func createTeam(name: String, avatar: TeamAvatar = .none) async {
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
                createdAt: Date(),
                avatar: avatar,
                managementMode: .managerOnly,
                lockedAt: nil
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

    // MARK: - Rename Team

    func renameTeam(_ newName: String) async {
        guard currentUserCanManage() else {
            errorMessage = "Only the team manager can rename the team."
            return
        }
        guard let team = currentTeam else { return }
        guard !team.isLocked else {
            errorMessage = "Can't rename a team during an active hunt."
            return
        }

        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Team name can't be empty."
            return
        }
        guard trimmed.count <= 30 else {
            errorMessage = "Team name must be 30 characters or fewer."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await dbRef.child("teams").child(team.id).child("name").setValue(trimmed)
            currentTeam?.name = trimmed
            errorMessage = nil
        } catch {
            errorMessage = "Failed to rename team: \(error.localizedDescription)"
        }
    }

    // MARK: - Update Avatar

    func updateAvatar(_ avatar: TeamAvatar) async {
        guard currentUserCanManage() else {
            errorMessage = "Only the team manager can change the avatar."
            return
        }
        guard let team = currentTeam else { return }
        guard !team.isLocked else {
            errorMessage = "Can't change avatar during an active hunt."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await dbRef.child("teams").child(team.id).child("avatar").setValue(avatar.toDict())
            currentTeam?.avatar = avatar
            errorMessage = nil
        } catch {
            errorMessage = "Failed to update avatar: \(error.localizedDescription)"
        }
    }

    // MARK: - Kick Member

    func kickMember(uid targetUID: String) async {
        guard currentUserCanManage() else {
            errorMessage = "You don't have permission to kick members."
            return
        }
        guard let team = currentTeam else { return }
        guard !team.isLocked else {
            errorMessage = "Can't kick members during an active hunt."
            return
        }
        guard targetUID != currentUID else {
            errorMessage = "You can't kick yourself. Use leave instead."
            return
        }
        guard targetUID != team.creatorUid else {
            errorMessage = "You can't kick the team creator."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var updatedMembers = team.members.filter { $0 != targetUID }
            if updatedMembers.isEmpty { updatedMembers = team.members } // safety

            try await dbRef.child("teams").child(team.id).child("members").setValue(updatedMembers)
            try await dbRef.child("users").child(targetUID).child("teamId").removeValue()

            currentTeam?.members = updatedMembers
            memberProfiles.removeAll { $0.uid == targetUID }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to kick member: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete Team

    func deleteTeam() async {
        guard currentUserCanManage(restrictedAction: true) else {
            errorMessage = "Only the team creator can delete the team."
            return
        }
        guard let team = currentTeam else { return }
        guard !team.isLocked else {
            errorMessage = "Can't delete a team during an active hunt."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Clear teamId for all members
            for memberUID in team.members {
                try await dbRef.child("users").child(memberUID).child("teamId").removeValue()
            }

            // Remove join code index
            try await dbRef.child("joinCodes").child(team.joinCode).removeValue()

            // Remove team document
            try await dbRef.child("teams").child(team.id).removeValue()

            removeAllListeners()
            currentTeam = nil
            memberProfiles = []
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete team: \(error.localizedDescription)"
        }
    }

    // MARK: - Lock Team for Hunt

    func lockTeamForHunt() async {
        guard let team = currentTeam else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let now = Date()
            let updates: [String: Any] = [
                "status": "locked",
                "lockedAt": now.timeIntervalSince1970
            ]
            try await dbRef.child("teams").child(team.id).updateChildValues(updates)

            currentTeam?.status = "locked"
            currentTeam?.lockedAt = now
        } catch {
            errorMessage = "Failed to lock team: \(error.localizedDescription)"
        }
    }

    // MARK: - Toggle Management Mode

    func toggleManagementMode() async {
        guard currentUserCanManage(restrictedAction: true) else {
            errorMessage = "Only the team creator can change the management mode."
            return
        }
        guard let team = currentTeam else { return }
        guard !team.isLocked else {
            errorMessage = "Can't change management mode during an active hunt."
            return
        }

        isLoading = true
        defer { isLoading = false }

        let newMode: ManagementMode = team.managementMode == .managerOnly ? .allMembers : .managerOnly

        do {
            try await dbRef.child("teams").child(team.id).child("managementMode").setValue(newMode.rawValue)
            currentTeam?.managementMode = newMode
            errorMessage = nil
        } catch {
            errorMessage = "Failed to update management mode: \(error.localizedDescription)"
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

            guard !team.isLocked else {
                errorMessage = "This team's roster is locked for an active hunt."
                return
            }

            guard !team.isFull else {
                errorMessage = "This team is full (max \(FirebaseTeam.maxMembers) members)."
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

        guard !team.isLocked else {
            errorMessage = "You can't leave a team during an active hunt."
            return
        }

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
                    // Team was deleted
                    self.removeAllListeners()
                    self.currentTeam = nil
                    self.memberProfiles = []
                    return
                }

                // Check if current user was kicked (no longer in members)
                if let uid = self.currentUID, !team.members.contains(uid) {
                    self.removeAllListeners()
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
