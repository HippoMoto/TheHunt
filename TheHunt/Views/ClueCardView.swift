import SwiftUI

struct ClueCardView: View {
    let tier: ClueTier
    let clueText: String
    let isNew: Bool

    private var tierColor: Color {
        switch tier {
        case .hard: .red
        case .medium: .orange
        case .easy: .green
        }
    }

    private var tierIcon: String {
        switch tier {
        case .hard: "flame.fill"
        case .medium: "bolt.fill"
        case .easy: "leaf.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: tierIcon)
                    .foregroundStyle(tierColor)
                Text("\(tier.label) Clue")
                    .font(.headline)
                    .foregroundStyle(tierColor)
                Spacer()
                if isNew {
                    Text("NEW")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tierColor)
                        .foregroundStyle(.white)
                        .clipShape(.capsule)
                }
            }

            Text(clueText)
                .font(.body)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(tierColor.opacity(0.15)), in: .rect(cornerRadius: 16))
    }
}

#Preview {
    VStack(spacing: 16) {
        ClueCardView(tier: .hard, clueText: "A monarch's offering to the divine, where voices have risen in song for over five centuries.", isNew: false)
        ClueCardView(tier: .medium, clueText: "This perpendicular Gothic masterpiece was founded by Henry VI in 1446.", isNew: true)
        ClueCardView(tier: .easy, clueText: "King's College Chapel on King's Parade.", isNew: true)
    }
    .padding()
}
