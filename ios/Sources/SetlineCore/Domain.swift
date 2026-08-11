import Foundation

public enum ActivityKind: String, Codable, CaseIterable, Sendable {
    case strength
    case repetitions
    case timed
    case cardio
    case mobility

    public var unitLabel: String {
        switch self {
        case .strength: "kg × reps"
        case .repetitions: "reps"
        case .timed: "seconds"
        case .cardio: "minutes"
        case .mobility: "dose"
        }
    }
}

public enum StepStatus: String, Codable, Sendable {
    case planned
    case complete
    case skipped
    case deferred
}

public struct SetSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var weight: Double?
    public var repetitions: Int?
    public var durationSeconds: Int?
    public var distanceKilometres: Double?

    public init(
        id: UUID = UUID(),
        weight: Double? = nil,
        repetitions: Int? = nil,
        durationSeconds: Int? = nil,
        distanceKilometres: Double? = nil
    ) {
        self.id = id
        self.weight = weight
        self.repetitions = repetitions
        self.durationSeconds = durationSeconds
        self.distanceKilometres = distanceKilometres
    }
}

public struct PlannedSet: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var label: String
    public var kind: ActivityKind
    public var target: String
    public var restSeconds: Int

    public init(
        id: UUID = UUID(),
        label: String,
        kind: ActivityKind,
        target: String,
        restSeconds: Int
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.target = target
        self.restSeconds = restSeconds
    }
}

public struct Exercise: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var cue: String
    public var sets: [PlannedSet]

    public init(id: UUID = UUID(), name: String, cue: String, sets: [PlannedSet]) {
        self.id = id
        self.name = name
        self.cue = cue
        self.sets = sets
    }
}

public struct WorkoutTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var detail: String
    public var isBundled: Bool
    public var exercises: [Exercise]

    public init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        isBundled: Bool,
        exercises: [Exercise]
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isBundled = isBundled
        self.exercises = exercises
    }
}

public struct WorkoutStep: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var plannedSetID: UUID?
    public var exerciseName: String
    public var cue: String
    public var label: String
    public var kind: ActivityKind
    public var target: String
    public var authoredPosition: Int
    public var restSeconds: Int
    public var status: StepStatus
    public var segments: [SetSegment]
    public var isExtra: Bool
    public var performedPosition: Int?
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        plannedSetID: UUID?,
        exerciseName: String,
        cue: String,
        label: String,
        kind: ActivityKind,
        target: String,
        authoredPosition: Int,
        restSeconds: Int,
        status: StepStatus = .planned,
        segments: [SetSegment] = [],
        isExtra: Bool = false,
        performedPosition: Int? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.plannedSetID = plannedSetID
        self.exerciseName = exerciseName
        self.cue = cue
        self.label = label
        self.kind = kind
        self.target = target
        self.authoredPosition = authoredPosition
        self.restSeconds = restSeconds
        self.status = status
        self.segments = segments
        self.isExtra = isExtra
        self.performedPosition = performedPosition
        self.completedAt = completedAt
    }
}

public struct RestState: Codable, Equatable, Sendable {
    public var authoredSeconds: Int
    public var adjustedSeconds: Int
    public var startedAt: Date
    public var endsAt: Date

    public init(authoredSeconds: Int, adjustedSeconds: Int, startedAt: Date, endsAt: Date) {
        self.authoredSeconds = authoredSeconds
        self.adjustedSeconds = adjustedSeconds
        self.startedAt = startedAt
        self.endsAt = endsAt
    }

    public func remaining(at date: Date = .now) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(date))))
    }

    public func actual(at date: Date = .now) -> Int {
        max(0, Int(date.timeIntervalSince(startedAt)))
    }
}

public struct WorkoutSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var templateID: UUID
    public var templateName: String
    public var startedAt: Date
    public var completedAt: Date?
    public var steps: [WorkoutStep]
    public var activeIndex: Int
    public var rest: RestState?

    public init(
        id: UUID = UUID(),
        templateID: UUID,
        templateName: String,
        startedAt: Date,
        completedAt: Date? = nil,
        steps: [WorkoutStep],
        activeIndex: Int = 0,
        rest: RestState? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.templateName = templateName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.steps = steps
        self.activeIndex = activeIndex
        self.rest = rest
    }

    public var currentStep: WorkoutStep? {
        guard steps.indices.contains(activeIndex) else { return nil }
        return steps[activeIndex]
    }

    public var completedCount: Int {
        steps.count { $0.status == .complete }
    }
}

public struct ProgrammeDay: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var weekday: Int
    public var templateID: UUID?

    public init(id: UUID = UUID(), weekday: Int, templateID: UUID?) {
        self.id = id
        self.weekday = weekday
        self.templateID = templateID
    }
}

