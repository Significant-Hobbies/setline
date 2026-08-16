import SetlineCore
import SwiftUI

@main
struct SetlineApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    await model.load()
                    // Local data first, always. Syncing follows the load rather than
                    // gating it, so a workout starts instantly with no signal.
                    await model.syncWithiCloud()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Returning to the app is when another device's work is most
                    // likely to be waiting.
                    guard phase == .active else { return }
                    Task { await model.syncWithiCloud() }
                }
        }
    }
}
