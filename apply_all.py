#!/usr/bin/env python3
"""Apply struct definition changes and call site transformations."""

import os

BASE = '/Users/sarthak/Desktop/fleet/setline/'

def apply_edit(filepath, old, new):
    with open(filepath, 'r') as f:
        content = f.read()
    if old not in content:
        print(f'WARNING: old string not found in {filepath}')
        return False
    content = content.replace(old, new, 1)
    with open(filepath, 'w') as f:
        f.write(content)
    return True

# === Domain.swift struct definitions ===
domain = BASE + 'ios/Sources/SetlineCore/Domain.swift'

# SetSegment
apply_edit(domain, '''public struct SetSegment: Codable, Equatable, Identifiable, Sendable {
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
    }''', '''public struct SetSegment: Codable, Equatable, Identifiable, Sendable {
    public struct LoadMetrics: Equatable, Sendable {
        public var weight: Double?
        public var repetitions: Int?
        public var rpe: Double?
        public var repsInReserve: Int?
        public var reachedFailure: Bool
        public var assistanceKilograms: Double?

        public init(
            weight: Double? = nil,
            repetitions: Int? = nil,
            rpe: Double? = nil,
            repsInReserve: Int? = nil,
            reachedFailure: Bool = false,
            assistanceKilograms: Double? = nil
        ) {
            self.weight = weight
            self.repetitions = repetitions
            self.rpe = rpe
            self.repsInReserve = repsInReserve
            self.reachedFailure = reachedFailure
            self.assistanceKilograms = assistanceKilograms
        }
    }

    public struct EnduranceMetrics: Equatable, Sendable {
        public var durationSeconds: Int?
        public var distanceKilometres: Double?
        public var rangeOfMotionValue: Double?
        public var averageHeartRate: Int?
        public var workSeconds: Int?

        public init(
            durationSeconds: Int? = nil,
            distanceKilometres: Double? = nil,
            rangeOfMotionValue: Double? = nil,
            averageHeartRate: Int? = nil,
            workSeconds: Int? = nil
        ) {
            self.durationSeconds = durationSeconds
            self.distanceKilometres = distanceKilometres
            self.rangeOfMotionValue = rangeOfMotionValue
            self.averageHeartRate = averageHeartRate
            self.workSeconds = workSeconds
        }
    }

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
        loadMetrics: LoadMetrics = .init(),
        enduranceMetrics: EnduranceMetrics = .init(),
        side: BodySide? = nil,
        hadPain: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.weight = loadMetrics.weight
        self.repetitions = loadMetrics.repetitions
        self.durationSeconds = enduranceMetrics.durationSeconds
        self.distanceKilometres = enduranceMetrics.distanceKilometres
        self.rpe = loadMetrics.rpe
        self.repsInReserve = loadMetrics.repsInReserve
        self.reachedFailure = loadMetrics.reachedFailure
        self.assistanceKilograms = loadMetrics.assistanceKilograms
        self.rangeOfMotionValue = enduranceMetrics.rangeOfMotionValue
        self.averageHeartRate = enduranceMetrics.averageHeartRate
        self.side = side
        self.workSeconds = enduranceMetrics.workSeconds
        self.hadPain = hadPain
        self.note = note
    }''')

# PlannedSet
apply_edit(domain, '''public struct PlannedSet: Codable, Equatable, Identifiable, Sendable {
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
    }''', '''public struct PlannedSet: Codable, Equatable, Identifiable, Sendable {
    public struct SetConfig: Equatable, Sendable {
        public var stepType: StepType
        public var isOptional: Bool

        public init(stepType: StepType = .working, isOptional: Bool = false) {
            self.stepType = stepType
            self.isOptional = isOptional
        }
    }

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
        target: SetTarget,
        rest: RestRange,
        config: SetConfig = .init(),
        cue: String? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.stepType = config.stepType
        self.target = target
        self.rest = rest
        self.isOptional = config.isOptional
        self.cue = cue
    }''')

