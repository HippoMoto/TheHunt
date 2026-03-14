import SwiftUI

struct TeamAvatarPickerView: View {
    @Binding var selectedAvatar: TeamAvatar

    private let emojiOptions = [
        "🔥", "🦊", "🐺", "🦅", "🐉", "🦁",
        "🎯", "⚡", "🌟", "🏴‍☠️", "🦈", "🐾",
        "🚀", "💎", "🎪", "🦉", "🐲", "🏆"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Team Avatar")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(emojiOptions, id: \.self) { emoji in
                    Button {
                        selectedAvatar = .emoji(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(width: 48, height: 48)
                    }
                    .glassEffect(
                        isSelected(emoji) ? .regular.tint(.blue) : .regular,
                        in: .rect(cornerRadius: 10)
                    )
                }
            }
        }
    }

    private func isSelected(_ emoji: String) -> Bool {
        if case .emoji(let selected) = selectedAvatar {
            return selected == emoji
        }
        return false
    }
}

#Preview {
    @Previewable @State var avatar: TeamAvatar = .emoji("🔥")
    TeamAvatarPickerView(selectedAvatar: $avatar)
        .padding()
}
