import Foundation

/// Fitness capability benchmarks — a periodic scorecard that complements daily
/// workout execution. Each benchmark has editable targets, a test protocol, and
/// an assessment that keeps recorded, estimated, reported, and unknown values
/// visibly distinct.
///
/// Ported from the standalone Baseline HTML tracker so Setline owns the
/// capability natively, sharing the same document, store, and design system.

// MARK: - Groups

public enum BenchmarkGroup: String, Codable, CaseIterable, Sendable {
    case strength
    case endurance
    case movement
    case power
    case skills
    case body

    public var title: String {
        switch self {
        case .strength: "Strength"
        case .endurance: "Endurance"
        case .movement: "Mobility & balance"
        case .power: "Power & agility"
        case .skills: "Reaction & coordination"
        case .body: "Body"
        }
    }

    /// SF Symbol names for tab/filter icons.
    public var systemImage: String {
        switch self {
        case .strength: "figure.strengthtraining.traditional"
        case .endurance: "figure.run"
        case .movement: "figure.stand"
        case .power: "figure.jump"
        case .skills: "figure.tennis"
        case .body: "ruler"
        }
    }
}

// MARK: - Field definitions

public enum BenchmarkField: Sendable {
    case number(key: String, label: String, min: Double, max: Double, step: Double, placeholder: String)
    case time(key: String, label: String, placeholder: String)
    case select(key: String, label: String, options: [String])
    case check(key: String, label: String)

    public var key: String {
        switch self {
        case .number(let key, _, _, _, _, _): key
        case .time(let key, _, _): key
        case .select(let key, _, _): key
        case .check(let key, _): key
        }
    }

    public var label: String {
        switch self {
        case .number(_, let label, _, _, _, _): label
        case .time(_, let label, _): label
        case .select(_, let label, _): label
        case .check(_, let label): label
        }
    }
}

// MARK: - Metric definition

public struct BenchmarkDefinition: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let group: BenchmarkGroup
    public let systemImage: String
    public let description: String
    public let fields: [BenchmarkField]
    public let targets: [BenchmarkField]
    public let extra: [BenchmarkField]
    public let protocolText: String
    public let targetNote: String?

    public init(
        id: String,
        name: String,
        group: BenchmarkGroup,
        systemImage: String,
        description: String,
        fields: [BenchmarkField],
        targets: [BenchmarkField] = [],
        extra: [BenchmarkField] = [],
        protocolText: String,
        targetNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.systemImage = systemImage
        self.description = description
        self.fields = fields
        self.targets = targets
        self.extra = extra
        self.protocolText = protocolText
        self.targetNote = targetNote
    }
}

// MARK: - Dynamic state

/// Bodyweight and height, which drive weight-relative targets.
public struct BenchmarkProfile: Codable, Equatable, Sendable {
    public var weight: Double?
    public var height: Double?

    public init(weight: Double? = nil, height: Double? = nil) {
        self.weight = weight
        self.height = height
    }
}

/// One metric's current values. Numbers, text (time strings and select
/// options), and boolean flags are kept in separate dictionaries so each type
/// stays codable without type erasure. A `reported` flag marks values that came
/// from a conversation rather than a measured test.
public struct BenchmarkMetricState: Codable, Equatable, Sendable {
    public var numbers: [String: Double]
    public var texts: [String: String]
    public var flags: [String: Bool]
    public var reported: Bool

    public init(
        numbers: [String: Double] = [:],
        texts: [String: String] = [:],
        flags: [String: Bool] = [:],
        reported: Bool = false
    ) {
        self.numbers = numbers
        self.texts = texts
        self.flags = flags
        self.reported = reported
    }

    /// Reads a number field, returning nil for absent or invalid values.
    public func number(_ key: String) -> Double? {
        guard let value = numbers[key], value.isFinite else { return nil }
        return value
    }

    /// Reads a text or select field.
    public func text(_ key: String) -> String? {
        texts[key]
    }

    /// Reads a boolean flag.
    public func flag(_ key: String) -> Bool {
        flags[key] ?? false
    }
}

/// One metric's editable target values, keyed by field key.
public struct BenchmarkTargetState: Codable, Equatable, Sendable {
    public var values: [String: Double]

    public init(values: [String: Double] = [:]) {
        self.values = values
    }