# WorkoutStep
apply_edit(domain, '''public struct WorkoutStep: Codable, Equatable, Identifiable, Sendable {
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
    }''', '''public struct WorkoutStep: Codable, Equatable, Identifiable, Sendable {
    public struct ExerciseRef: Equatable, Sendable {
        public var plannedSetID: UUID?
        public var exerciseName: String
        public var exerciseSlug: String?
        public var cue: String
        public var label: String
        public var kind: ActivityKind

        public init(
            plannedSetID: UUID?,
            exerciseName: String,
            exerciseSlug: String? = nil,
            cue: String,
            label: String,
            kind: ActivityKind
        ) {
            self.plannedSetID = plannedSetID
            self.exerciseName = exerciseName
            self.exerciseSlug = exerciseSlug
            self.cue = cue
            self.label = label
            self.kind = kind
        }
    }

    public struct StepConfig: Equatable, Sendable {
        public var stepType: StepType
        public var target: SetTarget
        public var pillars: Set<Pillar>
        public var authoredPosition: Int
        public var rest: RestRange
        public var isOptional: Bool

        public init(
            stepType: StepType = .working,
            target: SetTarget,
            pillars: Set<Pillar> = [.strength],
            authoredPosition: Int,
            rest: RestRange,
            isOptional: Bool = false
        ) {
            self.stepType = stepType
            self.target = target
            self.pillars = pillars
            self.authoredPosition = authoredPosition
            self.rest = rest
            self.isOptional = isOptional
        }
    }

    public struct StepState: Equatable, Sendable {
        public var status: StepStatus
        public var segments: [SetSegment]
        public var isExtra: Bool
        public var performedPosition: Int?
        public var completedAt: Date?
        public var workSeconds: Int?

        public init(
            status: StepStatus = .planned,
            segments: [SetSegment] = [],
            isExtra: Bool = false,
            performedPosition: Int? = nil,
            completedAt: Date? = nil,
            workSeconds: Int? = nil
        ) {
            self.status = status
            self.segments = segments
            self.isExtra = isExtra
            self.performedPosition = performedPosition
            self.completedAt = completedAt
            self.workSeconds = workSeconds
        }
    }

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
        exerciseRef: ExerciseRef,
        config: StepConfig,
        state: StepState = .init()
    ) {
        self.id = id
        self.plannedSetID = exerciseRef.plannedSetID
        self.exerciseName = exerciseRef.exerciseName
        self.exerciseSlug = exerciseRef.exerciseSlug
        self.cue = exerciseRef.cue
        self.label = exerciseRef.label
        self.kind = exerciseRef.kind
        self.stepType = config.stepType
        self.target = config.target
        self.pillars = config.pillars
        self.authoredPosition = config.authoredPosition
        self.rest = config.rest
        self.isOptional = config.isOptional
        self.status = state.status
        self.segments = state.segments
        self.isExtra = state.isExtra
        self.performedPosition = state.performedPosition
        self.completedAt = state.completedAt
        self.workSeconds = state.workSeconds
    }''')

# WorkoutSession
apply_edit(domain, '''public struct WorkoutSession: Codable, Equatable, Identifiable, Sendable {
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
    }''', '''public struct WorkoutSession: Codable, Equatable, Identifiable, Sendable {
    public struct SessionContext: Equatable, Sendable {
        public var templateID: UUID
        public var templateName: String
        public var startedAt: Date
        public var completedAt: Date?

        public init(
            templateID: UUID,
            templateName: String,
            startedAt: Date,
            completedAt: Date? = nil
        ) {
            self.templateID = templateID
            self.templateName = templateName
            self.startedAt = startedAt
            self.completedAt = completedAt
        }
    }

    public struct SessionState: Equatable, Sendable {
        public var steps: [WorkoutStep]
        public var activeIndex: Int
        public var rest: RestState?
        public var programmeWeek: Int?
        public var programmeDayIndex: Int?

        public init(
            steps: [WorkoutStep],
            activeIndex: Int = 0,
            rest: RestState? = nil,
            programmeWeek: Int? = nil,
            programmeDayIndex: Int? = nil
        ) {
            self.steps = steps
            self.activeIndex = activeIndex
            self.rest = rest
            self.programmeWeek = programmeWeek
            self.programmeDayIndex = programmeDayIndex
        }
    }

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
        context: SessionContext,
        state: SessionState
    ) {
        self.id = id
        self.templateID = context.templateID
        self.templateName = context.templateName
        self.startedAt = context.startedAt
        self.completedAt = context.completedAt
        self.steps = state.steps
        self.activeIndex = state.activeIndex
        self.rest = state.rest
        self.programmeWeek = state.programmeWeek
        self.programmeDayIndex = state.programmeDayIndex
    }''')

# SetlineDocument
apply_edit(domain, '''public struct SetlineDocument: Codable, Equatable, Sendable {
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
    }''', '''public struct SetlineDocument: Codable, Equatable, Sendable {
    public struct SyncInfo: Equatable, Sendable {
        public var syncState: SyncState
        public var lastSyncedAt: Date?

        public init(syncState: SyncState = .deviceOnly, lastSyncedAt: Date? = nil) {
            self.syncState = syncState
            self.lastSyncedAt = lastSyncedAt
        }
    }

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
        sync: SyncInfo = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.templates = templates
        self.programme = programme
        self.activeSession = activeSession
        self.history = history
        self.goals = goals
        self.syncState = sync.syncState
        self.lastSyncedAt = sync.lastSyncedAt
    }''')

