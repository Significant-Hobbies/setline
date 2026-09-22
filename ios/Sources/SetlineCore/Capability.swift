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
            passingCriteria: "Meet your pull-up target (default 15 clean repetitions).",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Band-assisted or bodyweight-row practice.",
            nextProgression: "Raise the rep target or add load.",
            source: .benchmark("pullups"),
            evidenceField: "reps",
            targetField: "reps",
            unlocksFromHistory: true
        ),
        CapabilityAssessment(
            id: "S-bench",
            axis: .strength,
            title: "Bench press",
            setup: "Consistent, controlled range with safeties or a spotter; load includes the bar.",
            passingCriteria: "An actual clean lift at or above your target load-to-bodyweight ratio. An estimated 1RM is planning evidence, not a passed lift.",
            acceptableEvidence: [.measured, .estimated, .selfReported],
            easierVariation: "Lighter bench work or a controlled press-up progression.",
            nextProgression: "Raise the load-to-bodyweight target.",
            source: .benchmark("bench"),
            evidenceField: "load",
            targetField: "ratio"
        ),
        CapabilityAssessment(
            id: "S-split",
            axis: .strength,
            title: "Bulgarian split squat",
            setup: "Same stance and rear-foot support each time; controlled depth; weight is per hand.",
            passingCriteria: "Meet the external-load and reps-per-leg targets on both sides.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Bodyweight split squats or a supported stance.",
            nextProgression: "Raise the load or rep target.",
            source: .benchmark("split"),
            evidenceField: "load",
            targetField: "ratio"
        ),
        CapabilityAssessment(
            id: "S-carry",
            axis: .strength,
            title: "Farmer carry",
            setup: "One weight in each hand, continuous walk, no straps and no put-downs.",
            passingCriteria: "Meet the load-per-hand and distance targets.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Lighter loads over the same route.",
            nextProgression: "Raise load or distance.",
            source: .benchmark("carry"),
            evidenceField: "load",
            targetField: "ratio"
        ),

        // Endurance — the two endurance benchmarks.
        CapabilityAssessment(
            id: "E-run",
            axis: .endurance,
            title: "Continuous 10 km run",
            setup: "Flat, measured course; elapsed time without pausing the clock.",
            passingCriteria: "Complete the target distance within the target time, continuously. Shorter efforts are not extrapolated.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Shorter continuous runs or intervals at an easy pace.",
            nextProgression: "A faster target time or a longer distance.",
            source: .benchmark("run"),
            evidenceField: "distance",
            targetField: "distance"
        ),
        CapabilityAssessment(
            id: "E-swim",
            axis: .endurance,
            title: "Water competence",
            setup: "Supervised pool with help available.",
            passingCriteria: "Continuous swim distance plus treading time and basic water-safety skills, per the benchmark protocol.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Shorter swims and supported treading practice.",
            nextProgression: "Raise distance or treading targets.",
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
            passingCriteria: "Meet the seconds target on each leg, eyes closed. Eyes-open results do not qualify.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Eyes-open single-leg stance with a fingertip on support.",
            nextProgression: "Raise the seconds target or reduce support.",
            source: .benchmark("balance"),
            evidenceField: nil,
            targetField: "seconds"
        ),
        CapabilityAssessment(
            id: "B-jump",
            axis: .balanceControl,
            title: "Standing broad jump",
            setup: "Two-foot take-off, controlled landing; best of three consistent attempts.",
            passingCriteria: "Meet the distance target with a controlled landing.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Smaller jumps with an emphasis on a still, balanced landing.",
            nextProgression: "Raise the distance target.",
            source: .benchmark("jump"),
            evidenceField: "distance",
            targetField: "distance"
        ),
        CapabilityAssessment(
            id: "B-agility",
            axis: .balanceControl,
            title: "Change of direction",
            setup: "5–10–5 shuttle on a consistent surface and timing method.",
            passingCriteria: "Finish at or under the target shuttle time.",
            acceptableEvidence: [.measured, .selfReported],
            easierVariation: "Sub-maximal shuttles to build sprint tolerance first.",
            nextProgression: "Lower the target time.",
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
                source: .mobilityCard(card.id)
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
