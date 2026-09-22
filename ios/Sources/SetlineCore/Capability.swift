import Foundation

/// The four abilities the capability system scores. Each axis is a curriculum,
/// not a population percentile — a score says how much of a defined, versioned
/// set of checkpoints is demonstrated, never how a body compares to anyone
/// else's.
public enum AbilityAxis: String, Codable, CaseIterable, Sendable {
    case strength
    case endurance
    case mobility
    case balanceControl

    public var title: String {
        switch self {
        case .strength: "Strength"
        case .endurance: "Endurance"
        case .mobility: "Mobility"
        case .balanceControl: "Balance & control"
        }
    }

    /// Exercise-catalogue pillars that make an exercise goal relevant to this
    /// axis. Balance & control has no pillar of its own — its goal-relevance
    /// comes from the axis's own benchmarks.
    public var pillars: [Pillar] {
        switch self {
        case .strength: [.strength]
        case .endurance: [.stamina]
        case .mobility: [.mobility, .flexibility]
        case .balanceControl: []
        }
    }
}

/// Where a piece of evidence came from. The four kinds stay visibly distinct:
/// a measured result, a derived estimate, an uncertain self-report, and a
/// genuine absence are not interchangeable.
public enum EvidenceKind: String, Codable, Sendable {
    /// A recorded working set or a deliberately recorded assessment value.
    case measured
    /// Derived from measurements — e.g. an Epley one-rep-max estimate.
    case estimated
    /// Entered from memory or conversation, flagged in the benchmark record.
    case selfReported
    /// Nothing usable exists. Rendered as unassessed, never as zero.
    case missing

    public var title: String {
        switch self {
        case .measured: "Measured"
        case .estimated: "Estimated"
        case .selfReported: "Reported"
        case .missing: "Unassessed"
        }
    }
}

/// How an assessment finds its evidence inside the document.
public enum AssessmentSource: Equatable, Sendable {
    /// A benchmark definition; its record lives in `BenchmarksState`.
    case benchmark(String)
    /// A mobility card; its records live in `MobilityState`.
    case mobilityCard(String)
    /// A logged exercise and metric, read from workout history.
    case loggedMetric(exercise: String, metric: MetricKind)
}

/// One checkpoint in one axis's curriculum. Every field a reader needs to
/// reproduce or audit the judgement is on the definition itself.
public struct CapabilityAssessment: Identifiable, Equatable, Sendable {
    public let id: String
    public let axis: AbilityAxis
    public let title: String
    /// The exact position, equipment, and conditions the result is judged under.
    public let setup: String
    /// What "met" means, in words a user can verify.
    public let passingCriteria: String
    /// Which evidence kinds may satisfy this assessment.
    public let acceptableEvidence: [EvidenceKind]
    /// The accessible starting point when the checkpoint is out of reach.
    public let easierVariation: String
    /// The authored step after this checkpoint — a different task, not a claim
    /// of more range or strength in the same task.
    public let nextProgression: String
    /// Share of the axis score this checkpoint carries.
    public let weight: Double
    public let source: AssessmentSource
    /// For benchmark sources: the field key carrying the measured value.
    public let evidenceField: String?
    /// For benchmark sources: the target field key carrying the checkpoint, so
    /// user-edited targets stay authoritative.
    public let targetField: String?
    /// For logged-metric sources: the recorded value that clears the checkpoint.
    public let threshold: Double?
    /// The exercise that practises this checkpoint — links into
    /// `ExerciseCatalogue` so practice is a real movement, not text.
    public let practiceSlug: String?
    /// Whether a qualifying logged performance may satisfy this assessment
    /// without a separate test. False for paired criteria — a 10 km distance
    /// alone cannot satisfy a distance-and-time checkpoint.
    public let unlocksFromHistory: Bool

