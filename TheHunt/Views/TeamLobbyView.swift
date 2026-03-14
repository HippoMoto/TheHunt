import SwiftUI
import CoreImage.CIFilterBuiltins

struct TeamLobbyView: View {
    @Environment(TeamManager.self) private var teamManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.15), .purple.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let team = teamManager.currentTeam {
                ScrollView {
                    VStack(spacing: 32) {
                        // Team name
                        VStack(spacing: 8) {
                            Text(team.name)
                                .font(.largeTitle.bold())
                            Text("Waiting for players...")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)

                        // Join code card
                        joinCodeCard(code: team.joinCode)

                        // Members list
                        membersSection

                        Spacer(minLength: 40)

                        // Leave team
                        Button(role: .destructive) {
                            Task {
                                await teamManager.leaveTeam()
                            }
                        } label: {
                            Label("Leave Team", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                        .disabled(teamManager.isLoading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            } else {
                ProgressView()
            }
        }
    }

    private func joinCodeCard(code: String) -> some View {
        VStack(spacing: 12) {
            Text("Share this code with your team")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(code)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .kerning(8)

            Button {
                UIPasteboard.general.string = code
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.glass)

            // QR code
            if let qrImage = generateQRCode(from: code) {
                qrImage
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Scan to join this team")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 24)
    }

    private func generateQRCode(from string: String) -> Image? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up with nearest-neighbor for crisp pixels
        let scale = 200.0 / outputImage.extent.width
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(uiImage: UIImage(cgImage: cgImage))
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members (\(teamManager.memberProfiles.count))")
                .font(.headline)

            ForEach(teamManager.memberProfiles) { profile in
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                    Text(profile.displayName)
                        .font(.body)
                    Spacer()
                    if profile.uid == teamManager.currentTeam?.creatorUid {
                        Text("Creator")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .glassEffect(.regular, in: .capsule)
                    }
                }
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 24)
    }
}
