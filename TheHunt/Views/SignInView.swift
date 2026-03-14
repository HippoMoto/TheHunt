import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App branding
                VStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 56))
                        .foregroundStyle(.primary)
                    Text("The Hunt")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text("Cambridge Scavenger Hunt")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if authViewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    VStack(spacing: 16) {
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            let hashedNonce = authViewModel.generateNonce()
                            request.requestedScopes = [.fullName]
                            request.nonce = hashedNonce
                        } onCompletion: { result in
                            authViewModel.handleSignInWithApple(result: result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        #if DEBUG
                        Button("Continue Without Sign In (Debug)") {
                            authViewModel.signInAnonymously()
                        }
                        .buttonStyle(.glass)
                        .font(.footnote)
                        #endif
                    }
                    .padding(.horizontal, 40)
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
    }
}