    public init(
        id: String,
        axis: AbilityAxis,
        title: String,
        setup: String,
        passingCriteria: String,
        acceptableEvidence: [EvidenceKind],
        easierVariation: String,
        nextProgression: String,
        weight: Double = 1,
        source: AssessmentSource,
        evidenceField: String? = nil,
        targetField: String? = nil,
        threshold: Double? = nil,
        practiceSlug: String? = nil,
        unlocksFromHistory: Bool = false
    ) {
        self.id = id
        self.axis = axis
        self.title = title
        self.setup = setup
        self.passingCriteria = passingCriteria
        self.acceptableEvidence = acceptableEvidence
        self.easierVariation = easierVariation
        self.nextProgression = nextProgression
        self.weight = weight
        self.source = source
        self.evidenceField = evidenceField
        self.targetField = targetField
        self.threshold = threshold
        self.practiceSlug = practiceSlug
        self.unlocksFromHistory = unlocksFromHistory
    }
}

/// What the document currently offers for one assessment.
public struct CapabilityEvidence: Equatable, Sendable {
    public var kind: EvidenceKind
    /// The best recorded number where the assessment has one.
    public var value: Double?
    /// Which session or record produced it — every number stays attributable.
    public var provenance: String?
    public var achievedAt: Date?

    public init(
        kind: EvidenceKind,
        value: Double? = nil,
        provenance: String? = nil,
        achievedAt: Date? = nil
    ) {
        self.kind = kind
        self.value = value
        self.provenance = provenance
        self.achievedAt = achievedAt
    }

    public static var missing: CapabilityEvidence { CapabilityEvidence(kind: .missing) }
}