    public func value(_ key: String) -> Double? {
        guard let value = values[key], value.isFinite else { return nil }
        return value
    }
}

/// A dated snapshot of all benchmarks, preserving the profile, values, and
/// targets as they stood on that day.
public struct BenchmarkCheckIn: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var profile: BenchmarkProfile
    public var metrics: [String: BenchmarkMetricState]
    public var targets: [String: BenchmarkTargetState]
    public var updated: [String: Date]

    public init(
        id: UUID = UUID(),
        date: Date,
        profile: BenchmarkProfile,
        metrics: [String: BenchmarkMetricState],
        targets: [String: BenchmarkTargetState],
        updated: [String: Date] = [:]
    ) {
        self.id = id
        self.date = date
        self.profile = profile
        self.metrics = metrics
        self.targets = targets
        self.updated = updated
    }
}

/// The full benchmarks state, stored inside `SetlineDocument`.
public struct BenchmarksState: Codable, Equatable, Sendable {
    public var profile: BenchmarkProfile
    public var metrics: [String: BenchmarkMetricState]
    public var targets: [String: BenchmarkTargetState]
    public var updated: [String: Date]
    public var history: [BenchmarkCheckIn]

    public init(
        profile: BenchmarkProfile = .init(),
        metrics: [String: BenchmarkMetricState] = [:],
        targets: [String: BenchmarkTargetState] = [:],
        updated: [String: Date] = [:],
        history: [BenchmarkCheckIn] = []
    ) {
        self.profile = profile
        self.metrics = metrics
        self.targets = targets
        self.updated = updated
        self.history = history
    }

    /// Fresh state with default targets and no entered values. A new user
    /// starts blank — no prefilled measurements, no assumed bodyweight.
    public static var initial: BenchmarksState {
        BenchmarksState(
            profile: BenchmarkProfile(),
            metrics: blankMetrics,
            targets: BenchmarkCatalog.defaultTargets,
            updated: [:],
            history: []
        )
    }

    /// Blank current values for every metric — used by "clear measurements".
    public static var blankMetrics: [String: BenchmarkMetricState] {
        var result: [String: BenchmarkMetricState] = [:]
        for metric in BenchmarkCatalog.metrics {
            var state = BenchmarkMetricState()
            for field in metric.fields + metric.extra {
                switch field {
                case .number:
                    // Absent key means nil — no entry needed.
                    break
                case .time(let key, _, _):
                    state.texts[key] = ""
                case .select(let key, _, let options):
                    state.texts[key] = options.first ?? ""
                case .check(let key, _):
                    state.flags[key] = false
                }
            }
            if metric.id == "overhead" {
                state.texts["status"] = "Not tested"
            }
            result[metric.id] = state
        }
        return result
    }
}

// MARK: - Catalog