# === Targets.swift ===
targets = BASE + 'ios/Sources/SetlineCore/Targets.swift'
apply_edit(targets, '''public struct SetTarget: Codable, Equatable, Sendable {
    public var repsLow: Int?
    public var repsHigh: Int?
    public var load: LoadTarget?
    public var repsInReserve: Int?
    public var rpe: Double?
    public var tempo: Tempo?
    public var timeSeconds: Int?
    public var holdSeconds: Int?
    public var distanceMetres: Double?
    public var paceSecondsPerKilometre: Int?
    public var heartRateZone: Int?
    public var perSide: Bool
    /// Preserves a target string that predates structured targets so historic
    /// sessions keep displaying exactly what they were performed against.
    public var legacyDisplay: String?

    public init(
        repsLow: Int? = nil,
        repsHigh: Int? = nil,
        load: LoadTarget? = nil,
        repsInReserve: Int? = nil,
        rpe: Double? = nil,
        tempo: Tempo? = nil,
        timeSeconds: Int? = nil,
        holdSeconds: Int? = nil,
        distanceMetres: Double? = nil,
        paceSecondsPerKilometre: Int? = nil,
        heartRateZone: Int? = nil,
        perSide: Bool = false,
        legacyDisplay: String? = nil
    ) {
        self.repsLow = repsLow
        self.repsHigh = repsHigh
        self.load = load
        self.repsInReserve = repsInReserve
        self.rpe = rpe
        self.tempo = tempo
        self.timeSeconds = timeSeconds
        self.holdSeconds = holdSeconds
        self.distanceMetres = distanceMetres
        self.paceSecondsPerKilometre = paceSecondsPerKilometre
        self.heartRateZone = heartRateZone
        self.perSide = perSide
        self.legacyDisplay = legacyDisplay
    }''', '''public struct SetTarget: Codable, Equatable, Sendable {
    public struct RepTarget: Equatable, Sendable {
        public var repsLow: Int?
        public var repsHigh: Int?
        public var repsInReserve: Int?
        public var rpe: Double?

        public init(
            repsLow: Int? = nil,
            repsHigh: Int? = nil,
            repsInReserve: Int? = nil,
            rpe: Double? = nil
        ) {
            self.repsLow = repsLow
            self.repsHigh = repsHigh
            self.repsInReserve = repsInReserve
            self.rpe = rpe
        }
    }

    public struct TimeTarget: Equatable, Sendable {
        public var tempo: Tempo?
        public var timeSeconds: Int?
        public var holdSeconds: Int?

        public init(
            tempo: Tempo? = nil,
            timeSeconds: Int? = nil,
            holdSeconds: Int? = nil
        ) {
            self.tempo = tempo
            self.timeSeconds = timeSeconds
            self.holdSeconds = holdSeconds
        }
    }

    public struct DistanceTarget: Equatable, Sendable {
        public var distanceMetres: Double?
        public var paceSecondsPerKilometre: Int?
        public var heartRateZone: Int?

        public init(
            distanceMetres: Double? = nil,
            paceSecondsPerKilometre: Int? = nil,
            heartRateZone: Int? = nil
        ) {
            self.distanceMetres = distanceMetres
            self.paceSecondsPerKilometre = paceSecondsPerKilometre
            self.heartRateZone = heartRateZone
        }
    }

    public var repsLow: Int?
    public var repsHigh: Int?
    public var load: LoadTarget?
    public var repsInReserve: Int?
    public var rpe: Double?
    public var tempo: Tempo?
    public var timeSeconds: Int?
    public var holdSeconds: Int?
    public var distanceMetres: Double?
    public var paceSecondsPerKilometre: Int?
    public var heartRateZone: Int?
    public var perSide: Bool
    /// Preserves a target string that predates structured targets so historic
    /// sessions keep displaying exactly what they were performed against.
    public var legacyDisplay: String?

    public init(
        repTarget: RepTarget = .init(),
        timeTarget: TimeTarget = .init(),
        distanceTarget: DistanceTarget = .init(),
        load: LoadTarget? = nil,
        perSide: Bool = false,
        legacyDisplay: String? = nil
    ) {
        self.repsLow = repTarget.repsLow
        self.repsHigh = repTarget.repsHigh
        self.load = load
        self.repsInReserve = repTarget.repsInReserve
        self.rpe = repTarget.rpe
        self.tempo = timeTarget.tempo
        self.timeSeconds = timeTarget.timeSeconds
        self.holdSeconds = timeTarget.holdSeconds
        self.distanceMetres = distanceTarget.distanceMetres
        self.paceSecondsPerKilometre = distanceTarget.paceSecondsPerKilometre
        self.heartRateZone = distanceTarget.heartRateZone
        self.perSide = perSide
        self.legacyDisplay = legacyDisplay
    }''')