/// The authored assessment set. Small on purpose: every entry reuses an
/// existing benchmark definition, mobility card, or logged movement rather
/// than introducing new tests or equipment.
///
/// Curriculum checkpoints come from the same place the benchmark defaults do —
/// the user's editable targets — so the score stays a curriculum score and the
/// targets stay under user control.
public enum CapabilityAssessmentCatalog {
    public static let assessments: [CapabilityAssessment] = [
        // Strength — the four strength benchmarks, in authored order.
        CapabilityAssessment(
            id: "S-pullups",
            axis: .strength,
            title: "Strict pull-ups",
            setup: "Straight-arm hang, chin above the bar, controlled lowering. No swinging or kipping.",
            passingCriteria: "15 clean repetitions. A fixed curriculum checkpoint; your editable benchmark target is tracked separately.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Band-assisted or bodyweight-row practice.",
            nextProgression: "More clean reps, then added load.",
            source: .benchmark("pullups"),
            evidenceField: "reps",
            targetField: "reps",
            practiceSlug: "pull-up",
            unlocksFromHistory: true
        ),
        CapabilityAssessment(
            id: "S-bench",
            axis: .strength,
            title: "Bench press",
            setup: "Consistent, controlled range with safeties or a spotter; load includes the bar.",
            passingCriteria: "A clean lift at 1.25\u{00D7} bodyweight. An estimated 1RM is planning evidence, not a passed lift.",
            acceptableEvidence: [.measured, .estimated, .selfReported],
            easierVariation: "Lighter bench work or a controlled press-up progression.",
            nextProgression: "Heavier load at the same clean range.",
            source: .benchmark("bench"),
            evidenceField: "load",
            targetField: "ratio",
            practiceSlug: "bench-press",
        ),
        CapabilityAssessment(
            id: "S-split",
            axis: .strength,
            title: "Bulgarian split squat",
            setup: "Same stance and rear-foot support each time; controlled depth; weight is per hand.",
            passingCriteria: "0.5\u{00D7} bodyweight total external load for 8 repetitions per leg, both sides.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Bodyweight split squats or a supported stance.",
            nextProgression: "More load or more reps per leg.",
            source: .benchmark("split"),
            evidenceField: "load",
            targetField: "ratio",
            practiceSlug: "supported-bulgarian-split-squat",
        ),
        CapabilityAssessment(
            id: "S-carry",
            axis: .strength,
            title: "Farmer carry",
            setup: "One weight in each hand, continuous walk, no straps and no put-downs.",
            passingCriteria: "0.5\u{00D7} bodyweight per hand for 50 metres without a put-down.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Lighter loads over the same route.",
            nextProgression: "Raise load or distance.",
            source: .benchmark("carry"),
            evidenceField: "load",
            targetField: "ratio",
            practiceSlug: "farmer-carry",
        ),

        // Endurance — the two endurance benchmarks.
        CapabilityAssessment(
            id: "E-run",
            axis: .endurance,
            title: "Continuous 10 km run",
            setup: "Flat, measured course; elapsed time without pausing the clock.",
            passingCriteria: "Continuous 10 km in under 50 minutes. Shorter efforts are not extrapolated.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Shorter continuous runs or intervals at an easy pace.",
            nextProgression: "A faster 10 km or a longer continuous run.",
            source: .benchmark("run"),
            evidenceField: "distance",
            targetField: "distance",
            practiceSlug: "run",
        ),
        CapabilityAssessment(
            id: "E-swim",
            axis: .endurance,
            title: "Water competence",
            setup: "Supervised pool with help available.",
            passingCriteria: "400 m continuous swim plus 2 minutes treading and basic water-safety skills.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Shorter swims and supported treading practice.",
            nextProgression: "A longer continuous swim or more treading.",
            source: .benchmark("swim"),
            evidenceField: "distance",
            targetField: "distance"
        ),

        // Balance & control — the control-bearing movement benchmarks.
        CapabilityAssessment(
            id: "B-balance",
            axis: .balanceControl,
            title: "Eyes-closed balance",
            setup: "Single-leg stance near stable support, eyes closed, best of three per leg.",
            passingCriteria: "30 seconds per leg, eyes closed. Eyes-open results do not qualify.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Eyes-open single-leg stance with a fingertip on support.",
            nextProgression: "Longer holds or less support.",
            source: .benchmark("balance"),
            evidenceField: nil,
            targetField: "seconds",
            practiceSlug: "single-leg-balance",
        ),
        CapabilityAssessment(
            id: "B-jump",
            axis: .balanceControl,
            title: "Standing broad jump",
            setup: "Two-foot take-off, controlled landing; best of three consistent attempts.",
            passingCriteria: "2.3 metres with a controlled landing.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Smaller jumps with an emphasis on a still, balanced landing.",
            nextProgression: "A longer jump with the same controlled landing.",
            source: .benchmark("jump"),
            evidenceField: "distance",
            targetField: "distance",
            practiceSlug: "box-jump",
        ),
        CapabilityAssessment(
            id: "B-agility",
            axis: .balanceControl,
            title: "Change of direction",
            setup: "5–10–5 shuttle on a consistent surface and timing method.",
            passingCriteria: "5.5 seconds or faster on the 5\u{2013}10\u{2013}5 shuttle.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Sub-maximal shuttles to build sprint tolerance first.",
            nextProgression: "A faster shuttle.",
            source: .benchmark("agility"),
            evidenceField: "seconds",
            targetField: "seconds"
        ),
    ]

    /// Mobility contributes all 15 cards plus the two functional benchmarks,
    /// generated rather than repeated so the mobility catalogue stays the one
    /// source of truth for its content.
    public static let mobilityAssessments: [CapabilityAssessment] =
        MobilityCatalog.all.map { card in
            CapabilityAssessment(
                id: card.id,
                axis: .mobility,
                title: card.name,
                setup: card.assessmentSetup,
                passingCriteria: card.role == .functionalBenchmark
                    ? "Complete the functional task and record the setup, support, and result you used."
                    : "Demonstrate every check in the card at a repeatable, comfortable level under the same setup.",
                acceptableEvidence: [.measured],
                easierVariation: card.easyPractice,
                nextProgression: card.progressionOptions.first ?? "Maintain under the same setup.",
                source: .mobilityCard(card.id),
                practiceSlug: card.practiceSlugs.first
            )
        }

    /// The full curriculum in authored order.
    public static var all: [CapabilityAssessment] {
        assessments + mobilityAssessments
    }

    public static func assessment(for id: String) -> CapabilityAssessment? {
        all.first { $0.id == id }
    }

