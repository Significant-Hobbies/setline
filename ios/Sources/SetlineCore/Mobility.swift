import Foundation

/// Head-to-toe mobility curriculum — a periodic movement baseline that
/// complements daily workout execution. Fifteen assessment cards (ten main
/// progression tracks and five full-body coverage checks) plus two optional
/// functional benchmarks.
///
/// Ported from the owner's `setline_mobility_catalog_v0_1.json` content
/// prototype. This is a movement-check curriculum, not a clinically validated
/// assessment or a normative score: no composite number, no universal pass
/// marks, and symptoms are always recorded separately from the result.

// MARK: - Card roles

public enum MobilityCardRole: String, Codable, CaseIterable, Sendable {
    case mainTrack
    case coverageCheck
    case functionalBenchmark

    public var title: String {
        switch self {
        case .mainTrack: "Main track"
        case .coverageCheck: "Full-body check"
        case .functionalBenchmark: "Functional benchmark"
        }
    }
}

// MARK: - Result status

/// The draft's manual-entry input states. `symptomBlocked` is a stop state —
/// it is never rendered as zero mobility or as a prompt to stretch harder.
public enum MobilityResultStatus: String, Codable, CaseIterable, Sendable {
    case notTested
    case completedAsShown
    case modifiedOrAssisted
    case notYet
    case unsure
    case symptomBlocked
    case notApplicable

    public var title: String {
        switch self {
        case .notTested: "Not tested"
        case .completedAsShown: "Completed as shown"
        case .modifiedOrAssisted: "Modified or assisted"
        case .notYet: "Not yet"
        case .unsure: "Unsure"
        case .symptomBlocked: "Stopped by symptoms"
        case .notApplicable: "Not applicable"
        }
    }
}

public enum MobilityConfidence: String, Codable, CaseIterable, Sendable {
    case certain
    case unsure

    public var title: String {
        switch self {
        case .certain: "Certain"
        case .unsure: "Unsure"
        }
    }
}

// MARK: - Check definition

/// What kind of endpoint a check records. Most checks capture a landmark or a
/// description; the knee-to-wall lunge is the one numeric measurement in the
/// catalogue.
public enum MobilityEndpointKind: Sendable {
    /// No endpoint beyond the status itself (functional benchmarks).
    case completion
    /// A described endpoint, e.g. "fingertips past the crown".
    case landmark
    /// A measured toe-to-wall distance in centimetres.
    case centimetres
}

/// One separately-recorded observation inside a card. A card with several
/// checks is several results, never a single yes/no answer.
public struct MobilityCheck: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    /// Left and right are recorded as independent results.
    public let perSide: Bool
    public let endpoint: MobilityEndpointKind

    public init(id: String, label: String, perSide: Bool, endpoint: MobilityEndpointKind = .landmark) {
        self.id = id
        self.label = label
        self.perSide = perSide
        self.endpoint = endpoint
    }
}

// MARK: - Card definition

public struct MobilityCardDefinition: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let role: MobilityCardRole
    public let regions: [String]
    public let checks: [MobilityCheck]
    public let assessmentSetup: String
    /// The fields the assessment keeps distinct on every record.
    public let recordSeparately: [String]
    public let validAttemptRules: [String]
    public let easyPractice: String
    /// Practice options, not a requirement to perform every variation during
    /// assessment. A substantially different setup is a different task.
    public let progressionOptions: [String]
    /// ExerciseCatalogue slugs for the practice movements, so a selected track
    /// can be added to a custom workout.
    public let practiceSlugs: [String]
    public let sourceIDs: [String]
    /// Shown on the card: what this result is not.
    public let measurementCaveat: String

    public init(
        id: String,
        name: String,
        role: MobilityCardRole,
        regions: [String],
        checks: [MobilityCheck],
        assessmentSetup: String,
        recordSeparately: [String],
        validAttemptRules: [String],
        easyPractice: String,
        progressionOptions: [String],
        practiceSlugs: [String] = [],
        sourceIDs: [String],
        measurementCaveat: String
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.regions = regions
        self.checks = checks
        self.assessmentSetup = assessmentSetup
        self.recordSeparately = recordSeparately
        self.validAttemptRules = validAttemptRules
        self.easyPractice = easyPractice
        self.progressionOptions = progressionOptions
        self.practiceSlugs = practiceSlugs
        self.sourceIDs = sourceIDs
        self.measurementCaveat = measurementCaveat
    }
}

// MARK: - Recorded state

/// One recorded result for one check on one side.
///
/// `setup` is part of the measurement's identity: a record made under a
/// different setup starts a new series and is never presented as changed joint
/// range. `symptoms` stays a separate field — pain during an attempt is not a
/// score.
public struct MobilityCheckRecord: Codable, Equatable, Sendable {
    public var status: MobilityResultStatus
    public var setup: String
    public var endpoint: String
    public var distanceCentimetres: Double?
    public var assistance: String
    public var confidence: MobilityConfidence
    public var symptoms: String
    public var recordedAt: Date?

