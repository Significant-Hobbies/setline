import AuthenticationServices
import Foundation
import Observation
import SetlineCore

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
    var account: SetlineAccount?
    var isAccountBusy = false
    var cloudConflict: SetlineCloudSnapshot?
    var accountMessage: String?

    private let store: SetlineStore
    private let restNotifier: RestNotifier
    private let accountClient: SetlineNativeAccountClient
    private let webAuthenticator: SetlineWebAuthenticator
    private var remoteRevision: Int?
    private var syncRequested = false
    private var isSyncing = false
    private var deferredConflict: SetlineCloudSnapshot?

    init(
        store: SetlineStore = SetlineStore(),
        restNotifier: RestNotifier = RestNotifier(),
        accountClient: SetlineNativeAccountClient = SetlineNativeAccountClient(),
        webAuthenticator: SetlineWebAuthenticator = SetlineWebAuthenticator()
    ) {
        self.store = store
        self.restNotifier = restNotifier
        self.accountClient = accountClient
        self.webAuthenticator = webAuthenticator
        if ProcessInfo.processInfo.arguments.contains("--plan-demo") { selectedTab = 1 }
        if ProcessInfo.processInfo.arguments.contains("--history-demo") { selectedTab = 2 }
        if ProcessInfo.processInfo.arguments.contains("--exercises-demo") { selectedTab = 4 }
        if ProcessInfo.processInfo.arguments.contains("--account-demo") ||
            ProcessInfo.processInfo.arguments.contains("--account-conflict-demo") {
            selectedTab = 3
        }
    }

    func load() async {
        defer { isLoading = false }
        do {
            if ProcessInfo.processInfo.arguments.contains("--ui-demo") {
                // A fixed, date-independent fixture so interface tests do not
                // depend on which day of the authored block today happens to be.
                var demo = SetlineDocument.sample
                demo.programme = .none
                document = demo
            } else if ProcessInfo.processInfo.arguments.contains("--fresh-demo") {
                document = .initial
            } else {
                document = try await store.load()
            }
            if ProcessInfo.processInfo.arguments.contains("--active-demo"), document.activeSession == nil,
               let resolved = document.session() {
                try document.startWorkout(
                    template: resolved.template,
                    programmeWeek: resolved.programmeWeek,
                    programmeDayIndex: resolved.programmeDayIndex
                )
                isWorkoutPresented = true
            }
            if ProcessInfo.processInfo.arguments.contains("--rest-demo"), document.activeSession == nil,
               let resolved = document.session() {
                try document.startWorkout(
                    template: resolved.template,
                    programmeWeek: resolved.programmeWeek,
                    programmeDayIndex: resolved.programmeDayIndex
                )
                // Advance to the first step that authors a rest period, since
                // preparation work deliberately flows straight through.
                while document.activeSession?.rest == nil, document.activeSession?.currentStep != nil {
                    try document.completeCurrent(with: [SetSegment(weight: 40, repetitions: 8, durationSeconds: 60)])
                }
                isWorkoutPresented = true
            }
            if ProcessInfo.processInfo.arguments.contains("--account-demo") {
                account = SetlineAccount(name: "Sarthak", email: "sarthak@example.com", providers: ["google"])
                document.syncState = .synced
                document.lastSyncedAt = Date().addingTimeInterval(-240)
            } else if ProcessInfo.processInfo.arguments.contains("--account-conflict-demo") {
                account = SetlineAccount(name: "Sarthak", email: "sarthak@example.com", providers: ["google"])
                document.syncState = .conflict
                var accountDocument = document
                if let template = accountDocument.templates.first ?? document.session()?.template {
                    accountDocument.history = [
                        WorkoutSession(
                            templateID: template.id,
                            templateName: template.name,
                            startedAt: Date().addingTimeInterval(-3_600),
                            completedAt: Date().addingTimeInterval(-2_700),
                            steps: []
                        ),
                    ]
                }
                cloudConflict = SetlineCloudSnapshot(
                    document: SetlineCloudDocument(document: accountDocument),
                    revision: 3
                )
            } else if !ProcessInfo.processInfo.arguments.contains("--fresh-demo"),
                      !ProcessInfo.processInfo.arguments.contains("--ui-demo") {
                await restoreAccount()
            }
        } catch {
            document = .initial
            message = error.localizedDescription
        }
    }

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
            document = importPreview
            self.importPreview = nil
            isImportConfirmationPresented = false
            message = "Setline data replaced."
            try await markPendingAndSync()
        } catch {
            message = error.localizedDescription
        }
    }

    func resetLocalData() async {
        do {
            try await store.reset()
            document = .initial
            message = "Local data reset."
            try await markPendingAndSync()
        } catch {
            message = error.localizedDescription
        }
    }

    func connectAccount() async {
        isAccountBusy = true
        accountMessage = nil
        defer { isAccountBusy = false }
        do {
            let url = await accountClient.googleStartURL
            let code = try await webAuthenticator.authenticate(at: url)
            account = try await accountClient.exchangeHandoff(code)
            try await reconcileAccountCopy()
        } catch let error as NSError
            where error.domain == ASWebAuthenticationSessionErrorDomain && error.code == 1 {
            accountMessage = nil
        } catch {
            accountMessage = friendlyMessage(for: error)
        }
    }

    func completeAppleSignIn(_ payload: AppleIdentityPayload) async {
        isAccountBusy = true
        accountMessage = nil
        defer { isAccountBusy = false }
        do {
            if let account, !account.hasApple {
                self.account = try await accountClient.linkApple(payload)
                accountMessage = "Apple sign-in added to this Setline account."
            } else {
                account = try await accountClient.signInWithApple(payload)
            }
            try await reconcileAccountCopy()
        } catch {
            accountMessage = friendlyMessage(for: error)
        }
    }

    func syncNow() async {
        guard account != nil else { return }
        if let deferredConflict {
            self.deferredConflict = nil
            cloudConflict = deferredConflict
            return
        }
        await queueSync()
    }

    func keepDeviceCopy() async {
        guard let conflict = cloudConflict else { return }
        cloudConflict = nil
        deferredConflict = nil
        remoteRevision = conflict.revision
        await queueSync()
    }

    func useAccountCopy() async {
        guard let conflict = cloudConflict else { return }
        do {
            let restored = conflict.document.localDocument()
            try await store.replace(with: restored)
            document = restored
            remoteRevision = conflict.revision
            cloudConflict = nil
            deferredConflict = nil
            accountMessage = "Account copy restored on this iPhone."
        } catch {
            accountMessage = friendlyMessage(for: error)
        }
    }

    func decideConflictLater() {
        deferredConflict = cloudConflict
        cloudConflict = nil
        document.syncState = .conflict
        Task { try? await store.save(document) }
    }

    func signOut() async {
        await accountClient.signOut()
        account = nil
        remoteRevision = nil
        cloudConflict = nil
        deferredConflict = nil
        document.syncState = .deviceOnly
        try? await store.save(document)
        accountMessage = "Signed out. Your workouts remain on this iPhone."
    }

    func deleteAccount() async {
        isAccountBusy = true
        defer { isAccountBusy = false }
        do {
            try await accountClient.deleteAccount()
            account = nil
            remoteRevision = nil
            cloudConflict = nil
            deferredConflict = nil
            document.syncState = .deviceOnly
            try await store.save(document)
            accountMessage = "Setline account and its private cloud copy were deleted."
        } catch {
            accountMessage = friendlyMessage(for: error)
        }
    }

    private func restoreAccount() async {
        do {
            account = try await accountClient.restoreAccount()
            if account != nil { try await reconcileAccountCopy() }
        } catch {
            account = nil
            document.syncState = .deviceOnly
            accountMessage = friendlyMessage(for: error)
        }
    }

    private func reconcileAccountCopy() async throws {
        let remote = try await accountClient.fetchState()
        guard let remote else {
            let saved = try await accountClient.pushState(
                SetlineCloudDocument(document: document),
                baseRevision: nil
            )
            remoteRevision = saved.revision
            await markSynced()
            return
        }
        remoteRevision = remote.revision
        if remote.document == SetlineCloudDocument(document: document) {
            await markSynced()
        } else {
            document.syncState = .conflict
            try await store.save(document)
            cloudConflict = remote
        }
    }

    private func queueSync() async {
        syncRequested = true
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        while syncRequested {
            syncRequested = false
            document.syncState = .pending
            try? await store.save(document)
            do {
                let saved = try await accountClient.pushState(
                    SetlineCloudDocument(document: document),
                    baseRevision: remoteRevision
                )
                remoteRevision = saved.revision
                await markSynced()
            } catch let NativeAccountError.conflict(conflict) {
                document.syncState = .conflict
                try? await store.save(document)
                cloudConflict = conflict
                return
            } catch {
                document.syncState = .failed
                try? await store.save(document)
                accountMessage = friendlyMessage(for: error)
                return
            }
        }
    }

    private func markSynced() async {
        document.syncState = .synced
        document.lastSyncedAt = .now
        try? await store.save(document)
        accountMessage = "Private account copy is up to date."
    }

    private func friendlyMessage(for error: Error) -> String {
        if let native = error as? NativeAccountError {
            return native.errorDescription ?? "Setline account service is unavailable."
        }
        return "Setline could not complete that account action. Try again."
    }

    private func markPendingAndSync() async throws {
        guard account != nil, deferredConflict == nil, cloudConflict == nil else { return }
        document.syncState = .pending
        try await store.save(document)
        Task { await self.queueSync() }
    }

    private func mutate(_ operation: (inout SetlineDocument) throws -> Void) async {
        do {
            var next = document
            try operation(&next)
            try await store.save(next)
            document = next
            try await markPendingAndSync()
        } catch {
            message = error.localizedDescription
        }
    }
}