    public static func assessments(for axis: AbilityAxis) -> [CapabilityAssessment] {
        all.filter { $0.axis == axis }
    }
}

// MARK: - User-controlled state

/// Difficulty feedback on one checkpoint. "Too hard" drops one variable back
/// toward the easier variation; "too easy" points at the next progression.
/// Either stays attached until the user changes it or the checkpoint passes.
public enum CheckpointFeedback: String, Codable, Sendable {
    case tooHard
    case tooEasy

    public var title: String {
        switch self {
        case .tooHard: "Too hard"
        case .tooEasy: "Too easy"
        }
    }
}

/// The only capability state the document stores: what the user reported or
/// chose. Assessment results themselves are always derived — they live in
/// history, `BenchmarksState`, and `MobilityState`, never duplicated here.
public struct CapabilityState: Codable, Equatable, Sendable {
    /// Assessments the user reported pain on, keyed by assessment id. Pain
    /// blocks automatic progression and removes the movement from generated
    /// programmes until cleared.
    public var painReports: [String: Date]
    /// Difficulty feedback per checkpoint, keyed by assessment id.
    public var feedback: [String: CheckpointFeedback]
    /// Axes the user selected as ambitious focus — the Specialize input.
    public var focusAxes: Set<AbilityAxis>
    /// How many training days per week a generated programme may use.
    public var availableDays: Int

    public init(
        painReports: [String: Date] = [:],
        feedback: [String: CheckpointFeedback] = [:],
        focusAxes: Set<AbilityAxis> = [],
        availableDays: Int = 3
    ) {
        self.painReports = painReports
        self.feedback = feedback
        self.focusAxes = focusAxes
        self.availableDays = min(7, max(1, availableDays))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        painReports = try container.decodeIfPresent([String: Date].self, forKey: .painReports) ?? [:]
        feedback = try container.decodeIfPresent([String: CheckpointFeedback].self, forKey: .feedback) ?? [:]
        focusAxes = try container.decodeIfPresent(Set<AbilityAxis>.self, forKey: .focusAxes) ?? []
        availableDays = try container.decodeIfPresent(Int.self, forKey: .availableDays) ?? 3
    }

    public static var initial: CapabilityState { CapabilityState() }

    public func painReported(on assessmentID: String) -> Bool {
        painReports[assessmentID] != nil
    }
}

// MARK: - Population references

/// A disclosed population comparison. Every field is required: who was
/// measured, under which protocol, which demographic grouping applies, and
/// where the number comes from. Absent any one of those, the UI shows
/// "Benchmark unavailable" rather than a number.
public struct PopulationReference: Equatable, Sendable {
    public let population: String
    public let protocolText: String
    public let grouping: String
    public let source: String
    /// The comparison in words — deliberately not a percentile claim.
    public let finding: String

    public init(population: String, protocolText: String, grouping: String, source: String, finding: String) {
        self.population = population
        self.protocolText = protocolText
        self.grouping = grouping
        self.source = source
        self.finding = finding
    }
}

/// The reference registry, keyed by capability assessment id. Sparse on
/// purpose: a comparison exists only where the published protocol matches the
/// app's assessment exactly. Everything else is unavailable, not estimated.
public enum PopulationComparisons {
    public static func reference(for assessmentID: String) -> PopulationReference? {
        references[assessmentID]
    }

    private static let references: [String: PopulationReference] = [
        // Knee-to-wall (M10): the weight-bearing lunge test has published
        // reliability and validity evidence, and the app protocol matches it.
        "M10": PopulationReference(
            population: "Healthy adults",
            protocolText: "Weight-bearing lunge: knee touches the wall, heel planted, toe-to-wall distance measured.",
            grouping: "All adults; distance scales modestly with limb length, not age.",
            source: "Bennell et al., 1998 — reliability and validity of the weight-bearing ankle lunge measure.",
            finding: "Roughly 9–10 cm is a common functional result; less than that often limits squat and stair mechanics."
        ),
    ]
}
