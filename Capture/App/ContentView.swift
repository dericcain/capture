import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            NavigationStack {
                CaptureView()
            }
            .tabItem {
                Label("Capture", systemImage: "mic.circle.fill")
            }

            NavigationStack {
                RecentView()
            }
            .tabItem {
                Label("Recent", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .task {
            await BackgroundProcessor.shared.retryPendingCaptures()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await BackgroundProcessor.shared.retryPendingCaptures()
            }
        }
    }
}
