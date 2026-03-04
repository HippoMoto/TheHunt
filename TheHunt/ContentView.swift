import SwiftUI

struct ContentView: View {
    @Environment(GameViewModel.self) private var viewModel

    var body: some View {
        Group {
            switch viewModel.gamePhase {
            case .welcome:
                WelcomeView()
            case .lobby:
                LobbyView()
            case .active:
                ActiveHuntView()
            case .completed:
                HuntCompleteView()
            }
        }
        .animation(.smooth(duration: 0.5), value: viewModel.gamePhase)
    }
}

#Preview {
    ContentView()
        .environment(GameViewModel())
}
