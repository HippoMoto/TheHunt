import Foundation
import FirebaseAuth
import FirebaseDatabase
import AuthenticationServices

actor AuthenticationService {
    private var _dbRef: DatabaseReference?

    private var dbRef: DatabaseReference {
        if let ref = _dbRef { return ref }
        let ref = Database.database().reference()
        _dbRef = ref
        return ref
    }

    // MARK: - Auth State

    nonisolated var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Sign In with Apple

    func signInWithApple(idToken: String, nonce: String) async throws -> String {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user.uid
    }

    // MARK: - Anonymous Sign In (debug bypass)

    func signInAnonymously() async throws -> String {
        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - User Profile

    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DataSnapshot, Error>) in
            dbRef.child("users").child(uid).observeSingleEvent(of: .value, with: { snapshot in
                continuation.resume(returning: snapshot)
            }, withCancel: { error in
                continuation.resume(throwing: error)
            })
        }
        guard let dict = snapshot.value as? [String: Any] else { return nil }
        return UserProfile.fromDict(uid: uid, dict)
    }

    func saveUserProfile(_ profile: UserProfile) async throws {
        try await dbRef.child("users").child(profile.uid).setValue(profile.toDict())
    }

    func updateUserTeamId(uid: String, teamId: String?) async throws {
        let value: Any = teamId ?? NSNull()
        try await dbRef.child("users").child(uid).child("teamId").setValue(value)
    }

    // MARK: - Name Uniqueness

    func isUserNameAvailable(_ name: String) async throws -> Bool {
        let normalized = sanitize(name)
        let snapshot = try await dbRef.child("userNames").child(normalized).getData()
        return !snapshot.exists()
    }

    func isTeamNameAvailable(_ name: String) async throws -> Bool {
        let normalized = sanitize(name)
        let snapshot = try await dbRef.child("teamNames").child(normalized).getData()
        return !snapshot.exists()
    }

    /// Atomically claims a user name. Returns true if successful.
    func claimUserName(_ name: String, uid: String) async throws -> Bool {
        let normalized = sanitize(name)
        let ref = dbRef.child("userNames").child(normalized)
        return try await claimName(ref: ref, value: uid)
    }

    /// Atomically claims a team name. Returns true if successful.
    func claimTeamName(_ name: String, teamID: String) async throws -> Bool {
        let normalized = sanitize(name)
        let ref = dbRef.child("teamNames").child(normalized)
        return try await claimName(ref: ref, value: teamID)
    }

    // MARK: - Helpers

    private func sanitize(_ name: String) -> String {
        let trimmed = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // Firebase keys cannot contain . $ # [ ] /
        let forbidden = CharacterSet(charactersIn: ".#$[]/")
        return trimmed.components(separatedBy: forbidden).joined()
    }

    private func claimName(ref: DatabaseReference, value: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            ref.runTransactionBlock { currentData in
                if currentData.value is NSNull || currentData.value == nil {
                    currentData.value = value
                    return .success(withValue: currentData)
                }
                // Already taken
                return .abort()
            } andCompletionBlock: { error, committed, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: committed)
                }
            }
        }
    }
}
