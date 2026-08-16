import Foundation
import Observation
import SetlineCore

/// Owns the one Setline document and every action that changes it.
///
/// Setline is device-first: there is no account, no server, and no request in the
/// middle of a set. Every mutation writes to local storage and nothing else.
@MainActor
@Observable
final class AppModel {
    private(set) var document: SetlineDocument = .initial
    var isLoading = true
    var isWorkoutPresented = false
    var selectedTab = 0
    var message: String?
    var importPreview: SetlineDocument?
    var isImportConfirmationPresented = false
    /// Set only by a launch argument, so a specific exercise can be opened for
    /// screenshot capture without a person tapping through the interface.
    private(set) var demoExerciseName: String?
    /// What iCloud can do right now, so Settings can say why sync is idle rather
    /// than just showing it as off.
    private(set) var syncAvailability: SyncAvailability?
    private(set) var isSyncing = false

    private let store: SetlineStore
    private let restNotifier: RestNotifier
    private let syncCoordinator: SyncCoordinator?

    init(
        store: SetlineStore = SetlineStore(),
        restNotifier: RestNotifier = RestNotifier(),
        syncCoordinator: SyncCoordinator? = SyncCoordinator(store: CloudKitRecordStore())
    ) {
        self.store = store
        self.restNotifier = restNotifier
        let arguments = ProcessInfo.processInfo.arguments
        // Every demo and interface-test launch runs against a fixture, so none of
        // them may reach iCloud: a real account would make their results depend on
        // whatever happens to be in it.
        self.syncCoordinator = Self.isDemoLaunch(arguments) ? nil : syncCoordinator
        if arguments.contains("--plan-demo") { selectedTab = 1 }
        if arguments.contains("--history-demo") { selectedTab = 2 }
        if arguments.contains("--exercises-demo") { selectedTab = 4 }
        if let index = arguments.firstIndex(of: "--exercise-detail-demo"),
           arguments.indices.contains(index + 1) {
            selectedTab = 4
            demoExerciseName = arguments[index + 1]
        }
    }

    /// Any launch argument that substitutes a fixture for the person's real data.
    /// Listed once, so adding a demo mode cannot accidentally leave sync on.
    private static func isDemoLaunch(_ arguments: [String]) -> Bool {
        let demoFlags: Set<String> = [
            "--ui-demo", "--fresh-demo", "--evidence-demo", "--active-demo", "--rest-demo",
            "--plan-demo", "--history-demo", "--exercises-demo", "--exercise-detail-demo",
        ]
        return arguments.contains { demoFlags.contains($0) }
    }

    func load() async {
        defer { isLoading = false }
        let arguments = ProcessInfo.processInfo.arguments
        do {
            if arguments.contains("--evidence-demo") {
                document = .demoWithEvidence
            } else if arguments.contains("--ui-demo") {
                // A fixed, date-independent fixture so interface tests do not
                // depend on which day of the authored block today happens to be.
                var demo = SetlineDocument.sample
                demo.programme = .none
                document = demo
            } else if arguments.contains("--fresh-demo") {
                document = .initial
            } else {
                document = try await store.load()
            }
            try startDemoSessionIfRequested(arguments)
        } catch {
            document = .initial
            message = error.localizedDescription
        }
    }

    private func startDemoSessionIfRequested(_ arguments: [String]) throws {
        guard arguments.contains("--active-demo") || arguments.contains("--rest-demo") else { return }
        guard document.activeSession == nil, let resolved = document.session() else { return }
        try document.startWorkout(
            template: resolved.template,
            programmeWeek: resolved.programmeWeek,
            programmeDayIndex: resolved.programmeDayIndex
        )
        if arguments.contains("--rest-demo") {
            // Advance to the first step that authors a rest period, since
            // preparation work deliberately flows straight through.
            while document.activeSession?.rest == nil, document.activeSession?.currentStep != nil {
                try document.completeCurrent(
                    with: [SetSegment(weight: 40, repetitions: 8, durationSeconds: 60)]
                )
            }
        }
        isWorkoutPresented = true
    }

    // MARK: - Session

    func startWorkout(_ resolved: ResolvedSession) async {
        await mutate {
            try $0.startWorkout(
                template: resolved.template,
                programmeWeek: resolved.programmeWeek,
                programmeDayIndex: resolved.programmeDayIndex
            )
        }
        if document.activeSession != nil { isWorkoutPresented = true }
    }

    func startWorkout(_ template: WorkoutTemplate) async {
        await mutate { try $0.startWorkout(template: template) }
        if document.activeSession != nil { isWorkoutPresented = true }
    }

    func completeCurrent(segments: [SetSegment], workSeconds: Int? = nil) async {
        await mutate { try $0.completeCurrent(with: segments, workSeconds: workSeconds) }
        await syncRestAlert()
    }

    func skipCurrent() async {
        await mutate { try $0.skipCurrent() }
        await syncRestAlert()
    }

    func deferCurrent() async {
        await mutate { try $0.deferCurrent() }
    }

    func addExtraSet() async {
        await mutate { try $0.addExtraSet() }
    }

    func adjustRest(by seconds: Int) async {
        await mutate { $0.adjustRest(by: seconds) }
        await syncRestAlert()
    }

    func endRest() async {
        await mutate { $0.endRest() }
        await syncRestAlert()
    }