    public init(
        status: MobilityResultStatus = .notTested,
        setup: String = "",
        endpoint: String = "",
        distanceCentimetres: Double? = nil,
        assistance: String = "",
        confidence: MobilityConfidence = .certain,
        symptoms: String = "",
        recordedAt: Date? = nil
    ) {
        self.status = status
        self.setup = setup
        self.endpoint = endpoint
        self.distanceCentimetres = distanceCentimetres
        self.assistance = assistance
        self.confidence = confidence
        self.symptoms = symptoms
        self.recordedAt = recordedAt
    }

    /// Anything beyond "not tested" counts as an established observation.
    public var isRecorded: Bool {
        status != .notTested || !endpoint.isEmpty || distanceCentimetres != nil || recordedAt != nil
    }
}

/// All recorded results for one card, keyed by check slot.
public struct MobilityCardState: Codable, Equatable, Sendable {
    /// Results keyed by `key(checkID:side:)` — "shoulder-flexion.left".
    public var results: [String: MobilityCheckRecord]
    /// Earlier records for the same slot, oldest last. A re-recorded check keeps
    /// its series here so a changed setup never silently rewrites the baseline.
    public var superseded: [String: [MobilityCheckRecord]]

    public init(
        results: [String: MobilityCheckRecord] = [:],
        superseded: [String: [MobilityCheckRecord]] = [:]
    ) {
        self.results = results
        self.superseded = superseded
    }

    public static func key(checkID: String, side: BodySide?) -> String {
        guard let side, side != .both else { return checkID }
        return "\(checkID).\(side.rawValue)"
    }

    /// Records a result for a slot, moving the previous record into the
    /// superseded series. A result that carries nothing — "Not tested" with no
    /// fields — removes the slot instead of storing a blank. Returns false
    /// when nothing changed.
    @discardableResult
    public mutating func record(_ record: MobilityCheckRecord, checkID: String, side: BodySide?) -> Bool {
        let slot = Self.key(checkID: checkID, side: side)
        let stamped = record.withTimestampIfMissing()
        if let existing = results[slot] {
            guard existing != stamped else { return false }
            superseded[slot, default: []].insert(existing, at: 0)
        }
        if stamped.isRecorded {
            results[slot] = stamped
        } else {
            results.removeValue(forKey: slot)
        }
        return true
    }

    public func record(for check: MobilityCheck, side: BodySide?) -> MobilityCheckRecord? {
        results[Self.key(checkID: check.id, side: side)]
    }
}

extension MobilityCheckRecord {
    func withTimestampIfMissing(now: Date = .now) -> MobilityCheckRecord {
        var copy = self
        if copy.isRecorded, copy.recordedAt == nil {
            copy.recordedAt = now
        }
        return copy
    }
}

/// A dated snapshot of the whole curriculum, preserving setups and results as
/// they stood on that day — the mobility counterpart of `BenchmarkCheckIn`.
public struct MobilityAssessment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var cards: [String: MobilityCardState]
    public var practising: [String]

    public init(
        id: UUID = UUID(),
        date: Date,
        cards: [String: MobilityCardState],
        practising: [String]
    ) {
        self.id = id
        self.date = date
        self.cards = cards
        self.practising = practising
    }
}

/// The full mobility state, stored inside `SetlineDocument`.
public struct MobilityState: Codable, Equatable, Sendable {
    public var cards: [String: MobilityCardState]
    public var updated: [String: Date]
    /// Card ids the user has chosen as the current practice set (max 4).
    public var practising: [String]
    public var history: [MobilityAssessment]

    public init(
        cards: [String: MobilityCardState] = [:],
        updated: [String: Date] = [:],
        practising: [String] = [],
        history: [MobilityAssessment] = []
    ) {
        self.cards = cards
        self.updated = updated
        self.practising = practising
        self.history = history
    }

    /// A new user starts with nothing recorded — no assumed baseline.
    public static var initial: MobilityState { MobilityState() }
}

// MARK: - Sources

public struct MobilitySource: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let url: String
    /// What the source actually supports — exercises or published protocols,
    /// never this assembled curriculum or its checkpoints.
    public let supports: String
}

// MARK: - Catalogue

