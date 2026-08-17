import SwiftUI

struct ContentView: View {
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
    }
}
