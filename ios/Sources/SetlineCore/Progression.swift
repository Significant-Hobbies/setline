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
    /// Recommends the next load for an exercise using its authored rule.
    public static func recommendation(
        for exerciseName: String,
        slug: String? = nil,
        rule: ProgressionRule?,
        history: [WorkoutSession]
    ) -> ProgressionRecommendation? {
        let resolvedSlug = slug ?? ExerciseCatalogue.match(name: exerciseName)?.slug
        let resolvedRule = rule ?? resolvedSlug.flatMap { TwelveWeekProgramme.rule(forSlug: $0) }

        // Only completed working sets from the most recent session that trained
        // this movement. Warm-ups and preparation never inform progression.
        let steps = ExerciseMetrics.workingSteps(for: exerciseName, history: history)
        guard let latestSessionID = steps.first?.session.id else { return nil }
        let latest = steps.filter { $0.session.id == latestSessionID }
        guard !latest.isEmpty else { return nil }

        let sorted = latest.sorted { $0.step.authoredPosition < $1.step.authoredPosition }
        let repetitions = sorted.compactMap { entry in
            entry.step.segments.compactMap(\.repetitions).reduce(0, +)
        }.filter { $0 > 0 }
        let loads = sorted.compactMap { $0.step.segments.first?.effectiveKilograms }
        let date = sorted.compactMap(\.step.completedAt).max() ?? sorted.first?.session.completedAt

        guard !repetitions.isEmpty else { return nil }

        // A load recommendation only makes sense when the movement was loaded and
        // every working set used the same load.
        let uniqueLoads = Set(loads.map { ($0 * 100).rounded() })
        let currentLoad = uniqueLoads.count == 1 ? loads.first : nil

        guard let resolvedRule, resolvedRule.repsHigh > 0 else {
            return ProgressionRecommendation(
                exerciseName: exerciseName,
                exerciseSlug: resolvedSlug,
                action: .insufficientEvidence,
                currentLoad: currentLoad,
                lastSessionRepetitions: repetitions,
                lastSessionDate: date,
                rationale: "No authored rep range for this movement, so Setline will not suggest a load."
            )
        }

        let allAtTop = repetitions.allSatisfy { $0 >= resolvedRule.repsHigh }
        let anyBelowFloor = repetitions.contains { $0 < resolvedRule.repsLow }
        let range = "\(resolvedRule.repsLow)–\(resolvedRule.repsHigh)"

        if anyBelowFloor {
            let reduced = currentLoad.map { load in
                max(0, load - (resolvedRule.incrementKilograms ?? 2.5))
            }
            return ProgressionRecommendation(
                exerciseName: exerciseName,
                exerciseSlug: resolvedSlug,
                action: .reduceLoad,
                currentLoad: currentLoad,
                recommendedLoad: reduced,
                lastSessionRepetitions: repetitions,
                lastSessionDate: date,
                rationale: "At least one working set fell below \(resolvedRule.repsLow) reps. Reduce the load and rebuild inside \(range)."
            )
        }

        if allAtTop {
            guard let currentLoad else {
                return ProgressionRecommendation(
                    exerciseName: exerciseName,
                    exerciseSlug: resolvedSlug,
                    action: .addLoad,
                    lastSessionRepetitions: repetitions,
                    lastSessionDate: date,
                    rationale: "Every working set reached \(resolvedRule.repsHigh) reps. \(resolvedRule.specialRule)"
                )
            }
            guard let increment = resolvedRule.incrementKilograms else {
                return ProgressionRecommendation(
                    exerciseName: exerciseName,
                    exerciseSlug: resolvedSlug,
                    action: .addLoad,
                    currentLoad: currentLoad,
                    lastSessionRepetitions: repetitions,
                    lastSessionDate: date,
                    rationale: "Every working set reached \(resolvedRule.repsHigh) reps. \(resolvedRule.specialRule)"
                )
            }
            return ProgressionRecommendation(
                exerciseName: exerciseName,
                exerciseSlug: resolvedSlug,
                action: .addLoad,
                currentLoad: currentLoad,
                recommendedLoad: currentLoad + increment,
                lastSessionRepetitions: repetitions,
                lastSessionDate: date,
                rationale: "Every working set reached \(resolvedRule.repsHigh) reps at \(currentLoad.trimmedString) kg. \(resolvedRule.specialRule)"
            )
        }

        return ProgressionRecommendation(
            exerciseName: exerciseName,
            exerciseSlug: resolvedSlug,
            action: .addRepetitions,
            currentLoad: currentLoad,
            recommendedLoad: currentLoad,
            lastSessionRepetitions: repetitions,
            lastSessionDate: date,
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