public enum BenchmarkCatalog {
    /// All 15 benchmark definitions, in authored order.
    public static let metrics: [BenchmarkDefinition] = [
        BenchmarkDefinition(
            id: "run",
            name: "10 km run",
            group: .endurance,
            systemImage: "figure.run",
            description: "One running-endurance result. No VO\u{2082}max guesswork.",
            fields: [
                .number(key: "distance", label: "Distance completed \u{00B7} km", min: 0, max: 100, step: 0.01, placeholder: "\u{2014}"),
                .time(key: "time", label: "Elapsed time \u{00B7} mm:ss", placeholder: "40:00"),
                .select(key: "qualifier", label: "Timing", options: ["Exact time", "More than"]),
            ],
            targets: [
                .number(key: "distance", label: "Target distance \u{00B7} km", min: 1, max: 100, step: 0.1, placeholder: "\u{2014}"),
                .number(key: "minutes", label: "Time limit \u{00B7} minutes", min: 1, max: 1440, step: 0.5, placeholder: "\u{2014}"),
            ],
            extra: [.check(key: "continuous", label: "Completed continuously, without walking breaks")],
            protocolText: "Use actual elapsed time on a flat, measured course, without pausing the clock. The default goal is a continuous 10 km in under 50 minutes. A shorter effort is not extrapolated. Confirm whether the effort was continuous.",
            targetNote: "The distance and time are a paired goal. A shorter run will not be projected into a 10 km result."
        ),
        BenchmarkDefinition(
            id: "pullups",
            name: "Strict pull-ups",
            group: .strength,
            systemImage: "figure.climbing",
            description: "Relative upper-body pulling strength.",
            fields: [.number(key: "reps", label: "Clean repetitions", min: 0, max: 100, step: 1, placeholder: "\u{2014}")],
            targets: [.number(key: "reps", label: "Target repetitions", min: 1, max: 100, step: 1, placeholder: "\u{2014}")],
            protocolText: "Start with straight arms, raise your chin above the bar, and lower under control. No swinging, kipping, or shortened range. Count only clean repetitions."
        ),
        BenchmarkDefinition(
            id: "bench",
            name: "Bench press",
            group: .strength,
            systemImage: "figure.strengthtraining.traditional",
            description: "Pushing strength, relative to your bodyweight.",
            fields: [
                .number(key: "load", label: "Total barbell load \u{00B7} kg", min: 0, max: 500, step: 0.5, placeholder: "\u{2014}"),
                .number(key: "reps", label: "Repetitions", min: 1, max: 30, step: 1, placeholder: "\u{2014}"),
            ],
            targets: [.number(key: "ratio", label: "Target load \u{00F7} bodyweight", min: 0.25, max: 3, step: 0.05, placeholder: "\u{2014}")],
            protocolText: "Load includes the bar. Use consistent, controlled range and appropriate safeties or a spotter. Sets of 2\u{2013}10 reps produce a planning estimate: load \u{00D7} (1 + reps / 30). An estimate does not count as a tested single.",
            targetNote: "The target updates with profile bodyweight. Estimated 1RM is for planning only; a goal requires an actual clean lift with at least the target load."
        ),
        BenchmarkDefinition(
            id: "split",
            name: "Bulgarian split squat",
            group: .strength,
            systemImage: "figure.strengthtraining.functional",
            description: "Single-leg strength. External load only.",
            fields: [
                .number(key: "load", label: "Load in each hand \u{00B7} kg", min: 0, max: 150, step: 0.5, placeholder: "\u{2014}"),
                .number(key: "reps", label: "Reps \u{00B7} weaker leg", min: 0, max: 50, step: 1, placeholder: "\u{2014}"),
            ],
            targets: [
                .number(key: "ratio", label: "Total external load \u{00F7} bodyweight", min: 0.1, max: 2, step: 0.05, placeholder: "\u{2014}"),
                .number(key: "reps", label: "Repetitions per leg", min: 1, max: 50, step: 1, placeholder: "\u{2014}"),
            ],
            protocolText: "Use the same stance, rear-foot support, and controlled depth. Enter the weight in each hand, not both dumbbells combined. Repetitions are for the weaker leg; meet the standard on both sides."
        ),
        BenchmarkDefinition(
            id: "jump",
            name: "Standing broad jump",
            group: .power,
            systemImage: "figure.jump",
            description: "Lower-body explosive power and landing control.",
            fields: [
                .number(key: "distance", label: "Jump distance \u{00B7} metres", min: 0, max: 5, step: 0.01, placeholder: "\u{2014}"),
                .select(key: "effort", label: "Attempt type", options: ["Comfortable attempt", "Best of three"]),
            ],
            targets: [.number(key: "distance", label: "Target distance \u{00B7} metres", min: 0.5, max: 5, step: 0.05, placeholder: "\u{2014}")],
            protocolText: "After warming up and practising the movement, take off from two feet and land under control. Measure from the take-off line to the nearer heel. Record the best of three consistent attempts, not a running jump."
        ),
        BenchmarkDefinition(
            id: "carry",
            name: "Farmer carry",
            group: .strength,
            systemImage: "figure.walk",
            description: "Grip, trunk control, and moving under load.",
            fields: [
                .number(key: "load", label: "Load in each hand \u{00B7} kg", min: 0, max: 200, step: 0.5, placeholder: "\u{2014}"),
                .number(key: "distance", label: "Distance without stopping \u{00B7} m", min: 0, max: 1000, step: 1, placeholder: "\u{2014}"),
                .select(key: "effort", label: "Attempt type", options: ["Comfortable attempt", "Tested effort"]),
            ],
            targets: [
                .number(key: "ratio", label: "Load per hand \u{00F7} bodyweight", min: 0.1, max: 1.5, step: 0.05, placeholder: "\u{2014}"),
                .number(key: "distance", label: "Target distance \u{00B7} metres", min: 5, max: 1000, step: 5, placeholder: "\u{2014}"),
            ],
            protocolText: "Walk continuously with one weight in each hand, no straps and no put-downs. Keep handles, route, and turning conditions consistent. An easy carry proves that load and distance, not your maximum capacity."
        ),
        BenchmarkDefinition(
            id: "balance",
            name: "Eyes-closed balance",
            group: .movement,
            systemImage: "figure.stand",
            description: "Static single-leg balance. Both sides count.",
            fields: [
                .number(key: "left", label: "Left leg \u{00B7} seconds", min: 0, max: 300, step: 1, placeholder: "\u{2014}"),
                .number(key: "right", label: "Right leg \u{00B7} seconds", min: 0, max: 300, step: 1, placeholder: "\u{2014}"),
                .select(key: "condition", label: "Test condition", options: ["Not confirmed", "Eyes closed", "Eyes open"]),
            ],
            targets: [.number(key: "seconds", label: "Target per leg \u{00B7} seconds", min: 5, max: 300, step: 1, placeholder: "\u{2014}")],
            protocolText: "Stand near a stable support, with space to recover safely. Use the same stance each time. Eyes closed, record the best of three trials on each leg; stop when the raised foot touches down, the stance shifts, or you use support. Eyes-open results do not meet this goal."
        ),
        BenchmarkDefinition(
            id: "ankle",
            name: "Ankle mobility",
            group: .movement,
            systemImage: "figure.stand",
            description: "Knee-to-wall reach with the heel planted.",
            fields: [
                .number(key: "left", label: "Left foot-to-wall \u{00B7} cm", min: 0, max: 30, step: 0.1, placeholder: "\u{2014}"),
                .number(key: "right", label: "Right foot-to-wall \u{00B7} cm", min: 0, max: 30, step: 0.1, placeholder: "\u{2014}"),
            ],
            targets: [.number(key: "cm", label: "Target on each side \u{00B7} cm", min: 1, max: 25, step: 0.5, placeholder: "\u{2014}")],
            protocolText: "Face the wall in a staggered stance. Touch your knee to the wall with the heel planted and knee tracking over the toes. Measure toe-to-wall distance. Do not force a painful or pinching range; the default 10 cm is a practical goal, not a universal anatomical requirement."
        ),
        BenchmarkDefinition(
            id: "squat",
            name: "Deep-squat mobility",
            group: .movement,
            systemImage: "figure.squat",
            description: "A comfortable position, not just a stopwatch.",
            fields: [.number(key: "seconds", label: "Hold time \u{00B7} seconds", min: 0, max: 600, step: 1, placeholder: "\u{2014}")],
            targets: [.number(key: "seconds", label: "Target hold \u{00B7} seconds", min: 10, max: 600, step: 5, placeholder: "\u{2014}")],
            extra: [.check(key: "clean", label: "Unsupported, comfortably deep, heels planted")],
            protocolText: "Use a comfortable stance and toe angle. The test is an unsupported hold with the heels down, without pain. Assisted practice is useful but does not yet meet the unsupported standard. Do not force depth through pain."
        ),
        BenchmarkDefinition(
            id: "overhead",
            name: "Overhead mobility",
            group: .movement,
            systemImage: "figure.strengthtraining.functional",
            description: "Shoulder reach without borrowing from your back.",
            fields: [.select(key: "status", label: "Current movement", options: ["Not yet", "Meets standard", "Not tested"])],
            targets: [],
            protocolText: "Reach straight arms overhead beside your ears without pronounced rib flare or arching the lower back. Use a comfortable range. This is a functional check, not a diagnosis or a complete shoulder assessment."
        ),
        BenchmarkDefinition(
            id: "waist",
            name: "Waist-to-height",
            group: .body,
            systemImage: "ruler",
            description: "A body-composition guardrail, not an elite score.",
            fields: [.number(key: "waist", label: "Waist circumference \u{00B7} cm", min: 30, max: 250, step: 0.1, placeholder: "\u{2014}")],
            targets: [.number(key: "ratio", label: "Waist \u{00F7} height target \u{00B7} below", min: 0.3, max: 0.7, step: 0.01, placeholder: "\u{2014}")],
            protocolText: "Measure halfway between the bottom of the ribs and the top of the hips, after a natural breath out. Keep the tape horizontal and snug without compressing the skin. Use the same method each time. The default below-0.50 target is a health-oriented guardrail, not a diagnosis."
        ),
        BenchmarkDefinition(
            id: "swim",
            name: "Water competence",
            group: .endurance,
            systemImage: "figure.swimming",
            description: "Swimming, treading, and getting in and out safely.",
            fields: [
                .number(key: "distance", label: "Continuous swim \u{00B7} metres", min: 0, max: 20000, step: 25, placeholder: "\u{2014}"),
                .number(key: "tread", label: "Tread water \u{00B7} seconds", min: 0, max: 3600, step: 5, placeholder: "\u{2014}"),
            ],
            targets: [
                .number(key: "distance", label: "Continuous swim target \u{00B7} metres", min: 25, max: 20000, step: 25, placeholder: "\u{2014}"),
                .number(key: "tread", label: "Treading target \u{00B7} seconds", min: 15, max: 3600, step: 15, placeholder: "\u{2014}"),
            ],
            extra: [.check(key: "basics", label: "Entry, resurfacing, orientation, and safe exit practised")],
            protocolText: "The default goal is 400 m continuous swimming and 2 minutes treading, plus basic entry, resurfacing, orientation, and exit skills. Test in a supervised pool with help available. This does not certify open-water safety. No breath-hold challenge."
        ),
        BenchmarkDefinition(
            id: "reaction",
            name: "Visual reaction",
            group: .skills,
            systemImage: "bolt",
            description: "Ruler-drop catch. A simple reaction-time sample.",
            fields: [.number(key: "cm", label: "Mean catch distance \u{00B7} cm", min: 0.1, max: 150, step: 0.1, placeholder: "\u{2014}")],
            targets: [.number(key: "cm", label: "Maximum mean distance \u{00B7} cm", min: 1, max: 100, step: 0.5, placeholder: "\u{2014}")],
            protocolText: "A partner drops a vertical ruler without warning; catch it between finger and thumb. Keep the start position and hand consistent. Enter the mean catch distance across ten attempts. Approximate milliseconds come from free-fall distance: 1,000 \u{00D7} \u{221A}(2 \u{00D7} metres / 9.80665). This is not a sport-reflex score."
        ),
        BenchmarkDefinition(
            id: "coordination",
            name: "Hand\u{2013}eye coordination",
            group: .skills,
            systemImage: "figure.tennis",
            description: "Alternate-hand wall toss. One repeatable drill.",
            fields: [.number(key: "catches", label: "Successful catches in 30 seconds", min: 0, max: 200, step: 1, placeholder: "\u{2014}")],
            targets: [.number(key: "catches", label: "Target catches in 30 seconds", min: 1, max: 200, step: 1, placeholder: "\u{2014}")],
            protocolText: "Stand 2 m from a wall. Throw a tennis ball with one hand and catch it with the other, alternating hands. Count successful catches in 30 seconds. Keep the ball, distance, and surface consistent. This is a practical drill-specific target."
        ),
        BenchmarkDefinition(
            id: "agility",
            name: "Change of direction",
            group: .power,
            systemImage: "figure.run",
            description: "5\u{2013}10\u{2013}5 shuttle. Acceleration, braking, and turning.",
            fields: [.number(key: "seconds", label: "Shuttle time \u{00B7} seconds", min: 1, max: 120, step: 0.01, placeholder: "\u{2014}")],
            targets: [.number(key: "seconds", label: "Maximum shuttle time \u{00B7} seconds", min: 2, max: 60, step: 0.1, placeholder: "\u{2014}")],
            protocolText: "Set marks 5 yards (4.572 m) either side of a centre line. Start in the centre, run 5 yards one way, 10 the other, then 5 through the centre. Use consistent line touches, surface, start direction, and timing. Build sprint tolerance before testing. This measures planned direction changes, not reactions to an opponent."
        ),
    ]