/// The bundled curriculum. Held in Swift rather than a JSON resource, matching
/// `ExerciseCatalogue`, so card and check ids are compile-time checked.
public enum MobilityCatalog {
    /// Cards M01–M15 in authored order.
    public static let cards: [MobilityCardDefinition] = [
        MobilityCardDefinition(
            id: "M01",
            name: "Supine overhead reach",
            role: .mainTrack,
            regions: ["shoulder", "scapular movement"],
            checks: [
                MobilityCheck(id: "shoulder-flexion", label: "Active shoulder flexion", perSide: true),
            ],
            assessmentSetup: "On your back, knees bent; raise one straight arm overhead. Keep the same head support and surface each time.",
            recordSeparately: ["side", "active endpoint landmark", "assistance", "head support", "optional side-view video"],
            validAttemptRules: [
                "Do not gain reach by bending the elbow or increasing back arch.",
                "Allow normal shoulder-blade movement.",
            ],
            easyPractice: "Supported table slide or a short-range assisted overhead reach.",
            progressionOptions: [
                "Increase comfortable reach within the same variation.",
                "Use less help at the same reach.",
                "Practise the established reach actively while standing; record this as a different task.",
            ],
            practiceSlugs: ["supine-table-slide", "standing-overhead-reach"],
            sourceIDs: ["supine_reach", "aaos_shoulder"],
            measurementCaveat: "Active functional reach, not an isolated shoulder-joint measurement; floor contact is not a universal target."
        ),
        MobilityCardDefinition(
            id: "M02",
            name: "Supported shoulder rotations",
            role: .mainTrack,
            regions: ["shoulder"],
            checks: [
                MobilityCheck(id: "external-rotation", label: "External rotation", perSide: true),
                MobilityCheck(id: "internal-rotation", label: "Internal rotation", perSide: true),
            ],
            assessmentSetup: "On your back, support the upper arm on a towel at a documented angle away from the trunk; bend the elbow and turn the forearm each way. Use only a comfortable setup.",
            recordSeparately: ["side", "rotation direction", "upper-arm position", "active endpoint", "support"],
            validAttemptRules: [
                "Keep the upper arm in its selected position.",
                "Do not roll the trunk or lift the shoulder to gain range.",
            ],
            easyPractice: "Small active rotations with the arm supported in a comfortable position.",
            progressionOptions: [
                "Expand the comfortable arc in the same setup.",
                "Pause with control within that arc.",
                "Treat a different upper-arm position as a new assessment, not automatic improvement.",
            ],
            practiceSlugs: ["supported-shoulder-rotation"],
            sourceIDs: ["aaos_shoulder"],
            measurementCaveat: "App-adapted protocol requiring review. Do not force a 90-degree upper-arm position or force the forearm onto the floor."
        ),
        MobilityCardDefinition(
            id: "M03",
            name: "Seated trunk rotation",
            role: .mainTrack,
            regions: ["trunk"],
            checks: [
                MobilityCheck(id: "rotation", label: "Chest rotation", perSide: true),
            ],
            assessmentSetup: "Sit on a stable chair with feet planted and knees forward; arms crossed, turn the chest each way.",
            recordSeparately: ["direction", "endpoint landmark", "chair/foot setup", "optional overhead or consistent-view video"],
            validAttemptRules: [
                "Keep the pelvis and knees facing forward.",
                "Do not pull against the chair for extra rotation.",
            ],
            easyPractice: "Small seated turns.",
            progressionOptions: [
                "Reach a farther repeatable landmark without moving the pelvis.",
                "Add controlled pauses at the same endpoint.",
                "Use side-lying open-book practice as a separately tracked variation.",
            ],
            practiceSlugs: ["seated-trunk-rotation", "open-book-rotation"],
            sourceIDs: ["nhs_sitting", "trunk_study"],
            measurementCaveat: "Trunk rotation, not pure thoracic isolation. Published instrumented reliability does not validate manual visual scoring."
        ),
        MobilityCardDefinition(
            id: "M04",
            name: "Spinal movement check",
            role: .mainTrack,
            regions: ["spine", "pelvis"],
            checks: [
                MobilityCheck(id: "flexion-extension", label: "Round and extend (cat-camel)", perSide: false),
                MobilityCheck(id: "side-bend", label: "Side bend", perSide: true),
            ],
            assessmentSetup: "Use small cat-camel movements on hands and knees, or seated pelvic tilts when the floor is unsuitable. Check gentle side bends separately.",
            recordSeparately: ["direction", "setup", "ability to deliberately reverse the movement", "symptoms", "optional video"],
            validAttemptRules: [
                "Move slowly within comfort.",
                "Keep knees/hands in the same place for repeated cat-camel checks.",
            ],
            easyPractice: "Seated pelvic tilts and short, supported side bends.",
            progressionOptions: [
                "Make the same movement smooth and repeatable.",
                "Use a comfortable cat-camel variation if accessible.",
                "Maintenance rather than increasingly extreme spinal range.",
            ],
            practiceSlugs: ["seated-pelvic-tilt", "cat-camel"],
            sourceIDs: ["mayo_back", "nhs_flexibility"],
            measurementCaveat: "Qualitative movement/control check. Not a valid numerical measure of lumbar or thoracic flexibility."
        ),
        MobilityCardDefinition(
            id: "M05",
            name: "Single-knee-to-chest reach",
            role: .mainTrack,
            regions: ["hip"],
            checks: [
                MobilityCheck(id: "hip-flexion", label: "Knee toward chest", perSide: true),
            ],
            assessmentSetup: "Lie on your back and lift one bent knee toward the chest. Record the resting leg position. Assess active movement before any assisted practice.",
            recordSeparately: ["side", "active endpoint", "resting-leg position", "assistance", "body contact limiting motion"],
            validAttemptRules: [
                "Use the same pelvis and resting-leg setup on retest.",
                "Stop before using substantially more pelvic rolling to gain reach.",
            ],
            easyPractice: "A small active knee lift or gently supported knee-to-chest movement.",
            progressionOptions: [
                "Increase comfortable range in the same setup.",
                "Need less assistance at the same target.",
                "Practise a controlled seated knee lift as a separate task.",
            ],
            practiceSlugs: ["supine-knee-to-chest"],
            sourceIDs: ["aaos_hip"],
            measurementCaveat: "Body size/contact can limit the task. Do not interpret knee-to-chest contact as a universal normal or diagnose a tight muscle."
        ),
        MobilityCardDefinition(
            id: "M06",
            name: "Supine active knee extension",
            role: .mainTrack,
            regions: ["posterior thigh", "hip", "knee"],
            checks: [
                MobilityCheck(id: "knee-extension", label: "Knee straightening, thigh held", perSide: true),
            ],
            assessmentSetup: "On your back, hold behind one thigh in a documented position; slowly straighten that knee. The other leg stays in the same position on every test.",
            recordSeparately: ["side", "thigh position", "knee endpoint", "ankle position", "assistance"],
            validAttemptRules: [
                "Do not lower the thigh while straightening the knee.",
                "Do not pull on the knee or force the foot back.",
            ],
            easyPractice: "Use a lower thigh position and a smaller knee-straightening arc.",
            progressionOptions: [
                "Straighten farther with the thigh held in the same position.",
                "Use a more demanding thigh position only as a separately recorded variant.",
                "Add controlled holds without changing the reported range.",
            ],
            practiceSlugs: ["supine-knee-extension", "hamstring-stretch"],
            sourceIDs: ["aaos_hip", "aaos_knee"],
            measurementCaveat: "Adaptation of a hamstring-mobility exercise, not a validated self-test or an isolated diagnosis of hamstring tightness."
        ),
        MobilityCardDefinition(
            id: "M07",
            name: "Seated hip rotations",
            role: .mainTrack,
            regions: ["hip"],
            checks: [
                MobilityCheck(id: "internal-rotation", label: "Internal rotation", perSide: true),
                MobilityCheck(id: "external-rotation", label: "External rotation", perSide: true),
            ],
            assessmentSetup: "Sit upright with thighs supported and knees bent; keep one thigh still as its foot moves outward and inward. Foot outward corresponds to hip internal rotation.",
            recordSeparately: ["side", "direction", "seat height", "hip/knee setup", "endpoint"],
            validAttemptRules: [
                "Do not lean sideways or let the knee travel to fake extra rotation.",
                "Keep the same hip position on retest.",
            ],
            easyPractice: "Small seated rotations.",
            progressionOptions: [
                "Increase the active arc in the same setup.",
                "Pause with control.",
                "Optional raised-seat, hand-supported 90/90 practice; then less support.",
            ],
            practiceSlugs: ["seated-hip-rotation", "ninety-ninety-hip-switches"],
            sourceIDs: ["hip_position_study", "hss_hip"],
            measurementCaveat: "90/90 is a separate combined skill, not a universal endpoint or an isolated hip-rotation measurement."
        ),
        MobilityCardDefinition(
            id: "M08",
            name: "Supported hip-extension position",
            role: .mainTrack,
            regions: ["hip", "pelvis"],
            checks: [
                MobilityCheck(id: "hip-extension-task", label: "Split-stance / half-kneeling position", perSide: true),
            ],
            assessmentSetup: "Use a short supported split stance, or a padded half-kneeling stance when comfortable. Keep the pelvis controlled and gently move forward without arching the back.",
            recordSeparately: ["rear-leg side", "chosen variant", "stance marks", "support", "endpoint/position"],
            validAttemptRules: [
                "Do not create the appearance of hip extension by arching the lower back.",
                "Do not force through knee pressure or groin pinching.",
            ],
            easyPractice: "Small supported standing split-stance shift.",
            progressionOptions: [
                "Increase the comfortable shift with the same stance.",
                "Use less support at the same position.",
                "Optional shallow split-squat practice is a separate capacity task.",
            ],
            practiceSlugs: ["supported-split-stance", "half-kneeling-hip-flexor-stretch"],
            sourceIDs: ["ace_hip_flexor", "hss_hip"],
            measurementCaveat: "A practical position check, not an isolated or validated quantitative hip-extension test."
        ),
        MobilityCardDefinition(
            id: "M09",
            name: "Lateral hip opening",
            role: .mainTrack,
            regions: ["hip", "inner thigh"],
            checks: [
                MobilityCheck(id: "hip-abduction", label: "Sideways heel slide", perSide: true),
            ],
            assessmentSetup: "Begin lying on your back and slide one heel sideways with the kneecap upward. A supported adductor rock-back can be a later practice variation, not the same test.",
            recordSeparately: ["side", "heel endpoint or floor marker", "pelvis position", "variant"],
            validAttemptRules: [
                "Do not roll the pelvis or turn the leg outward to gain distance.",
                "Use a comfortable surface and do not force a groin stretch.",
            ],
            easyPractice: "A small sideways heel slide.",
            progressionOptions: [
                "Reach a farther floor marker in the same setup.",
                "Optional supported adductor rock-back with a narrow starting position.",
                "Optional supported lateral lunge; score as a separate skill.",
            ],
            practiceSlugs: ["lateral-heel-slide", "adductor-rock-back", "supported-lateral-lunge"],
            sourceIDs: ["aaos_hip"],
            measurementCaveat: "Original app adaptation; the source supports the movement family, not this exact protocol or the rock-back sequence."
        ),
        MobilityCardDefinition(
            id: "M10",
            name: "Knee-to-wall ankle lunge",
            role: .mainTrack,
            regions: ["ankle"],
            checks: [
                MobilityCheck(id: "dorsiflexion", label: "Knee-to-wall distance", perSide: true, endpoint: .centimetres),
            ],
            assessmentSetup: "Barefoot facing a wall, keep the heel down and guide the knee to the wall over the middle toes. Find the farthest reproducible toe-to-wall position without losing the setup.",
            recordSeparately: ["side", "toe-to-wall distance cm", "foot alignment", "support", "repeated trial values"],
            validAttemptRules: [
                "Keep the heel in contact.",
                "Do not turn the foot outward or use a different foot position between attempts.",
            ],
            easyPractice: "Small seated ankle movements, or a standing wall lunge from close to the wall.",
            progressionOptions: [
                "Practise comfortable knee-over-toe rocks.",
                "Increase measured distance only while preserving setup.",
                "Keep calf-strength progress separate from range progress.",
            ],
            practiceSlugs: ["knee-to-wall-ankle-rocks", "ankle-mobility"],
            sourceIDs: ["ankle_study", "aaos_foot"],
            measurementCaveat: "Best quantitative candidate in this selection, but the self-guided implementation still needs repeatability testing. No universal 10-cm pass mark."
        ),
        MobilityCardDefinition(
            id: "M11",
            name: "Neck movement check",
            role: .coverageCheck,
            regions: ["neck"],
            checks: [
                MobilityCheck(id: "turn", label: "Turn", perSide: true, endpoint: .completion),
                MobilityCheck(id: "look-down-up", label: "Look down / up", perSide: false, endpoint: .completion),
                MobilityCheck(id: "side-bend", label: "Side bend", perSide: true, endpoint: .completion),
            ],
            assessmentSetup: "Sit with the torso still; perform each direction separately and gently.",
            recordSeparately: ["direction", "comfortable endpoint", "trunk movement", "symptoms"],
            validAttemptRules: [
                "No hand pressure or forced end range.",
                "Do not turn the shoulders with the head.",
            ],
            easyPractice: "Short comfortable movements in each direction.",
            progressionOptions: [
                "Improve repeatable comfortable movement.",
                "Maintain useful range rather than chase increasingly extreme angles.",
            ],
            practiceSlugs: ["neck-mobility"],
            sourceIDs: ["nhs_sitting", "nhs_flexibility"],
            measurementCaveat: "Qualitative check; not a numerical cervical-health score. Stop for pain, dizziness or neurological symptoms."
        ),
        MobilityCardDefinition(
            id: "M12",
            name: "Elbow and forearm check",
            role: .coverageCheck,
            regions: ["elbow", "forearm"],
            checks: [
                MobilityCheck(id: "elbow-bend-straighten", label: "Elbow bend / straighten", perSide: true, endpoint: .completion),
                MobilityCheck(id: "palm-up-down", label: "Palm up / down", perSide: true, endpoint: .completion),
            ],
            assessmentSetup: "Bend and straighten the elbow without forcing it. For palm rotation keep the elbow bent and next to the trunk.",
            recordSeparately: ["side", "direction", "endpoint", "shoulder movement"],
            validAttemptRules: [
                "Do not substitute shoulder rotation for forearm rotation.",
                "Do not force elbow hyperextension.",
            ],
            easyPractice: "Unloaded small-arc elbow movement and supported forearm turns.",
            progressionOptions: [
                "Increase comfortable active movement within each separate direction.",
                "Maintain established range; resistance belongs to capacity tracking.",
            ],
            practiceSlugs: ["elbow-flexion-extension", "forearm-rotations"],
            sourceIDs: ["cuh_wrist", "aaos_shoulder"],
            measurementCaveat: "Elbow task is an app-designed unloaded check; forearm directions are supported by the hospital exercise guidance."
        ),
        MobilityCardDefinition(
            id: "M13",
            name: "Wrist and hand check",
            role: .coverageCheck,
            regions: ["wrist", "hand", "fingers", "thumb"],
            checks: [
                MobilityCheck(id: "wrist-flexion-extension", label: "Wrist bend forward / back", perSide: true, endpoint: .completion),
                MobilityCheck(id: "wrist-side-to-side", label: "Wrist side to side", perSide: true, endpoint: .completion),
                MobilityCheck(id: "fist-open", label: "Open and close the hand", perSide: true, endpoint: .completion),
                MobilityCheck(id: "finger-spread", label: "Spread fingers", perSide: true, endpoint: .completion),
                MobilityCheck(id: "thumb-to-fingertip", label: "Thumb to each fingertip", perSide: true, endpoint: .completion),
            ],
            assessmentSetup: "Support the forearm to move the wrist. Separately open and close the hand, spread the fingers and touch the thumb to each fingertip.",
            recordSeparately: ["side", "specific direction/finger", "endpoint or contact", "symptoms"],
            validAttemptRules: [
                "Keep forearm movement from substituting for wrist movement.",
                "Do not force contact or force fingers straight.",
            ],
            easyPractice: "Small supported wrist movements and partial finger opening/closing.",
            progressionOptions: [
                "Increase comfortable motion/contact in the same task.",
                "Optional wall-palm lean, then countertop support, if wrist loading is a goal.",
                "Loaded hand support is a capacity milestone, not pure range.",
            ],
            practiceSlugs: ["wrist-mobility", "finger-mobility"],
            sourceIDs: ["cuh_wrist", "cuh_fingers"],
            measurementCaveat: "Directions remain separate. The proposed weight-bearing progression requires review and is not validated by the cited leaflets."
        ),
        MobilityCardDefinition(
            id: "M14",
            name: "Knee bend and straighten check",
            role: .coverageCheck,
            regions: ["knee"],
            checks: [
                MobilityCheck(id: "flexion", label: "Heel slide toward you", perSide: true, endpoint: .completion),
                MobilityCheck(id: "extension", label: "Straighten back out", perSide: true, endpoint: .completion),
            ],
            assessmentSetup: "On a firm comfortable surface, slide one heel toward the body and back out. A seated version is an alternative protocol.",
            recordSeparately: ["side", "direction", "heel position", "setup", "assistance"],
            validAttemptRules: [
                "Keep hip/leg alignment consistent.",
                "Do not push the knee into hyperextension or force heel-to-buttock contact.",
            ],
            easyPractice: "Small heel slides or comfortable seated knee bends.",
            progressionOptions: [
                "Increase the comfortable arc in the same setup.",
                "Use less assistance for an established position.",
                "Treat kneeling or squatting as different tasks, not automatic next levels.",
            ],
            practiceSlugs: ["heel-slides"],
            sourceIDs: ["aaos_knee"],
            measurementCaveat: "App-designed range check. Soft-tissue contact, injury and surgery can alter appropriate targets."
        ),
        MobilityCardDefinition(
            id: "M15",
            name: "Foot and toe movement check",
            role: .coverageCheck,
            regions: ["ankle", "foot", "toes"],
            checks: [
                MobilityCheck(id: "point-pull", label: "Point / pull the foot", perSide: true, endpoint: .completion),
                MobilityCheck(id: "sole-in-out", label: "Turn sole inward / outward", perSide: true, endpoint: .completion),
                MobilityCheck(id: "toe-bend-straighten", label: "Bend / straighten toes", perSide: true, endpoint: .completion),
                MobilityCheck(id: "big-toe-control", label: "Lift the big toe alone", perSide: true, endpoint: .completion),
            ],
            assessmentSetup: "Sit with the foot unloaded to move the ankle; check toe movements separately with the foot supported.",
            recordSeparately: ["side", "direction", "endpoint", "toe control", "symptoms"],
            validAttemptRules: [
                "Keep the lower leg still during ankle movement.",
                "Do not force the toes or use body weight to push through restriction.",
            ],
            easyPractice: "Small ankle movements and relaxed toe opening/curling.",
            progressionOptions: [
                "Improve comfortable active movement.",
                "Practise toe control separately.",
                "Optional supported heel raises are capacity practice, not a proxy for toe range.",
            ],
            practiceSlugs: ["ankle-mobility", "toe-mobility"],
            sourceIDs: ["aaos_foot", "nhs_sitting"],
            measurementCaveat: "Qualitative coverage. Difficulty isolating the big toe does not establish restricted toe-joint range."
        ),
    ]

