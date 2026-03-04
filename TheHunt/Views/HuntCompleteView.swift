import SwiftUI

struct HuntCompleteView: View {
    @Environment(GameViewModel.self) private var viewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.yellow.opacity(0.2), .orange.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.yellow)

                    Text("Hunt Complete!")
                        .font(.largeTitle.bold())

                    if let team = viewModel.team {
                        Text(team.name)
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("\(team.totalScore)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                        Text("Total Points")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        // Per-location breakdown
                        VStack(spacing: 12) {
                            ForEach(team.completedLocations) { completed in
                                if let location = viewModel.huntData?.locations.first(where: { $0.id == completed.locationID }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(location.name)
                                                .font(.headline)
                                            Text("\(completed.hardestClueUsed.label) clue")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("+\(completed.pointsAwarded)")
                                            .font(.title3.bold().monospacedDigit())
                                    }
                                    .padding(14)
                                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    Button("View Leaderboard") {
                        viewModel.generateLeaderboard()
                        viewModel.showLeaderboard = true
                    }
                    .buttonStyle(.glassProminent)
                    .font(.title3.weight(.semibold))
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .sheet(isPresented: Bindable(viewModel).showLeaderboard) {
            LeaderboardView()
        }
    }
}

#Preview {
    let vm = GameViewModel()
    vm.createTeam(name: "Test Team", playerNames: ["Alice", "Bob"])
    return HuntCompleteView()
        .environment(vm)
}
