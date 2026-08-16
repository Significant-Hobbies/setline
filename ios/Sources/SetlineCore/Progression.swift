import Foundation

/// What to do with the load next time this movement comes up.
public enum ProgressionAction: String, Equatable, Sendable {
    /// Every working set reached the top of the rep range cleanly.
    case addLoad
    /// Hold the load and add repetitions inside the range.
    case addRepetitions
    /// The last session fell below the bottom of the range; reduce the load.
    case reduceLoad
    /// Not enough comparable evidence to say anything.
    case insufficientEvidence
}

public struct ProgressionRecommendation: Equatable, Sendable {
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
    }

    /// A short audit line such as "8, 8, 8 at 65 kg".
    public var evidenceSummary: String? {
        guard !lastSessionRepetitions.isEmpty else { return nil }
        let reps = lastSessionRepetitions.map(String.init).joined(separator: ", ")
        guard let currentLoad else { return reps }
        return "\(reps) at \(currentLoad.trimmedString) kg"
    }
}

/// Double progression: add repetitions inside the prescribed range first, then
/// add load once every working set sits at the top of it.
///
/// The rule and its increment come from the authored programme rather than a flat
/// default, so bench moves in 2.5 kg only after `3 × 8` is clean while a machine
/// moves by one increment.
public enum ProgressionEngine {
    /// What the most recent session that trained this movement actually produced.
    struct LatestEvidence: Equatable, Sendable {
        var repetitions: [Int]
        /// Nil when the movement was unloaded or the working sets used different
        /// loads, in which case no single load can be recommended.
        var currentLoad: Double?
        var date: Date?
    }

    static func latestEvidence(for exerciseName: String, history: [WorkoutSession]) -> LatestEvidence? {
        // Only completed working sets from the most recent session that trained
        // this movement. Warm-ups and preparation never inform progression.
        let steps = ExerciseMetrics.workingSteps(for: exerciseName, history: history)
        guard let latestSessionID = steps.first?.session.id else { return nil }
        let sorted = steps
            .filter { $0.session.id == latestSessionID }
            .sorted { $0.step.authoredPosition < $1.step.authoredPosition }
        guard !sorted.isEmpty else { return nil }

        let repetitions = sorted
            .map { $0.step.segments.compactMap(\.repetitions).reduce(0, +) }
            .filter { $0 > 0 }
        guard !repetitions.isEmpty else { return nil }

        let loads = sorted.compactMap { $0.step.segments.first?.effectiveKilograms }
        let distinctLoads = Set(loads.map { ($0 * 100).rounded() })
        return LatestEvidence(
            repetitions: repetitions,
            currentLoad: distinctLoads.count == 1 ? loads.first : nil,
            date: sorted.compactMap(\.step.completedAt).max() ?? sorted.first?.session.completedAt
        )
    }

    /// Recommends the next load for an exercise using its authored rule.
    public static func recommendation(
        for exerciseName: String,
        slug: String? = nil,
        rule: ProgressionRule?,
        history: [WorkoutSession]
    ) -> ProgressionRecommendation? {
        let resolvedSlug = slug ?? ExerciseCatalogue.match(name: exerciseName)?.slug
        let resolvedRule = rule ?? resolvedSlug.flatMap { TwelveWeekProgramme.rule(forSlug: $0) }
        guard let evidence = latestEvidence(for: exerciseName, history: history) else { return nil }

        func recommend(
            _ action: ProgressionAction,
            recommendedLoad: Double? = nil,
            rationale: String
        ) -> ProgressionRecommendation {
            ProgressionRecommendation(
                exerciseName: exerciseName,
                exerciseSlug: resolvedSlug,
                action: action,
                currentLoad: evidence.currentLoad,
                recommendedLoad: recommendedLoad,
                lastSessionRepetitions: evidence.repetitions,
                lastSessionDate: evidence.date,
                rationale: rationale
            )
        }

        guard let resolvedRule, resolvedRule.repsHigh > 0 else {
            return recommend(
                .insufficientEvidence,
                rationale: "No authored rep range for this movement, so Setline will not suggest a load."
            )
        }

        let range = "\(resolvedRule.repsLow)–\(resolvedRule.repsHigh) reps"
        if evidence.repetitions.contains(where: { $0 < resolvedRule.repsLow }) {
            let increment = resolvedRule.incrementKilograms ?? 2.5
            return recommend(
                .reduceLoad,
                recommendedLoad: evidence.currentLoad.map { max(0, $0 - increment) },
                rationale: "At least one working set fell below \(resolvedRule.repsLow) reps. Reduce the load and rebuild inside \(range)."
            )
        }

        if evidence.repetitions.allSatisfy({ $0 >= resolvedRule.repsHigh }) {
            guard let currentLoad = evidence.currentLoad, let increment = resolvedRule.incrementKilograms else {
                return recommend(
                    .addLoad,
                    rationale: "Every working set reached \(resolvedRule.repsHigh) reps. \(resolvedRule.specialRule)"
                )
            }
            return recommend(
                .addLoad,
                recommendedLoad: currentLoad + increment,
                rationale: "Every working set reached \(resolvedRule.repsHigh) reps at \(currentLoad.trimmedString) kg. \(resolvedRule.specialRule)"
            )
        }

        return recommend(
            .addRepetitions,
            recommendedLoad: evidence.currentLoad,
            rationale: "Keep the load and add repetitions until every set reaches \(resolvedRule.repsHigh), then increase."
        )
    }

    /// Recommendations for every movement with recorded working sets, ordered by
    /// how recently it was trained.
    public static func recommendations(history: [WorkoutSession]) -> [ProgressionRecommendation] {
        var seen = Set<String>()
        var names: [String] = []
        for session in history {
            for step in session.steps where step.countsTowardVolume {
                let key = ExerciseMetrics.normalise(step.exerciseName)
                if seen.insert(key).inserted { names.append(step.exerciseName) }
            }
        }
        return names.compactMap { name in
            recommendation(for: name, rule: nil, history: history)
        }
        .filter { $0.action != .insufficientEvidence }
    }
}
