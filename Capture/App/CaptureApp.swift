import SwiftUI
import SwiftData

@main
struct CaptureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceService.sharedModelContainer)
    }
}
