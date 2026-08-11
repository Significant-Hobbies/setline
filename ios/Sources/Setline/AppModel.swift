import Foundation
import Observation
import SetlineCore

@MainActor
@Observable
final class AppModel {
    private(set) var document: SetlineDocument = .sample
    var isLoading = true
    var isWorkoutPresented = false
    var selectedTab = 0
    var message: String?
    var importPreview: SetlineDocument?
    var isImportConfirmationPresented = false

    private let store: SetlineStore

    init(store: SetlineStore = SetlineStore()) {
        self.store = store
        if ProcessInfo.processInfo.arguments.contains("--plan-demo") { selectedTab = 1 }
        if ProcessInfo.processInfo.arguments.contains("--history-demo") { selectedTab = 2 }
    }

    func load() async {
        defer { isLoading = false }
        do {
            if ProcessInfo.processInfo.arguments.contains("--fresh-demo") {
                document = .sample
            } else {
                document = try await store.load()
            }
            if ProcessInfo.processInfo.arguments.contains("--active-demo"), document.activeSession == nil,
               let first = document.templates.first {
                try document.startWorkout(templateID: first.id)
                isWorkoutPresented = true
            }
            if ProcessInfo.processInfo.arguments.contains("--rest-demo"), document.activeSession == nil,
               let first = document.templates.first {
                try document.startWorkout(templateID: first.id)
                try document.completeCurrent(with: [SetSegment(weight: 40, repetitions: 8)])
                isWorkoutPresented = true
            }
        } catch {
            document = .sample
            message = error.localizedDescription
        }
    }

    func startWorkout(_ template: WorkoutTemplate) async {
        await mutate {
            try $0.startWorkout(templateID: template.id)
        }
        if document.activeSession != nil { isWorkoutPresented = true }
    }

    func completeCurrent(segments: [SetSegment]) async {
        await mutate { try $0.completeCurrent(with: segments) }
    }

    func skipCurrent() async {
        await mutate { try $0.skipCurrent() }
    }

    func deferCurrent() async {
        await mutate { try $0.deferCurrent() }
    }

    func addExtraSet() async {
        await mutate { try $0.addExtraSet() }
    }

    func adjustRest(by seconds: Int) async {
        await mutate { $0.adjustRest(by: seconds) }
    }

    func endRest() async {
        await mutate { $0.endRest() }
    }

    func finishWorkout() async {
        await mutate { try $0.finishWorkout() }
        if document.activeSession == nil { isWorkoutPresented = false }
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
            guard let index = document.programme?.days.firstIndex(where: { $0.weekday == weekday }) else { return }
            document.programme?.days[index].templateID = templateID
        }
    }

    func setProgrammeWeeks(_ weekCount: Int) async {
        await mutate { document in
            document.programme?.weekCount = min(16, max(1, weekCount))
        }
    }

    func toggleProgramme() async {
        await mutate { $0.programme?.enabled.toggle() }
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
        } catch {
            message = error.localizedDescription
        }
    }

    func resetLocalData() async {
        do {
            try await store.reset()
            document = .sample
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
