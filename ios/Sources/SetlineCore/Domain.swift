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

public enum BodySide: String, Codable, CaseIterable, Sendable {
    case left
    case right
    case both

    public var title: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .both: "Both"
        }
    }
}

/// One contiguous piece of work inside a single set.
///
/// A set is not always one number pair. `5 reps × 40 kg` immediately followed by
/// `2 reps × 30 kg` is one set with two segments, and both halves have to survive
/// into the record for the set to mean anything later.
public struct SetSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var weight: Double?
    public var repetitions: Int?
    public var durationSeconds: Int?
    public var distanceKilometres: Double?
    public var rpe: Double?
    public var repsInReserve: Int?
    public var reachedFailure: Bool
    public var assistanceKilograms: Double?
    public var rangeOfMotionValue: Double?
    public var averageHeartRate: Int?
    public var side: BodySide?
    /// Measured time under load for this segment, from the work timer.
    public var workSeconds: Int?
    public var hadPain: Bool
    public var note: String?

    public init(
        id: UUID = UUID(),
        weight: Double? = nil,
        repetitions: Int? = nil,
        durationSeconds: Int? = nil,
        distanceKilometres: Double? = nil,
        rpe: Double? = nil,
        repsInReserve: Int? = nil,
        reachedFailure: Bool = false,
        assistanceKilograms: Double? = nil,
        rangeOfMotionValue: Double? = nil,
        averageHeartRate: Int? = nil,
        side: BodySide? = nil,
        workSeconds: Int? = nil,
        hadPain: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.weight = weight
        self.repetitions = repetitions
        self.durationSeconds = durationSeconds
        self.distanceKilometres = distanceKilometres
        self.rpe = rpe
        self.repsInReserve = repsInReserve
        self.reachedFailure = reachedFailure
        self.assistanceKilograms = assistanceKilograms
        self.rangeOfMotionValue = rangeOfMotionValue
        self.averageHeartRate = averageHeartRate
        self.side = side
        self.workSeconds = workSeconds
        self.hadPain = hadPain
        self.note = note
    }

    /// Decodes documents written before the richer segment fields existed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        distanceKilometres = try container.decodeIfPresent(Double.self, forKey: .distanceKilometres)
        rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
        repsInReserve = try container.decodeIfPresent(Int.self, forKey: .repsInReserve)
        reachedFailure = try container.decodeIfPresent(Bool.self, forKey: .reachedFailure) ?? false
        assistanceKilograms = try container.decodeIfPresent(Double.self, forKey: .assistanceKilograms)
        rangeOfMotionValue = try container.decodeIfPresent(Double.self, forKey: .rangeOfMotionValue)
        averageHeartRate = try container.decodeIfPresent(Int.self, forKey: .averageHeartRate)
        side = try container.decodeIfPresent(BodySide.self, forKey: .side)
        workSeconds = try container.decodeIfPresent(Int.self, forKey: .workSeconds)
        hadPain = try container.decodeIfPresent(Bool.self, forKey: .hadPain) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    /// The effective load, accounting for assistance on bodyweight movements.
    public var effectiveKilograms: Double? {
        guard let weight else {
            guard let assistanceKilograms else { return nil }
            return -assistanceKilograms
        }
        return weight - (assistanceKilograms ?? 0)
    }

    public var isEmpty: Bool {
        weight == nil && repetitions == nil && durationSeconds == nil
            && distanceKilometres == nil && rangeOfMotionValue == nil
    }
}

/// Version 1 wrote `target` as free text and `rest` as a scalar `restSeconds`.
/// Both planned sets and recorded steps carried those fields, so the fallbacks
/// live in one place rather than being repeated in each decoder.
enum LegacyDecoding {
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(_ stringValue: String) { self.stringValue = stringValue }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    static func target(from decoder: any Decoder) throws -> SetTarget {
        let container = try decoder.container(keyedBy: Key.self)
        if let structured = try? container.decodeIfPresent(SetTarget.self, forKey: Key("target")) {
            return structured
        }
        return SetTarget(legacy: try container.decodeIfPresent(String.self, forKey: Key("target")) ?? "")
    }

    static func rest(from decoder: any Decoder) throws -> RestRange {
        let container = try decoder.container(keyedBy: Key.self)
        if let range = try? container.decodeIfPresent(RestRange.self, forKey: Key("rest")) {
            return range
        }
        return RestRange(try container.decodeIfPresent(Int.self, forKey: Key("restSeconds")) ?? 0)
    }
}

