import Foundation

public enum MuscleGroup: String, Codable, CaseIterable, Sendable {
    case chest
    case upperBack
    case lats
    case shoulders
    case biceps
    case triceps
    case forearms
    case trunk
    case lowerBack
    case glutes
    case quadriceps
    case hamstrings
    case adductors
    case calves
    case hipFlexors
    case thoracicSpine
    case ankles
    case fullBody

    public var title: String {
        switch self {
        case .chest: "Chest"
        case .upperBack: "Upper back"
        case .lats: "Lats"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms & grip"
        case .trunk: "Trunk"
        case .lowerBack: "Lower back"
        case .glutes: "Glutes"
        case .quadriceps: "Quadriceps"
        case .hamstrings: "Hamstrings"
        case .adductors: "Adductors"
        case .calves: "Calves"
        case .hipFlexors: "Hip flexors"
        case .thoracicSpine: "Thoracic spine"
        case .ankles: "Ankles"
        case .fullBody: "Full body"
        }
    }
}

public enum Equipment: String, Codable, CaseIterable, Sendable {
    case none
    case barbell
    case dumbbell
    case kettlebell
    case machine
    case cable
    case smithMachine
    case pullUpBar
    case rings
    case bench
    case box
    case bands
    case medicineBall
    case sled
    case rope
    case treadmill
    case bike
    case rower
    case elliptical
    case skiErg
    case wall
    case foamRoller

    public var title: String {
        switch self {
        case .none: "Bodyweight"
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .kettlebell: "Kettlebell"
        case .machine: "Machine"
        case .cable: "Cable"
        case .smithMachine: "Smith machine"
        case .pullUpBar: "Pull-up bar"
        case .rings: "Rings"
        case .bench: "Bench"
        case .box: "Box"
        case .bands: "Bands"
        case .medicineBall: "Medicine ball"
        case .sled: "Sled"
        case .rope: "Rope"
        case .treadmill: "Treadmill"
        case .bike: "Bike"
        case .rower: "Rower"
        case .elliptical: "Elliptical"
        case .skiErg: "Ski erg"
        case .wall: "Wall"
        case .foamRoller: "Foam roller"
        }
    }
}

/// A movement's stable identity. Templates and recorded steps point at a slug so
/// every measurement of the same movement accumulates in one place, no matter
/// which template or programme produced it.
public struct ExerciseDefinition: Codable, Equatable, Identifiable, Sendable {
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
}

/// The bundled movement library.
///
/// Held in Swift rather than a JSON resource so slugs are compile-time checked
/// and the catalogue is reachable from the framework without resource plumbing.
public enum ExerciseCatalogue {
    public static let all: [ExerciseDefinition] = strength + mobilityAndFlexibility + stamina + crossFit

    private static let byNormalisedName: [String: ExerciseDefinition] = {
        var index: [String: ExerciseDefinition] = [:]
        for definition in all {
            index[ExerciseMetrics.normalise(definition.name)] = definition
            for alias in definition.aliases {
                index[ExerciseMetrics.normalise(alias)] = definition
            }
        }
        return index
    }()

