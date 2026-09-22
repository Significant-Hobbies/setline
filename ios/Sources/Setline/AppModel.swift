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
    private let defaults: UserDefaults
    private let restNotifier: any RestNotifying
    /// The app's record-dating ledger. The mirror runtime owns transport
    /// bookkeeping; this file keeps "what the entities looked like at the last
    /// write", which is how deleted templates and goals become tombstones.
    private let syncStateStore: SyncStateStore
    private let mirror: PersonalMirrorConnection?
    private let hubSyncStatusStore: HubSyncStatusStore
    private(set) var hubAccountNotice: String?
    var hubAccountMatches: Bool {
        guard let owner = document.hubAccountID else { return false }
        return account?.session?.userId == owner
    }
    var needsHubApproval: Bool {
        document.hubAccountID == nil || document.history.contains { $0.hubAccountID == nil }
    }

    let account: PersonalAccountModel?

    init(
        store: SetlineStore = SetlineStore(),
        restNotifier: any RestNotifying = RestNotifier(),
        syncStateStore: SyncStateStore = SyncStateStore(),
        mirror: PersonalMirrorConnection? = AppModel.makeMirrorConnection(),
        hubSyncStatusStore: HubSyncStatusStore = HubSyncStatusStore(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.defaults = defaults
        self.restNotifier = restNotifier
        self.syncStateStore = syncStateStore
        self.hubSyncStatusStore = hubSyncStatusStore
        hubSyncSnapshot = hubSyncStatusStore.load()
        let arguments = ProcessInfo.processInfo.arguments
        // Every demo and interface-test launch runs against a fixture, so none of
        // them may reach iCloud or the Hub: a real account would make their
        // results depend on whatever happens to be in it.
        self.mirror = Self.isDemoLaunch(arguments) ? nil : mirror
        account = self.mirror?.account
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
            #if DEBUG
            if try PersistentUIFixture(arguments: arguments)?.cleanup == true {
                hasLoadedDocument = false
                return // Cleanup cannot load, seed, synchronize or enable mutations.
            }
            try await PersistentUIFixture.seedIfRequested(store: store, arguments: arguments)
            #endif
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
                    completed: defaults.bool(forKey: Self.onboardingCompletionKey)
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
        defaults.set(true, forKey: Self.onboardingCompletionKey)
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
        if mirror != nil { Task { await syncWithiCloud() } }
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

    // MARK: - Mobility

    /// Records one check result on one side. Re-recording a slot moves the
    /// previous result into the card's superseded series, so a changed setup
    /// never silently rewrites the baseline.
    func recordMobilityCheck(
        cardID: String,
        checkID: String,
        side: BodySide?,
        record: MobilityCheckRecord
    ) async {
        await mutate { document in
            var cardState = document.mobility.cards[cardID] ?? .init()
            cardState.record(record, checkID: checkID, side: side)
            document.mobility.cards[cardID] = cardState
            document.mobility.updated[cardID] = .now
        }
    }

    /// Adds or removes a card from the practise set, capped at
    /// `MobilityEngine.maxPractising`. Returns false when the cap blocked it.
    @discardableResult
    func toggleMobilityPractice(cardID: String) async -> Bool {
        if document.mobility.practising.contains(cardID) {
            await mutate { document in
                document.mobility.practising.removeAll { $0 == cardID }
            }
            return true
        }
        guard document.mobility.practising.count < MobilityEngine.maxPractising else { return false }
        await mutate { document in
            document.mobility.practising.append(cardID)
        }
        message = "Added to your practice set. Practise a few tracks rather than the whole library."
        return true
    }

    /// Saves a dated snapshot of the whole curriculum as it stands.
    func saveMobilityAssessment(date: Date) async {
        let committed = await mutate { document in
            let snapshot = MobilityAssessment(
                date: date,
                cards: document.mobility.cards,
                practising: document.mobility.practising
            )
            document.mobility.history.insert(snapshot, at: 0)
        }
        guard committed else { return }
        message = "Assessment snapshot saved."
    }

    /// Starts a practice session derived from the mobility practice set and
    /// hands it to the existing session player. Returns false when the set is
    /// empty or a workout is already underway.
    @discardableResult
    func startMobilityPractice() async -> Bool {
        guard document.activeSession == nil,
              let template = MobilityEngine.practiceTemplate(in: document.mobility)
        else { return false }
        await startWorkout(template)
        selectedTab = 0
        return true
    }

    /// The most recent practice session, for the retest loop's visibility.
    var lastMobilityPractice: WorkoutSession? {
        document.history.first { $0.templateName == "Mobility practice" }
    }

    // MARK: - Capability

    /// Marks or clears a user-selected Specialize focus for an axis.
    func toggleCapabilityFocus(_ axis: AbilityAxis) async {
        await mutate { document in
            if document.capability.focusAxes.contains(axis) {
                document.capability.focusAxes.remove(axis)
            } else {
                document.capability.focusAxes.insert(axis)
            }
        }
    }

    /// Reported pain blocks automatic progression and removes the movement
    /// from generated programmes until cleared.
    func setCapabilityPain(_ reported: Bool, assessmentID: String) async {
        await mutate { document in
            if reported {
                document.capability.painReports[assessmentID] = .now
            } else {
                document.capability.painReports.removeValue(forKey: assessmentID)
            }
        }
    }

    /// Records or clears a difficulty verdict on a checkpoint. Feedback
    /// adjusts one variable in generated sessions — never two.
    func setCapabilityFeedback(_ feedback: CheckpointFeedback?, assessmentID: String) async {
        await mutate { document in
            document.capability.feedback[assessmentID] = feedback
        }
    }

    func setCapabilityDays(_ days: Int) async {
        await mutate { $0.capability.availableDays = days }
    }

    /// Generates the coordinated programme and installs it as the custom
    /// programme. The generated templates are ordinary templates — the user
    /// keeps full edit and skip rights over them.
    @discardableResult
    func applyCapabilityProgramme() async -> Bool {
        guard let generated = CapabilityEngine.generateProgramme(in: document) else { return false }
        await mutate { document in
            document.templates.append(contentsOf: generated.templates)
            document.programme = .custom(generated.programme)
        }
        message = "Capability block scheduled on \(generated.templates.count) day\(generated.templates.count == 1 ? "" : "s")."
        return true
    }

    /// Starts a session practising one axis's unmet checkpoints.
    @discardableResult
    func startAxisSession(_ axis: AbilityAxis) async -> Bool {
        guard document.activeSession == nil,
              let template = CapabilityEngine.axisTemplate(axis, in: document)
        else { return false }
        await startWorkout(template)
        selectedTab = 0
        return true
    }

    func clearMobilityRecords() async {
        let committed = await mutate { document in
            document.mobility.cards = [:]
            document.mobility.updated = [:]
        }
        guard committed else { return }
        message = "Current mobility records cleared. Snapshots and your practice set were kept."
    }

    // MARK: - Mirror sync (iCloud + Hub)

    /// The document as the mirror runtime's record set: every syncable entity
    /// plus tombstones for entities that left it. Sessions are append-only;
    /// the active session is deliberately excluded — a workout in progress
    /// belongs to the phone in your hand.
    func mirrorRecords() async throws -> [MirrorRecord] {
        var bookkeeping = try await syncStateStore.load()
        var records = try SyncEngine.records(for: document, ledger: &bookkeeping.ledger, now: .now)
        records.append(
            contentsOf: SyncEngine.tombstones(for: document, ledger: &bookkeeping.ledger, now: .now)
        )
        try await syncStateStore.save(bookkeeping)
        return try records.map(Self.mirrorRecord(from:))
    }

    /// Wraps a `SyncRecord` in the mirror envelope: the entity payload stays
    /// byte-identical inside `data`, while `recordType`, `entityId`, and an ISO
    /// `occurredAt` give the Hub's contract and reads what they need without
    /// understanding Setline's entity encoding.
    private static func mirrorRecord(from record: SyncRecord) throws -> MirrorRecord {
        let payload = try record.payload.map {
            try mirrorEnvelope(entity: $0, kind: record.kind, entityID: record.entityID, occurredAt: record.modifiedAt)
        }
        return MirrorRecord(
            name: record.recordName,
            modifiedAt: record.modifiedAt,
            payload: payload,
            appendOnly: record.kind.isAppendOnly
        )
    }

    private static func mirrorEnvelope(
        entity: Data, kind: SyncRecordKind, entityID: UUID, occurredAt: Date
    ) throws -> Data {
        guard let object = try JSONSerialization.jsonObject(with: entity) as? [String: Any] else {
            throw SetlineMirrorError.invalidEntityPayload
        }
        return try JSONSerialization.data(
            withJSONObject: [
                "recordType": kind.rawValue,
                "entityId": entityID.uuidString.lowercased(),
                "occurredAt": iso(occurredAt),
                "data": object,
            ],
            options: [.sortedKeys]
        )
    }

    /// Unwraps the entity from a mirror payload. Records written before the
    /// envelope existed carry the raw entity at top level, so a missing `data`
    /// key means the payload already is the entity.
    private static func entityData(from payload: Data) -> Data {
        guard let envelope = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let data = envelope["data"],
              let raw = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys])
        else { return payload }
        return raw
    }

    /// Commits pulled mirror winners atomically. A failing local write throws,
    /// which leaves the transport's pull token unadvanced — the records are
    /// re-offered on the next pass instead of being acknowledged and lost.
    func commitMirrorRecords(_ records: [MirrorRecord]) async throws {
        await acquireLocalWrite()
        defer { releaseLocalWrite() }
        guard hasLoadedDocument, document.activeSession == nil else {
            throw SetlineHubCommitError.localDocumentUnavailable
        }
        var next = document
        for record in records {
            try Self.apply(record, to: &next)
        }
        next.history.sort { $0.startedAt > $1.startedAt }
        if next != document {
            try await store.save(next)
            document = next
        }
    }

    private static func apply(_ record: MirrorRecord, to document: inout SetlineDocument) throws {
        // Names that are not entity records — legacy Hub summaries and any
        // foreign record — are left alone rather than guessed at.
        guard let (kind, entityID) = SyncEngine.parse(record.name) else { return }
        if record.isDeleted {
            applyTombstone(kind, entityID: entityID, to: &document)
            return
        }
        guard let payload = record.payload else { return }
        try applyUpsert(kind, entityID: entityID, data: entityData(from: payload), to: &document)
    }

    private static func applyTombstone(
        _ kind: SyncRecordKind, entityID: UUID, to document: inout SetlineDocument
    ) {
        switch kind {
        case .template: document.templates.removeAll { $0.id == entityID }
        case .goal: document.goals.removeAll { $0.id == entityID }
        case .programme: document.programme = .none
        case .session: break // History is append-only; it never tombstones.
        }
    }

    private static func applyUpsert(
        _ kind: SyncRecordKind, entityID: UUID, data: Data, to document: inout SetlineDocument
    ) throws {
        let decoder = SyncEngine.makeDecoder()
        switch kind {
        case .template:
            let template = try decoder.decode(WorkoutTemplate.self, from: data)
            guard !template.isBundled else { return }
            upsert(template, into: &document.templates, id: \.id)
        case .session:
            upsert(try decoder.decode(WorkoutSession.self, from: data), into: &document.history, id: \.id)
        case .goal:
            upsert(try decoder.decode(ExerciseGoal.self, from: data), into: &document.goals, id: \.id)
        case .programme:
            document.programme = try decoder.decode(ProgrammeSelection.self, from: data)
        }
    }

    private static func upsert<T>(_ value: T, into collection: inout [T], id keyPath: KeyPath<T, UUID>) {
        let id = value[keyPath: keyPath]
        if let index = collection.firstIndex(where: { $0[keyPath: keyPath] == id }) {
            collection[index] = value
        } else {
            collection.append(value)
        }
    }

    /// Reads iCloud's state without syncing, so Settings can be honest on arrival.
    func refreshSyncAvailability() async {
        guard let mirror else { return }
        if let availability = await mirror.runtime.availability(transportID: "cloudkit") {
            syncAvailability = Self.syncAvailability(availability)
        }
    }

    private static func syncAvailability(_ availability: MirrorAvailability) -> SyncAvailability {
        switch availability {
        case .available: return .available
        case .unavailable(let reason):
            switch reason {
            case "no iCloud account": return .noAccount
            case "iCloud is restricted on this device": return .restricted
            default: return .unknown(reason)
            }
        }
    }

    /// Reconciles with every remote — iCloud and the Hub — in one pass. Safe on
    /// launch and foreground return; a workout in progress blocks it rather
    /// than risking a document change under a running set.
    func syncWithiCloud(announcing: Bool = false) async {
        guard let outcome = await synchronize() else { return }
        guard announcing else { return }
        let cloud = outcome.transports.first { $0.transportID == "cloudkit" }
        if let failure = cloud?.failure {
            message = failure
        } else if let cloud {
            message = (cloud.pushed + cloud.pulled) > 0
                ? "iCloud up to date. \(cloud.pulled) in, \(cloud.pushed) out."
                : "iCloud already up to date."
        }
    }

    // MARK: - Personal Platform

    func refreshHubSyncStatus() async {
        guard let mirror else { return }
        hubPendingCount = (try? await mirror.runtime.unpushedCount(
            transportID: "hub", records: mirrorRecords()
        )) ?? 0
    }

    func approveLocalHubHistory(for userID: String) async -> Bool {
        await mutate { try $0.approveHubHistory(for: userID) }
    }

    func approveHubAccount() async {
        guard !isPlatformSyncing, document.activeSession == nil, let mirror else { return }
        do {
            guard let verified = try await mirror.identity.verifiedSyncAccount(),
                  account?.session?.userId == verified.userID else { return }
            guard await approveLocalHubHistory(for: verified.userID) else { return }
            try await mirror.runtime.bindOwner(verified.userID)
            hubAccountNotice = nil
            await syncWithPlatform(announcing: true)
        } catch {
            hubAccountNotice = "Could not approve this Hub connection. Local training and waiting changes are preserved."
        }
    }

    func syncWithPlatform(announcing: Bool = false, recoverMissingRecords: Bool = false) async {
        guard account?.isSignedIn == true else { return }
        let outcome = await synchronize(recover: recoverMissingRecords)
        guard announcing, let outcome else { return }
        let hub = outcome.transports.first { $0.transportID == "hub" }
        if hub?.failure != nil {
            message = "Hub sync needs a retry. Pending changes stay on this iPhone."
        } else {
            message = recoverMissingRecords
                ? "Checked Hub history for missing records. Existing local workouts were kept."
                : "Significant Hobbies Hub is up to date."
        }
    }

    /// Runs the mirror pass over both transports and updates every surface the
    /// views read: iCloud availability and document sync state, Hub pending
    /// count, snapshot, and account notice. Returns nil when the pass cannot
    /// run (no mirror, a workout in progress, or a pass already underway).
    @discardableResult
    private func synchronize(recover: Bool = false) async -> MirrorRuntime.Outcome? {
        guard hasLoadedDocument, let mirror, !isSyncing, !isPlatformSyncing,
              document.activeSession == nil else { return nil }
        isSyncing = true
        isPlatformSyncing = true
        defer { isSyncing = false; isPlatformSyncing = false }
        if let availability = await mirror.runtime.availability(transportID: "cloudkit") {
            syncAvailability = Self.syncAvailability(availability)
        }
        do {
            if recover { try await mirror.runtime.repullAll() }
            let outcome = try await mirror.runtime.synchronize(records: {
                try await self.mirrorRecords()
            }) { pulled in
                try await self.commitMirrorRecords(pulled)
            }
            hubPendingCount = (try? await mirror.runtime.unpushedCount(
                transportID: "hub", records: mirrorRecords()
            )) ?? 0
            await applySyncOutcome(outcome)
            return outcome
        } catch {
            if let ownership = error as? SetlineHubOwnershipError {
                hubAccountNotice = ownership.localizedDescription
            } else if error is PersonalSyncOwnershipError {
                hubAccountNotice = "Approve the connection to resume, or sign in to the account that owns the waiting changes."
            }
            return nil
        }
    }

    /// Writes the pass's results back into the surfaces views read: document
    /// sync state and the Hub snapshot/notice.
    private func applySyncOutcome(_ outcome: MirrorRuntime.Outcome) async {
        await acquireLocalWrite()
        defer { releaseLocalWrite() }
        var next = document
        if let cloud = outcome.transports.first(where: { $0.transportID == "cloudkit" }) {
            next.syncState = cloud.failure == nil ? .synced : .failed
            if cloud.failure == nil { next.lastSyncedAt = outcome.completedAt }
        }
        if next != document {
            try? await store.save(next)
            document = next
        }
        guard let hub = outcome.transports.first(where: { $0.transportID == "hub" }) else { return }
        if hub.failure == nil {
            hubAccountNotice = nil
            hubSyncSnapshot = hubSyncStatusStore.recordSuccess()
        } else if document.hubAccountID != nil && !hubAccountMatches {
            hubAccountNotice = "This training belongs to another Hub account. Sign in to that account to sync."
        } else if hub.failure == "not signed in" {
            hubAccountNotice = nil
        } else if hubAccountMatches {
            hubSyncSnapshot = hubSyncStatusStore.recordFailure()
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
            try? await syncStateStore.reset()
            try? await mirror?.runtime.forgetBookkeeping()
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
            // training from iCloud, the Hub, and every other device.
            try? await syncStateStore.reset()
            try? await mirror?.runtime.forgetBookkeeping()
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

    private static func iso(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    nonisolated(unsafe) private static let isoFormatter = ISO8601DateFormatter()

    private static func makeMirrorConnection() -> PersonalMirrorConnection? {
        #if targetEnvironment(simulator)
        // CKContainer(identifier:) traps rather than throws when the unsigned
        // simulator build lacks the iCloud entitlement — `try?` cannot catch
        // it. The mirror simply stays off on simulator until that leg can be
        // constructed conditionally.
        return nil
        #else
        let defaults = UserDefaults.standard
        let key = "personal-platform-device-id"
        let deviceId = defaults.string(forKey: key) ?? UUID().uuidString.lowercased()
        defaults.set(deviceId, forKey: key)
        return try? PersonalMirrorConnection(
            domain: .setline,
            keychainService: "com.significanthobbies.setline",
            supportDirectory: SetlineFiles.supportDirectory,
            deviceId: deviceId,
            callbackScheme: "setline",
            cloudKitContainer: "iCloud.com.significanthobbies.setline",
            // The existing zone and record type keep the device's CloudKit
            // history rather than re-seeding a fresh zone.
            cloudKitZone: "Training",
            cloudKitRecordType: "SyncRecord",
            appendOnly: { name in
                SyncEngine.parse(name)?.0.isAppendOnly ?? false
            },
            // The Hub leg stays quiet until the committed document is bound to
            // the verified account; CloudKit syncs regardless.
            accountGate: { verified in
                (try? await SetlineStore().load())?.hubAccountID == verified.userID
            }
        )
        #endif
    }
}

enum SetlineHubCommitError: Error { case localDocumentUnavailable }

enum SetlineMirrorError: Error { case invalidEntityPayload }