public struct PlannedSet: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var label: String
    public var kind: ActivityKind
    public var stepType: StepType
    public var target: SetTarget
    public var rest: RestRange
    /// Conditional work the programme offers but never inserts silently.
    public var isOptional: Bool
    /// Overrides the parent exercise cue when this specific set needs different
    /// instruction, as warm-up ramps and conditional sets routinely do.
    public var cue: String?

    public init(
        id: UUID = UUID(),
        label: String,
        kind: ActivityKind,
        stepType: StepType = .working,
        target: SetTarget,
        rest: RestRange,
        isOptional: Bool = false,
        cue: String? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.stepType = stepType
        self.target = target
        self.rest = rest
        self.isOptional = isOptional
        self.cue = cue
    }

    /// Decodes documents whose targets were free text and whose rest was scalar.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        kind = try container.decodeIfPresent(ActivityKind.self, forKey: .kind) ?? .strength
        stepType = try container.decodeIfPresent(StepType.self, forKey: .stepType) ?? .working
        target = try LegacyDecoding.target(from: decoder)
        rest = try LegacyDecoding.rest(from: decoder)
        isOptional = try container.decodeIfPresent(Bool.self, forKey: .isOptional) ?? false
        cue = try container.decodeIfPresent(String.self, forKey: .cue)
    }
}

public struct Exercise: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var cue: String
    public var sets: [PlannedSet]
    /// Links this exercise to a catalogue definition so measurements accumulate
    /// across every template and session that trains the same movement.
    public var definitionSlug: String?
    public var pillars: Set<Pillar>

    public init(
        id: UUID = UUID(),
        name: String,
        cue: String,
        sets: [PlannedSet],
        definitionSlug: String? = nil,
        pillars: Set<Pillar> = [.strength]
    ) {
        self.id = id
        self.name = name
        self.cue = cue
        self.sets = sets
        self.definitionSlug = definitionSlug
        self.pillars = pillars
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        cue = try container.decodeIfPresent(String.self, forKey: .cue) ?? ""
        sets = try container.decodeIfPresent([PlannedSet].self, forKey: .sets) ?? []
        definitionSlug = try container.decodeIfPresent(String.self, forKey: .definitionSlug)
        pillars = try container.decodeIfPresent(Set<Pillar>.self, forKey: .pillars) ?? [.strength]
    }

    public var workingSets: [PlannedSet] {
        sets.filter { $0.stepType.countsAsWorkingSet }
    }
}

public struct WorkoutTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var detail: String
    public var isBundled: Bool
    public var exercises: [Exercise]
    /// Authored notes the programme attaches to the session as a whole.
    public var notes: [String]
    public var expectedMinutes: Int?

    public init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        isBundled: Bool,
        exercises: [Exercise],
        notes: [String] = [],
        expectedMinutes: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isBundled = isBundled
        self.exercises = exercises
        self.notes = notes
        self.expectedMinutes = expectedMinutes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        isBundled = try container.decodeIfPresent(Bool.self, forKey: .isBundled) ?? false
        exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
        expectedMinutes = try container.decodeIfPresent(Int.self, forKey: .expectedMinutes)
    }

    public var plannedSetCount: Int { exercises.flatMap(\.sets).count }
    public var workingSetCount: Int { exercises.flatMap(\.workingSets).count }
    public var pillars: Set<Pillar> { exercises.reduce(into: []) { $0.formUnion($1.pillars) } }
}