    /// Optional functional benchmarks F01–F02 — practical-capability milestones
    /// kept visibly separate from the range cards.
    public static let functionalBenchmarks: [MobilityCardDefinition] = [
        MobilityCardDefinition(
            id: "F01",
            name: "Supported squat to a target",
            role: .functionalBenchmark,
            regions: ["hip", "knee", "ankle", "whole-body control"],
            checks: [
                MobilityCheck(id: "squat-to-target", label: "Squat to the target and stand", perSide: false, endpoint: .completion),
            ],
            assessmentSetup: "Use a stable support and a fixed chair/box target. Record stance, target height and any heel wedge.",
            recordSeparately: ["target height", "hand support", "stance", "heel support", "controlled completion"],
            validAttemptRules: [
                "Use a stable target, not an unstable stack.",
                "Compare like-for-like setups; more load does not equal more range.",
            ],
            easyPractice: "High-target supported squat.",
            progressionOptions: [
                "Lower the target slightly while keeping support constant.",
                "Reduce hand support at the same depth.",
                "Practise the established depth without support when appropriate.",
            ],
            practiceSlugs: ["supported-squat-repetitions", "supported-squat-hold"],
            sourceIDs: [],
            measurementCaveat: "Original functional milestone, not a validated isolated mobility test or injury-risk predictor."
        ),
        MobilityCardDefinition(
            id: "F02",
            name: "Supported floor transfer",
            role: .functionalBenchmark,
            regions: ["whole-body function"],
            checks: [
                MobilityCheck(id: "floor-transfer", label: "Down to the floor and back up", perSide: false, endpoint: .completion),
            ],
            assessmentSetup: "Only when safe: use stable furniture and a comfortable kneeling or side-sitting route. Skip when balance/fall risk or symptoms make it unsuitable.",
            recordSeparately: ["route", "support used", "surface", "comfortable completion"],
            validAttemptRules: [
                "Do not test speed.",
                "Do not remove support simply to earn points.",
            ],
            easyPractice: "Practise an accessible part of the transfer with stable support.",
            progressionOptions: [
                "Complete the same route comfortably.",
                "Use less support only when safe and useful.",
            ],
            practiceSlugs: ["supported-floor-transfer"],
            sourceIDs: [],
            measurementCaveat: "Original functional milestone affected by strength, balance, body size and skill; not pure mobility. No automatic no-hands target."
        ),
    ]