# === Progression.swift ===
progression = BASE + 'ios/Sources/SetlineCore/Progression.swift'
apply_edit(progression, '''public struct ProgressionRecommendation: Equatable, Sendable {
    public var exerciseName: String
    public var exerciseSlug: String?
    public var action: ProgressionAction
    public var currentLoad: Double?
    public var recommendedLoad: Double?
    /// The repetitions achieved on each working set of the most recent session,
    /// in authored order, so the suggestion can always be audited.
    public var lastSessionRepetitions: [Int]
    public var lastSessionDate: Date?
    public var rationale: String

    public init(
        exerciseName: String,
        exerciseSlug: String? = nil,
        action: ProgressionAction,
        currentLoad: Double? = nil,
        recommendedLoad: Double? = nil,
        lastSessionRepetitions: [Int] = [],
        lastSessionDate: Date? = nil,
        rationale: String
    ) {
        self.exerciseName = exerciseName
        self.exerciseSlug = exerciseSlug
        self.action = action
        self.currentLoad = currentLoad
        self.recommendedLoad = recommendedLoad
        self.lastSessionRepetitions = lastSessionRepetitions
        self.lastSessionDate = lastSessionDate
        self.rationale = rationale
    }''', '''public struct ProgressionRecommendation: Equatable, Sendable {
    public struct LoadInfo: Equatable, Sendable {
        public var currentLoad: Double?
        public var recommendedLoad: Double?

        public init(currentLoad: Double? = nil, recommendedLoad: Double? = nil) {
            self.currentLoad = currentLoad
            self.recommendedLoad = recommendedLoad
        }
    }

    public var exerciseName: String
    public var exerciseSlug: String?
    public var action: ProgressionAction
    public var currentLoad: Double?
    public var recommendedLoad: Double?
    /// The repetitions achieved on each working set of the most recent session,
    /// in authored order, so the suggestion can always be audited.
    public var lastSessionRepetitions: [Int]
    public var lastSessionDate: Date?
    public var rationale: String

    public init(
        exerciseName: String,
        exerciseSlug: String? = nil,
        action: ProgressionAction,
        load: LoadInfo = .init(),
        lastSessionRepetitions: [Int] = [],
        lastSessionDate: Date? = nil,
        rationale: String
    ) {
        self.exerciseName = exerciseName
        self.exerciseSlug = exerciseSlug
        self.action = action
        self.currentLoad = load.currentLoad
        self.recommendedLoad = load.recommendedLoad
        self.lastSessionRepetitions = lastSessionRepetitions
        self.lastSessionDate = lastSessionDate
        self.rationale = rationale
    }''')

# === Goals.swift ===
goals = BASE + 'ios/Sources/SetlineCore/Goals.swift'
apply_edit(goals, '''public struct ExerciseGoal: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    /// Matched against recorded step names, case- and whitespace-insensitively.
    public var exerciseName: String
    public var metric: MetricKind
    public var targetValue: Double
    /// For `topSetLoad`, the repetition count the load must be held for.
    public var referenceRepetitions: Int?
    public var targetDate: Date?
    public var createdAt: Date
    public var note: String?

    public init(
        id: UUID = UUID(),
        exerciseName: String,
        metric: MetricKind,
        targetValue: Double,
        referenceRepetitions: Int? = nil,
        targetDate: Date? = nil,
        createdAt: Date = .now,
        note: String? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.metric = metric
        self.targetValue = targetValue
        self.referenceRepetitions = referenceRepetitions
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.note = note
    }''', '''public struct ExerciseGoal: Codable, Equatable, Identifiable, Sendable {
    public struct GoalTiming: Equatable, Sendable {
        public var targetDate: Date?
        public var createdAt: Date

        public init(targetDate: Date? = nil, createdAt: Date = .now) {
            self.targetDate = targetDate
            self.createdAt = createdAt
        }
    }

    public var id: UUID
    /// Matched against recorded step names, case- and whitespace-insensitively.
    public var exerciseName: String
    public var metric: MetricKind
    public var targetValue: Double
    /// For `topSetLoad`, the repetition count the load must be held for.
    public var referenceRepetitions: Int?
    public var targetDate: Date?
    public var createdAt: Date
    public var note: String?

    public init(
        id: UUID = UUID(),
        exerciseName: String,
        metric: MetricKind,
        targetValue: Double,
        referenceRepetitions: Int? = nil,
        timing: GoalTiming = .init(),
        note: String? = nil
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.metric = metric
        self.targetValue = targetValue
        self.referenceRepetitions = referenceRepetitions
        self.targetDate = timing.targetDate
        self.createdAt = timing.createdAt
        self.note = note
    }''')

