import SwiftUI

struct EvidenceChallengeView: View {
    @Environment(GameViewModel.self) private var viewModel
    @State private var answer = ""

    private var location: HuntLocation? {
        viewModel.pendingEvidenceLocation
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    Text("Evidence Challenge")
                        .font(.title2.bold())
                    if let name = location?.name {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Challenge content
                if let challenge = location?.evidenceChallenge {
                    VStack(alignment: .leading, spacing: 16) {
                        // Instruction
                        Text(challenge.instruction)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        // Question
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Question", systemImage: "questionmark.circle")
                                .font(.headline)
                            Text(challenge.question)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        TextField("Your answer", text: $answer)
                            .textFieldStyle(.plain)
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
                }

                // Submit / Skip buttons
                VStack(spacing: 12) {
                    Button {
                        viewModel.submitEvidence(answer: answer)
                    } label: {
                        if viewModel.isSubmittingEvidence {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        } else {
                            Text("Submit Evidence")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSubmittingEvidence)

                    Button {
                        viewModel.skipEvidence()
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 20)
        }
    }
}
