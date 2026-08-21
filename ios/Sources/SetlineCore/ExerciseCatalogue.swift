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
    public struct Anatomy: Equatable, Sendable {
        public var primaryMuscles: [MuscleGroup]
        public var secondaryMuscles: [MuscleGroup]
        public var equipment: [Equipment]
        public var isUnilateral: Bool

        public init(
            primaryMuscles: [MuscleGroup] = [],
            secondaryMuscles: [MuscleGroup] = [],
            equipment: [Equipment] = [.none],
            isUnilateral: Bool = false
        ) {
            self.primaryMuscles = primaryMuscles
            self.secondaryMuscles = secondaryMuscles
            self.equipment = equipment
            self.isUnilateral = isUnilateral
        }
    }

    public struct ExerciseConfig: Equatable, Sendable {
        public var aliases: [String]
        public var defaultRest: RestRange
        public var cue: String
        public var goalMetrics: [MetricKind]

        public init(
            aliases: [String] = [],
            defaultRest: RestRange = RestRange(90),
            cue: String = "",
            goalMetrics: [MetricKind] = [.estimatedOneRepMax, .topSetLoad]
        ) {
            self.aliases = aliases
            self.defaultRest = defaultRest
            self.cue = cue
            self.goalMetrics = goalMetrics
        }
    }

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
        pillars: Set<Pillar>,
        kind: ActivityKind,
        anatomy: Anatomy = .init(),
        config: ExerciseConfig = .init()
    ) {
        self.slug = slug
        self.name = name
        self.aliases = config.aliases
        self.pillars = pillars
        self.kind = kind
        self.primaryMuscles = anatomy.primaryMuscles
        self.secondaryMuscles = anatomy.secondaryMuscles
        self.equipment = anatomy.equipment
        self.isUnilateral = anatomy.isUnilateral
        self.defaultRest = config.defaultRest
        self.cue = config.cue
        self.goalMetrics = config.goalMetrics
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
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.chest], secondaryMuscles: [.triceps, .shoulders], equipment: [.barbell, .bench]),
            config: .init(aliases: ["barbell bench press", "flat bench"], defaultRest: RestRange(lowSeconds: 150, highSeconds: 180), cue: "Set the shoulder blades and repeat the same touch point.")
        ),
        ExerciseDefinition(
            slug: "incline-bench-press",
            name: "Incline bench press",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.chest, .shoulders], secondaryMuscles: [.triceps], equipment: [.barbell, .bench]),
            config: .init(defaultRest: RestRange(lowSeconds: 120, highSeconds: 180))
        ),
        ExerciseDefinition(
            slug: "dumbbell-bench-press",
            name: "Dumbbell bench press",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.chest], secondaryMuscles: [.triceps, .shoulders], equipment: [.dumbbell, .bench]),
            config: .init(defaultRest: RestRange(lowSeconds: 120, highSeconds: 150))
        ),
        ExerciseDefinition(
            slug: "push-up",
            name: "Push-up",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.chest], secondaryMuscles: [.triceps, .trunk]),
            config: .init(defaultRest: RestRange(60), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "overhead-press",
            name: "Overhead press",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.shoulders], secondaryMuscles: [.triceps, .trunk], equipment: [.barbell]),
            config: .init(aliases: ["barbell overhead press", "strict press"], defaultRest: RestRange(lowSeconds: 120, highSeconds: 180))
        ),
        ExerciseDefinition(
            slug: "machine-or-db-shoulder-press",
            name: "Machine or DB shoulder press",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.shoulders], secondaryMuscles: [.triceps], equipment: [.machine, .dumbbell]),
            config: .init(aliases: ["shoulder press", "machine shoulder press", "dumbbell shoulder press"], defaultRest: RestRange(lowSeconds: 90, highSeconds: 150), cue: "Choose a machine or neutral-grip dumbbells; do not force a barbell position.")
        ),
        ExerciseDefinition(
            slug: "lateral-raise",
            name: "Lateral raise",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.shoulders], equipment: [.dumbbell]),
            config: .init(defaultRest: RestRange(60))
        ),
        ExerciseDefinition(
            slug: "lat-pulldown",
            name: "Lat pulldown",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.lats], secondaryMuscles: [.upperBack, .biceps], equipment: [.machine, .cable]),
            config: .init(aliases: ["pulldown", "cable pulldown"], defaultRest: RestRange(lowSeconds: 90, highSeconds: 150), cue: "Lead with the elbows; do not shorten the range.")
        ),
        ExerciseDefinition(
            slug: "pull-up",
            name: "Strict pull-up",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.lats], secondaryMuscles: [.upperBack, .biceps, .forearms], equipment: [.pullUpBar]),
            config: .init(aliases: ["pull-up", "pullup", "strict pullup"], defaultRest: RestRange(lowSeconds: 120, highSeconds: 180), cue: "Full hang to chin over the bar without kipping.", goalMetrics: [.maxRepetitions, .topSetLoad])
        ),
        ExerciseDefinition(
            slug: "chin-up",
            name: "Chin-up",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.lats, .biceps], equipment: [.pullUpBar]),
            config: .init(defaultRest: RestRange(lowSeconds: 120, highSeconds: 180), goalMetrics: [.maxRepetitions, .topSetLoad])
        ),
        ExerciseDefinition(
            slug: "chest-supported-or-cable-row",
            name: "Chest-supported or cable row",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.upperBack], secondaryMuscles: [.lats, .biceps], equipment: [.machine, .cable]),
            config: .init(aliases: ["chest-supported row", "cable row", "seated cable row", "seated row"], defaultRest: RestRange(lowSeconds: 90, highSeconds: 150), cue: "Row without using lower-back momentum.")
        ),
        ExerciseDefinition(
            slug: "barbell-row",
            name: "Barbell row",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.upperBack, .lats], secondaryMuscles: [.lowerBack, .biceps], equipment: [.barbell]),
            config: .init(defaultRest: RestRange(lowSeconds: 120, highSeconds: 180))
        ),
        ExerciseDefinition(
            slug: "face-pull",
            name: "Face pull",
            pillars: [.strength, .mobility],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.upperBack, .shoulders], equipment: [.cable, .bands]),
            config: .init(defaultRest: RestRange(60))
        ),
        ExerciseDefinition(
            slug: "biceps-curl",
            name: "Biceps curl",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.biceps], equipment: [.dumbbell, .barbell]),
            config: .init(aliases: ["dumbbell curl", "barbell curl"], defaultRest: RestRange(60))
        ),
        ExerciseDefinition(
            slug: "triceps-extension",
            name: "Triceps extension",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.triceps], equipment: [.cable, .dumbbell]),
            config: .init(defaultRest: RestRange(60))
        ),
        ExerciseDefinition(
            slug: "back-squat",
            name: "Back squat",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.quadriceps, .glutes], secondaryMuscles: [.trunk, .lowerBack], equipment: [.barbell]),
            config: .init(defaultRest: RestRange(lowSeconds: 150, highSeconds: 210))
        ),
        ExerciseDefinition(
            slug: "front-squat",
            name: "Front squat",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.quadriceps], secondaryMuscles: [.trunk, .upperBack], equipment: [.barbell]),
            config: .init(defaultRest: RestRange(lowSeconds: 150, highSeconds: 180), cue: "Brace before the descent. Keep elbows tall.")
        ),
        ExerciseDefinition(
            slug: "hack-squat-or-leg-press",
            name: "Hack squat or leg press",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.quadriceps, .glutes], equipment: [.machine]),
            config: .init(aliases: ["hack squat", "leg press"], defaultRest: RestRange(lowSeconds: 150, highSeconds: 180), cue: "Keep the same chosen machine and a repeatable depth for the full block.")
        ),
        ExerciseDefinition(
            slug: "goblet-squat",
            name: "Goblet squat",
            pillars: [.strength, .mobility],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.quadriceps, .glutes], equipment: [.kettlebell, .dumbbell]),
            config: .init(aliases: ["light goblet squat"], defaultRest: RestRange(60), cue: "Use a slow descent and control the available range.")
        ),
        ExerciseDefinition(
            slug: "deadlift",
            name: "Deadlift",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.glutes, .hamstrings, .lowerBack], secondaryMuscles: [.upperBack, .forearms], equipment: [.barbell]),
            config: .init(defaultRest: RestRange(lowSeconds: 180, highSeconds: 240))
        ),
        ExerciseDefinition(
            slug: "romanian-deadlift",
            name: "Romanian deadlift",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.hamstrings, .glutes], secondaryMuscles: [.lowerBack, .forearms], equipment: [.barbell]),
            config: .init(aliases: ["rdl"], defaultRest: RestRange(lowSeconds: 150, highSeconds: 180), cue: "Push the hips back, keep the bar close, and never train this to failure.")
        ),
        ExerciseDefinition(
            slug: "supported-bulgarian-split-squat",
            name: "Supported Bulgarian split squat",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.quadriceps, .glutes], secondaryMuscles: [.adductors], equipment: [.dumbbell, .bench], isUnilateral: true),
            config: .init(aliases: ["bulgarian split squat", "bulgarians"], defaultRest: RestRange(lowSeconds: 90, highSeconds: 150), cue: "Use support so balance does not limit the legs.")
        ),
        ExerciseDefinition(
            slug: "lying-leg-curl",
            name: "Lying leg curl",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.hamstrings], equipment: [.machine]),
            config: .init(aliases: ["leg curl"], defaultRest: RestRange(lowSeconds: 60, highSeconds: 90), cue: "Control the return; do not shorten range.")
        ),
        ExerciseDefinition(
            slug: "standing-calf-raise",
            name: "Standing calf raise",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.calves], equipment: [.smithMachine, .machine, .dumbbell]),
            config: .init(aliases: ["calf raise"], defaultRest: RestRange(lowSeconds: 60, highSeconds: 90), cue: "Control the descent, pause in the stretch, rise fully, and do not bounce.")
        ),
        ExerciseDefinition(
            slug: "hip-thrust",
            name: "Hip thrust",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.glutes], secondaryMuscles: [.hamstrings], equipment: [.barbell, .bench]),
            config: .init(defaultRest: RestRange(lowSeconds: 90, highSeconds: 150))
        ),
        ExerciseDefinition(
            slug: "ab-wheel",
            name: "Ab wheel from knees",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.trunk], secondaryMuscles: [.lats]),
            config: .init(aliases: ["ab wheel", "ab rollout"], defaultRest: RestRange(lowSeconds: 60, highSeconds: 90), cue: "Stop before the lower back sags or arches.", goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "plank",
            name: "Plank",
            pillars: [.strength],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.trunk]),
            config: .init(defaultRest: RestRange(60), goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "hanging-leg-raise",
            name: "Hanging leg raise",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.trunk, .hipFlexors], equipment: [.pullUpBar]),
            config: .init(defaultRest: RestRange(lowSeconds: 60, highSeconds: 90), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "farmer-carry",
            name: "Farmer carry",
            pillars: [.strength, .stamina],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.forearms, .trunk], secondaryMuscles: [.upperBack, .glutes], equipment: [.dumbbell, .kettlebell]),
            config: .init(aliases: ["farmers carry", "farmer's carry"], defaultRest: RestRange(lowSeconds: 90, highSeconds: 120), cue: "Stay tall; avoid leaning or excessive shrugging.", goalMetrics: [.bestHoldSeconds, .topSetLoad])
        ),
        ExerciseDefinition(
            slug: "suitcase-carry",
            name: "Suitcase carry",
            pillars: [.strength, .stamina],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.trunk, .forearms], equipment: [.dumbbell, .kettlebell], isUnilateral: true),
            config: .init(defaultRest: RestRange(45), cue: "Walk tall without leaning.", goalMetrics: [.bestHoldSeconds, .topSetLoad])
        ),
        ExerciseDefinition(
            slug: "scapular-pulldown",
            name: "Very light scapular pulldown",
            pillars: [.mobility, .strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.upperBack, .lats], equipment: [.cable, .machine]),
            config: .init(aliases: ["scapular pulldown"], defaultRest: RestRange(30), cue: "Move the shoulder blades without turning this into a working set.", goalMetrics: [.maxRepetitions])
        ),
    ]

    // MARK: - Mobility and flexibility

    static let mobilityAndFlexibility: [ExerciseDefinition] = [
        ExerciseDefinition(
            slug: "knee-to-wall-ankle-rocks",
            name: "Knee-to-wall ankle rocks",
            pillars: [.mobility],
            kind: .mobility,
            anatomy: .init(primaryMuscles: [.ankles, .calves], equipment: [.wall], isUnilateral: true),
            config: .init(aliases: ["ankle rocks"], defaultRest: RestRange(30), cue: "Keep the heel down and the movement controlled.", goalMetrics: [.rangeOfMotion, .maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "supported-squat-hold",
            name: "Supported squat hold",
            pillars: [.mobility, .flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.ankles, .glutes, .adductors], equipment: [.none]),
            config: .init(defaultRest: RestRange(30), cue: "Hold a rack or post. Elevate the heels when needed; do not force depth.", goalMetrics: [.bestHoldSeconds, .rangeOfMotion])
        ),
        ExerciseDefinition(
            slug: "supported-squat-repetitions",
            name: "Supported squat repetitions",
            pillars: [.mobility],
            kind: .mobility,
            anatomy: .init(primaryMuscles: [.quadriceps, .ankles]),
            config: .init(defaultRest: RestRange(30), cue: "Use a short pause and heel elevation when needed.", goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "ninety-ninety-hip-switches",
            name: "90/90 hip switches",
            pillars: [.mobility],
            kind: .mobility,
            anatomy: .init(primaryMuscles: [.glutes, .hipFlexors], isUnilateral: true),
            config: .init(aliases: ["90/90 switches", "hip switches"], defaultRest: RestRange(30), cue: "Move through hip rotation without forcing the knees.", goalMetrics: [.maxRepetitions, .rangeOfMotion])
        ),
        ExerciseDefinition(
            slug: "half-kneeling-hip-flexor-stretch",
            name: "Half-kneeling hip-flexor stretch",
            pillars: [.flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.hipFlexors], isUnilateral: true),
            config: .init(aliases: ["hip flexor stretch"], defaultRest: RestRange(15), cue: "Extend the hip without arching the lower back.", goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "wall-slides",
            name: "Wall slides",
            pillars: [.mobility],
            kind: .mobility,
            anatomy: .init(primaryMuscles: [.shoulders, .thoracicSpine], equipment: [.wall]),
            config: .init(defaultRest: RestRange(30), cue: "Move smoothly through a comfortable shoulder range.", goalMetrics: [.maxRepetitions, .rangeOfMotion])
        ),
        ExerciseDefinition(
            slug: "bench-lat-stretch",
            name: "Bench lat stretch",
            pillars: [.flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.lats, .shoulders], equipment: [.bench]),
            config: .init(defaultRest: RestRange(15), cue: "Keep the ribs controlled while reaching overhead.", goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "doorway-pec-stretch",
            name: "Doorway pec stretch",
            pillars: [.flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.chest, .shoulders], isUnilateral: true),
            config: .init(aliases: ["pec stretch"], defaultRest: RestRange(15), cue: "Stop for sharp or radiating pain.", goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "open-book-rotation",
            name: "Open-book rotation",
            pillars: [.mobility],
            kind: .mobility,
            anatomy: .init(primaryMuscles: [.thoracicSpine], isUnilateral: true),
            config: .init(defaultRest: RestRange(15), cue: "Use only if it feels useful; do not force range.", goalMetrics: [.maxRepetitions, .rangeOfMotion])
        ),
        ExerciseDefinition(
            slug: "straight-knee-calf-stretch",
            name: "Straight-knee calf stretch",
            pillars: [.flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.calves], equipment: [.wall], isUnilateral: true),
            config: .init(defaultRest: RestRange(15), goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "bent-knee-calf-stretch",
            name: "Bent-knee calf stretch",
            pillars: [.flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.calves, .ankles], equipment: [.wall], isUnilateral: true),
            config: .init(defaultRest: RestRange(15), goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "unloaded-hip-hinge",
            name: "Unloaded hip hinges",
            pillars: [.mobility],
            kind: .mobility,
            anatomy: .init(primaryMuscles: [.hamstrings, .glutes]),
            config: .init(defaultRest: RestRange(30), cue: "Push the hips back while keeping a small knee bend.", goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "arm-circles",
            name: "Arm circles",
            pillars: [.mobility],
            kind: .mobility,
            anatomy: .init(primaryMuscles: [.shoulders]),
            config: .init(defaultRest: RestRange(0), cue: "Complete equal repetitions forward and backward.", goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "thoracic-extension-over-roller",
            name: "Thoracic extension over roller",
            pillars: [.mobility, .flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.thoracicSpine], equipment: [.foamRoller]),
            config: .init(defaultRest: RestRange(15), goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "hamstring-stretch",
            name: "Seated hamstring stretch",
            pillars: [.flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.hamstrings], isUnilateral: true),
            config: .init(defaultRest: RestRange(15), goalMetrics: [.bestHoldSeconds, .rangeOfMotion])
        ),
        ExerciseDefinition(
            slug: "pigeon-stretch",
            name: "Pigeon stretch",
            pillars: [.flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.glutes, .hipFlexors], isUnilateral: true),
            config: .init(defaultRest: RestRange(15), goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "couch-stretch",
            name: "Couch stretch",
            pillars: [.flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.hipFlexors, .quadriceps], isUnilateral: true),
            config: .init(defaultRest: RestRange(15), goalMetrics: [.bestHoldSeconds])
        ),
        ExerciseDefinition(
            slug: "deep-squat-hold",
            name: "Deep squat hold",
            pillars: [.mobility, .flexibility],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.ankles, .adductors, .glutes]),
            config: .init(defaultRest: RestRange(30), goalMetrics: [.bestHoldSeconds, .rangeOfMotion])
        ),
        ExerciseDefinition(
            slug: "shoulder-dislocates",
            name: "Shoulder dislocates",
            pillars: [.mobility],
            kind: .mobility,
            anatomy: .init(primaryMuscles: [.shoulders, .thoracicSpine], equipment: [.bands]),
            config: .init(defaultRest: RestRange(15), goalMetrics: [.maxRepetitions, .rangeOfMotion])
        ),
    ]

    // MARK: - Stamina

    /// Cardio machines differ only by identity and equipment, so they share one
    /// builder rather than repeating the same eight fields each time.
    static func cardioMachine(
        slug: String,
        name: String,
        equipment: [Equipment],
        aliases: [String] = [],
        pillars: Set<Pillar> = [.stamina],
        cue: String = ""
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            slug: slug,
            name: name,
            pillars: pillars,
            kind: .cardio,
            anatomy: .init(primaryMuscles: [.fullBody], equipment: equipment),
            config: .init(aliases: aliases, defaultRest: RestRange(0), cue: cue, goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre])
        )
    }

    static let stamina: [ExerciseDefinition] = [
        cardioMachine(
            slug: "easy-cardio",
            name: "Easy cardio",
            equipment: [.treadmill, .bike, .elliptical, .rower],
            aliases: ["conversational cardio", "easy cardio cooldown"],
            cue: "Stay around 3\u{2013}4/10; full sentences should remain possible."
        ),
        cardioMachine(
            slug: "easy-treadmill-bike-or-rower",
            name: "Easy treadmill, bike or rower",
            equipment: [.treadmill, .bike, .rower],
            aliases: ["easy bike or treadmill"],
            cue: "Use an easy pace as general preparation."
        ),
        ExerciseDefinition(
            slug: "controlled-hard-interval",
            name: "Controlled hard interval",
            pillars: [.stamina],
            kind: .cardio,
            anatomy: .init(primaryMuscles: [.fullBody], equipment: [.bike, .elliptical, .rower, .treadmill]),
            config: .init(defaultRest: RestRange(180), cue: "Use 8/10 effort: demanding and controlled, never all-out.", goalMetrics: [.longestDistanceMetres, .bestPaceSecondsPerKilometre])
        ),
        cardioMachine(
            slug: "easy-interval-recovery",
            name: "Easy interval recovery",
            equipment: [.bike, .elliptical, .rower, .treadmill],
            cue: "Recover at an easy pace."
        ),
        cardioMachine(
            slug: "bike-or-elliptical",
            name: "Bike or elliptical",
            equipment: [.bike, .elliptical],
            aliases: ["bike or elliptical cooldown", "bike intervals"]
        ),
        cardioMachine(slug: "run", name: "Run", equipment: [.treadmill, .none]),
        cardioMachine(
            slug: "row",
            name: "Row",
            equipment: [.rower],
            pillars: [.stamina, .strength]
        ),
        cardioMachine(slug: "ski-erg", name: "Ski erg", equipment: [.skiErg]),
        cardioMachine(
            slug: "incline-walk",
            name: "Incline walk",
            equipment: [.treadmill, .none],
            aliases: ["recovery walk", "walk"]
        ),
        cardioMachine(slug: "assault-bike", name: "Assault bike", equipment: [.bike]),
        ExerciseDefinition(
            slug: "jump-rope",
            name: "Jump rope",
            pillars: [.stamina],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.calves, .fullBody], equipment: [.rope]),
            config: .init(aliases: ["single unders"], defaultRest: RestRange(30), goalMetrics: [.maxRepetitions, .bestHoldSeconds])
        ),
    ]

    // MARK: - CrossFit movement vocabulary

    static let crossFit: [ExerciseDefinition] = [
        ExerciseDefinition(
            slug: "clean-and-jerk",
            name: "Clean and jerk",
            pillars: [.strength, .stamina],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.fullBody], equipment: [.barbell]),
            config: .init(defaultRest: RestRange(lowSeconds: 120, highSeconds: 180))
        ),
        ExerciseDefinition(
            slug: "power-clean",
            name: "Power clean",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.fullBody, .glutes], equipment: [.barbell]),
            config: .init(defaultRest: RestRange(lowSeconds: 120, highSeconds: 180))
        ),
        ExerciseDefinition(
            slug: "snatch",
            name: "Snatch",
            pillars: [.strength],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.fullBody, .shoulders], equipment: [.barbell]),
            config: .init(defaultRest: RestRange(lowSeconds: 120, highSeconds: 180))
        ),
        ExerciseDefinition(
            slug: "thruster",
            name: "Thruster",
            pillars: [.strength, .stamina],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.quadriceps, .shoulders], equipment: [.barbell, .dumbbell]),
            config: .init(defaultRest: RestRange(lowSeconds: 90, highSeconds: 150))
        ),
        ExerciseDefinition(
            slug: "wall-ball",
            name: "Wall ball",
            pillars: [.strength, .stamina],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.quadriceps, .shoulders], equipment: [.medicineBall, .wall]),
            config: .init(defaultRest: RestRange(60), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "kettlebell-swing",
            name: "Kettlebell swing",
            pillars: [.strength, .stamina],
            kind: .strength,
            anatomy: .init(primaryMuscles: [.glutes, .hamstrings], secondaryMuscles: [.trunk, .forearms], equipment: [.kettlebell]),
            config: .init(defaultRest: RestRange(60))
        ),
        ExerciseDefinition(
            slug: "box-jump",
            name: "Box jump",
            pillars: [.strength, .stamina],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.quadriceps, .calves], equipment: [.box]),
            config: .init(defaultRest: RestRange(60), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "burpee",
            name: "Burpee",
            pillars: [.stamina, .strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.fullBody]),
            config: .init(defaultRest: RestRange(60), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "toes-to-bar",
            name: "Toes-to-bar",
            pillars: [.strength, .mobility],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.trunk, .lats], equipment: [.pullUpBar]),
            config: .init(defaultRest: RestRange(lowSeconds: 60, highSeconds: 90), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "double-under",
            name: "Double-under",
            pillars: [.stamina],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.calves], equipment: [.rope]),
            config: .init(defaultRest: RestRange(60), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "handstand-push-up",
            name: "Handstand push-up",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.shoulders, .triceps], equipment: [.wall]),
            config: .init(defaultRest: RestRange(lowSeconds: 90, highSeconds: 150), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "ring-dip",
            name: "Ring dip",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.chest, .triceps], equipment: [.rings]),
            config: .init(defaultRest: RestRange(lowSeconds: 90, highSeconds: 120), goalMetrics: [.maxRepetitions, .topSetLoad])
        ),
        ExerciseDefinition(
            slug: "muscle-up",
            name: "Muscle-up",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.lats, .chest, .triceps], equipment: [.rings, .pullUpBar]),
            config: .init(defaultRest: RestRange(lowSeconds: 120, highSeconds: 180), goalMetrics: [.maxRepetitions])
        ),
        ExerciseDefinition(
            slug: "sled-push",
            name: "Sled push",
            pillars: [.strength, .stamina],
            kind: .timed,
            anatomy: .init(primaryMuscles: [.quadriceps, .glutes], equipment: [.sled]),
            config: .init(defaultRest: RestRange(lowSeconds: 90, highSeconds: 150), goalMetrics: [.longestDistanceMetres, .topSetLoad])
        ),
        ExerciseDefinition(
            slug: "rope-climb",
            name: "Rope climb",
            pillars: [.strength],
            kind: .repetitions,
            anatomy: .init(primaryMuscles: [.lats, .forearms], equipment: [.rope]),
            config: .init(defaultRest: RestRange(lowSeconds: 90, highSeconds: 150), goalMetrics: [.maxRepetitions])
        ),
    ]
}