    /// Filter groups in display order, each with a display name.
    public static let groups: [(id: String, name: String)] = [
        ("all", "All benchmarks"),
        ("strength", BenchmarkGroup.strength.title),
        ("endurance", BenchmarkGroup.endurance.title),
        ("movement", BenchmarkGroup.movement.title),
        ("power", BenchmarkGroup.power.title),
        ("skills", BenchmarkGroup.skills.title),
        ("body", BenchmarkGroup.body.title),
    ]

    /// Default target values per metric, keyed by field key.
    public static let defaultTargets: [String: BenchmarkTargetState] = [
        "run": .init(values: ["distance": 10, "minutes": 50]),
        "pullups": .init(values: ["reps": 15]),
        "bench": .init(values: ["ratio": 1.25]),
        "split": .init(values: ["ratio": 0.5, "reps": 8]),
        "jump": .init(values: ["distance": 2.3]),
        "carry": .init(values: ["ratio": 0.5, "distance": 50]),
        "balance": .init(values: ["seconds": 30]),
        "ankle": .init(values: ["cm": 10]),
        "squat": .init(values: ["seconds": 60]),
        "overhead": .init(),
        "waist": .init(values: ["ratio": 0.5]),
        "swim": .init(values: ["distance": 400, "tread": 120]),
        "reaction": .init(values: ["cm": 20]),
        "coordination": .init(values: ["catches": 30]),
        "agility": .init(values: ["seconds": 5.5]),
    ]

