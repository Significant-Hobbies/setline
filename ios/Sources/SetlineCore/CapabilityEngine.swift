import Foundation

/// One assessment resolved against the document: its definition, the evidence
/// found, the fraction of the checkpoint demonstrated, and whether it passes.
public struct AssessmentResult: Equatable, Sendable {
    public let assessment: CapabilityAssessment
    public let evidence: CapabilityEvidence
    /// 0–1 share of this checkpoint demonstrated. Nil when unassessed — a
    /// missing slot contributes nothing rather than counting as failure.
    public let fraction: Double?
    public let isPassed: Bool

    public var isAssessed: Bool { evidence.kind != .missing }
}

/// One axis's curriculum score with the coverage that produced it.
public struct AxisScore: Equatable, Sendable {
    public let axis: AbilityAxis
    /// Versioned 0–100 curriculum score. See `CapabilityEngine.curriculumVersion`.
    public let score: Int
    /// Assessments with any usable evidence.
    public let assessed: Int
    public let total: Int
    /// Weighted share of the curriculum demonstrated, 0–1.
    public let demonstrated: Double
    /// Most recent evidence date across the axis. Nil when nothing is recorded.
    public let lastVerified: Date?
    public let results: [AssessmentResult]

    public var coverageFraction: Double { total == 0 ? 0 : Double(assessed) / Double(total) }
    public var isFullyCovered: Bool { assessed == total }
}

/// What the programme should do with one axis this cycle.
public enum AxisStatus: String, Codable, Sendable {
    /// No usable evidence — establish a baseline before judging anything.
    case unassessed
    /// Unmet checkpoints remain; progress toward them.
    case build
    /// Every checkpoint met; preserve and verify periodically.
    case maintain
    /// A user-selected ambitious focus despite the larger time cost.
    case specialize

    public var title: String {
        switch self {
        case .unassessed: "Unassessed"
        case .build: "Build"
        case .maintain: "Maintain"
        case .specialize: "Specialize"
        }
    }
}

/// The prioritizer's decision for one axis.
public struct AxisPlan: Equatable, Sendable {
    public let axis: AbilityAxis
    public let status: AxisStatus
    /// 1-based rank when this axis is a selected priority, else nil.
    public let priorityRank: Int?
    /// Why the axis holds this status — inspectable, deterministic wording.
    public let rationale: String
    /// The first unmet checkpoint in curriculum order.
    public let nextCheckpoint: CapabilityAssessment?
}

/// The whole decision: per-axis plans plus the one or two selected priorities.
public struct CapabilityPlan: Equatable, Sendable {
    public let axes: [AxisPlan]
    /// One or two primary improvement priorities, most important first.
    public let priorities: [AbilityAxis]
}

/// Resolves evidence, scores the curriculum, and decides priorities.
///
/// Everything here is deterministic and inspectable: the same document always
/// produces the same profile and plan, and every judgement cites the definition
/// and evidence behind it.
public enum CapabilityEngine {
    /// The curriculum scoring version. Bump it when the assessment set or the
    /// scoring rule changes so stored interpretations stay attributable.
    public static let curriculumVersion = 1

    /// A priority selection never covers more than two axes at once.
    public static let maximumPriorities = 2

    // MARK: - Evidence resolution

    /// Resolves one assessment against the document's existing state. Reads
    /// workout history, benchmark records, and mobility records — the shared
    /// layer stores nothing of its own.
    public static func resolve(
        _ assessment: CapabilityAssessment,
        in document: SetlineDocument
    ) -> AssessmentResult {
        switch assessment.source {
        case let .benchmark(id):
            return resolveBenchmark(assessment, benchmarkID: id, in: document)
        case let .mobilityCard(id):
            return resolveMobilityCard(assessment, cardID: id, in: document)
        case let .loggedMetric(exercise, metric):
            return resolveLoggedMetric(assessment, exercise: exercise, metric: metric, in: document)
        }
    }

