import SwiftUI

struct ArrivalCelebrationView: View {
    @Environment(GameViewModel.self) private var viewModel
    @State private var showContent = false

    private var lastCompleted: CompletedLocation? {
        viewModel.team?.completedLocations.last
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)
                    .scaleEffect(showContent ? 1.0 : 0.3)

                Text("Location Found!")
                    .font(.largeTitle.bold())

                if let location = viewModel.currentTargetLocation {
                    Text(location.name)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                if let completed = lastCompleted {
                    VStack(spacing: 8) {
                        Text("+\(completed.pointsAwarded)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                        Text("points")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Solved with \(completed.hardestClueUsed.label) clue")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Continue") {
                    viewModel.advanceToNextLocation()
                }
                .buttonStyle(.glassProminent)
                .font(.title3.weight(.semibold))
                .padding(.top, 12)
            }
            .padding(32)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
            .padding(.horizontal, 24)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 50)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                showContent = true
            }
        }
    }
}
