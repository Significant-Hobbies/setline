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

    private let store: SetlineStore
    private let restNotifier: RestNotifier

    init(store: SetlineStore = SetlineStore(), restNotifier: RestNotifier = RestNotifier()) {
        self.store = store
        self.restNotifier = restNotifier
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--plan-demo") { selectedTab = 1 }
        if arguments.contains("--history-demo") { selectedTab = 2 }
        if arguments.contains("--exercises-demo") { selectedTab = 4 }
        if let index = arguments.firstIndex(of: "--exercise-detail-demo"),
           arguments.indices.contains(index + 1) {
            selectedTab = 4
            demoExerciseName = arguments[index + 1]
        }
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
