import SwiftUI

struct ContentView: View {
    @Environment(GameViewModel.self) private var viewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TeamManager.self) private var teamManager

    var body: some View {
        ZStack {
            Group {
                switch viewModel.gamePhase {
                case .authenticating:
                    switch authViewModel.authState {
                    case .unknown:
                        ProgressView()
                    case .signedOut:
                        SignInView()
                    case .needsProfile:
                        ProfileSetupView()
                    case .ready:
                        ProgressView()
                    }
                case .welcome:
                    if teamManager.currentTeam != nil {
                        TeamLobbyView()
                    } else {
                        TeamSetupView()
                    }
                case .lobby:
                    LobbyView()
                case .active:
                    ActiveHuntView()
                case .completed:
                    HuntCompleteView()
                }
            }
            .animation(.smooth(duration: 0.5), value: viewModel.gamePhase)
            .animation(.smooth(duration: 0.5), value: authViewModel.authState)
            .animation(.smooth(duration: 0.5), value: teamManager.currentTeam != nil)

            // Event banner overlay
            if let banner = viewModel.currentBanner {
                EventBannerView(event: banner) {
                    viewModel.dismissBanner()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(GameViewModel())
        .environment(AuthViewModel())
        .environment(TeamManager())
}
