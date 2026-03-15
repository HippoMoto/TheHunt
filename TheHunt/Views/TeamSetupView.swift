import SwiftUI

struct TeamSetupView: View {
    @Environment(TeamManager.self) private var teamManager
    @State private var mode: TeamSetupMode?

    enum TeamSetupMode {
        case create
        case join
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch mode {
            case .none:
                choiceView
            case .create:
                CreateTeamFormView(onBack: { withAnimation { mode = nil } })
            case .join:
                JoinTeamFormView(onBack: { withAnimation { mode = nil } })
            }
        }
        .animation(.smooth(duration: 0.35), value: mode)
    }

    private var choiceView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.primary)
                Text("Join or Create a Team")
                    .font(.title.bold())
                Text("Team up to start the hunt")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                Button {
                    withAnimation { mode = .create }
                } label: {
                    Label("Create a Team", systemImage: "plus.circle.fill")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)

                Button {
                    withAnimation { mode = .join }
                } label: {
                    Label("Join a Team", systemImage: "person.badge.plus")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Create Team Form

private struct CreateTeamFormView: View {
    @Environment(TeamManager.self) private var teamManager
    @State private var teamName = ""
    @State private var selectedAvatar: TeamAvatar = .emoji("🔥")
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Button {
                        onBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.glass)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Text("Create a Team")
                    .font(.largeTitle.bold())

                Text("Choose a name and avatar for your team.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                TextField("Team Name", text: $teamName)
                    .font(.title2)
                    .textFieldStyle(.plain)
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .padding(.horizontal, 24)
                    .onChange(of: teamName) { _, _ in
                        teamManager.errorMessage = nil
                    }

                TeamAvatarPickerView(selectedAvatar: $selectedAvatar)
                    .padding(.horizontal, 24)

                if let error = teamManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }

                if teamManager.isLoading {
                    ProgressView()
                }

                Spacer(minLength: 40)

                Button {
                    Task {
                        await teamManager.createTeam(
                            name: teamName.trimmingCharacters(in: .whitespaces),
                            avatar: selectedAvatar
                        )
                    }
                } label: {
                    Text("Create Team")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .disabled(teamName.trimmingCharacters(in: .whitespaces).isEmpty || teamManager.isLoading)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Join Team Form

private struct JoinTeamFormView: View {
    @Environment(TeamManager.self) private var teamManager
    @State private var joinCode = ""
    @State private var showScanner = false
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button {
                    onBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.glass)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            Text("Join a Team")
                .font(.largeTitle.bold())

            Text("Enter the 6-character code or scan a QR code.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            TextField("Join Code", text: $joinCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                .padding(.horizontal, 48)
                .onChange(of: joinCode) { _, newValue in
                    teamManager.errorMessage = nil
                    if newValue.count > 6 {
                        joinCode = String(newValue.prefix(6))
                    }
                }

            Button {
                showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.glass)

            if let error = teamManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
            }

            if teamManager.isLoading {
                ProgressView()
            }

            Spacer()

            Button {
                Task {
                    await teamManager.joinTeamByCode(joinCode)
                }
            } label: {
                Text("Join Team")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .disabled(joinCode.trimmingCharacters(in: .whitespaces).count != 6 || teamManager.isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView { scannedCode in
                joinCode = scannedCode
                Task {
                    await teamManager.joinTeamByCode(scannedCode)
                }
            }
        }
    }
}
#Preview {
    TeamSetupView()
        .environment(TeamManager())
}

