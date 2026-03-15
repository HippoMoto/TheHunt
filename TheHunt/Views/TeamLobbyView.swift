import SwiftUI
import CoreImage.CIFilterBuiltins

struct TeamLobbyView: View {
    @Environment(TeamManager.self) private var teamManager

    @State private var showRenameAlert = false
    @State private var showAvatarPicker = false
    @State private var showDeleteConfirm = false
    @State private var showKickConfirm = false
    @State private var kickTargetUID: String?
    @State private var kickTargetName: String = ""
    @State private var newTeamName = ""
    @State private var selectedAvatar: TeamAvatar = .none

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
                        // Locked banner
                        if team.isLocked {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                Text("Roster locked — hunt in progress")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular.tint(.orange), in: .rect(cornerRadius: 12))
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                        }

                        // Team header with avatar
                        VStack(spacing: 8) {
                            TeamAvatarView(avatar: team.avatar, size: 64)
                            Text(team.name)
                                .font(.largeTitle.bold())
                            if team.isLocked {
                                Text("Hunt in progress")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Waiting for players...")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, team.isLocked ? 16 : 60)

                        // Manager toolbar
                        if teamManager.currentUserCanManage() && !team.isLocked {
                            managerToolbar(team: team)
                        }

                        // Join code card (hidden when locked)
                        if !team.isLocked {
                            joinCodeCard(code: team.joinCode, isFull: team.isFull)
                        }

                        // Members list
                        membersSection(team: team)

                        // Error message
                        if let error = teamManager.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)

                        // Delete team (always manager-only)
                        if teamManager.currentUserCanManage(restrictedAction: true) && !team.isLocked {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Team", systemImage: "trash")
                                    .font(.body.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                            .buttonStyle(.glass)
                            .disabled(teamManager.isLoading)
                            .padding(.horizontal, 24)
                        }

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
                        .disabled(teamManager.isLoading || team.isLocked)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)

                        if team.isLocked {
                            Text("You can't leave during an active hunt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 20)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .alert("Rename Team", isPresented: $showRenameAlert) {
            TextField("New team name", text: $newTeamName)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                Task { await teamManager.renameTeam(newTeamName) }
            }
        } message: {
            Text("Enter a new name for your team.")
        }
        .sheet(isPresented: $showAvatarPicker) {
            avatarPickerSheet
        }
        .alert("Delete Team", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await teamManager.deleteTeam() }
            }
        } message: {
            Text("This will remove all members and permanently delete the team. This can't be undone.")
        }
        .alert("Kick \(kickTargetName)?", isPresented: $showKickConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Kick", role: .destructive) {
                if let uid = kickTargetUID {
                    Task { await teamManager.kickMember(uid: uid) }
                }
            }
        } message: {
            Text("\(kickTargetName) will be removed from the team.")
        }
    }

    // MARK: - Manager Toolbar

    private func managerToolbar(team: FirebaseTeam) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    newTeamName = team.name
                    showRenameAlert = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Button {
                    selectedAvatar = team.avatar
                    showAvatarPicker = true
                } label: {
                    Label("Avatar", systemImage: "face.smiling")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }

            // Management mode toggle — always manager-only
            if teamManager.currentUserCanManage(restrictedAction: true) {
                Button {
                    Task { await teamManager.toggleManagementMode() }
                } label: {
                    HStack {
                        Image(systemName: team.managementMode == .allMembers
                              ? "person.3.fill" : "person.fill")
                        Text(team.managementMode == .allMembers
                             ? "All members can manage" : "Manager only")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
            }
        }
        .disabled(teamManager.isLoading)
        .padding(.horizontal, 24)
    }

    // MARK: - Avatar Picker Sheet

    private var avatarPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TeamAvatarView(avatar: selectedAvatar, size: 80)
                    .padding(.top, 20)

                TeamAvatarPickerView(selectedAvatar: $selectedAvatar)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Team Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAvatarPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        showAvatarPicker = false
                        Task { await teamManager.updateAvatar(selectedAvatar) }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Join Code Card

    private func joinCodeCard(code: String, isFull: Bool) -> some View {
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

            if isFull {
                Text("Team is full")
                    .font(.caption)
                    .foregroundStyle(.orange)
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

    // MARK: - Members Section

    private func membersSection(team: FirebaseTeam) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members (\(teamManager.memberProfiles.count)/\(FirebaseTeam.maxMembers))")
                .font(.headline)

            ForEach(teamManager.memberProfiles) { profile in
                memberRow(profile: profile, team: team)
            }
        }
        .padding(.horizontal, 24)
    }

    private func memberRow(profile: UserProfile, team: FirebaseTeam) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .foregroundStyle(.secondary)
            Text(profile.displayName)
                .font(.body)
            Spacer()

            if profile.uid == team.creatorUid {
                Text("Manager")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .glassEffect(.regular, in: .capsule)
            } else if team.managementMode == .allMembers {
                Text("Can manage")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .swipeActions(edge: .trailing) {
            if teamManager.currentUserCanManage()
                && profile.uid != team.creatorUid
                && !team.isLocked {
                Button(role: .destructive) {
                    kickTargetUID = profile.uid
                    kickTargetName = profile.displayName
                    showKickConfirm = true
                } label: {
                    Label("Kick", systemImage: "person.fill.xmark")
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var manager: TeamManager = {
        let m = TeamManager()
        m.currentTeam = FirebaseTeam(
            id: "preview-team",
            name: "Team Rocket",
            joinCode: "FOX447",
            creatorUid: "user1",
            members: ["user1", "user2"],
            status: "waiting",
            createdAt: Date(),
            avatar: .emoji("🚀"),
            managementMode: .managerOnly,
            lockedAt: nil
        )
        m.memberProfiles = [
            UserProfile(uid: "user1", displayName: "Alice", teamId: "preview-team", createdAt: Date()),
            UserProfile(uid: "user2", displayName: "Bob 🎯", teamId: "preview-team", createdAt: Date())
        ]
        return m
    }()
    TeamLobbyView()
        .environment(manager)
}
