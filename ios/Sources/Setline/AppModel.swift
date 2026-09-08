import Foundation
import Observation
import PersonalSyncKit
import SetlineCore

/// Owns the one Setline document and every action that changes it.
///
/// Setline is device-first: no request runs in the middle of a set. Personal
/// Platform synchronization is optional and always follows the local write.
@MainActor
@Observable
final class AppModel {
    private(set) var document: SetlineDocument = .initial
    var isLoading = true
    private(set) var hasLoadedDocument = false
    private(set) var isSaving = false
    private var localWriteWaiters: [CheckedContinuation<Void, Never>] = []
    var isOnboardingPresented = false
    private(set) var isExistingOwnerOrientation = false
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
    private(set) var isPlatformSyncing = false
    private(set) var hubPendingCount = 0
    private(set) var hubSyncSnapshot: HubSyncSnapshot

    private let store: SetlineStore
    private let restNotifier: RestNotifier
    private let syncCoordinator: SetlineCore.SyncCoordinator?
    private let platform: PersonalPlatformConnection?
    private let hubSyncStatusStore: HubSyncStatusStore
    let account: PersonalAccountModel?

    init(
        store: SetlineStore = SetlineStore(),
        restNotifier: RestNotifier = RestNotifier(),
        syncCoordinator: SetlineCore.SyncCoordinator? = SetlineCore.SyncCoordinator(store: CloudKitRecordStore()),
        platform: PersonalPlatformConnection? = AppModel.makePlatformConnection(),
        hubSyncStatusStore: HubSyncStatusStore = HubSyncStatusStore()
    ) {
        self.store = store
        self.restNotifier = restNotifier
        self.hubSyncStatusStore = hubSyncStatusStore
        hubSyncSnapshot = hubSyncStatusStore.load()
        let arguments = ProcessInfo.processInfo.arguments
        // Every demo and interface-test launch runs against a fixture, so none of
        // them may reach iCloud: a real account would make their results depend on
        // whatever happens to be in it.
        self.syncCoordinator = Self.isDemoLaunch(arguments) ? nil : syncCoordinator
        self.platform = Self.isDemoLaunch(arguments) ? nil : platform
        account = self.platform.map {
            PersonalAccountModel(identity: $0.identity, callbackScheme: "setline")
        }
        if arguments.contains("--plan-demo") { selectedTab = 1 }
        if arguments.contains("--history-demo") { selectedTab = 2 }
        if arguments.contains("--exercises-demo") { selectedTab = 4 }
        if arguments.contains("--benchmarks-demo") { selectedTab = 3 }
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
            "--onboarding-demo", "--benchmarks-demo", "--recovery-demo",
        ]
        return arguments.contains { demoFlags.contains($0) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let arguments = ProcessInfo.processInfo.arguments
        do {
            if arguments.contains("--recovery-demo") {
                throw CocoaError(.fileReadCorruptFile)
            } else if arguments.contains("--evidence-demo") {
                document = .demoWithEvidence
            } else if arguments.contains("--ui-demo") {
                // A fixed, date-independent fixture so interface tests do not
                // depend on which day of the authored block today happens to be.
                var demo = SetlineDocument.sample
                demo.programme = .none
                document = demo
            } else if arguments.contains("--fresh-demo") {
                document = .initial
            } else if arguments.contains("--onboarding-demo") {
                document = .initial
            } else {
                document = try await store.load()
            }
            let showsDemo = arguments.contains("--onboarding-demo")
            isExistingOwnerOrientation = !showsDemo
                && SetlineOnboardingPolicy.hasExistingData(document)
            isOnboardingPresented = showsDemo
                || SetlineOnboardingPolicy.shouldPresent(
                    document: document,
                    completed: UserDefaults.standard.bool(forKey: Self.onboardingCompletionKey)
                )
            try startDemoSessionIfRequested(arguments)
            hasLoadedDocument = true
        } catch {
            hasLoadedDocument = false
            message = "Your programme could not be opened. The saved file has not been changed. Try again before editing."
        }
    }

    /// Optional account validation may use the network; it must not gate local
    /// launch or recovery of a workout that is already in progress.
    func restoreAccountIfIdle() async {
        guard hasLoadedDocument, document.activeSession == nil else { return }
        await account?.restore()
        await refreshHubSyncStatus()
    }

    static let onboardingCompletionKey = "setline.illustrated-onboarding.seen.v1"

