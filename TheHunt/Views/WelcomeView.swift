import SwiftUI

// MARK: - Deprecated
// This view is no longer reachable from ContentView. Team creation and joining
// now goes through TeamSetupView / TeamLobbyView via TeamManager.
// Kept for reference — safe to delete.

struct WelcomeView: View {
    @Environment(GameViewModel.self) private var viewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showCreateTeam = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showCreateTeam {
                CreateTeamView(showCreateTeam: $showCreateTeam)
            } else {
                VStack(spacing: 32) {
                    Spacer()

                    // Greeting
                    VStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 56))
                            .foregroundStyle(.primary)
                        if let profile = authViewModel.userProfile {
                            Text("Welcome, \(profile.displayName)!")
                                .font(.title.bold())
                        } else {
                            Text("The Hunt")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                        }
                        Text("Join a team or start your own")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Team options
                    VStack(spacing: 16) {
                        Button {
                            withAnimation {
                                showCreateTeam = true
                            }
                        } label: {
                            Label("Create a Team", systemImage: "plus.circle.fill")
                                .font(.title2.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glassProminent)

                        Button {
                            // TODO: Join team flow
                        } label: {
                            Label("Join a Team", systemImage: "person.2.fill")
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
        .animation(.smooth(duration: 0.35), value: showCreateTeam)
    }
}

// MARK: - Create Team

private struct CreateTeamView: View {
    @Environment(GameViewModel.self) private var viewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @Binding var showCreateTeam: Bool
    @State private var teamName = ""
    @State private var playerNames = [""]
    @State private var selectedAvatar: TeamAvatar = .emoji("🔥")

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                HStack {
                    Button {
                        withAnimation {
                            showCreateTeam = false
                        }
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

                // Team entry
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Team Name", text: $teamName)
                            .font(.title2)
                            .textFieldStyle(.plain)
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                            .onChange(of: teamName) { _, _ in
                                viewModel.errorMessage = nil
                            }
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.leading, 4)
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(playerNames.indices, id: \.self) { index in
                            TextField("Player \(index + 1)", text: $playerNames[index])
                                .textFieldStyle(.plain)
                                .padding()
                                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        }
                    }

                    if playerNames.count < 6 {
                        Button {
                            withAnimation {
                                playerNames.append("")
                            }
                        } label: {
                            Label("Add Player", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 24)

                // Avatar picker
                TeamAvatarPickerView(selectedAvatar: $selectedAvatar)
                    .padding(.horizontal, 24)

                Spacer(minLength: 40)

                Button {
                    viewModel.createTeam(name: teamName, playerNames: playerNames, avatar: selectedAvatar)
                } label: {
                    Text("Create Team")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .disabled(teamName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if let name = authViewModel.userProfile?.displayName, playerNames == [""] {
                playerNames[0] = name
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environment(GameViewModel())
        .environment(AuthViewModel())
}
