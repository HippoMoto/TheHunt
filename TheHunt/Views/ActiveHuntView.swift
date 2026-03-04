import SwiftUI

struct ActiveHuntView: View {
    @Environment(GameViewModel.self) private var viewModel
    @Namespace private var clueNamespace
    @State private var elapsedTime: TimeInterval = 0
    @State private var elapsedTimerTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.08), .indigo.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header bar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Location \(viewModel.huntProgress)")
                            .font(.headline)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("\(viewModel.team?.totalScore ?? 0) pts")
                            .font(.headline.monospacedDigit())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 24) {
                        // Clue cards with Liquid Glass morphing
                        GlassEffectContainer(spacing: 16) {
                            VStack(spacing: 16) {
                                if viewModel.revealedTiers.contains(.hard),
                                   let clue = viewModel.currentTargetLocation?.clues.hard {
                                    ClueCardView(
                                        tier: .hard,
                                        clueText: clue,
                                        isNew: false
                                    )
                                    .glassEffectID("clue-hard", in: clueNamespace)
                                }

                                if viewModel.revealedTiers.contains(.medium),
                                   let clue = viewModel.currentTargetLocation?.clues.medium {
                                    ClueCardView(
                                        tier: .medium,
                                        clueText: clue,
                                        isNew: true
                                    )
                                    .glassEffectID("clue-medium", in: clueNamespace)
                                    .transition(.blurReplace)
                                }

                                if viewModel.revealedTiers.contains(.easy),
                                   let clue = viewModel.currentTargetLocation?.clues.easy {
                                    ClueCardView(
                                        tier: .easy,
                                        clueText: clue,
                                        isNew: true
                                    )
                                    .glassEffectID("clue-easy", in: clueNamespace)
                                    .transition(.blurReplace)
                                }
                            }
                            .animation(.smooth(duration: 0.6), value: viewModel.revealedTiers)
                        }
                        .padding(.horizontal, 16)

                        // Distance display
                        if let distance = viewModel.distanceToTarget {
                            VStack(spacing: 4) {
                                Text(formatDistance(distance))
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
                                Text("to destination")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .glassEffect(
                                .regular.tint(distanceColor(distance)),
                                in: .rect(cornerRadius: 20)
                            )
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "location.slash.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                                Text("Acquiring location...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                            .padding(.horizontal, 16)
                        }

                        // Timer
                        VStack(spacing: 4) {
                            Text(formatTime(elapsedTime))
                                .font(.system(size: 24, weight: .medium, design: .monospaced))
                                .contentTransition(.numericText())
                            Text("elapsed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .glassEffect(.clear, in: .rect(cornerRadius: 12))

                        // Clue reveal hint
                        if !viewModel.revealedTiers.contains(.easy) {
                            let nextTier: String = viewModel.revealedTiers.contains(.medium) ? "Easy" : "Medium"
                            let revealTime = viewModel.revealedTiers.contains(.medium)
                                ? (viewModel.huntData?.hunt.easyRevealMinutes ?? 10)
                                : (viewModel.huntData?.hunt.mediumRevealMinutes ?? 5)
                            let elapsed = Int(elapsedTime)
                            let remaining = max(0, revealTime * 60 - elapsed)

                            if remaining > 0 {
                                Text("\(nextTier) clue reveals in \(formatTime(Double(remaining)))")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 80)
                }
                .scrollEdgeEffectStyle(.soft, for: .all)

                // Bottom toolbar
                HStack {
                    Spacer()
                    Button {
                        viewModel.showLeaderboard = true
                    } label: {
                        Label("Leaderboard", systemImage: "trophy.fill")
                    }
                    .buttonStyle(.glass)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Arrival celebration overlay
            if viewModel.showArrivalCelebration {
                ArrivalCelebrationView()
            }
        }
        .sheet(isPresented: Bindable(viewModel).showLeaderboard) {
            LeaderboardView()
        }
        .onAppear {
            startElapsedTimer()
        }
        .onDisappear {
            elapsedTimerTask?.cancel()
        }
    }

    private func startElapsedTimer() {
        elapsedTimerTask?.cancel()
        elapsedTimerTask = Task { @MainActor in
            while !Task.isCancelled {
                withAnimation {
                    elapsedTime = viewModel.secondsSinceLocationStart
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters)) m"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func distanceColor(_ meters: Double) -> Color {
        if meters < 50 { return .green }
        if meters < 200 { return .orange }
        return .blue
    }
}

#Preview {
    let vm = GameViewModel()
    vm.createTeam(name: "Test Team", playerNames: ["Alice"])
    vm.startHunt()
    return ActiveHuntView()
        .environment(vm)
}