    /// Looks up a definition by id.
    public static func metric(for id: String) -> BenchmarkDefinition? {
        metrics.first { $0.id == id }
    }

    /// Whether a metric's targets differ from the defaults.
    public static func targetIsCustom(_ id: String, targets: [String: BenchmarkTargetState]) -> Bool {
        targets[id] != defaultTargets[id]
    }

    /// Counts how many benchmarks have reached their target.
    public static func reachedCount(in state: BenchmarksState) -> Int {
        metrics.count { BenchmarkEngine.assess($0.id, state: state).reached }
    }

    /// Counts how many benchmarks have any recorded value (measured or reported).
    public static func recordedCount(in state: BenchmarksState) -> Int {
        metrics.count { BenchmarkEngine.assess($0.id, state: state).recorded }
    }

    /// Counts how many benchmarks have reached their target in a check-in snapshot.
    public static func reachedCount(in checkIn: BenchmarkCheckIn) -> Int {
        metrics.count { BenchmarkEngine.assess($0.id, checkIn: checkIn).reached }
    }
}

// MARK: - Focus model

/// A prioritised view of benchmarks for progressive disclosure. Instead of
/// showing all 15 with equal weight, the overview surfaces the benchmarks that
/// need attention first, then collapses the rest behind an expansion.
public struct BenchmarkFocus: Sendable {
    /// Benchmarks that have a recorded value but haven't reached the target yet
    /// — the ones where progress is in motion.
    public let inProgress: [BenchmarkDefinition]
    /// Benchmarks with no recorded value at all — the gaps to fill.
    public let notStarted: [BenchmarkDefinition]
    /// Benchmarks that have reached their target — the wins to maintain.
    public let reached: [BenchmarkDefinition]
    /// All 15, in authored order, for the expanded view.
    public let all: [BenchmarkDefinition]

