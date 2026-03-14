import SwiftUI

struct ProfileSetupView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var displayName = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("What's Your Name?")
                    .font(.largeTitle.bold())

                Text("Choose a display name that your team will see. Emoji welcome!")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("Display Name", text: $displayName)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .padding(.horizontal, 24)
                    .onChange(of: displayName) { _, _ in
                        authViewModel.errorMessage = nil
                    }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }

                if authViewModel.isLoading {
                    ProgressView()
                }

                Spacer()

                Button {
                    authViewModel.saveProfile(
                        displayName: displayName.trimmingCharacters(in: .whitespaces)
                    )
                } label: {
                    Text("Continue")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .disabled(displayName.trimmingCharacters(in: .whitespaces).isEmpty || authViewModel.isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