# === ExerciseCatalogue.swift ===
catalogue = BASE + 'ios/Sources/SetlineCore/ExerciseCatalogue.swift'
apply_edit(catalogue, '''public struct ExerciseDefinition: Codable, Equatable, Identifiable, Sendable {
    public var slug: String
    public var name: String
    public var aliases: [String]
    public var pillars: Set<Pillar>
    public var kind: ActivityKind
    public var primaryMuscles: [MuscleGroup]
    public var secondaryMuscles: [MuscleGroup]
    public var equipment: [Equipment]
    public var isUnilateral: Bool
    public var defaultRest: RestRange
    public var cue: String
    /// The metrics worth setting a goal against for this movement.
    public var goalMetrics: [MetricKind]

    public var id: String { slug }

    public init(
        slug: String,
        name: String,
        aliases: [String] = [],
        pillars: Set<Pillar>,
        kind: ActivityKind,
        primaryMuscles: [MuscleGroup] = [],
        secondaryMuscles: [MuscleGroup] = [],
        equipment: [Equipment] = [.none],
        isUnilateral: Bool = false,
        defaultRest: RestRange = RestRange(90),
        cue: String = "",
        goalMetrics: [MetricKind] = [.estimatedOneRepMax, .topSetLoad]
    ) {
        self.slug = slug
        self.name = name
        self.aliases = aliases
        self.pillars = pillars
        self.kind = kind
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.isUnilateral = isUnilateral
        self.defaultRest = defaultRest
        self.cue = cue
        self.goalMetrics = goalMetrics
    }
}''', '''public struct ExerciseDefinition: Codable, Equatable, Identifiable, Sendable {
    public struct Anatomy: Equatable, Sendable {
        public var primaryMuscles: [MuscleGroup]
        public var secondaryMuscles: [MuscleGroup]
        public var equipment: [Equipment]
        public var isUnilateral: Bool

        public init(
            primaryMuscles: [MuscleGroup] = [],
            secondaryMuscles: [MuscleGroup] = [],
            equipment: [Equipment] = [.none],
            isUnilateral: Bool = false
        ) {
            self.primaryMuscles = primaryMuscles
            self.secondaryMuscles = secondaryMuscles
            self.equipment = equipment
            self.isUnilateral = isUnilateral
        }
    }

    public struct ExerciseConfig: Equatable, Sendable {
        public var aliases: [String]
        public var defaultRest: RestRange
        public var cue: String
        public var goalMetrics: [MetricKind]

        public init(
            aliases: [String] = [],
            defaultRest: RestRange = RestRange(90),
            cue: String = "",
            goalMetrics: [MetricKind] = [.estimatedOneRepMax, .topSetLoad]
        ) {
            self.aliases = aliases
            self.defaultRest = defaultRest
            self.cue = cue
            self.goalMetrics = goalMetrics
        }
    }

    public var slug: String
    public var name: String
    public var aliases: [String]
    public var pillars: Set<Pillar>
    public var kind: ActivityKind
    public var primaryMuscles: [MuscleGroup]
    public var secondaryMuscles: [MuscleGroup]
    public var equipment: [Equipment]
    public var isUnilateral: Bool
    public var defaultRest: RestRange
    public var cue: String
    /// The metrics worth setting a goal against for this movement.
    public var goalMetrics: [MetricKind]

    public var id: String { slug }

    public init(
        slug: String,
        name: String,
        pillars: Set<Pillar>,
        kind: ActivityKind,
        anatomy: Anatomy = .init(),
        config: ExerciseConfig = .init()
    ) {
        self.slug = slug
        self.name = name
        self.aliases = config.aliases
        self.pillars = pillars
        self.kind = kind
        self.primaryMuscles = anatomy.primaryMuscles
        self.secondaryMuscles = anatomy.secondaryMuscles
        self.equipment = anatomy.equipment
        self.isUnilateral = anatomy.isUnilateral
        self.defaultRest = config.defaultRest
        self.cue = config.cue
        self.goalMetrics = config.goalMetrics
    }
}''')

print("Struct definitions applied successfully!")