    /// Every definition — assessment cards followed by functional benchmarks.
    public static var all: [MobilityCardDefinition] { cards + functionalBenchmarks }

    /// Underlying exercise and protocol references. Each entry states what it
    /// supports; none of them validate this assembled curriculum.
    public static let sources: [MobilitySource] = [
        MobilitySource(
            id: "aaos_shoulder",
            title: "Rotator Cuff and Shoulder Conditioning Program — AAOS",
            url: "https://www.orthoinfo.org/recovery/rotator-cuff-and-shoulder-conditioning-program/",
            supports: "Exercise examples and safety, not validation of this app battery."
        ),
        MobilitySource(
            id: "aaos_hip",
            title: "Hip Conditioning Program — AAOS",
            url: "https://www.orthoinfo.org/recovery/hip-conditioning-program/",
            supports: "Exercise examples, not app scoring or a universal corrective prescription."
        ),
        MobilitySource(
            id: "aaos_foot",
            title: "Foot and Ankle Conditioning Program — AAOS",
            url: "https://www.orthoinfo.org/recovery/foot-and-ankle-conditioning-program/",
            supports: "Foot and ankle exercise examples."
        ),
        MobilitySource(
            id: "aaos_knee",
            title: "Knee Conditioning Program — AAOS",
            url: "https://www.orthoinfo.org/recovery/knee-conditioning-program/",
            supports: "Knee exercise examples and safety; app heel-slide protocol requires review."
        ),
        MobilitySource(
            id: "nhs_sitting",
            title: "Sitting exercises — NHS",
            url: "https://www.nhs.uk/live-well/exercise/sitting-exercises/",
            supports: "Accessible seated movement examples."
        ),
        MobilitySource(
            id: "nhs_flexibility",
            title: "Flexibility exercises — NHS",
            url: "https://www.nhs.uk/live-well/exercise/flexibility-exercises/",
            supports: "Neck turning, neck side bending and trunk side bending."
        ),
        MobilitySource(
            id: "cuh_wrist",
            title: "Hand Therapy Active Wrist exercises — Cambridge University Hospitals",
            url: "https://www.cuh.nhs.uk/patient-information/hand-therapy-active-wrist-exercises/",
            supports: "Wrist directions and forearm rotation; not the proposed loaded progression."
        ),
        MobilitySource(
            id: "cuh_fingers",
            title: "Hand therapy active finger exercises — Cambridge University Hospitals",
            url: "https://www.cuh.nhs.uk/patient-information/hand-therapy-active-finger-exercises/",
            supports: "Finger opening, closing and spreading examples."
        ),
        MobilitySource(
            id: "mayo_back",
            title: "Back exercises in 15 minutes a day — Mayo Clinic",
            url: "https://www.mayoclinic.org/healthy-lifestyle/adult-health/in-depth/back-pain/art-20546859",
            supports: "Cat stretch and pelvic movement examples, not a numerical spinal score."
        ),
        MobilitySource(
            id: "supine_reach",
            title: "Supine Shoulder Flexion — The Pelvic PT",
            url: "https://www.thepelvicpt.com/videos/supine-shoulder-flexion",
            supports: "Supine overhead exercise and avoiding extra back arching."
        ),
        MobilitySource(
            id: "ankle_study",
            title: "Chisholm et al. (2012), Reliability and Validity of a Weight-Bearing Measure of Ankle Dorsiflexion Range of Motion",
            url: "https://pubmed.ncbi.nlm.nih.gov/23997389/",
            supports: "Reliability/validity of a studied clinician-administered lunge protocol, not this self-guided adaptation."
        ),
        MobilitySource(
            id: "trunk_study",
            title: "Johnson et al. (2012), Reliability of thoracic spine rotation range-of-motion measurements in healthy adults",
            url: "https://pubmed.ncbi.nlm.nih.gov/22488230/",
            supports: "Reliability of specific examiner-administered measurement protocols; not self-estimated degrees."
        ),
        MobilitySource(
            id: "hip_position_study",
            title: "Simoneau et al. (1998), Influence of hip position and gender on active hip internal and external rotation",
            url: "https://pubmed.ncbi.nlm.nih.gov/9742472/",
            supports: "Hip rotation depends on assessment position; supports keeping setups consistent."
        ),
        MobilitySource(
            id: "ace_hip_flexor",
            title: "Kneeling Hip-flexor Stretch — American Council on Exercise",
            url: "https://www.acefitness.org/resources/everyone/exercise-library/142/kneeling-hip-flexor-stretch/",
            supports: "Exercise setup, not validity as an isolated hip-extension test."
        ),
        MobilitySource(
            id: "hss_hip",
            title: "Four Hip Flexor Stretches to Relieve Tightness, from a PT — Hospital for Special Surgery",
            url: "https://www.hss.edu/health-library/move-better/hip-flexor-stretch",
            supports: "Examples of hip positions including 90/90; not app levels."
        ),
        MobilitySource(
            id: "nhs_hypermobility",
            title: "Joint hypermobility syndrome — NHS",
            url: "https://www.nhs.uk/conditions/joint-hypermobility-syndrome/",
            supports: "Do not reward unlimited joint overextension; strength/control may be the appropriate goal."
        ),
    ]

