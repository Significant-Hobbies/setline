import Foundation

/// A measurable quality of one exercise. Every "current" value Setline shows and
/// every "ideal" value you author is expressed as one of these, so the two are
/// always comparable.
public enum MetricKind: String, Codable, CaseIterable, Sendable {
    /// Estimated one-repetition maximum, in kilograms.
    case estimatedOneRepMax
    /// Heaviest load completed for at least a reference repetition count.
    case topSetLoad
    /// Most repetitions completed in a single set.
    case maxRepetitions
    /// Longest hold or carry, in seconds.
    case bestHoldSeconds
    /// Furthest single effort, in metres.
    case longestDistanceMetres
    /// Quickest pace, in seconds per kilometre. Lower is better.
    case bestPaceSecondsPerKilometre
    /// Measured range, in the unit the movement is assessed in.
    case rangeOfMotion

    public var title: String {
        switch self {
        case .estimatedOneRepMax: "Estimated 1RM"
        case .topSetLoad: "Top set load"
        case .maxRepetitions: "Max repetitions"
        case .bestHoldSeconds: "Best hold"
        case .longestDistanceMetres: "Longest distance"
        case .bestPaceSecondsPerKilometre: "Best pace"
        case .rangeOfMotion: "Range of motion"
        }
    }

    public var unit: String {
        switch self {
        case .estimatedOneRepMax, .topSetLoad: "kg"
        case .maxRepetitions: "reps"
        case .bestHoldSeconds: "sec"
        case .longestDistanceMetres: "m"
        case .bestPaceSecondsPerKilometre: "/km"
        case .rangeOfMotion: "cm"
        }
    }

    /// Pace improves as it falls; every other metric improves as it rises.
    public var lowerIsBetter: Bool { self == .bestPaceSecondsPerKilometre }

    /// Metrics that only mean something when the movement is loaded.
    public var requiresLoad: Bool {
        self == .estimatedOneRepMax || self == .topSetLoad
    }

    public func format(_ value: Double) -> String {
        switch self {
        case .estimatedOneRepMax, .topSetLoad: "\(value.kilogramString) kg"
        case .maxRepetitions: "\(Int(value)) reps"
        case .bestHoldSeconds: Int(value).durationLabel
        case .longestDistanceMetres: value.distanceLabel
        case .bestPaceSecondsPerKilometre: "\(Int(value).paceLabel)/km"
        case .rangeOfMotion: "\(value.trimmedString) cm"
        }
    }
}

/// The ideal you are training toward for one exercise.
public struct ExerciseGoal: Codable, Equatable, Identifiable, Sendable {
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
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) ?? ""
        metric = try container.decodeIfPresent(MetricKind.self, forKey: .metric) ?? .estimatedOneRepMax
        targetValue = try container.decodeIfPresent(Double.self, forKey: .targetValue) ?? 0
        referenceRepetitions = try container.decodeIfPresent(Int.self, forKey: .referenceRepetitions)
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }
}

/// One measured point, always carrying the session that produced it. Setline
/// never shows a number it cannot attribute to a recorded set.
public struct MeasuredValue: Equatable, Identifiable, Sendable {
    public var id: UUID { sessionID }
    public var metric: MetricKind
    public var value: Double
    public var repetitions: Int?
    public var achievedAt: Date
    public var sessionID: UUID
    public var sessionName: String

    public init(
        metric: MetricKind,
        value: Double,
        repetitions: Int? = nil,
        achievedAt: Date,
        sessionID: UUID,
        sessionName: String
    ) {
        self.metric = metric
        self.value = value
        self.repetitions = repetitions
        self.achievedAt = achievedAt
        self.sessionID = sessionID
        self.sessionName = sessionName
    }

    public var provenance: String {
        "\(sessionName) · \(achievedAt.formatted(date: .abbreviated, time: .omitted))"
    }
}

/// How far a goal has come and, when the evidence supports it, where it is headed.
public struct GoalProgress: Equatable, Sendable {
    public var goal: ExerciseGoal
    /// The best recorded value, or nil when nothing comparable has been recorded.
    public var current: MeasuredValue?
    /// Where the metric stood when the goal was created, used as the origin.
    public var baseline: MeasuredValue?
    /// 0 to 1 from baseline to target. Nil when there is no evidence to measure.
    public var fraction: Double?
    public var remaining: Double?
    /// Change per week across the recorded series. Nil below two data points.
    public var ratePerWeek: Double?
    public var projectedDate: Date?
    public var evidenceCount: Int

    public var isAchieved: Bool {
        guard let current else { return false }
        return goal.metric.lowerIsBetter
            ? current.value <= goal.targetValue
            : current.value >= goal.targetValue
    }
}

/// Derives current values, records and goal progress from recorded history.
///
/// Everything here reads only completed **working** sets. Warm-up ramps,
/// preparation and cooldown work are deliberately invisible to measurement, in
/// line with the authored rule that warm-ups are not working sets.
public enum ExerciseMetrics {
    /// Epley. Deliberately capped: past about 12 repetitions the estimate stops
    /// being a strength measurement, so Setline declines to report one.
    static let maximumRepetitionsForEstimate = 12