    /// A benchmark is passed when its record reaches the target. When nothing
    /// is recorded, a qualifying logged performance can still satisfy it — but
    /// only for single-criterion assessments that opted in.
    private static func resolveBenchmark(
        _ assessment: CapabilityAssessment,
        benchmarkID: String,
        in document: SetlineDocument
    ) -> AssessmentResult {
        let benchmarks = document.benchmarks
        let assessed = BenchmarkEngine.assess(benchmarkID, state: benchmarks)
        if assessed.recorded {
            let state = benchmarks.metrics[benchmarkID]
            let kind: EvidenceKind = (state?.reported ?? false) ? .selfReported : .measured
            return AssessmentResult(
                assessment: assessment,
                evidence: CapabilityEvidence(
                    kind: kind,
                    value: assessment.evidenceField.flatMap { state?.number($0) },
                    provenance: assessed.current,
                    achievedAt: benchmarks.updated[benchmarkID]
                ),
                fraction: assessed.reached ? 1 : 0,
                isPassed: assessed.reached
            )
        }
        // No benchmark record — fall back to logged workout evidence when a
        // suggestion exists. The evidence is shown as measured either way, but
        // only single-criterion assessments that opted in can pass from it: a
        // logged distance alone cannot satisfy a distance-and-time checkpoint.
        guard let suggestion = historySuggestion(for: benchmarkID, in: document.history),
              let field = assessment.evidenceField,
              let value = suggestion.numbers[field]
        else {
            return AssessmentResult(
                assessment: assessment,
                evidence: .missing,
                fraction: nil,
                isPassed: false
            )
        }
        let target = assessment.targetField.flatMap {
            benchmarks.targets[benchmarkID]?.value($0)
                ?? BenchmarkCatalog.defaultTargets[benchmarkID]?.value($0)
        }
        let unlocked = assessment.unlocksFromHistory && (target.map { value >= $0 } ?? false)
        return AssessmentResult(
            assessment: assessment,
            evidence: CapabilityEvidence(
                kind: .measured,
                value: value,
                provenance: "\(suggestion.sourceExerciseName) · \(suggestion.sourceDate.formatted(date: .abbreviated, time: .omitted))",
                achievedAt: suggestion.sourceDate
            ),
            fraction: unlocked ? 1 : 0,
            isPassed: unlocked
        )
    }

    /// Logged evidence for a benchmark, reusing the existing bridge so the
    /// semantic matches live in exactly one place.
    private static func historySuggestion(
        for benchmarkID: String,
        in history: [WorkoutSession]
    ) -> BenchmarkSuggestion? {
        BenchmarkHistoryBridge.suggestions(from: history).first { $0.metricID == benchmarkID }
    }

    /// A mobility card is scored by the share of its check slots demonstrated.
    /// Symptom-blocked slots are assessed but cannot demonstrate; untested
    /// slots keep the card visibly incomplete.
    private static func resolveMobilityCard(
        _ assessment: CapabilityAssessment,
        cardID: String,
        in document: SetlineDocument
    ) -> AssessmentResult {
        guard let card = MobilityCatalog.card(for: cardID) else {
            return AssessmentResult(assessment: assessment, evidence: .missing, fraction: nil, isPassed: false)
        }
        let summary = MobilityEngine.summary(for: card, in: document.mobility)
        guard summary.hasBaseline else {
            return AssessmentResult(assessment: assessment, evidence: .missing, fraction: nil, isPassed: false)
        }
        let fraction = summary.total == 0 ? 0 : Double(summary.demonstrated) / Double(summary.total)
        let passed = fraction >= 1 && summary.symptomBlocked == 0
        return AssessmentResult(
            assessment: assessment,
            evidence: CapabilityEvidence(
                kind: .measured,
                value: fraction,
                provenance: "\(summary.demonstrated) of \(summary.total) checks demonstrated",
                achievedAt: document.mobility.updated[cardID]
            ),
            fraction: fraction,
            isPassed: passed
        )
    }

    private static func resolveLoggedMetric(
        _ assessment: CapabilityAssessment,
        exercise: String,
        metric: MetricKind,
        in document: SetlineDocument
    ) -> AssessmentResult {
        guard let current = ExerciseMetrics.current(for: exercise, metric: metric, history: document.history) else {
            return AssessmentResult(assessment: assessment, evidence: .missing, fraction: nil, isPassed: false)
        }
        let kind: EvidenceKind = metric == .estimatedOneRepMax ? .estimated : .measured
        let passed = assessment.thresholdMet(current.value)
        return AssessmentResult(
            assessment: assessment,
            evidence: CapabilityEvidence(
                kind: kind,
                value: current.value,
                provenance: current.provenance,
                achievedAt: current.achievedAt
            ),
            fraction: passed ? 1 : 0,
            isPassed: passed
        )
    }

    // MARK: - Scoring

    /// One axis's curriculum score. The score is the weighted share of the
    /// curriculum demonstrated; unassessed checkpoints keep coverage visibly
    /// incomplete rather than silently renormalising the score.
    public static func axisScore(_ axis: AbilityAxis, in document: SetlineDocument) -> AxisScore {
        let results = CapabilityAssessmentCatalog.assessments(for: axis).map { resolve($0, in: document) }
        let totalWeight = results.reduce(0) { $0 + $1.assessment.weight }
        let demonstrated = results.reduce(0) { $0 + ($1.fraction ?? 0) * $1.assessment.weight }
        let score = totalWeight > 0 ? Int((demonstrated / totalWeight * 100).rounded()) : 0
        let verified = results.compactMap(\.evidence.achievedAt).max()
        return AxisScore(
            axis: axis,
            score: score,
            assessed: results.count(where: \.isAssessed),
            total: results.count,
            demonstrated: totalWeight > 0 ? demonstrated / totalWeight : 0,
            lastVerified: verified,
            results: results
        )
    }

