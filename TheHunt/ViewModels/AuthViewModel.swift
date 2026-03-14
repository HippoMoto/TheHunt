import Foundation
import Observation
import AuthenticationServices
@preconcurrency import CryptoKit

enum AuthState: Equatable {
    case unknown
    case signedOut
    case needsProfile
    case ready
}

@Observable
@MainActor
class AuthViewModel {
    // MARK: - State

    var authState: AuthState = .unknown
    var userProfile: UserProfile?
    var errorMessage: String?
    var isLoading = false

    @ObservationIgnored
    var currentNonce: String?

    // MARK: - Services

    @ObservationIgnored
    private lazy var authService = AuthenticationService()

    // MARK: - Check Existing Auth

    func checkAuthState() {
        Task {
            isLoading = true
            defer { isLoading = false }

            guard let uid = authService.currentUID else {
                authState = .signedOut
                return
            }

            do {
                if let profile = try await authService.fetchUserProfile(uid: uid) {
                    userProfile = profile
                    authState = .ready
                } else {
                    authState = .needsProfile
                }
            } catch {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
                authState = .needsProfile
            }
        }
    }

    // MARK: - Sign In with Apple

    func handleSignInWithApple(result: Result<ASAuthorization, any Error>) {
        Task {
            isLoading = true
            defer { isLoading = false }

            switch result {
            case .success(let authorization):
                guard
                    let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    let idTokenData = appleCredential.identityToken,
                    let idToken = String(data: idTokenData, encoding: .utf8),
                    let nonce = currentNonce
                else {
                    errorMessage = "Invalid Apple credential"
                    return
                }

                do {
                    let uid = try await authService.signInWithApple(
                        idToken: idToken, nonce: nonce
                    )
                    if let profile = try await authService.fetchUserProfile(uid: uid) {
                        userProfile = profile
                        authState = .ready
                    } else {
                        authState = .needsProfile
                    }
                } catch {
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                }

            case .failure(let error):
                if (error as? ASAuthorizationError)?.code != .canceled {
                    errorMessage = "Sign in failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Anonymous Sign In (debug bypass)

    func signInAnonymously() {
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let uid = try await authService.signInAnonymously()
                if let profile = try await authService.fetchUserProfile(uid: uid) {
                    userProfile = profile
                    authState = .ready
                } else {
                    authState = .needsProfile
                }
            } catch {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Profile Setup

    func saveProfile(displayName: String) {
        guard let uid = authService.currentUID else { return }

        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let claimed = try await authService.claimUserName(displayName, uid: uid)
                guard claimed else {
                    errorMessage = "That display name is already taken. Please choose another."
                    return
                }

                let profile = UserProfile(
                    uid: uid,
                    displayName: displayName,
                    teamId: nil,
                    createdAt: Date()
                )
                try await authService.saveUserProfile(profile)
                userProfile = profile
                errorMessage = nil
                authState = .ready
            } catch {
                errorMessage = "Failed to save profile: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Team Name Uniqueness

    func claimTeamName(_ name: String, teamID: String) async -> Bool {
        do {
            return try await authService.claimTeamName(name, teamID: teamID)
        } catch {
            return false
        }
    }

    func updateUserTeamId(_ teamId: String?) {
        guard let uid = userProfile?.uid else { return }
        Task {
            do {
                try await authService.updateUserTeamId(uid: uid, teamId: teamId)
                userProfile?.teamId = teamId
            } catch {
                errorMessage = "Failed to update team: \(error.localizedDescription)"
            }
        }
    }

    var currentUID: String? {
        authService.currentUID
    }

    // MARK: - Nonce (required for Sign in with Apple)

    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            fatalError("Unable to generate nonce: \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