public struct CustomProgramme: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var weekCount: Int
    public var enabled: Bool
    public var days: [ProgrammeDay]

    public init(
        id: UUID = UUID(),
        name: String,
        weekCount: Int,
        enabled: Bool,
        days: [ProgrammeDay]
    ) {
        self.id = id
        self.name = name
        self.weekCount = min(16, max(1, weekCount))
        self.enabled = enabled
        self.days = days
    }
}

public enum SyncState: String, Codable, Sendable {
    case deviceOnly
    case pending
    case synced
    case conflict
    case failed
}

public struct SetlineDocument: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var templates: [WorkoutTemplate]
    public var programme: CustomProgramme?
    public var activeSession: WorkoutSession?
    public var history: [WorkoutSession]
    public var syncState: SyncState
    public var lastSyncedAt: Date?

    public init(
        schemaVersion: Int = 1,
        templates: [WorkoutTemplate] = [],
        programme: CustomProgramme? = nil,
        activeSession: WorkoutSession? = nil,
        history: [WorkoutSession] = [],
        syncState: SyncState = .deviceOnly,
        lastSyncedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.templates = templates
        self.programme = programme
        self.activeSession = activeSession
        self.history = history
        self.syncState = syncState
        self.lastSyncedAt = lastSyncedAt
    }
}

public extension SetlineDocument {
    static var sample: SetlineDocument {
        let lower = WorkoutTemplate(
            name: "Lower strength",
            detail: "Squat · hinge · carry",
            isBundled: true,
            exercises: [
                Exercise(name: "Front squat", cue: "Brace before the descent. Keep elbows tall.", sets: [
                    PlannedSet(label: "Warm-up", kind: .strength, target: "40 kg × 8", restSeconds: 60),
                    PlannedSet(label: "Working 1", kind: .strength, target: "60 kg × 5", restSeconds: 150),
                    PlannedSet(label: "Working 2", kind: .strength, target: "60 kg × 5", restSeconds: 150),
                    PlannedSet(label: "Working 3", kind: .strength, target: "60 kg × 5", restSeconds: 150),
                ]),
                Exercise(name: "Romanian deadlift", cue: "Hips back. Keep the bar close.", sets: [
                    PlannedSet(label: "Working 1", kind: .strength, target: "70 kg × 8", restSeconds: 120),
                    PlannedSet(label: "Working 2", kind: .strength, target: "70 kg × 8", restSeconds: 120),
                    PlannedSet(label: "Working 3", kind: .strength, target: "70 kg × 8", restSeconds: 120),
                ]),
                Exercise(name: "Suitcase carry", cue: "Walk tall without leaning.", sets: [
                    PlannedSet(label: "Left", kind: .timed, target: "45 seconds", restSeconds: 45),
                    PlannedSet(label: "Right", kind: .timed, target: "45 seconds", restSeconds: 45),
                ]),
            ]
        )
        let conditioning = WorkoutTemplate(
            name: "Engine + mobility",
            detail: "Intervals · hips · shoulders",
            isBundled: true,
            exercises: [
                Exercise(name: "Bike intervals", cue: "Strong, repeatable effort. Do not sprint the first round.", sets: [
                    PlannedSet(label: "Round 1", kind: .cardio, target: "4 minutes", restSeconds: 90),
                    PlannedSet(label: "Round 2", kind: .cardio, target: "4 minutes", restSeconds: 90),
                    PlannedSet(label: "Round 3", kind: .cardio, target: "4 minutes", restSeconds: 90),
                ]),
                Exercise(name: "90/90 hip switches", cue: "Move slowly through the available range.", sets: [
                    PlannedSet(label: "Mobility", kind: .mobility, target: "8 each side", restSeconds: 30),
                ]),
            ]
        )
        return SetlineDocument(
            templates: [lower, conditioning],
            programme: CustomProgramme(
                name: "Current block",
                weekCount: 12,
                enabled: true,
                days: (1...7).map { day in
                    ProgrammeDay(weekday: day, templateID: day == 2 || day == 5 ? lower.id : (day == 4 ? conditioning.id : nil))
                }
            )
        )
    }

    mutating func startWorkout(templateID: UUID, at date: Date = .now) throws {
        guard activeSession == nil else { throw SetlineError.sessionAlreadyActive }
        guard let template = templates.first(where: { $0.id == templateID }) else {
            throw SetlineError.templateNotFound
        }
        var position = 0
        let steps = template.exercises.flatMap { exercise in
            exercise.sets.map { planned in
                defer { position += 1 }
                return WorkoutStep(
                    plannedSetID: planned.id,
                    exerciseName: exercise.name,
                    cue: exercise.cue,
                    label: planned.label,
                    kind: planned.kind,
                    target: planned.target,
                    authoredPosition: position,
                    restSeconds: planned.restSeconds
                )
            }
        }
        activeSession = WorkoutSession(
            templateID: template.id,
            templateName: template.name,
            startedAt: date,
            steps: steps
        )
    }

