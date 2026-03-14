import SwiftUI

struct TeamAvatarView: View {
    let avatar: TeamAvatar
    let size: CGFloat

    var body: some View {
        switch avatar {
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: size * 0.55))
                .frame(width: size, height: size)
                .glassEffect(.regular, in: .circle)

        case .none:
            Image(systemName: "person.3.fill")
                .font(.system(size: size * 0.35))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .glassEffect(.regular, in: .circle)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        TeamAvatarView(avatar: .emoji("🔥"), size: 48)
        TeamAvatarView(avatar: .emoji("🦊"), size: 48)
        TeamAvatarView(avatar: .none, size: 48)
    }
}
