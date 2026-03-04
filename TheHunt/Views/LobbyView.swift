import SwiftUI

struct LobbyView: View {
    @Environment(GameViewModel.self) private var viewModel
    @State private var countdown: String = "--:--:--"
    @State private var timeRemaining: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Text(viewModel.huntData?.hunt.title ?? "The Hunt")
                    .font(.largeTitle.bold())

                Text(viewModel.huntData?.hunt.description ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Countdown
                VStack(spacing: 8) {
                    Text("Starting in")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(countdown)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                }
                .padding(32)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))

                // Team card
                if let team = viewModel.team {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(team.name, systemImage: "person.3.fill")
                            .font(.title2.bold())
                        ForEach(team.players) { player in
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                                Text(player.name)
                            }
                            .font(.body)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Debug: Start now button (for testing)
                if timeRemaining > 60 {
                    Button("Start Now (Debug)") {
                        viewModel.startHunt()
                    }
                    .buttonStyle(.glass)
                    .font(.footnote)
                }

                Text("All teams start simultaneously")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            startCountdownTimer()
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private func startCountdownTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                updateCountdown()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func updateCountdown() {
        guard let startTime = viewModel.huntData?.hunt.startTime else {
            countdown = "--:--:--"
            return
        }
        let remaining = startTime.timeIntervalSinceNow
        timeRemaining = remaining
        if remaining <= 0 {
            timerTask?.cancel()
            viewModel.startHunt()
            return
        }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        withAnimation {
            countdown = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

#Preview {
    let vm = GameViewModel()
    vm.createTeam(name: "Test Team", playerNames: ["Alice", "Bob"])
    return LobbyView()
        .environment(vm)
}