    mutating func completeCurrent(with segments: [SetSegment], at date: Date = .now) throws {
        guard var session = activeSession, session.steps.indices.contains(session.activeIndex) else {
            throw SetlineError.noActiveStep
        }
        session.steps[session.activeIndex].segments = segments
        session.steps[session.activeIndex].status = .complete
        session.steps[session.activeIndex].completedAt = date
        session.steps[session.activeIndex].performedPosition = session.completedCount
        let authoredRest = session.steps[session.activeIndex].restSeconds
        session.activeIndex = nextPendingIndex(in: session.steps, after: session.activeIndex) ?? session.steps.count
        if session.activeIndex < session.steps.count && authoredRest > 0 {
            session.rest = RestState(
                authoredSeconds: authoredRest,
                adjustedSeconds: authoredRest,
                startedAt: date,
                endsAt: date.addingTimeInterval(TimeInterval(authoredRest))
            )
        } else {
            session.rest = nil
        }
        activeSession = session
    }

    mutating func skipCurrent() throws {
        guard var session = activeSession, session.steps.indices.contains(session.activeIndex) else {
            throw SetlineError.noActiveStep
        }
        session.steps[session.activeIndex].status = .skipped
        session.activeIndex = nextPendingIndex(in: session.steps, after: session.activeIndex) ?? session.steps.count
        session.rest = nil
        activeSession = session
    }

    mutating func deferCurrent() throws {
        guard var session = activeSession, session.steps.indices.contains(session.activeIndex) else {
            throw SetlineError.noActiveStep
        }
        var step = session.steps.remove(at: session.activeIndex)
        step.status = .deferred
        session.steps.append(step)
        if session.activeIndex >= session.steps.count { session.activeIndex = max(0, session.steps.count - 1) }
        session.rest = nil
        activeSession = session
    }

    mutating func addExtraSet() throws {
        guard var session = activeSession, let current = session.currentStep else {
            throw SetlineError.noActiveStep
        }
        let extra = WorkoutStep(
            plannedSetID: nil,
            exerciseName: current.exerciseName,
            cue: current.cue,
            label: "Extra set",
            kind: current.kind,
            target: current.target,
            authoredPosition: current.authoredPosition,
            restSeconds: current.restSeconds,
            isExtra: true
        )
        session.steps.insert(extra, at: min(session.activeIndex + 1, session.steps.count))
        activeSession = session
    }

    mutating func adjustRest(by seconds: Int, at date: Date = .now) {
        guard var session = activeSession, var rest = session.rest else { return }
        rest.adjustedSeconds = max(0, rest.adjustedSeconds + seconds)
        rest.endsAt = rest.startedAt.addingTimeInterval(TimeInterval(rest.adjustedSeconds))
        session.rest = rest
        activeSession = session
    }

    mutating func endRest() {
        activeSession?.rest = nil
    }

    mutating func finishWorkout(at date: Date = .now) throws {
        guard var session = activeSession else { throw SetlineError.noActiveSession }
        for index in session.steps.indices where session.steps[index].status == .planned || session.steps[index].status == .deferred {
            session.steps[index].status = .skipped
        }
        session.completedAt = date
        session.rest = nil
        history.insert(session, at: 0)
        activeSession = nil
    }

    mutating func duplicateTemplate(_ id: UUID) throws {
        guard var copy = templates.first(where: { $0.id == id }) else { throw SetlineError.templateNotFound }
        copy.id = UUID()
        copy.name += " copy"
        copy.isBundled = false
        copy.exercises = copy.exercises.map { exercise in
            var next = exercise
            next.id = UUID()
            next.sets = next.sets.map { set in
                var nextSet = set
                nextSet.id = UUID()
                return nextSet
            }
            return next
        }
        templates.append(copy)
    }

    private func nextPendingIndex(in steps: [WorkoutStep], after index: Int) -> Int? {
        guard index + 1 < steps.count else { return nil }
        return steps.indices[(index + 1)...].first { steps[$0].status == .planned || steps[$0].status == .deferred }
    }
}

public enum SetlineError: LocalizedError, Equatable {
    case templateNotFound
    case sessionAlreadyActive
    case noActiveSession
    case noActiveStep
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .templateNotFound: "That workout is no longer available."
        case .sessionAlreadyActive: "Finish the active workout before starting another."
        case .noActiveSession: "There is no active workout."
        case .noActiveStep: "There is no remaining set to record."
        case let .unsupportedSchema(version): "This Setline data uses unsupported version \(version)."
        }
    }
}