    /// The four-axis profile, in axis order.
    public static func profile(in document: SetlineDocument) -> [AxisScore] {
        AbilityAxis.allCases.map { axisScore($0, in: document) }
    }

    // MARK: - Prioritization

    /// Decides each axis's status and picks one or two priorities.
    ///
    /// Ranking is deterministic: user-selected focus axes first, then axes a
    /// user's exercise goals point at, then axes still missing a baseline, then
    /// lowest demonstrated share. The lowest score never wins on its own.
    public static func plan(
        in document: SetlineDocument,
        focusAxes: Set<AbilityAxis> = []
    ) -> CapabilityPlan {
        let scores = profile(in: document)
        let goalAxes = goalRelevantAxes(in: document)
        let plans = scores.map { score -> AxisPlan in
            let status = status(for: score, focusAxes: focusAxes)
            return AxisPlan(
                axis: score.axis,
                status: status,
                priorityRank: nil,
                rationale: rationale(for: score, status: status, goalAxes: goalAxes),
                nextCheckpoint: score.results.first { !$0.isPassed }?.assessment
            )
        }
        let priorities = selectPriorities(from: scores, focusAxes: focusAxes, goalAxes: goalAxes)
        return CapabilityPlan(
            axes: plans.map { plan in
                AxisPlan(
                    axis: plan.axis,
                    status: plan.status,
                    priorityRank: priorities.firstIndex(of: plan.axis).map { $0 + 1 },
                    rationale: plan.rationale,
                    nextCheckpoint: plan.nextCheckpoint
                )
            },
            priorities: priorities
        )
    }

    /// Axes an exercise goal touches, via the catalogue's pillar tags.
    private static func goalRelevantAxes(in document: SetlineDocument) -> Set<AbilityAxis> {
        var axes = Set<AbilityAxis>()
        for goal in document.goals {
            guard let definition = ExerciseCatalogue.match(name: goal.exerciseName) else { continue }
            for axis in AbilityAxis.allCases where !Set(axis.pillars).isDisjoint(with: definition.pillars) {
                axes.insert(axis)
            }
        }
        return axes
    }

    private static func status(for score: AxisScore, focusAxes: Set<AbilityAxis>) -> AxisStatus {
        if focusAxes.contains(score.axis) { return .specialize }
        if score.assessed == 0 { return .unassessed }
        if score.results.allSatisfy(\.isPassed) { return .maintain }
        return .build
    }

    private static func rationale(
        for score: AxisScore,
        status: AxisStatus,
        goalAxes: Set<AbilityAxis>
    ) -> String {
        let goalNote = goalAxes.contains(score.axis) ? " Your goals point here." : ""
        switch status {
        case .unassessed:
            return "No evidence yet — establish a baseline before this axis can be judged."
        case .maintain:
            return "Every authored checkpoint is met. Preserve the ability and verify it periodically."
        case .specialize:
            return "A focus you selected; it carries a larger share of training time by choice.\(goalNote)"
        case .build:
            let remaining = score.results.count { !$0.isPassed }
            return "\(remaining) checkpoint\(remaining == 1 ? "" : "s") unfinished.\(goalNote)"
        }
    }

    /// One or two priorities, ranked by focus → goal relevance → unassessed →
    /// lowest demonstrated share, with authored axis order breaking ties.
    private static func selectPriorities(
        from scores: [AxisScore],
        focusAxes: Set<AbilityAxis>,
        goalAxes: Set<AbilityAxis>
    ) -> [AbilityAxis] {
        scores
            .filter { score in
                !score.results.isEmpty && !score.results.allSatisfy(\.isPassed)
            }
            .sorted { left, right in
                rank(of: left, focusAxes: focusAxes, goalAxes: goalAxes)
                    < rank(of: right, focusAxes: focusAxes, goalAxes: goalAxes)
            }
            .prefix(maximumPriorities)
            .map(\.axis)
    }

    /// Lower sorts earlier. Focus beats goal relevance beats baseline-needed
    /// beats demonstrated share; the score itself only matters after all that.
    private static func rank(
        of score: AxisScore,
        focusAxes: Set<AbilityAxis>,
        goalAxes: Set<AbilityAxis>
    ) -> (Int, Int, Int, Double) {
        (
            focusAxes.contains(score.axis) ? 0 : 1,
            goalAxes.contains(score.axis) ? 0 : 1,
            score.assessed == 0 ? 0 : 1,
            score.demonstrated
        )
    }
}

private extension CapabilityAssessment {
    /// Whether a logged value clears this assessment's checkpoint. Benchmark
    /// sources resolve their checkpoint through the target fields instead; a
    /// logged-metric source needs an explicit threshold on the definition.
    func thresholdMet(_ value: Double) -> Bool {
        guard case let .loggedMetric(_, metric) = source, let threshold else {
            return false
        }
        return metric.lowerIsBetter ? value <= threshold : value >= threshold
    }
}