    func completeOnboarding(openPlan: Bool = false) {
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletionKey)
        isOnboardingPresented = false
        isExistingOwnerOrientation = false
        selectedTab = openPlan ? 1 : 0
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
                    with: [SetSegment(
                        loadMetrics: .init(weight: 40, repetitions: 8),
                        enduranceMetrics: .init(durationSeconds: 60)
                    )]
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
        guard await mutate({ try $0.finishWorkout() }) else { return }
        await syncRestAlert()
        if let completed = document.history.first { enqueue(completed) }
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
        let committed = await mutate { try $0.duplicateTemplate(template.id) }
        guard committed else { return }
        message = "Independent copy created."
    }

    @discardableResult
    func saveTemplate(_ template: WorkoutTemplate) async -> Bool {
        let committed = await mutate { document in
            var saved = template
            saved.isBundled = false
            if let index = document.templates.firstIndex(where: { $0.id == saved.id }) {
                document.templates[index] = saved
            } else {
                document.templates.append(saved)
            }
        }
        guard committed else { return false }
        message = "Template saved."
        return true
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

    @discardableResult
    func saveGoal(_ goal: ExerciseGoal) async -> Bool {
        let committed = await mutate { document in
            if let index = document.goals.firstIndex(where: { $0.id == goal.id }) {
                document.goals[index] = goal
            } else {
                document.goals.append(goal)
            }
        }
        guard committed else { return false }
        message = "Target saved."
        return true
    }

    func deleteGoal(_ goal: ExerciseGoal) async {
        await mutate { document in
            document.goals.removeAll { $0.id == goal.id }
        }
    }

    // MARK: - Benchmarks

    func updateBenchmarkProfile(weight: Double?, height: Double?) async {
        await mutate { document in
            document.benchmarks.profile.weight = weight
            document.benchmarks.profile.height = height
        }
    }

    func updateBenchmarkNumber(_ metricID: String, field key: String, value: Double?) async {
        await mutate { document in
            var state = document.benchmarks.metrics[metricID] ?? .init()
            if let value { state.numbers[key] = value } else { state.numbers.removeValue(forKey: key) }
            document.benchmarks.metrics[metricID] = state
            document.benchmarks.updated[metricID] = .now
        }
    }

    func updateBenchmarkText(_ metricID: String, field key: String, value: String) async {
        await mutate { document in
            var state = document.benchmarks.metrics[metricID] ?? .init()
            state.texts[key] = value
            document.benchmarks.metrics[metricID] = state
            document.benchmarks.updated[metricID] = .now
        }
    }

    func updateBenchmarkFlag(_ metricID: String, field key: String, value: Bool) async {
        await mutate { document in
            var state = document.benchmarks.metrics[metricID] ?? .init()
            state.flags[key] = value
            document.benchmarks.metrics[metricID] = state
            document.benchmarks.updated[metricID] = .now
        }
    }

    func updateBenchmarkTarget(_ metricID: String, values: [String: Double]) async {
        let committed = await mutate { document in
            document.benchmarks.targets[metricID] = BenchmarkTargetState(values: values)
        }
        guard committed else { return }
        message = "Target updated. Previous check-ins keep their original targets."
    }

    func saveBenchmarkCheckIn(date: Date) async {
        let committed = await mutate { document in
            let checkIn = BenchmarkCheckIn(
                date: date,
                profile: document.benchmarks.profile,
                metrics: document.benchmarks.metrics,
                targets: document.benchmarks.targets,
                updated: document.benchmarks.updated
            )
            document.benchmarks.history.insert(checkIn, at: 0)
        }
        guard committed else { return }
        message = "Check-in saved."
    }

    func clearBenchmarkMeasurements() async {
        let committed = await mutate { document in
            document.benchmarks.metrics = BenchmarksState.blankMetrics
            document.benchmarks.updated = [:]
        }
        guard committed else { return }
        message = "Current measurements cleared. Check-ins and targets were kept."
    }

    /// Applies a single workout-history suggestion to the benchmark state,
    /// marking it with the source date so the UI can show provenance.
    func applyBenchmarkSuggestion(_ suggestion: BenchmarkSuggestion) async {
        let committed = await mutate { document in
            var state = document.benchmarks.metrics[suggestion.metricID] ?? .init()
            for (key, value) in suggestion.numbers {
                state.numbers[key] = value
            }
            for (key, value) in suggestion.texts {
                state.texts[key] = value
            }
            document.benchmarks.metrics[suggestion.metricID] = state
            document.benchmarks.updated[suggestion.metricID] = suggestion.sourceDate
        }
        guard committed else { return }
        message = "Filled from \(suggestion.sourceExerciseName) on \(suggestion.sourceDate.formatted(date: .abbreviated, time: .omitted))."
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
        guard hasLoadedDocument else { return }
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
            let base = document
            let (merged, outcome) = try await syncCoordinator.sync(base)
            await acquireLocalWrite()
            defer { releaseLocalWrite() }
            guard document == base else {
                if announcing { message = "Your programme changed while iCloud was syncing. Sync again when idle." }
                return
            }
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

    // MARK: - Personal Platform

    func refreshHubSyncStatus() async {
        guard let platform else { return }
        hubPendingCount = await platform.sync.pendingMutationCount()
    }

    func syncWithPlatform(announcing: Bool = false) async {
        guard hasLoadedDocument else { return }
        guard let platform, account?.isSignedIn == true,
              !isPlatformSyncing, document.activeSession == nil else { return }
        isPlatformSyncing = true
        defer { isPlatformSyncing = false }
        do {
            for session in document.history {
                guard let completedAt = session.completedAt else { continue }
                try await platform.sync.enqueue(
                    recordId: session.id.uuidString.lowercased(),
                    occurredAt: SetlinePlatformRecord.iso(session.startedAt),
                    record: SetlinePlatformRecord.session(session, completedAt: completedAt)
                )
            }
            hubPendingCount = await platform.sync.pendingMutationCount()
            let changes = try await platform.sync.synchronize()
            await acquireLocalWrite()
            defer { releaseLocalWrite() }
            var next = document
            for change in changes {
                guard change.operation == .upsert,
                      let session = SetlinePlatformRecord.session(from: change) else { continue }
                if let index = next.history.firstIndex(where: { $0.id == session.id }) {
                    next.history[index] = session
                } else {
                    next.history.append(session)
                }
            }
            next.history.sort { $0.startedAt > $1.startedAt }
            if next != document {
                try await store.save(next)
                document = next
            }
            hubPendingCount = await platform.sync.pendingMutationCount()
            hubSyncSnapshot = hubSyncStatusStore.recordSuccess()
            if announcing { message = "Significant Hobbies Hub is up to date." }
        } catch {
            hubPendingCount = await platform.sync.pendingMutationCount()
            hubSyncSnapshot = hubSyncStatusStore.recordFailure()
            if announcing {
                message = "Hub sync needs a retry. Pending summaries stay on this iPhone."
            }
        }
    }

    private func enqueue(_ session: WorkoutSession) {
        guard let platform, account?.isSignedIn == true,
              let completedAt = session.completedAt else { return }
        Task {
            do {
                try await platform.sync.enqueue(
                    recordId: session.id.uuidString.lowercased(),
                    occurredAt: SetlinePlatformRecord.iso(session.startedAt),
                    record: SetlinePlatformRecord.session(session, completedAt: completedAt)
                )
                hubPendingCount = await platform.sync.pendingMutationCount()
                _ = try await platform.sync.synchronize()
                hubPendingCount = await platform.sync.pendingMutationCount()
                hubSyncSnapshot = hubSyncStatusStore.recordSuccess()
            } catch {
                hubPendingCount = await platform.sync.pendingMutationCount()
                hubSyncSnapshot = hubSyncStatusStore.recordFailure()
            }
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
        await acquireLocalWrite()
        defer { releaseLocalWrite() }
        do {
            try await store.replace(with: importPreview)
            // The imported file is now this device's truth, but everything it does
            // not contain must not be read as deleted elsewhere.
            try? await syncCoordinator?.forgetBookkeeping()
            document = importPreview
            hasLoadedDocument = true
            self.importPreview = nil
            isImportConfirmationPresented = false
            message = "Setline data replaced."
        } catch {
            message = error.localizedDescription
        }
    }

    func resetLocalData() async {
        await acquireLocalWrite()
        defer { releaseLocalWrite() }
        do {
            try await store.reset()
            // Resetting this device must not propagate as a deletion of the same
            // training from iCloud and every other device.
            try? await syncCoordinator?.forgetBookkeeping()
            document = .initial
            hasLoadedDocument = true
            message = "Local data reset."
        } catch {
            message = error.localizedDescription
        }
    }

    private func acquireLocalWrite() async {
        if isSaving {
            await withCheckedContinuation { localWriteWaiters.append($0) }
        } else {
            isSaving = true
        }
    }

    private func releaseLocalWrite() {
        if localWriteWaiters.isEmpty { isSaving = false }
        else { localWriteWaiters.removeFirst().resume() }
    }

    @discardableResult
    private func mutate(_ operation: (inout SetlineDocument) throws -> Void) async -> Bool {
        guard hasLoadedDocument else {
            message = "Your programme could not be opened. Reopen it before saving; the existing file has not been changed."
            return false
        }
        await acquireLocalWrite()
        defer { releaseLocalWrite() }
        do {
            var next = document
            try operation(&next)
            try await store.save(next)
            document = next
            message = nil
            return true
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    private static func makePlatformConnection() -> PersonalPlatformConnection? {
        let defaults = UserDefaults.standard
        let key = "personal-platform-device-id"
        let deviceId = defaults.string(forKey: key) ?? UUID().uuidString.lowercased()
        defaults.set(deviceId, forKey: key)
        return try? PersonalPlatformConnection(
            domain: .setline,
            keychainService: "com.significanthobbies.setline",
            supportDirectory: SetlineFiles.supportDirectory,
            deviceId: deviceId
        )
    }
}
