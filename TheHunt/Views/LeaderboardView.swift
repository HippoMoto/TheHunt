import SwiftUI

struct LeaderboardView: View {
    @Environment(GameViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(
                        Array(viewModel.leaderboardEntries.enumerated()),
                        id: \.element.id
                    ) { index, entry in
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.title2.bold())
                                .frame(width: 44)

                            TeamAvatarView(avatar: entry.avatar, size: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.teamName)
                                    .font(.headline)
                                Text("\(entry.locationsCompleted) locations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(entry.score) pts")
                                .font(.title3.bold().monospacedDigit())
                        }
                        .padding(16)
                        .glassEffect(
                            entry.isCurrentTeam
                                ? .regular.tint(.blue)
                                : .regular,
                            in: .rect(cornerRadius: 14)
                        )
                    }
                }
                .padding(16)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}