    public init(
        inProgress: [BenchmarkDefinition] = [],
        notStarted: [BenchmarkDefinition] = [],
        reached: [BenchmarkDefinition] = [],
        all: [BenchmarkDefinition] = BenchmarkCatalog.metrics
    ) {
        self.inProgress = inProgress
        self.notStarted = notStarted
        self.reached = reached
        self.all = all
    }

    /// Partitions the 15 benchmarks into focus buckets based on the current
    /// state. The order within each bucket follows authored order.
    public static func compute(from state: BenchmarksState) -> BenchmarkFocus {
        var inProgress: [BenchmarkDefinition] = []
        var notStarted: [BenchmarkDefinition] = []
        var reached: [BenchmarkDefinition] = []
        for metric in BenchmarkCatalog.metrics {
            let assessment = BenchmarkEngine.assess(metric.id, state: state)
            if assessment.reached {
                reached.append(metric)
            } else if assessment.recorded {
                inProgress.append(metric)
            } else {
                notStarted.append(metric)
            }
        }
        return BenchmarkFocus(inProgress: inProgress, notStarted: notStarted, reached: reached)
    }

    /// Whether the focus view has enough content to be worth showing instead of
    /// the flat list. When everything is blank, the flat list with empty-state
    /// prompts is more useful than three empty buckets.
    public var hasContent: Bool {
        !inProgress.isEmpty || !reached.isEmpty
    }
}

// MARK: - Workout history bridge

