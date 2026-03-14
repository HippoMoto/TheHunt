import SwiftUI

struct EventBannerView: View {
    let event: GameEvent
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                TeamAvatarView(avatar: event.avatar, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: event.eventType.icon)
                            .foregroundStyle(.blue)
                        Text(event.teamName)
                            .font(.subheadline.bold())
                    }
                    Text(event.eventType.message(teamName: event.teamName, locationName: event.locationName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    dismissBanner()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 16)

            Spacer()
        }
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                isVisible = true
            }
        }
    }

    private func dismissBanner() {
        withAnimation(.easeOut(duration: 0.25)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}