    private static let bySlug: [String: ExerciseDefinition] = {
        Dictionary(all.map { ($0.slug, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    public static func definition(slug: String) -> ExerciseDefinition? { bySlug[slug] }

    /// Resolves a free-text exercise name to a catalogue definition.
    public static func match(name: String) -> ExerciseDefinition? {
        byNormalisedName[ExerciseMetrics.normalise(name)]
    }

    public static func definitions(for pillar: Pillar) -> [ExerciseDefinition] {
        all.filter { $0.pillars.contains(pillar) }.sorted { $0.name < $1.name }
    }

    public static func search(_ query: String) -> [ExerciseDefinition] {
        let needle = ExerciseMetrics.normalise(query)
        guard !needle.isEmpty else { return all.sorted { $0.name < $1.name } }
        return all
            .filter { definition in
                ExerciseMetrics.normalise(definition.name).contains(needle)
                    || definition.aliases.contains { ExerciseMetrics.normalise($0).contains(needle) }
            }
            .sorted { $0.name < $1.name }
    }

    // MARK: - Strength

    static let strength: [ExerciseDefinition] = [
        ExerciseDefinition(
            slug: "bench-press",
            name: "Bench press",
            aliases: ["barbell bench press", "flat bench"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps, .shoulders],
            equipment: [.barbell, .bench],
            defaultRest: RestRange(lowSeconds: 150, highSeconds: 180),
            cue: "Set the shoulder blades and repeat the same touch point."
        ),
        ExerciseDefinition(
            slug: "incline-bench-press",
            name: "Incline bench press",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.chest, .shoulders],
            secondaryMuscles: [.triceps],
            equipment: [.barbell, .bench],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180)
        ),
        ExerciseDefinition(
            slug: "dumbbell-bench-press",
            name: "Dumbbell bench press",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps, .shoulders],
            equipment: [.dumbbell, .bench],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 150)
        ),
        ExerciseDefinition(
            slug: "push-up",
            name: "Push-up",
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps, .trunk],
            defaultRest: RestRange(60),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "overhead-press",
            name: "Overhead press",
            aliases: ["barbell overhead press", "strict press"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.shoulders],
            secondaryMuscles: [.triceps, .trunk],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180)
        ),
        ExerciseDefinition(
            slug: "machine-or-db-shoulder-press",
            name: "Machine or DB shoulder press",
            aliases: ["shoulder press", "machine shoulder press", "dumbbell shoulder press"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.shoulders],
            secondaryMuscles: [.triceps],
            equipment: [.machine, .dumbbell],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150),
            cue: "Choose a machine or neutral-grip dumbbells; do not force a barbell position."
        ),
        ExerciseDefinition(
            slug: "lateral-raise",
            name: "Lateral raise",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.shoulders],
            equipment: [.dumbbell],
            defaultRest: RestRange(60)
        ),
        ExerciseDefinition(
            slug: "lat-pulldown",
            name: "Lat pulldown",
            aliases: ["pulldown", "cable pulldown"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.lats],
            secondaryMuscles: [.upperBack, .biceps],
            equipment: [.machine, .cable],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150),
            cue: "Lead with the elbows; do not shorten the range."
        ),
        ExerciseDefinition(
            slug: "pull-up",
            name: "Strict pull-up",
            aliases: ["pull-up", "pullup", "strict pullup"],
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.lats],
            secondaryMuscles: [.upperBack, .biceps, .forearms],
            equipment: [.pullUpBar],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180),
            cue: "Full hang to chin over the bar without kipping.",
            goalMetrics: [.maxRepetitions, .topSetLoad]
        ),
        ExerciseDefinition(
            slug: "chin-up",
            name: "Chin-up",
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.lats, .biceps],
            equipment: [.pullUpBar],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180),
            goalMetrics: [.maxRepetitions, .topSetLoad]
        ),
        ExerciseDefinition(
            slug: "chest-supported-or-cable-row",
            name: "Chest-supported or cable row",
            aliases: ["chest-supported row", "cable row", "seated cable row", "seated row"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.upperBack],
            secondaryMuscles: [.lats, .biceps],
            equipment: [.machine, .cable],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150),
            cue: "Row without using lower-back momentum."
        ),
        ExerciseDefinition(
            slug: "barbell-row",
            name: "Barbell row",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.upperBack, .lats],
            secondaryMuscles: [.lowerBack, .biceps],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180)
        ),
        ExerciseDefinition(
            slug: "face-pull",
            name: "Face pull",
            pillars: [.strength, .mobility],
            kind: .strength,
            primaryMuscles: [.upperBack, .shoulders],
            equipment: [.cable, .bands],
            defaultRest: RestRange(60)
        ),
        ExerciseDefinition(
            slug: "biceps-curl",
            name: "Biceps curl",
            aliases: ["dumbbell curl", "barbell curl"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.biceps],
            equipment: [.dumbbell, .barbell],
            defaultRest: RestRange(60)
        ),
        ExerciseDefinition(
            slug: "triceps-extension",
            name: "Triceps extension",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.triceps],
            equipment: [.cable, .dumbbell],
            defaultRest: RestRange(60)
        ),
        ExerciseDefinition(
            slug: "back-squat",
            name: "Back squat",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.quadriceps, .glutes],
            secondaryMuscles: [.trunk, .lowerBack],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 150, highSeconds: 210)
        ),
        ExerciseDefinition(
            slug: "front-squat",
            name: "Front squat",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.quadriceps],
            secondaryMuscles: [.trunk, .upperBack],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 150, highSeconds: 180),
            cue: "Brace before the descent. Keep elbows tall."
        ),
        ExerciseDefinition(
            slug: "hack-squat-or-leg-press",
            name: "Hack squat or leg press",
            aliases: ["hack squat", "leg press"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.quadriceps, .glutes],
            equipment: [.machine],
            defaultRest: RestRange(lowSeconds: 150, highSeconds: 180),
            cue: "Keep the same chosen machine and a repeatable depth for the full block."
        ),
        ExerciseDefinition(
            slug: "goblet-squat",
            name: "Goblet squat",
            aliases: ["light goblet squat"],
            pillars: [.strength, .mobility],
            kind: .strength,
            primaryMuscles: [.quadriceps, .glutes],
            equipment: [.kettlebell, .dumbbell],
            defaultRest: RestRange(60),
            cue: "Use a slow descent and control the available range."
        ),
        ExerciseDefinition(
            slug: "deadlift",
            name: "Deadlift",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.glutes, .hamstrings, .lowerBack],
            secondaryMuscles: [.upperBack, .forearms],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 180, highSeconds: 240)
        ),
        ExerciseDefinition(
            slug: "romanian-deadlift",
            name: "Romanian deadlift",
            aliases: ["rdl"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.hamstrings, .glutes],
            secondaryMuscles: [.lowerBack, .forearms],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 150, highSeconds: 180),
            cue: "Push the hips back, keep the bar close, and never train this to failure."
        ),
        ExerciseDefinition(
            slug: "supported-bulgarian-split-squat",
            name: "Supported Bulgarian split squat",
            aliases: ["bulgarian split squat", "bulgarians"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.quadriceps, .glutes],
            secondaryMuscles: [.adductors],
            equipment: [.dumbbell, .bench],
            isUnilateral: true,
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150),
            cue: "Use support so balance does not limit the legs."
        ),
        ExerciseDefinition(
            slug: "lying-leg-curl",
            name: "Lying leg curl",
            aliases: ["leg curl"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.hamstrings],
            equipment: [.machine],
            defaultRest: RestRange(lowSeconds: 60, highSeconds: 90),
            cue: "Control the return; do not shorten range."
        ),
        ExerciseDefinition(
            slug: "standing-calf-raise",
            name: "Standing calf raise",
            aliases: ["calf raise"],
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.calves],
            equipment: [.smithMachine, .machine, .dumbbell],
            defaultRest: RestRange(lowSeconds: 60, highSeconds: 90),
            cue: "Control the descent, pause in the stretch, rise fully, and do not bounce."
        ),
        ExerciseDefinition(
            slug: "hip-thrust",
            name: "Hip thrust",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.glutes],
            secondaryMuscles: [.hamstrings],
            equipment: [.barbell, .bench],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150)
        ),
        ExerciseDefinition(
            slug: "ab-wheel",
            name: "Ab wheel from knees",
            aliases: ["ab wheel", "ab rollout"],
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.trunk],
            secondaryMuscles: [.lats],
            defaultRest: RestRange(lowSeconds: 60, highSeconds: 90),
            cue: "Stop before the lower back sags or arches.",
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "plank",
            name: "Plank",
            pillars: [.strength],
            kind: .timed,
            primaryMuscles: [.trunk],
            defaultRest: RestRange(60),
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "hanging-leg-raise",
            name: "Hanging leg raise",
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.trunk, .hipFlexors],
            equipment: [.pullUpBar],
            defaultRest: RestRange(lowSeconds: 60, highSeconds: 90),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "farmer-carry",
            name: "Farmer carry",
            aliases: ["farmers carry", "farmer's carry"],
            pillars: [.strength, .stamina],
            kind: .timed,
            primaryMuscles: [.forearms, .trunk],
            secondaryMuscles: [.upperBack, .glutes],
            equipment: [.dumbbell, .kettlebell],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 120),
            cue: "Stay tall; avoid leaning or excessive shrugging.",
            goalMetrics: [.bestHoldSeconds, .topSetLoad]
        ),
        ExerciseDefinition(
            slug: "suitcase-carry",
            name: "Suitcase carry",
            pillars: [.strength, .stamina],
            kind: .timed,
            primaryMuscles: [.trunk, .forearms],
            equipment: [.dumbbell, .kettlebell],
            isUnilateral: true,
            defaultRest: RestRange(45),
            cue: "Walk tall without leaning.",
            goalMetrics: [.bestHoldSeconds, .topSetLoad]
        ),
        ExerciseDefinition(
            slug: "scapular-pulldown",
            name: "Very light scapular pulldown",
            aliases: ["scapular pulldown"],
            pillars: [.mobility, .strength],
            kind: .strength,
            primaryMuscles: [.upperBack, .lats],
            equipment: [.cable, .machine],
            defaultRest: RestRange(30),
            cue: "Move the shoulder blades without turning this into a working set.",
            goalMetrics: [.maxRepetitions]
        ),
    ]

    // MARK: - Mobility and flexibility

    static let mobilityAndFlexibility: [ExerciseDefinition] = [
        ExerciseDefinition(
            slug: "knee-to-wall-ankle-rocks",
            name: "Knee-to-wall ankle rocks",
            aliases: ["ankle rocks"],
            pillars: [.mobility],
            kind: .mobility,
            primaryMuscles: [.ankles, .calves],
            equipment: [.wall],
            isUnilateral: true,
            defaultRest: RestRange(30),
            cue: "Keep the heel down and the movement controlled.",
            goalMetrics: [.rangeOfMotion, .maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "supported-squat-hold",
            name: "Supported squat hold",
            pillars: [.mobility, .flexibility],
            kind: .timed,
            primaryMuscles: [.ankles, .glutes, .adductors],
            equipment: [.none],
            defaultRest: RestRange(30),
            cue: "Hold a rack or post. Elevate the heels when needed; do not force depth.",
            goalMetrics: [.bestHoldSeconds, .rangeOfMotion]
        ),
        ExerciseDefinition(
            slug: "supported-squat-repetitions",
            name: "Supported squat repetitions",
            pillars: [.mobility],
            kind: .mobility,
            primaryMuscles: [.quadriceps, .ankles],
            defaultRest: RestRange(30),
            cue: "Use a short pause and heel elevation when needed.",
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "ninety-ninety-hip-switches",
            name: "90/90 hip switches",
            aliases: ["90/90 switches", "hip switches"],
            pillars: [.mobility],
            kind: .mobility,
            primaryMuscles: [.glutes, .hipFlexors],
            isUnilateral: true,
            defaultRest: RestRange(30),
            cue: "Move through hip rotation without forcing the knees.",
            goalMetrics: [.maxRepetitions, .rangeOfMotion]
        ),
        ExerciseDefinition(
            slug: "half-kneeling-hip-flexor-stretch",
            name: "Half-kneeling hip-flexor stretch",
            aliases: ["hip flexor stretch"],
            pillars: [.flexibility],
            kind: .timed,
            primaryMuscles: [.hipFlexors],
            isUnilateral: true,
            defaultRest: RestRange(15),
            cue: "Extend the hip without arching the lower back.",
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "wall-slides",
            name: "Wall slides",
            pillars: [.mobility],
            kind: .mobility,
            primaryMuscles: [.shoulders, .thoracicSpine],
            equipment: [.wall],
            defaultRest: RestRange(30),
            cue: "Move smoothly through a comfortable shoulder range.",
            goalMetrics: [.maxRepetitions, .rangeOfMotion]
        ),
        ExerciseDefinition(
            slug: "bench-lat-stretch",
            name: "Bench lat stretch",
            pillars: [.flexibility],
            kind: .timed,
            primaryMuscles: [.lats, .shoulders],
            equipment: [.bench],
            defaultRest: RestRange(15),
            cue: "Keep the ribs controlled while reaching overhead.",
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "doorway-pec-stretch",
            name: "Doorway pec stretch",
            aliases: ["pec stretch"],
            pillars: [.flexibility],
            kind: .timed,
            primaryMuscles: [.chest, .shoulders],
            isUnilateral: true,
            defaultRest: RestRange(15),
            cue: "Stop for sharp or radiating pain.",
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "open-book-rotation",
            name: "Open-book rotation",
            pillars: [.mobility],
            kind: .mobility,
            primaryMuscles: [.thoracicSpine],
            isUnilateral: true,
            defaultRest: RestRange(15),
            cue: "Use only if it feels useful; do not force range.",
            goalMetrics: [.maxRepetitions, .rangeOfMotion]
        ),
        ExerciseDefinition(
            slug: "straight-knee-calf-stretch",
            name: "Straight-knee calf stretch",
            pillars: [.flexibility],
            kind: .timed,
            primaryMuscles: [.calves],
            equipment: [.wall],
            isUnilateral: true,
            defaultRest: RestRange(15),
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "bent-knee-calf-stretch",
            name: "Bent-knee calf stretch",
            pillars: [.flexibility],
            kind: .timed,
            primaryMuscles: [.calves, .ankles],
            equipment: [.wall],
            isUnilateral: true,
            defaultRest: RestRange(15),
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "unloaded-hip-hinge",
            name: "Unloaded hip hinges",
            pillars: [.mobility],
            kind: .mobility,
            primaryMuscles: [.hamstrings, .glutes],
            defaultRest: RestRange(30),
            cue: "Push the hips back while keeping a small knee bend.",
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "arm-circles",
            name: "Arm circles",
            pillars: [.mobility],
            kind: .mobility,
            primaryMuscles: [.shoulders],
            defaultRest: RestRange(0),
            cue: "Complete equal repetitions forward and backward.",
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "thoracic-extension-over-roller",
            name: "Thoracic extension over roller",
            pillars: [.mobility, .flexibility],
            kind: .timed,
            primaryMuscles: [.thoracicSpine],
            equipment: [.foamRoller],
            defaultRest: RestRange(15),
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "hamstring-stretch",
            name: "Seated hamstring stretch",
            pillars: [.flexibility],
            kind: .timed,
            primaryMuscles: [.hamstrings],
            isUnilateral: true,
            defaultRest: RestRange(15),
            goalMetrics: [.bestHoldSeconds, .rangeOfMotion]
        ),
        ExerciseDefinition(
            slug: "pigeon-stretch",
            name: "Pigeon stretch",
            pillars: [.flexibility],
            kind: .timed,
            primaryMuscles: [.glutes, .hipFlexors],
            isUnilateral: true,
            defaultRest: RestRange(15),
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "couch-stretch",
            name: "Couch stretch",
            pillars: [.flexibility],
            kind: .timed,
            primaryMuscles: [.hipFlexors, .quadriceps],
            isUnilateral: true,
            defaultRest: RestRange(15),
            goalMetrics: [.bestHoldSeconds]
        ),
        ExerciseDefinition(
            slug: "deep-squat-hold",
            name: "Deep squat hold",
            pillars: [.mobility, .flexibility],
            kind: .timed,
            primaryMuscles: [.ankles, .adductors, .glutes],
            defaultRest: RestRange(30),
            goalMetrics: [.bestHoldSeconds, .rangeOfMotion]
        ),
        ExerciseDefinition(
            slug: "shoulder-dislocates",
            name: "Shoulder dislocates",
            pillars: [.mobility],
            kind: .mobility,
            primaryMuscles: [.shoulders, .thoracicSpine],
            equipment: [.bands],
            defaultRest: RestRange(15),
            goalMetrics: [.maxRepetitions, .rangeOfMotion]
        ),
    ]

    // MARK: - Stamina

    static let stamina: [ExerciseDefinition] = [
        ExerciseDefinition(
            slug: "easy-cardio",
            name: "Easy cardio",
            aliases: ["conversational cardio", "easy cardio cooldown"],
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.treadmill, .bike, .elliptical, .rower],
            defaultRest: RestRange(0),
            cue: "Stay around 3–4/10; full sentences should remain possible.",
            goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre]
        ),
        ExerciseDefinition(
            slug: "easy-treadmill-bike-or-rower",
            name: "Easy treadmill, bike or rower",
            aliases: ["easy bike or treadmill"],
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.treadmill, .bike, .rower],
            defaultRest: RestRange(0),
            cue: "Use an easy pace as general preparation.",
            goalMetrics: [.longestDistanceMetres]
        ),
        ExerciseDefinition(
            slug: "controlled-hard-interval",
            name: "Controlled hard interval",
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.bike, .elliptical, .rower, .treadmill],
            defaultRest: RestRange(180),
            cue: "Use 8/10 effort: demanding and controlled, never all-out.",
            goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre]
        ),
        ExerciseDefinition(
            slug: "easy-interval-recovery",
            name: "Easy interval recovery",
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.bike, .elliptical, .rower, .treadmill],
            defaultRest: RestRange(0),
            cue: "Recover at an easy pace.",
            goalMetrics: [.longestDistanceMetres]
        ),
        ExerciseDefinition(
            slug: "bike-or-elliptical",
            name: "Bike or elliptical",
            aliases: ["bike or elliptical cooldown", "bike intervals"],
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.bike, .elliptical],
            defaultRest: RestRange(0),
            goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre]
        ),
        ExerciseDefinition(
            slug: "run",
            name: "Run",
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.treadmill, .none],
            defaultRest: RestRange(0),
            goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre]
        ),
        ExerciseDefinition(
            slug: "row",
            name: "Row",
            pillars: [.stamina, .strength],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.rower],
            defaultRest: RestRange(0),
            goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre]
        ),
        ExerciseDefinition(
            slug: "ski-erg",
            name: "Ski erg",
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.skiErg],
            defaultRest: RestRange(0),
            goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre]
        ),
        ExerciseDefinition(
            slug: "incline-walk",
            name: "Incline walk",
            aliases: ["recovery walk", "walk"],
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.treadmill, .none],
            defaultRest: RestRange(0),
            goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre]
        ),
        ExerciseDefinition(
            slug: "assault-bike",
            name: "Assault bike",
            pillars: [.stamina],
            kind: .cardio,
            primaryMuscles: [.fullBody],
            equipment: [.bike],
            defaultRest: RestRange(0),
            goalMetrics: [.longestDistanceMetres]
        ),
        ExerciseDefinition(
            slug: "jump-rope",
            name: "Jump rope",
            aliases: ["single unders"],
            pillars: [.stamina],
            kind: .repetitions,
            primaryMuscles: [.calves, .fullBody],
            equipment: [.rope],
            defaultRest: RestRange(30),
            goalMetrics: [.maxRepetitions, .bestHoldSeconds]
        ),
    ]

    // MARK: - CrossFit movement vocabulary

    static let crossFit: [ExerciseDefinition] = [
        ExerciseDefinition(
            slug: "clean-and-jerk",
            name: "Clean and jerk",
            pillars: [.strength, .stamina],
            kind: .strength,
            primaryMuscles: [.fullBody],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180)
        ),
        ExerciseDefinition(
            slug: "power-clean",
            name: "Power clean",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.fullBody, .glutes],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180)
        ),
        ExerciseDefinition(
            slug: "snatch",
            name: "Snatch",
            pillars: [.strength],
            kind: .strength,
            primaryMuscles: [.fullBody, .shoulders],
            equipment: [.barbell],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180)
        ),
        ExerciseDefinition(
            slug: "thruster",
            name: "Thruster",
            pillars: [.strength, .stamina],
            kind: .strength,
            primaryMuscles: [.quadriceps, .shoulders],
            equipment: [.barbell, .dumbbell],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150)
        ),
        ExerciseDefinition(
            slug: "wall-ball",
            name: "Wall ball",
            pillars: [.strength, .stamina],
            kind: .repetitions,
            primaryMuscles: [.quadriceps, .shoulders],
            equipment: [.medicineBall, .wall],
            defaultRest: RestRange(60),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "kettlebell-swing",
            name: "Kettlebell swing",
            pillars: [.strength, .stamina],
            kind: .strength,
            primaryMuscles: [.glutes, .hamstrings],
            secondaryMuscles: [.trunk, .forearms],
            equipment: [.kettlebell],
            defaultRest: RestRange(60)
        ),
        ExerciseDefinition(
            slug: "box-jump",
            name: "Box jump",
            pillars: [.strength, .stamina],
            kind: .repetitions,
            primaryMuscles: [.quadriceps, .calves],
            equipment: [.box],
            defaultRest: RestRange(60),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "burpee",
            name: "Burpee",
            pillars: [.stamina, .strength],
            kind: .repetitions,
            primaryMuscles: [.fullBody],
            defaultRest: RestRange(60),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "toes-to-bar",
            name: "Toes-to-bar",
            pillars: [.strength, .mobility],
            kind: .repetitions,
            primaryMuscles: [.trunk, .lats],
            equipment: [.pullUpBar],
            defaultRest: RestRange(lowSeconds: 60, highSeconds: 90),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "double-under",
            name: "Double-under",
            pillars: [.stamina],
            kind: .repetitions,
            primaryMuscles: [.calves],
            equipment: [.rope],
            defaultRest: RestRange(60),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "handstand-push-up",
            name: "Handstand push-up",
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.shoulders, .triceps],
            equipment: [.wall],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "ring-dip",
            name: "Ring dip",
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.chest, .triceps],
            equipment: [.rings],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 120),
            goalMetrics: [.maxRepetitions, .topSetLoad]
        ),
        ExerciseDefinition(
            slug: "muscle-up",
            name: "Muscle-up",
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.lats, .chest, .triceps],
            equipment: [.rings, .pullUpBar],
            defaultRest: RestRange(lowSeconds: 120, highSeconds: 180),
            goalMetrics: [.maxRepetitions]
        ),
        ExerciseDefinition(
            slug: "sled-push",
            name: "Sled push",
            pillars: [.strength, .stamina],
            kind: .timed,
            primaryMuscles: [.quadriceps, .glutes],
            equipment: [.sled],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150),
            goalMetrics: [.longestDistanceMetres, .topSetLoad]
        ),
        ExerciseDefinition(
            slug: "rope-climb",
            name: "Rope climb",
            pillars: [.strength],
            kind: .repetitions,
            primaryMuscles: [.lats, .forearms],
            equipment: [.rope],
            defaultRest: RestRange(lowSeconds: 90, highSeconds: 150),
            goalMetrics: [.maxRepetitions]
        ),
    ]
}
