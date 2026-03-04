import SwiftUI

struct WelcomeView: View {
    @Environment(GameViewModel.self) private var viewModel
    @State private var teamName = ""
    @State private var playerNames = [""]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo.opacity(0.3), .purple.opacity(0.2), .blue.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // App title
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
                    .padding(.top, 60)

                    // Team entry
                    VStack(spacing: 16) {
                        TextField("Team Name", text: $teamName)
                            .font(.title2)
                            .textFieldStyle(.plain)
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))

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

                    Spacer(minLength: 40)

                    Button {
                        viewModel.createTeam(name: teamName, playerNames: playerNames)
                    } label: {
                        Text("Join The Hunt")
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
        }
    }
}

#Preview {
    WelcomeView()
        .environment(GameViewModel())
}