    func finishWorkout() async {
        await mutate { try $0.finishWorkout() }
        await syncRestAlert()
        if document.activeSession == nil { isWorkoutPresented = false }
    }

    /// Keeps the queued rest notification matching the session's current rest.
    private func syncRestAlert() async {
        await restNotifier.update(
            for: document.activeSession?.rest,
            nextStep: document.activeSession?.currentStep
        )
    }

    // MARK: - Planning

    func duplicateTemplate(_ template: WorkoutTemplate) async {
        await mutate { try $0.duplicateTemplate(template.id) }
        message = "Independent copy created."
    }

    func saveTemplate(_ template: WorkoutTemplate) async {
        await mutate { document in
            var saved = template
            saved.isBundled = false
            if let index = document.templates.firstIndex(where: { $0.id == saved.id }) {
                document.templates[index] = saved
            } else {
                document.templates.append(saved)
            }
        }
        message = "Template saved."
    }

    func assignTemplate(_ templateID: UUID?, to weekday: Int) async {
        await mutate { document in
            guard var programme = document.programme.customProgramme,
                  let index = programme.days.firstIndex(where: { $0.weekday == weekday })
            else { return }
            programme.days[index].templateID = templateID
            document.programme = .custom(programme)
        }
    }

    func setProgrammeWeeks(_ weekCount: Int) async {
        await mutate { document in
            guard var programme = document.programme.customProgramme else { return }
            programme.weekCount = min(16, max(1, weekCount))
            document.programme = .custom(programme)
        }
    }

    func toggleProgramme() async {
        await mutate { document in
            guard var programme = document.programme.customProgramme else { return }
            programme.enabled.toggle()
            document.programme = .custom(programme)
        }
    }

    /// Switches Today between the authored block and a device-authored programme.
    func selectProgramme(_ selection: ProgrammeSelection) async {
        await mutate { $0.programme = selection }
    }

    func saveGoal(_ goal: ExerciseGoal) async {
        await mutate { document in
            if let index = document.goals.firstIndex(where: { $0.id == goal.id }) {
                document.goals[index] = goal
            } else {
                document.goals.append(goal)
            }
        }
        message = "Target saved."
    }

    func deleteGoal(_ goal: ExerciseGoal) async {
        await mutate { document in
            document.goals.removeAll { $0.id == goal.id }
        }
    }

    // MARK: - iCloud

    /// Reads iCloud's state without syncing, so Settings can be honest on arrival.
    func refreshSyncAvailability() async {
        guard let syncCoordinator else { return }
        syncAvailability = await syncCoordinator.availability()
    }

    /// Reconciles with iCloud. Safe to call on launch and on returning to the
    /// foreground; it does nothing when there is no active workout to disturb and
    /// nothing to say when the account is simply absent.
    ///
    /// A workout in progress blocks it. The merge already refuses to sync an active
    /// session, but re-entering the document underneath a running set is a needless
    /// risk for no benefit.
    func syncWithiCloud(announcing: Bool = false) async {
        guard let syncCoordinator, !isSyncing, document.activeSession == nil else { return }
        isSyncing = true
        defer { isSyncing = false }

        let availability = await syncCoordinator.availability()
        syncAvailability = availability
        guard availability.isAvailable else {
            if announcing, let reason = SyncError.unavailable(availability).errorDescription {
                message = reason
            }
            return
        }

        do {
            let (merged, outcome) = try await syncCoordinator.sync(document)
            if !merged.hasSameContent(as: document) || merged.lastSyncedAt != document.lastSyncedAt {
                try await store.save(merged)
                document = merged
            }
            if announcing {
                message = outcome.changedAnything
                    ? "iCloud up to date. \(outcome.pulled) in, \(outcome.pushed) out."
                    : "iCloud already up to date."
            }
        } catch {
            // A failed sync must never look like a successful one, but it also must
            // not interrupt training: the local document is untouched either way.
            document.syncState = .failed
            if announcing { message = error.localizedDescription }
        }
    }

    // MARK: - Data transfer

    func exportData() async -> Data? {
        do {
            return try await store.export(document)
        } catch {
            message = error.localizedDescription
            return nil
        }
    }

    func prepareImport(_ data: Data) async {
        do {
            importPreview = try await store.previewImport(data)
            isImportConfirmationPresented = true
        } catch {
            message = error.localizedDescription
        }
    }

    func confirmImport() async {
        guard let importPreview else { return }
        do {
            try await store.replace(with: importPreview)
            // The imported file is now this device's truth, but everything it does
            // not contain must not be read as deleted elsewhere.
            try? await syncCoordinator?.forgetBookkeeping()
            document = importPreview
            self.importPreview = nil
            isImportConfirmationPresented = false
            message = "Setline data replaced."
        } catch {
            message = error.localizedDescription
        }
    }

    func resetLocalData() async {
        do {
            try await store.reset()
            // Resetting this device must not propagate as a deletion of the same
            // training from iCloud and every other device.
            try? await syncCoordinator?.forgetBookkeeping()
            document = .initial
            message = "Local data reset."
        } catch {
            message = error.localizedDescription
        }
    }

    private func mutate(_ operation: (inout SetlineDocument) throws -> Void) async {
        do {
            var next = document
            try operation(&next)
            try await store.save(next)
            document = next
        } catch {
            message = error.localizedDescription
        }
    }
}