public struct WorkoutStep: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var plannedSetID: UUID?
    public var exerciseName: String
    public var exerciseSlug: String?
    public var cue: String
    public var label: String
    public var kind: ActivityKind
    public var stepType: StepType
    public var target: SetTarget
    public var pillars: Set<Pillar>
    public var authoredPosition: Int
    public var rest: RestRange
    public var isOptional: Bool
    public var status: StepStatus
    public var segments: [SetSegment]
    public var isExtra: Bool
    public var performedPosition: Int?
    public var completedAt: Date?
    /// Measured duration of the set itself, distinct from the rest that follows.
    public var workSeconds: Int?

    public init(
        id: UUID = UUID(),
        plannedSetID: UUID?,
        exerciseName: String,
        exerciseSlug: String? = nil,
        cue: String,
        label: String,
        kind: ActivityKind,
        stepType: StepType = .working,
        target: SetTarget,
        pillars: Set<Pillar> = [.strength],
        authoredPosition: Int,
        rest: RestRange,
        isOptional: Bool = false,
        status: StepStatus = .planned,
        segments: [SetSegment] = [],
        isExtra: Bool = false,
        performedPosition: Int? = nil,
        completedAt: Date? = nil,
        workSeconds: Int? = nil
    ) {
        self.id = id
        self.plannedSetID = plannedSetID
        self.exerciseName = exerciseName
        self.exerciseSlug = exerciseSlug
        self.cue = cue
        self.label = label
        self.kind = kind
        self.stepType = stepType
        self.target = target
        self.pillars = pillars
        self.authoredPosition = authoredPosition
        self.rest = rest
        self.isOptional = isOptional
        self.status = status
        self.segments = segments
        self.isExtra = isExtra
        self.performedPosition = performedPosition
        self.completedAt = completedAt
        self.workSeconds = workSeconds
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        plannedSetID = try container.decodeIfPresent(UUID.self, forKey: .plannedSetID)
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? ""
        exerciseSlug = try container.decodeIfPresent(String.self, forKey: .exerciseSlug)
        cue = try container.decodeIfPresent(String.self, forKey: .cue) ?? ""
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        kind = try container.decodeIfPresent(ActivityKind.self, forKey: .kind) ?? .strength
        stepType = try container.decodeIfPresent(StepType.self, forKey: .stepType) ?? .working
        target = try LegacyDecoding.target(from: decoder)
        pillars = try container.decodeIfPresent(Set<Pillar>.self, forKey: .pillars) ?? [.strength]
        authoredPosition = try container.decodeIfPresent(Int.self, forKey: .authoredPosition) ?? 0
        rest = try LegacyDecoding.rest(from: decoder)
        isOptional = try container.decodeIfPresent(Bool.self, forKey: .isOptional) ?? false
        status = try container.decodeIfPresent(StepStatus.self, forKey: .status) ?? .planned
        segments = try container.decodeIfPresent([SetSegment].self, forKey: .segments) ?? []
        isExtra = try container.decodeIfPresent(Bool.self, forKey: .isExtra) ?? false
        performedPosition = try container.decodeIfPresent(Int.self, forKey: .performedPosition)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        workSeconds = try container.decodeIfPresent(Int.self, forKey: .workSeconds)
    }

    /// The cue shown to the lifter: the set's own instruction when it has one.
    public var effectiveCue: String { cue }

    public var countsTowardVolume: Bool {
        stepType.countsAsWorkingSet && status == .complete
    }

    /// Total load moved by this step, for tonnage. Warm-ups deliberately excluded.
    public var tonnage: Double {
        guard countsTowardVolume else { return 0 }
        return segments.reduce(0) { total, segment in
            guard let kilograms = segment.effectiveKilograms, let reps = segment.repetitions else {
                return total
            }
            return total + kilograms * Double(reps)
        }
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
    /// Where this session sat in the programme, so history stays interpretable
    /// after the block ends.
    public var programmeWeek: Int?
    public var programmeDayIndex: Int?

    public init(
        id: UUID = UUID(),
        templateID: UUID,
        templateName: String,
        startedAt: Date,
        completedAt: Date? = nil,
        steps: [WorkoutStep],
        activeIndex: Int = 0,
        rest: RestState? = nil,
        programmeWeek: Int? = nil,
        programmeDayIndex: Int? = nil
    ) {
        self.id = id
        self.templateID = templateID
        self.templateName = templateName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.steps = steps
        self.activeIndex = activeIndex
        self.rest = rest
        self.programmeWeek = programmeWeek
        self.programmeDayIndex = programmeDayIndex
    }

    public var currentStep: WorkoutStep? {
        guard steps.indices.contains(activeIndex) else { return nil }
        return steps[activeIndex]
    }

    public var completedCount: Int {
        steps.count { $0.status == .complete }
    }

    public var completedWorkingSetCount: Int {
        steps.count(where: \.countsTowardVolume)
    }

    public var tonnage: Double {
        steps.reduce(0) { $0 + $1.tonnage }
    }

    public var pillars: Set<Pillar> {
        steps.filter { $0.status == .complete }.reduce(into: []) { $0.formUnion($1.pillars) }
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

/// Which programme drives Today. Bundled blocks are dated and week-aware, so
/// they resolve sessions rather than storing a fixed weekday-to-template map.
public enum ProgrammeSelection: Codable, Equatable, Sendable {
    case none
    case bundled(BundledProgrammeID)
    case custom(CustomProgramme)

    public var customProgramme: CustomProgramme? {
        guard case let .custom(programme) = self else { return nil }
        return programme
    }

    public var bundledID: BundledProgrammeID? {
        guard case let .bundled(id) = self else { return nil }
        return id
    }

    public var isEnabled: Bool {
        switch self {
        case .none: false
        case .bundled: true
        case let .custom(programme): programme.enabled
        }
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
    public var programme: ProgrammeSelection
    public var activeSession: WorkoutSession?
    public var history: [WorkoutSession]
    public var goals: [ExerciseGoal]
    public var syncState: SyncState
    public var lastSyncedAt: Date?

    public static let currentSchemaVersion = 2

    public init(
        schemaVersion: Int = SetlineDocument.currentSchemaVersion,
        templates: [WorkoutTemplate] = [],
        programme: ProgrammeSelection = .none,
        activeSession: WorkoutSession? = nil,
        history: [WorkoutSession] = [],
        goals: [ExerciseGoal] = [],
        syncState: SyncState = .deviceOnly,
        lastSyncedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.templates = templates
        self.programme = programme
        self.activeSession = activeSession
        self.history = history
        self.goals = goals
        self.syncState = syncState
        self.lastSyncedAt = lastSyncedAt
    }

    /// Reads both the version 1 envelope, whose `programme` was a bare custom
    /// programme, and the current selection-based envelope.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        templates = try container.decodeIfPresent([WorkoutTemplate].self, forKey: .templates) ?? []
        if let selection = try? container.decodeIfPresent(ProgrammeSelection.self, forKey: .programme) {
            programme = selection
        } else if let legacy = try? container.decodeIfPresent(CustomProgramme.self, forKey: .programme) {
            programme = .custom(legacy)
        } else {
            programme = .none
        }
        activeSession = try container.decodeIfPresent(WorkoutSession.self, forKey: .activeSession)
        history = try container.decodeIfPresent([WorkoutSession].self, forKey: .history) ?? []
        goals = try container.decodeIfPresent([ExerciseGoal].self, forKey: .goals) ?? []
        syncState = try container.decodeIfPresent(SyncState.self, forKey: .syncState) ?? .deviceOnly
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }
}

public extension SetlineDocument {
    /// True when two documents hold the same training, ignoring sync bookkeeping.
    ///
    /// Recording that a save succeeded must never itself look like a change, or
    /// syncing would trigger another sync forever.
    func hasSameContent(as other: SetlineDocument) -> Bool {
        var left = self
        var right = other
        left.syncState = .deviceOnly
        left.lastSyncedAt = nil
        right.syncState = .deviceOnly
        right.lastSyncedAt = nil
        return left == right
    }

    /// What a fresh install opens on: the authored twelve-week block, enabled.
    static var initial: SetlineDocument {
        SetlineDocument(programme: .bundled(.twelveWeekStrengthCardioMobility))
    }

    /// A document carrying four weeks of recorded bench and pulldown work plus
    /// authored targets, so the measurement surfaces can be exercised and captured
    /// without waiting a month for real evidence to accumulate.
    static var demoWithEvidence: SetlineDocument {
        let week: TimeInterval = 604_800
        let benchProgression: [(load: Double, reps: [Int])] = [
            (65, [8, 8, 8]),
            (67.5, [7, 7, 6]),
            (70, [6, 6, 6]),
            (72.5, [8, 7, 7]),
        ]
        let pulldownProgression: [(load: Double, reps: [Int])] = [
            (50, [10, 10, 9]),
            (52.5, [9, 9, 8]),
            (55, [8, 8, 8]),
            (55, [10, 10, 10]),
        ]

        func session(weeksAgo: Int, index: Int) -> WorkoutSession {
            let date = Date.now.addingTimeInterval(-Double(weeksAgo) * week)
            var position = 0
            func steps(
                name: String,
                slug: String,
                repsHigh: Int,
                progression: [(load: Double, reps: [Int])]
            ) -> [WorkoutStep] {
                let entry = progression[index]
                return entry.reps.map { reps in
                    defer { position += 1 }
                    return WorkoutStep(
                        plannedSetID: UUID(),
                        exerciseName: name,
                        exerciseSlug: slug,
                        cue: "",
                        label: "Working set \(position % 3 + 1) of 3",
                        kind: .strength,
                        stepType: .working,
                        target: SetTarget(
                            repsLow: repsHigh - 3,
                            repsHigh: repsHigh,
                            load: .absolute(kilograms: entry.load),
                            repsInReserve: 1
                        ),
                        authoredPosition: position,
                        rest: RestRange(lowSeconds: 150, highSeconds: 180),
                        status: .complete,
                        segments: [SetSegment(weight: entry.load, repetitions: reps)],
                        completedAt: date
                    )
                }
            }
            return WorkoutSession(
                templateID: ProgrammeSessionKind.upper.templateID,
                templateName: "Upper",
                startedAt: date,
                completedAt: date.addingTimeInterval(3_900),
                steps: steps(
                    name: "Bench press",
                    slug: "bench-press",
                    repsHigh: 8,
                    progression: benchProgression
                ) + steps(
                    name: "Lat pulldown",
                    slug: "lat-pulldown",
                    repsHigh: 10,
                    progression: pulldownProgression
                ),
                programmeWeek: index + 1,
                programmeDayIndex: 0
            )
        }

        // Newest first, matching how completed sessions are stored.
        let history = (0..<4).map { offset in
            session(weeksAgo: offset, index: 3 - offset)
        }
        return SetlineDocument(
            programme: .bundled(.twelveWeekStrengthCardioMobility),
            history: history,
            goals: [
                ExerciseGoal(
                    exerciseName: "Bench press",
                    metric: .topSetLoad,
                    targetValue: 90,
                    referenceRepetitions: 5,
                    createdAt: Date.now.addingTimeInterval(-4 * week),
                    note: "Bodyweight-relative strength target for the block after this one."
                ),
                ExerciseGoal(
                    exerciseName: "Lat pulldown",
                    metric: .estimatedOneRepMax,
                    targetValue: 80,
                    createdAt: Date.now.addingTimeInterval(-4 * week)
                ),
            ]
        )
    }

    static var sample: SetlineDocument {
        let lower = WorkoutTemplate(
            name: "Lower strength",
            detail: "Squat · hinge · carry",
            isBundled: true,
            exercises: [
                Exercise(name: "Front squat", cue: "Brace before the descent. Keep elbows tall.", sets: [
                    PlannedSet(
                        label: "Warm-up",
                        kind: .strength,
                        stepType: .warmUp,
                        target: SetTarget(repsLow: 8, load: .absolute(kilograms: 40)),
                        rest: RestRange(60)
                    ),
                    PlannedSet(
                        label: "Working 1",
                        kind: .strength,
                        target: SetTarget(repsLow: 5, load: .absolute(kilograms: 60)),
                        rest: RestRange(150)
                    ),
                    PlannedSet(
                        label: "Working 2",
                        kind: .strength,
                        target: SetTarget(repsLow: 5, load: .absolute(kilograms: 60)),
                        rest: RestRange(150)
                    ),
                    PlannedSet(
                        label: "Working 3",
                        kind: .strength,
                        target: SetTarget(repsLow: 5, load: .absolute(kilograms: 60)),
                        rest: RestRange(150)
                    ),
                ], pillars: [.strength]),
                Exercise(name: "Romanian deadlift", cue: "Hips back. Keep the bar close.", sets: [
                    PlannedSet(
                        label: "Working 1",
                        kind: .strength,
                        target: SetTarget(repsLow: 8, load: .absolute(kilograms: 70)),
                        rest: RestRange(120)
                    ),
                    PlannedSet(
                        label: "Working 2",
                        kind: .strength,
                        target: SetTarget(repsLow: 8, load: .absolute(kilograms: 70)),
                        rest: RestRange(120)
                    ),
                    PlannedSet(
                        label: "Working 3",
                        kind: .strength,
                        target: SetTarget(repsLow: 8, load: .absolute(kilograms: 70)),
                        rest: RestRange(120)
                    ),
                ], pillars: [.strength]),
                Exercise(name: "Suitcase carry", cue: "Walk tall without leaning.", sets: [
                    PlannedSet(
                        label: "Left",
                        kind: .timed,
                        target: SetTarget(holdSeconds: 45, perSide: true),
                        rest: RestRange(45)
                    ),
                    PlannedSet(
                        label: "Right",
                        kind: .timed,
                        target: SetTarget(holdSeconds: 45, perSide: true),
                        rest: RestRange(45)
                    ),
                ], pillars: [.strength, .stamina]),
            ]
        )
        let conditioning = WorkoutTemplate(
            name: "Engine + mobility",
            detail: "Intervals · hips · shoulders",
            isBundled: true,
            exercises: [
                Exercise(
                    name: "Bike intervals",
                    cue: "Strong, repeatable effort. Do not sprint the first round.",
                    sets: (1...3).map { round in
                        PlannedSet(
                            label: "Round \(round)",
                            kind: .cardio,
                            stepType: .cardio,
                            target: SetTarget(timeSeconds: 240),
                            rest: RestRange(90)
                        )
                    },
                    pillars: [.stamina]
                ),
                Exercise(
                    name: "90/90 hip switches",
                    cue: "Move slowly through the available range.",
                    sets: [
                        PlannedSet(
                            label: "Mobility",
                            kind: .mobility,
                            stepType: .mobility,
                            target: SetTarget(repsLow: 8, perSide: true),
                            rest: RestRange(30)
                        ),
                    ],
                    pillars: [.mobility]
                ),
            ]
        )
        return SetlineDocument(
            templates: [lower, conditioning],
            programme: .custom(CustomProgramme(
                name: "Current block",
                weekCount: 12,
                enabled: true,
                days: (1...7).map { day in
                    ProgrammeDay(weekday: day, templateID: day == 2 || day == 5 ? lower.id : (day == 4 ? conditioning.id : nil))
                }
            ))
        )
    }

    /// Starts a session from an already-resolved template. Programme sessions are
    /// generated per week and day, so they are not present in `templates`.
    mutating func startWorkout(
        template: WorkoutTemplate,
        at date: Date = .now,
        programmeWeek: Int? = nil,
        programmeDayIndex: Int? = nil
    ) throws {
        guard activeSession == nil else { throw SetlineError.sessionAlreadyActive }
        var position = 0
        let steps = template.exercises.flatMap { exercise in
            exercise.sets.map { planned in
                defer { position += 1 }
                return WorkoutStep(
                    plannedSetID: planned.id,
                    exerciseName: exercise.name,
                    exerciseSlug: exercise.definitionSlug,
                    cue: planned.cue ?? exercise.cue,
                    label: planned.label,
                    kind: planned.kind,
                    stepType: planned.stepType,
                    target: planned.target,
                    pillars: exercise.pillars,
                    authoredPosition: position,
                    rest: planned.rest,
                    isOptional: planned.isOptional
                )
            }
        }
        activeSession = WorkoutSession(
            templateID: template.id,
            templateName: template.name,
            startedAt: date,
            steps: steps,
            programmeWeek: programmeWeek,
            programmeDayIndex: programmeDayIndex
        )
    }

    mutating func startWorkout(templateID: UUID, at date: Date = .now) throws {
        guard let template = templates.first(where: { $0.id == templateID }) else {
            throw SetlineError.templateNotFound
        }
        try startWorkout(template: template, at: date)
    }

    mutating func completeCurrent(
        with segments: [SetSegment],
        workSeconds: Int? = nil,
        at date: Date = .now
    ) throws {
        guard var session = activeSession, session.steps.indices.contains(session.activeIndex) else {
            throw SetlineError.noActiveStep
        }
        session.steps[session.activeIndex].segments = segments
        session.steps[session.activeIndex].status = .complete
        session.steps[session.activeIndex].completedAt = date
        session.steps[session.activeIndex].workSeconds = workSeconds
        session.steps[session.activeIndex].performedPosition = session.completedCount
        let authoredRest = session.steps[session.activeIndex].rest
        session.activeIndex = nextPendingIndex(in: session.steps, after: session.activeIndex) ?? session.steps.count
        if session.activeIndex < session.steps.count && !authoredRest.isEmpty {
            let seconds = authoredRest.timerSeconds
            session.rest = RestState(
                authoredSeconds: seconds,
                adjustedSeconds: seconds,
                startedAt: date,
                endsAt: date.addingTimeInterval(TimeInterval(seconds))
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
            exerciseSlug: current.exerciseSlug,
            cue: current.cue,
            label: "Extra set",
            kind: current.kind,
            stepType: current.stepType,
            target: current.target,
            pillars: current.pillars,
            authoredPosition: current.authoredPosition,
            rest: current.rest,
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