    public static func normalise(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func estimatedOneRepMax(kilograms: Double, repetitions: Int) -> Double? {
        guard kilograms > 0, repetitions > 0, repetitions <= maximumRepetitionsForEstimate else {
            return nil
        }
        if repetitions == 1 { return kilograms }
        return kilograms * (1 + Double(repetitions) / 30)
    }

    /// Every completed working step for one exercise, newest first.
    public static func workingSteps(
        for exerciseName: String,
        history: [WorkoutSession]
    ) -> [(session: WorkoutSession, step: WorkoutStep)] {
        let key = normalise(exerciseName)
        return history.flatMap { session in
            session.steps
                .filter { normalise($0.exerciseName) == key && $0.countsTowardVolume }
                .map { (session, $0) }
        }
    }

    /// The measured series for a metric, oldest first, one best point per session.
    public static func series(
        for exerciseName: String,
        metric: MetricKind,
        referenceRepetitions: Int? = nil,
        history: [WorkoutSession]
    ) -> [MeasuredValue] {
        var bestBySession: [UUID: MeasuredValue] = [:]
        for (session, step) in workingSteps(for: exerciseName, history: history) {
            guard let candidate = value(
                for: metric,
                step: step,
                session: session,
                referenceRepetitions: referenceRepetitions
            ) else { continue }
            if let existing = bestBySession[session.id], !improves(candidate.value, on: existing.value, metric: metric) {
                continue
            }
            bestBySession[session.id] = candidate
        }
        return bestBySession.values.sorted { $0.achievedAt < $1.achievedAt }
    }

    /// The single best recorded value for a metric.
    public static func current(
        for exerciseName: String,
        metric: MetricKind,
        referenceRepetitions: Int? = nil,
        history: [WorkoutSession]
    ) -> MeasuredValue? {
        series(
            for: exerciseName,
            metric: metric,
            referenceRepetitions: referenceRepetitions,
            history: history
        ).max { improves($1.value, on: $0.value, metric: metric) }
    }

    /// Which metrics this exercise has actually produced evidence for.
    public static func availableMetrics(
        for exerciseName: String,
        history: [WorkoutSession]
    ) -> [MetricKind] {
        MetricKind.allCases.filter { metric in
            !series(for: exerciseName, metric: metric, history: history).isEmpty
        }
    }

    public static func progress(for goal: ExerciseGoal, history: [WorkoutSession]) -> GoalProgress {
        let points = series(
            for: goal.exerciseName,
            metric: goal.metric,
            referenceRepetitions: goal.referenceRepetitions,
            history: history
        )
        let current = points.max { improves($1.value, on: $0.value, metric: goal.metric) }
        // The origin is the last measurement at or before the goal was authored;
        // without one, the earliest point available.
        let baseline = points.last { $0.achievedAt <= goal.createdAt } ?? points.first
        var fraction: Double?
        var remaining: Double?
        if let current {
            remaining = goal.metric.lowerIsBetter
                ? max(0, current.value - goal.targetValue)
                : max(0, goal.targetValue - current.value)
            if let baseline {
                let span = goal.metric.lowerIsBetter
                    ? baseline.value - goal.targetValue
                    : goal.targetValue - baseline.value
                let travelled = goal.metric.lowerIsBetter
                    ? baseline.value - current.value
                    : current.value - baseline.value
                if span > 0 { fraction = min(1, max(0, travelled / span)) }
            }
        }
        let rate = ratePerWeek(points, metric: goal.metric)
        return GoalProgress(
            goal: goal,
            current: current,
            baseline: baseline,
            fraction: fraction,
            remaining: remaining,
            ratePerWeek: rate,
            projectedDate: projectedDate(
                current: current,
                remaining: remaining,
                ratePerWeek: rate,
                metric: goal.metric
            ),
            evidenceCount: points.count
        )
    }

    // MARK: - Internals

    static func improves(_ candidate: Double, on existing: Double, metric: MetricKind) -> Bool {
        metric.lowerIsBetter ? candidate < existing : candidate > existing
    }

    /// One measurement of a step, or nil when the step cannot express that metric.
    ///
    /// Each metric reads the recorded segments in its own way, so the dispatch and
    /// the per-metric arithmetic are kept apart.
    static func value(
        for metric: MetricKind,
        step: WorkoutStep,
        session: WorkoutSession,
        referenceRepetitions: Int?
    ) -> MeasuredValue? {
        guard let reading = reading(for: metric, step: step, referenceRepetitions: referenceRepetitions) else {
            return nil
        }
        return MeasuredValue(
            metric: metric,
            value: reading.value,
            repetitions: reading.repetitions,
            achievedAt: step.completedAt ?? session.completedAt ?? session.startedAt,
            sessionID: session.id,
            sessionName: session.templateName
        )
    }

    static func reading(
        for metric: MetricKind,
        step: WorkoutStep,
        referenceRepetitions: Int?
    ) -> (value: Double, repetitions: Int?)? {
        switch metric {
        case .estimatedOneRepMax: bestEstimatedOneRepMax(in: step.segments)
        case .topSetLoad: heaviestLoad(in: step.segments, atLeast: referenceRepetitions ?? 1)
        case .maxRepetitions: totalRepetitions(in: step.segments)
        case .bestHoldSeconds: longestHold(in: step.segments)
        case .longestDistanceMetres: furthestDistance(in: step.segments)
        case .bestPaceSecondsPerKilometre: quickestPace(in: step.segments)
        case .rangeOfMotion: deepestRange(in: step.segments)
        }
    }

    static func bestEstimatedOneRepMax(in segments: [SetSegment]) -> (Double, Int?)? {
        let estimates = segments.compactMap { segment -> (Double, Int)? in
            guard let kilograms = segment.effectiveKilograms,
                  let reps = segment.repetitions,
                  let estimate = estimatedOneRepMax(kilograms: kilograms, repetitions: reps)
            else { return nil }
            return (estimate, reps)
        }
        guard let best = estimates.max(by: { $0.0 < $1.0 }) else { return nil }
        return (best.0, best.1)
    }

    static func heaviestLoad(in segments: [SetSegment], atLeast minimumReps: Int) -> (Double, Int?)? {
        let loads = segments.compactMap { segment -> (Double, Int)? in
            guard let kilograms = segment.effectiveKilograms,
                  let reps = segment.repetitions,
                  reps >= minimumReps
            else { return nil }
            return (kilograms, reps)
        }
        guard let best = loads.max(by: { $0.0 < $1.0 }) else { return nil }
        return (best.0, best.1)
    }

    /// Summed across segments: `5×40 + 2×30` is seven repetitions of work.
    static func totalRepetitions(in segments: [SetSegment]) -> (Double, Int?)? {
        let reps = segments.compactMap(\.repetitions).reduce(0, +)
        guard reps > 0 else { return nil }
        return (Double(reps), reps)
    }

    static func longestHold(in segments: [SetSegment]) -> (Double, Int?)? {
        let seconds = segments.compactMap { $0.durationSeconds ?? $0.workSeconds }
        guard let best = seconds.max(), best > 0 else { return nil }
        return (Double(best), nil)
    }

    static func furthestDistance(in segments: [SetSegment]) -> (Double, Int?)? {
        let metres = segments.compactMap(\.distanceKilometres).map { $0 * 1_000 }
        guard let best = metres.max(), best > 0 else { return nil }
        return (best, nil)
    }

    static func quickestPace(in segments: [SetSegment]) -> (Double, Int?)? {
        let paces = segments.compactMap { segment -> Double? in
            guard let kilometres = segment.distanceKilometres, kilometres > 0,
                  let seconds = segment.durationSeconds ?? segment.workSeconds, seconds > 0
            else { return nil }
            return Double(seconds) / kilometres
        }
        guard let best = paces.min() else { return nil }
        return (best, nil)
    }

    static func deepestRange(in segments: [SetSegment]) -> (Double, Int?)? {
        let values = segments.compactMap(\.rangeOfMotionValue)
        guard let best = values.max(), best > 0 else { return nil }
        return (best, nil)
    }

    /// Least-squares slope over time, expressed per week. Nil below two points or
    /// when every point shares a timestamp.
    static func ratePerWeek(_ points: [MeasuredValue], metric: MetricKind) -> Double? {
        guard points.count >= 2 else { return nil }
        let origin = points[0].achievedAt.timeIntervalSince1970
        let weeks = points.map { ($0.achievedAt.timeIntervalSince1970 - origin) / 604_800 }
        let values = points.map(\.value)
        let meanWeek = weeks.reduce(0, +) / Double(weeks.count)
        let meanValue = values.reduce(0, +) / Double(values.count)
        var covariance = 0.0
        var variance = 0.0
        for index in weeks.indices {
            let deltaWeek = weeks[index] - meanWeek
            covariance += deltaWeek * (values[index] - meanValue)
            variance += deltaWeek * deltaWeek
        }
        guard variance > 0 else { return nil }
        return covariance / variance
    }

    static func projectedDate(
        current: MeasuredValue?,
        remaining: Double?,
        ratePerWeek: Double?,
        metric: MetricKind
    ) -> Date? {
        guard let current, let remaining, remaining > 0, let ratePerWeek else { return nil }
        // A trend moving away from the goal cannot produce an arrival date. For
        // pace, improvement is a falling value; for everything else, a rising one.
        let progressPerWeek = metric.lowerIsBetter ? -ratePerWeek : ratePerWeek
        guard progressPerWeek > 0 else { return nil }
        let weeks = remaining / progressPerWeek
        guard weeks.isFinite, weeks > 0, weeks < 520 else { return nil }
        return current.achievedAt.addingTimeInterval(weeks * 604_800)
    }
}
