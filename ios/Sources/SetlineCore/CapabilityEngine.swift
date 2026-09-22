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
    /// The user reported pain on this assessment — automatic progression is
    /// blocked until cleared, regardless of what the evidence shows.
    public var isPainBlocked: Bool
    /// The user's difficulty verdict, if any.
    public var feedback: CheckpointFeedback?

    public init(
        assessment: CapabilityAssessment,
        evidence: CapabilityEvidence,
        fraction: Double?,
        isPassed: Bool,
        isPainBlocked: Bool = false,
        feedback: CheckpointFeedback? = nil
    ) {
        self.assessment = assessment
        self.evidence = evidence
        self.fraction = fraction
        self.isPassed = isPassed
        self.isPainBlocked = isPainBlocked
        self.feedback = feedback
    }

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
    /// For a maintained axis, when to verify it again. Nil otherwise.
    public let verificationDue: Date?
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

    /// How often a maintained axis asks for verification — four weeks is a
    /// deliberately conservative cadence, shown as guidance.
    public static let maintenanceVerificationInterval: TimeInterval = 28 * 86_400

    // MARK: - Evidence resolution

    /// Resolves one assessment against the document's existing state. Reads
    /// workout history, benchmark records, and mobility records — the shared
    /// layer stores nothing of its own.
    public static func resolve(
        _ assessment: CapabilityAssessment,
        in document: SetlineDocument
    ) -> AssessmentResult {
        var result: AssessmentResult
        switch assessment.source {
        case let .benchmark(id):
            result = resolveBenchmark(assessment, benchmarkID: id, in: document)
        case let .mobilityCard(id):
            result = resolveMobilityCard(assessment, cardID: id, in: document)
        case let .loggedMetric(exercise, metric):
            result = resolveLoggedMetric(assessment, exercise: exercise, metric: metric, in: document)
        }
        result.isPainBlocked = document.capability.painReports[assessment.id] != nil
        result.feedback = document.capability.feedback[assessment.id]
        return result
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
        // The curriculum judges against the authored default targets, not the
        // user's editable ones — a checkpoint must mean the same thing for
        // everyone or the 0–100 score stops meaning anything. User targets
        // still drive the benchmark scorecard itself and the goal markers.
        var curriculumState = benchmarks
        curriculumState.targets = BenchmarkCatalog.defaultTargets
        let assessed = BenchmarkEngine.assess(benchmarkID, state: curriculumState)
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
            BenchmarkCatalog.defaultTargets[benchmarkID]?.value($0)
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

    /// What the axis scores if its next unmet checkpoint is passed — the
    /// dashed outline on the dashboard. Returns the current score when the
    /// axis is already complete.
    public static func projectedScore(_ axis: AbilityAxis, in document: SetlineDocument) -> Int {
        let score = axisScore(axis, in: document)
        guard let next = score.results.first(where: { !$0.isPassed }) else { return score.score }
        let totalWeight = score.results.reduce(0) { $0 + $1.assessment.weight }
        guard totalWeight > 0 else { return score.score }
        let demonstrated = score.demonstrated + next.assessment.weight / totalWeight
        return Int((min(1, demonstrated) * 100).rounded())
    }

    /// The score the axis reaches if the checkpoints a user's goals touch are
    /// passed — the diamond's target marker. A goal counts a checkpoint when
    /// its exercise matches the checkpoint's practice movement. Nil when no
    /// goal points at this axis at all.
    public static func goalProjectedScore(_ axis: AbilityAxis, in document: SetlineDocument) -> Int? {
        let goalSlugs = Set(document.goals.compactMap { ExerciseCatalogue.match(name: $0.exerciseName)?.slug })
        guard goalRelevantAxes(in: document).contains(axis) else { return nil }
        let score = axisScore(axis, in: document)
        let totalWeight = score.results.reduce(0) { $0 + $1.assessment.weight }
        guard totalWeight > 0 else { return nil }
        var demonstrated = score.demonstrated
        var matched = false
        for result in score.results where !result.isPassed {
            guard let slug = result.assessment.practiceSlug, goalSlugs.contains(slug) else { continue }
            demonstrated += result.assessment.weight / totalWeight
            matched = true
        }
        // A goal on the axis but not on any specific checkpoint still shows a
        // marker at the next-checkpoint projection.
        if !matched, let next = score.results.first(where: { !$0.isPassed }) {
            demonstrated += next.assessment.weight / totalWeight
        }
        return Int((min(1, demonstrated) * 100).rounded())
    }

    // MARK: - Prioritization

    /// Decides each axis's status and picks one or two priorities.
    ///
    /// Ranking is deterministic: user-selected focus axes first, then axes a
    /// user's exercise goals point at, then axes still missing a baseline, then
    /// lowest demonstrated share. The lowest score never wins on its own.
    public static func plan(in document: SetlineDocument) -> CapabilityPlan {
        let focusAxes = document.capability.focusAxes
        let scores = profile(in: document)
        let goalAxes = goalRelevantAxes(in: document)
        let plans = scores.map { score -> AxisPlan in
            let status = status(for: score, focusAxes: focusAxes)
            return AxisPlan(
                axis: score.axis,
                status: status,
                priorityRank: nil,
                rationale: rationale(for: score, status: status, goalAxes: goalAxes),
                nextCheckpoint: score.results.first { !$0.isPassed }?.assessment,
                verificationDue: status == .maintain
                    ? score.lastVerified?.addingTimeInterval(maintenanceVerificationInterval)
                    : nil
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
                    nextCheckpoint: plan.nextCheckpoint,
                    verificationDue: plan.verificationDue
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
            let blocked = score.results.count { $0.isPainBlocked }
            let painNote = blocked > 0 ? " Pain reported on \(blocked) — progression paused there." : ""
            return "\(remaining) checkpoint\(remaining == 1 ? "" : "s") unfinished.\(goalNote)\(painNote)"
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

    // MARK: - Sessions and programmes

    /// How many practice exercises a generated axis session carries.
    public static let maximumAxisSessionExercises = 4

    /// A workout template practising one axis's unmet checkpoints, built from
    /// the catalogue exercises each checkpoint links to. Pain-blocked
    /// checkpoints are excluded — reported pain stops automatic progression
    /// for that movement. Mobility reuses the practice set when one exists.
    ///
    /// Sets are working sets so qualifying performances feed the evidence
    /// layer back; mobility-derived exercises stay mobility sets.
    public static func axisTemplate(
        _ axis: AbilityAxis,
        in document: SetlineDocument
    ) -> WorkoutTemplate? {
        if axis == .mobility, !document.mobility.practising.isEmpty {
            return MobilityEngine.practiceTemplate(in: document.mobility)
        }
        let exercises = axisScore(axis, in: document).results
            .filter { !$0.isPassed && !$0.isPainBlocked }
            .prefix(maximumAxisSessionExercises)
            .compactMap { result -> Exercise? in
                guard let slug = result.assessment.practiceSlug,
                      let definition = ExerciseCatalogue.definition(slug: slug) else { return nil }
                // "Too hard" starts below the checkpoint at the easier
                // variation; "too easy" points at the next progression. Either
                // way the cue says why this variation was selected.
                let cue = switch result.feedback {
                case .tooEasy: result.assessment.nextProgression
                default: result.assessment.easierVariation
                }
                return Exercise(
                    name: definition.name,
                    cue: cue,
                    sets: axisSets(for: definition, feedback: result.feedback),
                    definitionSlug: definition.slug,
                    pillars: definition.pillars
                )
            }
        guard !exercises.isEmpty else { return nil }
        return WorkoutTemplate(
            name: "\(axis.title) practice",
            detail: "Unmet checkpoints, easiest first",
            isBundled: false,
            exercises: exercises
        )
    }

    /// Authored sets for one practice exercise, by activity kind. Feedback
    /// adjusts exactly one variable — duration for timed work, repetitions for
    /// everything else — never two at once.
    private static func axisSets(
        for definition: ExerciseDefinition,
        feedback: CheckpointFeedback?
    ) -> [PlannedSet] {
        switch definition.kind {
        case .cardio:
            let seconds: Int = switch feedback {
            case .tooHard: 600
            case .tooEasy: 1_800
            default: 1_200
            }
            return [PlannedSet(
                label: "Easy effort",
                kind: .cardio,
                target: SetTarget(timeTarget: .init(timeSeconds: seconds)),
                rest: RestRange(0),
                config: .init(stepType: .cardio)
            )]
        case .timed:
            let hold: Int = switch feedback {
            case .tooHard: 15
            case .tooEasy: 45
            default: 30
            }
            return [PlannedSet(
                label: "Hold",
                kind: .timed,
                target: SetTarget(timeTarget: .init(holdSeconds: hold), perSide: definition.isUnilateral),
                rest: definition.defaultRest,
                config: .init(stepType: .mobility)
            )]
        default:
            let reps: Int = switch feedback {
            case .tooHard: 5
            case .tooEasy: 12
            default: 8
            }
            let set = PlannedSet(
                label: "Practice",
                kind: definition.kind,
                target: SetTarget(
                    repTarget: .init(repsLow: reps),
                    load: definition.kind == .strength ? .chooseLoad : nil,
                    perSide: definition.isUnilateral
                ),
                rest: definition.defaultRest,
                config: .init(stepType: definition.kind == .mobility ? .mobility : .working)
            )
            return [set, set]
        }
    }

    /// One coordinated programme: at most one session per axis that still has
    /// unmet, unblocked checkpoints — priorities first — spread across the
    /// week within the user's day budget. Returns nil when no axis has
    /// practice work to schedule.
    ///
    /// The emitted programme is an ordinary custom programme: authored order
    /// is preserved and the user keeps full edit and skip rights over it.
    public static func generateProgramme(
        in document: SetlineDocument
    ) -> (programme: CustomProgramme, templates: [WorkoutTemplate])? {
        let plan = plan(in: document)
        let ordered = AbilityAxis.allCases.sorted { left, right in
            let leftRank = plan.priorities.firstIndex(of: left) ?? .max
            let rightRank = plan.priorities.firstIndex(of: right) ?? .max
            return leftRank != rightRank ? leftRank < rightRank : false
        }
        var templates: [WorkoutTemplate] = []
        for axis in ordered where templates.count < document.capability.availableDays {
            guard let template = axisTemplate(axis, in: document) else { continue }
            templates.append(template)
        }
        guard !templates.isEmpty else { return nil }
        // Spread sessions through the week rather than stacking them.
        let weekdays = [2, 4, 6, 7, 1, 3, 5]
        let programme = CustomProgramme(
            name: "Capability block",
            weekCount: 4,
            enabled: true,
            days: (1...7).map { weekday in
                ProgrammeDay(
                    weekday: weekday,
                    templateID: zip(weekdays, templates).first { $0.0 == weekday }?.1.id
                )
            }
        )
        return (programme, templates)
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