/// A suggested benchmark value derived from recorded workout history, with
/// provenance so the UI can label it clearly as "from workout on [date]" rather
/// than a measured benchmark test.
public struct BenchmarkSuggestion: Equatable, Sendable {
    public let metricID: String
    public let numbers: [String: Double]
    public let texts: [String: String]
    public let sourceDate: Date
    public let sourceExerciseName: String

    public init(metricID: String, numbers: [String: Double] = [:], texts: [String: String] = [:], sourceDate: Date, sourceExerciseName: String) {
        self.metricID = metricID
        self.numbers = numbers
        self.texts = texts
        self.sourceDate = sourceDate
        self.sourceExerciseName = sourceExerciseName
    }
}

/// Maps recorded workout evidence to benchmark suggestions. Only exercises with
/// a direct semantic match produce suggestions — no extrapolation, no guessing.
public enum BenchmarkHistoryBridge {
    /// Returns suggestions for benchmarks that can be pre-filled from workout
    /// history. Only produces a suggestion when there is actual recorded
    /// evidence and a clear semantic match to the benchmark protocol.
    public static func suggestions(from history: [WorkoutSession]) -> [BenchmarkSuggestion] {
        var results: [BenchmarkSuggestion] = []

        if let pullup = pullups(from: history) { results.append(pullup) }
        if let bench = benchPress(from: history) { results.append(bench) }
        if let run = runDistance(from: history) { results.append(run) }

        return results
    }

    /// Strict pull-ups: max reps from any recorded pull-up working step.
    private static func pullups(from history: [WorkoutSession]) -> BenchmarkSuggestion? {
        guard let current = ExerciseMetrics.current(
            for: "Strict pull-up",
            metric: .maxRepetitions,
            history: history
        ) else { return nil }
        return BenchmarkSuggestion(
            metricID: "pullups",
            numbers: ["reps": current.value],
            sourceDate: current.achievedAt,
            sourceExerciseName: "Strict pull-up"
        )
    }

    /// Bench press: best estimated 1RM from recorded bench working sets.
    /// Labelled as an estimate, not a tested single.
    private static func benchPress(from history: [WorkoutSession]) -> BenchmarkSuggestion? {
        guard let current = ExerciseMetrics.current(
            for: "Bench press",
            metric: .estimatedOneRepMax,
            history: history
        ) else { return nil }
        // Also find the actual load × reps that produced the estimate, so the
        // benchmark card shows the real set, not just the derived number.
        let topSet = ExerciseMetrics.current(
            for: "Bench press",
            metric: .topSetLoad,
            history: history
        )
        let load = topSet?.value ?? current.value
        let reps = current.repetitions ?? 1
        return BenchmarkSuggestion(
            metricID: "bench",
            numbers: ["load": load, "reps": Double(reps)],
            texts: ["source": "Estimated 1RM: \(Int(current.value)) kg"],
            sourceDate: current.achievedAt,
            sourceExerciseName: "Bench press"
        )
    }

    /// Run: longest single-effort distance. Not extrapolated to 10 km.
    private static func runDistance(from history: [WorkoutSession]) -> BenchmarkSuggestion? {
        guard let current = ExerciseMetrics.current(
            for: "Run",
            metric: .longestDistanceMetres,
            history: history
        ) else { return nil }
        return BenchmarkSuggestion(
            metricID: "run",
            numbers: ["distance": current.value / 1000], // metres → km
            texts: ["qualifier": "More than"],
            sourceDate: current.achievedAt,
            sourceExerciseName: "Run"
        )
    }
}

// MARK: - Assessment result

public struct BenchmarkAssessment: Equatable, Sendable {
    public enum Tone: String, Codable, Sendable {
        case good
        case caution
        case neutral
    }

    public var current: String
    public var currentSub: String
    public var target: String
    public var targetSub: String
    public var message: String
    public var status: String
    public var tone: Tone
    public var reached: Bool
    public var recorded: Bool

    public init(
        current: String = "Not logged",
        currentSub: String = "Add your first result",
        target: String = "",
        targetSub: String = "",
        message: String = "No baseline yet. Enter a result to start tracking.",
        status: String = "Not tested",
        tone: Tone = .neutral,
        reached: Bool = false,
        recorded: Bool = false
    ) {
        self.current = current
        self.currentSub = currentSub
        self.target = target
        self.targetSub = targetSub
        self.message = message
        self.status = status
        self.tone = tone
        self.reached = reached
        self.recorded = recorded
    }
}
