import SetlineCore
import SwiftUI

@main
struct SetlineApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.load() }
        }
    }
}
