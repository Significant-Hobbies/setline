import Foundation
import SetlineCore
import SwiftUI

@main
struct SetlineApp: App {
    @State private var model = AppModel.forApplicationLaunch()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task {
                    await model.load()
                    await model.restoreAccountIfIdle()
                    // Local data first, always. Syncing follows the load rather than
                    // gating it, so a workout starts instantly with no signal.
                    await model.syncWithiCloud()
                    await model.syncWithPlatform()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Returning to the app is when another device's work is most
                    // likely to be waiting.
                    guard phase == .active else { return }
                    Task {
                        await model.restoreAccountIfIdle()
                        await model.syncWithiCloud()
                        await model.syncWithPlatform()
                    }
                }
        }
    }
}


extension AppModel {
    static func forApplicationLaunch() -> AppModel {
        #if DEBUG
        do {
            if let fixture = try PersistentUIFixture(arguments: ProcessInfo.processInfo.arguments) {
                let defaults = try fixture.defaultsForLaunch()
                return AppModel(
                    store: SetlineStore(fileURL: fixture.fileURL),
                    restNotifier: FixtureRestNotifier(), syncCoordinator: nil, platform: nil,
                    hubSyncStatusStore: HubSyncStatusStore(defaults: defaults), defaults: defaults
                )
            }
        } catch {
            preconditionFailure("Invalid isolated UI fixture: \(error)")
        }
        #endif
        return AppModel()
    }
}

#if DEBUG
/// Only an opaque UUID is accepted; a test cannot redirect into an owner file.
struct PersistentUIFixture {
    enum Failure: Error { case invalidIdentifier, conflictingDemo, mismatchedStore }
    let identifier: UUID
    let cleanup: Bool
    var directory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("setline-ui-\(identifier.uuidString)", isDirectory: true)
    }
    var fileURL: URL { directory.appendingPathComponent("workout.json") }
    var defaultsName: String { "setline.ui-fixture.\(identifier.uuidString)" }

    init?(arguments: [String]) throws {
        guard let index = arguments.firstIndex(of: "--ui-persistent-fixture") else {
            if arguments.contains("--ui-fixture-cleanup") { throw Failure.invalidIdentifier }
            return nil
        }
        guard arguments.indices.contains(index + 1),
              let identifier = UUID(uuidString: arguments[index + 1]),
              arguments.filter({ $0 == "--ui-persistent-fixture" }).count == 1
        else { throw Failure.invalidIdentifier }
        guard !arguments.contains(where: { $0.hasSuffix("-demo") }) else { throw Failure.conflictingDemo }
        self.identifier = identifier
        cleanup = arguments.contains("--ui-fixture-cleanup")
    }

    @MainActor func defaultsForLaunch() throws -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsName)!
        if cleanup {
            if FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.removeItem(at: directory)
            }
            defaults.removePersistentDomain(forName: defaultsName)
        }
        defaults.register(defaults: [AppModel.onboardingCompletionKey: true])
        return defaults
    }

    static func seedIfRequested(store: SetlineStore, arguments: [String]) async throws {
        guard let fixture = try Self(arguments: arguments) else { return }
        guard await store.fileURL == fixture.fileURL else { throw Failure.mismatchedStore }
        guard !fixture.cleanup,
              !FileManager.default.fileExists(atPath: fixture.fileURL.path) else { return }
        var document = SetlineDocument.sample
        document.programme = .none
        try await store.save(document)
    }
}

@MainActor
private struct FixtureRestNotifier: RestNotifying {
    func update(for rest: RestState?, nextStep: WorkoutStep?) async {}
}
#endif
