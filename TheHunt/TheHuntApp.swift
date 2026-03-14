import SwiftUI
import FirebaseCore
import FirebaseDatabase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        // Debug: verify database URL is configured
        if let app = FirebaseApp.app() {
            print("[Firebase] Database URL: \(app.options.databaseURL ?? "NIL - NOT SET")")
        }
        print("[Firebase] Database reference: \(Database.database().reference().url)")

        return true
    }
}

@main
struct TheHuntApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var authViewModel = AuthViewModel()
    @State private var gameViewModel = GameViewModel()
    @State private var teamManager = TeamManager()

    var body: some View {
        ContentView()
            .environment(authViewModel)
            .environment(gameViewModel)
            .environment(teamManager)
            .onAppear {
                authViewModel.checkAuthState()
            }
            .onChange(of: authViewModel.authState) { _, newState in
                if newState == .ready {
                    teamManager.restoreTeamIfNeeded(teamId: authViewModel.userProfile?.teamId)
                    gameViewModel.onAuthReady(authViewModel: authViewModel)
                }
            }
    }
}