    /// Who should get individual guidance before using a track.
    public static let eligibility = "Users with current injury, recent surgery, joint instability, significant pain or relevant medical restrictions need individualised professional guidance before using affected tracks."

    /// When to stop a movement. `symptomBlocked` records this state.
    public static let stopRule = "Stop the affected movement for pain, sharp pinching, numbness, tingling, dizziness or giving-way. Persistent or new symptoms need appropriate clinical assessment."

    /// The catalogue does not chase range for its own sake.
    public static let rangeLimit = "Do not reward joint hyperextension or extreme neck/spinal motion. Goals must be appropriate to you."

    /// Assessment protocol guidance shown in the guide tab.
    public static let protocolNotes: [String] = [
        "Use a consistent light warm-up and test before targeted stretching or fatiguing training.",
        "Use a demonstration and a few controlled attempts; do not assess with a long maximal hold.",
        "Cards contain several directions — record each separately, and left and right separately.",
        "Changed position, assistance or loading is not automatically changed joint range.",
        "Retest under the same setup, roughly every 2 weeks. Confirm borderline gains.",
    ]

    /// Looks up a card or functional benchmark by id.
    public static func card(for id: String) -> MobilityCardDefinition? {
        all.first { $0.id == id }
    }

    /// Looks up a source by id.
    public static func source(for id: String) -> MobilitySource? {
        sources.first { $0.id == id }
    }
}
