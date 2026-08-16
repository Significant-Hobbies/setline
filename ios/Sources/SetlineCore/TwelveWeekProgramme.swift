import Foundation

public enum BundledProgrammeID: String, Codable, CaseIterable, Sendable {
    case twelveWeekStrengthCardioMobility

    public var title: String {
        switch self {
        case .twelveWeekStrengthCardioMobility:
            "12-Week Strength, Cardio & Mobility Plan"
        }
    }
}

/// The five session shapes the twelve-week block schedules.
public enum ProgrammeSessionKind: String, Codable, CaseIterable, Sendable {
    case upper
    case lower
    case easyCardioMobility
    case upperPlusHardCardio
    case fullMobility

    /// A stable identity so history written in one week still resolves later.
    public var templateID: UUID {
        switch self {
        case .upper: UUID(uuidString: "5E71C0DE-0000-4000-A000-000000000001")!
        case .lower: UUID(uuidString: "5E71C0DE-0000-4000-A000-000000000002")!
        case .easyCardioMobility: UUID(uuidString: "5E71C0DE-0000-4000-A000-000000000003")!
        case .upperPlusHardCardio: UUID(uuidString: "5E71C0DE-0000-4000-A000-000000000004")!
        case .fullMobility: UUID(uuidString: "5E71C0DE-0000-4000-A000-000000000005")!
        }
    }
}

public struct ProgrammeScheduleEntry: Equatable, Sendable, Identifiable {
    /// 0 = Monday, matching the block's Monday-based weeks.
    public var dayIndex: Int
    public var dayLabel: String
    public var title: String
    public var kind: ProgrammeSessionKind
    /// Whether the day counts toward the weekly completion standard.
    public var isRequired: Bool

    public var id: Int { dayIndex }
}

public struct ProgrammeCheckpoint: Equatable, Sendable, Identifiable {
    public var name: String
    public var dayOffset: Int
    public var id: Int { dayOffset }
}

/// A load increase rule for one movement, as the block writes it.
public struct ProgressionRule: Equatable, Sendable {
    public var exerciseSlug: String
    public var repsLow: Int
    public var repsHigh: Int
    /// Total added load once every working set reaches the top of the range.
    public var incrementKilograms: Double?
    public var specialRule: String

    public init(
        exerciseSlug: String,
        repsLow: Int,
        repsHigh: Int,
        incrementKilograms: Double?,
        specialRule: String
    ) {
        self.exerciseSlug = exerciseSlug
        self.repsLow = repsLow
        self.repsHigh = repsHigh
        self.incrementKilograms = incrementKilograms
        self.specialRule = specialRule
    }
}

public struct ProgrammePosition: Equatable, Sendable {
    public var weekNumber: Int
    public var dayIndex: Int
    public var inBlock: Bool
    public var beforeBlock: Bool
    public var afterBlock: Bool
    public var schedule: ProgrammeScheduleEntry
    public var template: WorkoutTemplate
}

/// Sarthak's authored twelve-week block, Monday 27 July to Sunday 18 October 2026.
///
/// The block is week-aware rather than a fixed set of templates: the third RDL
/// set, the hard-cardio round count, the pull-up checkpoints and the optional
/// lateral raise all depend on which week you are in. Sessions are therefore
/// resolved on demand instead of stored.
public enum TwelveWeekProgramme {
    public static let id = BundledProgrammeID.twelveWeekStrengthCardioMobility
    public static let name = "Sarthak's 12-Week Strength, Cardio & Mobility Plan"
    public static let shortName = "12-Week Strength · Cardio · Mobility"
    public static let weekCount = 12
    public static let dayCount = weekCount * 7

    public static let startDateComponents = DateComponents(year: 2026, month: 7, day: 27)

    public static let schedule: [ProgrammeScheduleEntry] = [
        ProgrammeScheduleEntry(dayIndex: 0, dayLabel: "MON", title: "Upper", kind: .upper, isRequired: true),
        ProgrammeScheduleEntry(dayIndex: 1, dayLabel: "TUE", title: "Lower", kind: .lower, isRequired: true),
        ProgrammeScheduleEntry(
            dayIndex: 2,
            dayLabel: "WED",
            title: "Easy + mobility",
            kind: .easyCardioMobility,
            isRequired: true
        ),
        ProgrammeScheduleEntry(
            dayIndex: 3,
            dayLabel: "THU",
            title: "Upper + hard",
            kind: .upperPlusHardCardio,
            isRequired: true
        ),
        ProgrammeScheduleEntry(dayIndex: 4, dayLabel: "FRI", title: "Mobility", kind: .fullMobility, isRequired: true),
        ProgrammeScheduleEntry(dayIndex: 5, dayLabel: "SAT", title: "Lower", kind: .lower, isRequired: true),
        ProgrammeScheduleEntry(
            dayIndex: 6,
            dayLabel: "SUN",
            title: "Easy + mobility",
            kind: .easyCardioMobility,
            isRequired: true
        ),
    ]

    /// Baseline, week 5, week 9 and end-of-block reassessments.
    public static let checkpoints: [ProgrammeCheckpoint] = [
        ProgrammeCheckpoint(name: "Baseline", dayOffset: 0),
        ProgrammeCheckpoint(name: "Week 5", dayOffset: 28),
        ProgrammeCheckpoint(name: "Week 9", dayOffset: 56),
        ProgrammeCheckpoint(name: "End of block", dayOffset: 83),
    ]

    /// The nine measures the block asks you to record at each checkpoint.
    public static let checkpointMeasures: [String] = [
        "Body weight",
        "Waist",
        "Bench: best clean working set",
        "Strict pull-ups",
        "Hack squat / leg press working load",
        "RDL working load and reps",
        "45-min easy-cardio pace",
        "Knee-to-wall distance",
        "Squat support / heel elevation",
    ]

    public static let progressionRules: [ProgressionRule] = [
        ProgressionRule(
            exerciseSlug: "bench-press",
            repsLow: 5,
            repsHigh: 8,
            incrementKilograms: 2.5,
            specialRule: "Only after 3 × 8 is clean."
        ),
        ProgressionRule(
            exerciseSlug: "machine-or-db-shoulder-press",
            repsLow: 6,
            repsHigh: 10,
            incrementKilograms: nil,
            specialRule: "Smallest available increment. Protect technique and shoulder comfort."
        ),
        ProgressionRule(
            exerciseSlug: "lat-pulldown",
            repsLow: 6,
            repsHigh: 10,
            incrementKilograms: nil,
            specialRule: "One machine increment. Do not shorten range."
        ),
        ProgressionRule(
            exerciseSlug: "chest-supported-or-cable-row",
            repsLow: 8,
            repsHigh: 12,
            incrementKilograms: nil,
            specialRule: "One machine increment. Do not shorten range."
        ),
        ProgressionRule(
            exerciseSlug: "hack-squat-or-leg-press",
            repsLow: 6,
            repsHigh: 10,
            incrementKilograms: nil,
            specialRule: "Smallest reasonable increment. Keep the same machine and depth."
        ),
        ProgressionRule(
            exerciseSlug: "romanian-deadlift",
            repsLow: 6,
            repsHigh: 10,
            incrementKilograms: 2.5,
            specialRule: "2.5–5 kg total. Never sacrifice hinge position."
        ),
        ProgressionRule(
            exerciseSlug: "supported-bulgarian-split-squat",
            repsLow: 8,
            repsHigh: 12,
            incrementKilograms: 2,
            specialRule: "1–2 kg per dumbbell, only after both legs reach the top range."
        ),
        ProgressionRule(
            exerciseSlug: "lying-leg-curl",
            repsLow: 10,
            repsHigh: 15,
            incrementKilograms: nil,
            specialRule: "One machine increment. Controlled eccentric."
        ),
        ProgressionRule(
            exerciseSlug: "standing-calf-raise",
            repsLow: 10,
            repsHigh: 20,
            incrementKilograms: nil,
            specialRule: "Reach 20 controlled reps on all sets, then add load."
        ),
        ProgressionRule(
            exerciseSlug: "ab-wheel",
            repsLow: 6,
            repsHigh: 12,
            incrementKilograms: nil,
            specialRule: "Reps, then range, then a slower eccentric."
        ),
        ProgressionRule(
            exerciseSlug: "farmer-carry",
            repsLow: 0,
            repsHigh: 0,
            incrementKilograms: nil,
            specialRule: "Reach 2 × 45 sec, then add weight and return to 30 sec."
        ),
    ]

    public static func rule(forSlug slug: String) -> ProgressionRule? {
        progressionRules.first { $0.exerciseSlug == slug }
    }

    // MARK: - Calendar

    public static func startDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: startDateComponents) ?? Date(timeIntervalSince1970: 1_784_505_600)
    }

    /// Day offset from the block start, clamped into the block for resolution but
    /// reported honestly through `beforeBlock` / `afterBlock`.
    public static func position(for date: Date, calendar: Calendar = .current) -> ProgrammePosition {
        let start = calendar.startOfDay(for: startDate(calendar: calendar))
        let today = calendar.startOfDay(for: date)
        let offset = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let beforeBlock = offset < 0
        let afterBlock = offset >= dayCount
        let bounded = min(dayCount - 1, max(0, offset))
        let weekNumber = bounded / 7 + 1
        let dayIndex = bounded % 7
        let entry = schedule[dayIndex]
        return ProgrammePosition(
            weekNumber: weekNumber,
            dayIndex: dayIndex,
            inBlock: !beforeBlock && !afterBlock,
            beforeBlock: beforeBlock,
            afterBlock: afterBlock,
            schedule: entry,
            template: template(for: entry.kind, week: weekNumber, dayIndex: dayIndex)
        )
    }

    public static func checkpointDate(_ checkpoint: ProgrammeCheckpoint, calendar: Calendar = .current) -> Date {
        calendar.date(
            byAdding: .day,
            value: checkpoint.dayOffset,
            to: calendar.startOfDay(for: startDate(calendar: calendar))
        ) ?? startDate(calendar: calendar)
    }

    // MARK: - Session resolution

    public static func template(
        for kind: ProgrammeSessionKind,
        week: Int,
        dayIndex: Int = 0
    ) -> WorkoutTemplate {
        let boundedWeek = min(weekCount, max(1, week))
        switch kind {
        case .upper, .upperPlusHardCardio:
            return upperTemplate(week: boundedWeek, dayIndex: dayIndex, includeHardCardio: kind == .upperPlusHardCardio)
        case .lower:
            return lowerTemplate(week: boundedWeek)
        case .easyCardioMobility:
            return WorkoutTemplate(
                id: kind.templateID,
                name: "Easy cardio + full mobility",
                detail: "45 min conversational · full mobility routine",
                isBundled: true,
                exercises: easyCardioExercises + fullMobilityExercises,
                notes: [
                    "Start around the existing 5 km/h baseline when walking.",
                    "Increase speed or incline only after two comfortable weeks.",
                ],
                expectedMinutes: 60
            )
        case .fullMobility:
            return WorkoutTemplate(
                id: kind.templateID,
                name: "Full mobility",
                detail: "12–15 min routine · Friday recovery",
                isBundled: true,
                exercises: fullMobilityExercises,
                notes: [
                    "An optional 20–40 minute walk is allowed only when recovery is good.",
                    "Sharp pain, radiating symptoms, or worsening back pain are stop signals.",
                ],
                expectedMinutes: 15
            )
        }
    }

    /// Whether a strict pull-up is tested on this session. The block tests at the
    /// start of weeks 5 and 9, and at the end of week 12 — never more often.
    static func testsPullUp(week: Int, dayIndex: Int) -> Bool {
        (dayIndex == 0 && (week == 5 || week == 9)) || (dayIndex == 3 && week == 12)
    }

    /// Reps in reserve on compounds: 2–3 while learning, then 1–2.
    static func repsInReserve(week: Int) -> Int { week <= 2 ? 2 : 1 }

    // MARK: - Upper

    static func upperTemplate(week: Int, dayIndex: Int, includeHardCardio: Bool) -> WorkoutTemplate {
        let kind: ProgrammeSessionKind = includeHardCardio ? .upperPlusHardCardio : .upper
        var exercises = upperPreparationExercises
        exercises.append(benchExercise(week: week))
        if testsPullUp(week: week, dayIndex: dayIndex) {
            exercises.append(pullUpCheckpointExercise)
        }
        exercises.append(latPulldownExercise(week: week))
        exercises.append(shoulderPressExercise(week: week))
        exercises.append(rowExercise(week: week))
        // Optional accessory the block permits only after four consistent weeks.
        if week >= 5 { exercises.append(lateralRaiseExercise) }
        exercises.append(abWheelExercise)
        exercises.append(farmerCarryExercise)
        exercises.append(contentsOf: upperCooldownExercises)
        if includeHardCardio {
            exercises.append(contentsOf: hardCardioExercises(week: week))
        }
        var notes = [
            "Bench begins at 65 kg for 3 × 5–8. Add 2.5 kg only after 3 × 8 is clean.",
            week <= 2
                ? "Weeks 1–2: finish with 2–3 reps in reserve."
                : "Keep 1–2 reps in reserve on compounds.",
        ]
        if includeHardCardio {
            notes.append("Complete the full Upper session first. Hard cardio comes afterward.")
        }
        if week >= 5 {
            notes.append("Optional lateral raises are compliant to skip; they do not fix a missing pattern.")
        }
        return WorkoutTemplate(
            id: kind.templateID,
            name: includeHardCardio ? "Upper + hard cardio" : "Upper",
            detail: includeHardCardio
                ? "Bench · pull · press · row · then intervals"
                : "Bench · vertical pull · press · row · trunk · carry",
            isBundled: true,
            exercises: exercises,
            notes: notes,
            expectedMinutes: includeHardCardio ? 105 : 65
        )
    }

    static let upperPreparationExercises: [Exercise] = [
        exercise("easy-treadmill-bike-or-rower", sets: [
            set(
                "General preparation · 1 of 4",
                .cardio,
                .preparation,
                SetTarget(timeSeconds: 180),
                cue: "Use an easy pace for 2–3 minutes."
            ),
        ]),
        exercise("arm-circles", sets: [
            set(
                "General preparation · 2 of 4",
                .mobility,
                .preparation,
                SetTarget(repsLow: 20),
                cue: "Complete 10 forward and 10 backward."
            ),
        ]),
        exercise("wall-slides", sets: [
            set("General preparation · 3 of 4", .mobility, .preparation, SetTarget(repsLow: 8)),
        ]),
        exercise("scapular-pulldown", sets: [
            set(
                "General preparation · 4 of 4",
                .strength,
                .preparation,
                SetTarget(repsLow: 10, load: .chooseLoad)
            ),
        ]),
    ]

    static func benchExercise(week: Int) -> Exercise {
        // The authored ramp: 20 kg × 10, 40 × 5, 55 × 2–3, then 65 kg working sets.
        var sets = [
            set(
                "20 kg bar · ramp 1 of 3",
                .strength,
                .warmUp,
                SetTarget(repsLow: 10, load: .absolute(kilograms: 20)),
                rest: RestRange(60),
                cue: "Set the shoulder blades and repeat the same touch point."
            ),
            set(
                "40 kg · ramp 2 of 3",
                .strength,
                .warmUp,
                SetTarget(repsLow: 5, load: .absolute(kilograms: 40)),
                rest: RestRange(60),
                cue: "Keep the setup identical to the working sets."
            ),
            set(
                "55 kg · ramp 3 of 3",
                .strength,
                .warmUp,
                SetTarget(repsLow: 2, repsHigh: 3, load: .absolute(kilograms: 55)),
                rest: RestRange(90),
                cue: "Warm up without accumulating fatigue."
            ),
        ]
        sets += (1...3).map { number in
            set(
                "Working set \(number) of 3",
                .strength,
                .working,
                SetTarget(
                    repsLow: 5,
                    repsHigh: 8,
                    load: .absolute(kilograms: 65),
                    repsInReserve: repsInReserve(week: week)
                ),
                rest: RestRange(lowSeconds: 150, highSeconds: 180),
                cue: "Do not train bench to failure."
            )
        }
        return exercise("bench-press", sets: sets)
    }

    static let pullUpCheckpointExercise = exercise(
        "pull-up",
        sets: [
            set(
                "One test before pulldowns",
                .repetitions,
                .check,
                SetTarget(repsLow: 1, load: .bodyweight(plusKilograms: 0)),
                optional: true,
                cue: "Attempt one clean strict pull-up only. Do not repeat-test."
            ),
        ]
    )

    static func latPulldownExercise(week: Int) -> Exercise {
        exercise("lat-pulldown", sets: [
            warmUpSet(
                "1 light set",
                SetTarget(repsLow: 8, load: .chooseLoad),
                cue: "Use a comfortable neutral or shoulder-width grip."
            ),
        ] + workingSets(
            count: 3,
            repsLow: 6,
            repsHigh: 10,
            week: week,
            rest: RestRange(lowSeconds: 90, highSeconds: 150)
        ))
    }

    static func shoulderPressExercise(week: Int) -> Exercise {
        exercise("machine-or-db-shoulder-press", sets: [
            warmUpSet("1 light set", SetTarget(repsLow: 6, repsHigh: 8, load: .chooseLoad)),
        ] + workingSets(
            count: 2,
            repsLow: 6,
            repsHigh: 10,
            week: week,
            rest: RestRange(lowSeconds: 90, highSeconds: 150)
        ))
    }

    static func rowExercise(week: Int) -> Exercise {
        exercise("chest-supported-or-cable-row", sets: [
            warmUpSet(
                "Optional light set",
                SetTarget(repsLow: 8, load: .chooseLoad),
                optional: true,
                cue: "Use this familiarisation set only if needed."
            ),
        ] + workingSets(
            count: 3,
            repsLow: 8,
            repsHigh: 12,
            week: week,
            rest: RestRange(lowSeconds: 90, highSeconds: 150)
        ))
    }

    static let lateralRaiseExercise = exercise(
        "lateral-raise",
        sets: (1...2).map { number in
            set(
                "Optional set \(number) of 2",
                .strength,
                .working,
                SetTarget(repsLow: 12, repsHigh: 20, load: .chooseLoad),
                rest: RestRange(60),
                optional: true,
                cue: "Add only if shoulders feel good and recovery is comfortable."
            )
        }
    )

    static let abWheelExercise = exercise(
        "ab-wheel",
        sets: (1...2).map { number in
            set(
                "Working set \(number) of 2",
                .repetitions,
                .working,
                SetTarget(repsLow: 6, repsHigh: 12),
                rest: RestRange(lowSeconds: 60, highSeconds: 90)
            )
        }
    )

    static let farmerCarryExercise = exercise(
        "farmer-carry",
        sets: [
            set(
                "Optional light carry",
                .timed,
                .warmUp,
                SetTarget(load: .chooseLoad, holdSeconds: 15),
                rest: RestRange(60),
                optional: true
            ),
        ] + (1...2).map { number in
            set(
                "Carry \(number) of 2",
                .timed,
                .working,
                SetTarget(load: .chooseLoad, holdSeconds: 30),
                rest: RestRange(lowSeconds: 90, highSeconds: 120),
                cue: "Build toward 45 seconds, then add weight and return to 30."
            )
        }
    )

    static let upperCooldownExercises: [Exercise] = [
        exercise("doorway-pec-stretch", sets: [
            set(
                "1 hold per side",
                .timed,
                .cooldown,
                SetTarget(holdSeconds: 45, perSide: true),
                cue: "Use 30–45 seconds per side."
            ),
        ]),
        exercise("bench-lat-stretch", sets: [
            set("1 hold", .timed, .cooldown, SetTarget(holdSeconds: 45)),
        ]),
        exercise("open-book-rotation", sets: [
            set(
                "Optional · each side",
                .mobility,
                .cooldown,
                SetTarget(repsLow: 5, perSide: true),
                optional: true
            ),
        ]),
    ]

    // MARK: - Lower

    static func lowerTemplate(week: Int) -> WorkoutTemplate {
        let rdlSets = week <= 2 ? 2 : 3
        let exercises = lowerPreparationExercises + [
            hackSquatExercise(week: week),
            romanianDeadliftExercise(week: week, workingSets: rdlSets),
            bulgarianExercise(week: week),
            legCurlExercise(week: week),
            calfRaiseExercise(week: week),
        ] + lowerCooldownExercises
        return WorkoutTemplate(
            id: ProgrammeSessionKind.lower.templateID,
            name: "Lower",
            detail: "Squat · hinge · split squat · curl · calf",
            isBundled: true,
            exercises: exercises,
            notes: [
                "Choose hack squat or leg press once and keep it for all 12 weeks.",
                week <= 2
                    ? "Weeks 1–2 use exactly two RDL working sets."
                    : "The third RDL set is conditional on stable technique and reasonable lower-back fatigue.",
                "Do not add leg extensions or back extensions during the core block.",
            ],
            expectedMinutes: 70
        )
    }

    static let lowerPreparationExercises: [Exercise] = [
        exercise("easy-treadmill-bike-or-rower", sets: [
            set(
                "General preparation · 1 of 5",
                .cardio,
                .preparation,
                SetTarget(timeSeconds: 180),
                cue: "Use an easy pace for 3 minutes."
            ),
        ]),
        exercise("knee-to-wall-ankle-rocks", sets: [
            set(
                "General preparation · 2 of 5",
                .mobility,
                .preparation,
                SetTarget(repsLow: 10, perSide: true)
            ),
        ]),
        exercise("supported-squat-repetitions", sets: [
            set("General preparation · 3 of 5", .mobility, .preparation, SetTarget(repsLow: 5)),
        ]),
        exercise("goblet-squat", sets: [
            set(
                "General preparation · 4 of 5",
                .strength,
                .preparation,
                SetTarget(repsLow: 6, repsHigh: 8, load: .chooseLoad),
                cue: "Elevate the heels when needed."
            ),
        ]),
        exercise("unloaded-hip-hinge", sets: [
            set("General preparation · 5 of 5", .mobility, .preparation, SetTarget(repsLow: 8)),
        ]),
    ]

    static func hackSquatExercise(week: Int) -> Exercise {
        exercise("hack-squat-or-leg-press", sets: [
            warmUpSet("Light × 10 · ramp 1 of 3", SetTarget(repsLow: 10, load: .chooseLoad)),
            warmUpSet(
                "About 50% × 5 · ramp 2 of 3",
                SetTarget(repsLow: 5, load: .percentOfOneRepMax(50))
            ),
            warmUpSet(
                "About 70% × 3 · ramp 3 of 3",
                SetTarget(repsLow: 3, load: .percentOfOneRepMax(70)),
                rest: RestRange(90),
                cue: "Repeat the working-set stance and depth."
            ),
        ] + workingSets(
            count: 3,
            repsLow: 6,
            repsHigh: 10,
            week: week,
            rest: RestRange(lowSeconds: 150, highSeconds: 180),
            cue: "Do not train to failure; keep depth repeatable."
        ))
    }

    static func romanianDeadliftExercise(week: Int, workingSets: Int) -> Exercise {
        var sets = [
            set(
                "Bar × 8 · ramp 1 of 2",
                .strength,
                .warmUp,
                SetTarget(repsLow: 8, load: .absolute(kilograms: 20)),
                rest: RestRange(60)
            ),
            set(
                "50–60% × 5 · ramp 2 of 2",
                .strength,
                .warmUp,
                SetTarget(repsLow: 5, load: .percentOfOneRepMax(55)),
                rest: RestRange(90),
                cue: "Stop when further descent would require spinal movement."
            ),
        ]
        sets += (1...workingSets).map { number in
            let isConditional = number == 3
            return set(
                isConditional ? "Conditional working set 3 of 3" : "Working set \(number) of \(workingSets)",
                .strength,
                .working,
                SetTarget(
                    repsLow: 6,
                    repsHigh: 10,
                    load: .chooseLoad,
                    repsInReserve: repsInReserve(week: week)
                ),
                rest: RestRange(lowSeconds: 150, highSeconds: 180),
                optional: isConditional,
                cue: isConditional
                    ? "Complete only when technique is stable and lower-back fatigue is reasonable."
                    : "Keep the hinge in hamstrings and glutes; never train this to failure."
            )
        }
        return exercise("romanian-deadlift", sets: sets)
    }

    static func bulgarianExercise(week: Int) -> Exercise {
        exercise("supported-bulgarian-split-squat", sets: [
            warmUpSet(
                "Bodyweight or light × 5 per leg",
                SetTarget(repsLow: 5, load: .chooseLoad, perSide: true)
            ),
        ] + workingSets(
            count: 2,
            repsLow: 8,
            repsHigh: 12,
            week: week,
            rest: RestRange(lowSeconds: 90, highSeconds: 150),
            perSide: true,
            cue: "Let the legs, not balance, limit the set."
        ))
    }

    static func legCurlExercise(week: Int) -> Exercise {
        exercise("lying-leg-curl", sets: [
            warmUpSet("1 light set", SetTarget(repsLow: 8, repsHigh: 10, load: .chooseLoad)),
        ] + workingSets(
            count: 2,
            repsLow: 10,
            repsHigh: 15,
            week: week,
            rest: RestRange(lowSeconds: 60, highSeconds: 90)
        ))
    }

    static func calfRaiseExercise(week: Int) -> Exercise {
        exercise("standing-calf-raise", sets: [
            set(
                "Bodyweight × 10",
                .repetitions,
                .warmUp,
                SetTarget(repsLow: 10, load: .bodyweight(plusKilograms: 0)),
                rest: RestRange(60),
                cue: "Use a Smith machine, single-leg dumbbell raise, or straight-knee leg-press calf press."
            ),
        ] + workingSets(
            count: 3,
            repsLow: 10,
            repsHigh: 20,
            week: week,
            rest: RestRange(lowSeconds: 60, highSeconds: 90)
        ))
    }

    static let lowerCooldownExercises: [Exercise] = [
        exercise("straight-knee-calf-stretch", sets: [
            set(
                "1 hold per side",
                .timed,
                .cooldown,
                SetTarget(holdSeconds: 45, perSide: true),
                cue: "Use 30–45 seconds per side."
            ),
        ]),
        exercise("bent-knee-calf-stretch", sets: [
            set(
                "1 hold per side",
                .timed,
                .cooldown,
                SetTarget(holdSeconds: 45, perSide: true),
                cue: "Use 30–45 seconds per side."
            ),
        ]),
        exercise("half-kneeling-hip-flexor-stretch", sets: [
            set(
                "1 hold per side",
                .timed,
                .cooldown,
                SetTarget(holdSeconds: 45, perSide: true),
                cue: "Avoid arching the lower back."
            ),
        ]),
    ]

    // MARK: - Cardio

    /// 7–8 min easy, then 4 rounds in weeks 1–2 and 5 thereafter, then 5 min easy.
    static func hardCardioExercises(week: Int) -> [Exercise] {
        let rounds = week <= 2 ? 4 : 5
        var exercises = [
            exercise("bike-or-elliptical", sets: [
                set(
                    "Easy warm-up",
                    .cardio,
                    .cardio,
                    SetTarget(timeSeconds: 480),
                    cue: "Use 7–8 easy minutes after the full Upper session."
                ),
            ]),
        ]
        exercises.append(exercise("controlled-hard-interval", sets: (1...rounds).map { round in
            set(
                "Hard round \(round) of \(rounds)",
                .cardio,
                .cardio,
                SetTarget(timeSeconds: 120),
                rest: RestRange(180),
                cue: "Use 8/10 effort: demanding and controlled, never all-out."
            )
        }))
        exercises.append(exercise("bike-or-elliptical", sets: [
            set(
                "Easy cooldown",
                .cardio,
                .cooldown,
                SetTarget(timeSeconds: 300),
                cue: "Finish with 5 easy minutes."
            ),
        ]))
        return exercises
    }

    static let easyCardioExercises: [Exercise] = [
        exercise("easy-cardio", sets: [
            set(
                "Very easy start · 1 of 3",
                .cardio,
                .cardio,
                SetTarget(timeSeconds: 300),
                cue: "Use treadmill walking, incline walking, bike, or elliptical."
            ),
            set(
                "Aerobic work · 2 of 3",
                .cardio,
                .cardio,
                SetTarget(timeSeconds: 2_100),
                cue: "Stay around 3–4/10; full sentences should remain possible."
            ),
            set(
                "Easy finish · 3 of 3",
                .cardio,
                .cooldown,
                SetTarget(timeSeconds: 300),
                cue: "Finish fresh; do not turn the session into a race."
            ),
        ]),
    ]

    // MARK: - Mobility

    /// The eight-movement, 12–15 minute routine, in authored order.
    static let fullMobilityExercises: [Exercise] = [
        exercise("knee-to-wall-ankle-rocks", sets: (1...2).map { number in
            set(
                "Set \(number) of 2 · each side",
                .mobility,
                .mobility,
                SetTarget(repsLow: 10, perSide: true),
                rest: RestRange(30)
            )
        }),
        exercise("supported-squat-hold", sets: (1...2).map { number in
            set(
                "Hold \(number) of 2",
                .timed,
                .mobility,
                SetTarget(holdSeconds: 45),
                rest: RestRange(30),
                cue: "Hold a rack or post. Elevate the heels when needed; do not force depth."
            )
        }),
        exercise("goblet-squat", sets: (1...2).map { number in
            set(
                "Set \(number) of 2 · slow descent",
                .strength,
                .mobility,
                SetTarget(repsLow: 6, load: .chooseLoad),
                rest: RestRange(30),
                cue: "Use a slow descent and control the available range."
            )
        }),
        exercise("ninety-ninety-hip-switches", sets: (1...2).map { number in
            set(
                "Set \(number) of 2 · each side",
                .mobility,
                .mobility,
                SetTarget(repsLow: 6, perSide: true),
                rest: RestRange(30)
            )
        }),
        exercise("half-kneeling-hip-flexor-stretch", sets: [
            set(
                "1 hold per side",
                .timed,
                .mobility,
                SetTarget(holdSeconds: 45, perSide: true),
                rest: RestRange(15)
            ),
        ]),
        exercise("wall-slides", sets: (1...2).map { number in
            set("Set \(number) of 2", .mobility, .mobility, SetTarget(repsLow: 8), rest: RestRange(30))
        }),
        exercise("bench-lat-stretch", sets: [
            set("1 hold", .timed, .mobility, SetTarget(holdSeconds: 45), rest: RestRange(15)),
        ]),
        exercise("doorway-pec-stretch", sets: [
            set(
                "1 hold per side",
                .timed,
                .mobility,
                SetTarget(holdSeconds: 45, perSide: true),
                rest: RestRange(15),
                cue: "Use 30–45 seconds per side; stop for sharp or radiating pain."
            ),
        ]),
    ]

    // MARK: - Builders

    /// Builds an exercise from the catalogue so every authored movement is a
    /// known definition and inherits its pillars, cue and default rest.
    static func exercise(_ slug: String, cue: String? = nil, sets: [PlannedSet]) -> Exercise {
        guard let definition = ExerciseCatalogue.definition(slug: slug) else {
            // A missing slug is an authoring error, surfaced rather than hidden.
            return Exercise(name: slug, cue: cue ?? "", sets: sets, definitionSlug: slug)
        }
        return Exercise(
            name: definition.name,
            cue: cue ?? definition.cue,
            sets: sets,
            definitionSlug: slug,
            pillars: definition.pillars
        )
    }

    /// A single light preparation set before the working sets, as most of the
    /// block's accessories prescribe.
    static func warmUpSet(
        _ label: String,
        _ target: SetTarget,
        rest: RestRange = RestRange(60),
        optional: Bool = false,
        cue: String? = nil
    ) -> PlannedSet {
        set(label, .strength, .warmUp, target, rest: rest, optional: optional, cue: cue)
    }

    /// The block's working sets for one movement: the same range, rest and
    /// reps-in-reserve repeated, labelled "Working set n of N".
    static func workingSets(
        count: Int,
        repsLow: Int,
        repsHigh: Int,
        week: Int,
        rest: RestRange,
        perSide: Bool = false,
        cue: String? = nil
    ) -> [PlannedSet] {
        (1...count).map { number in
            set(
                perSide
                    ? "Working set \(number) of \(count) · per leg"
                    : "Working set \(number) of \(count)",
                .strength,
                .working,
                SetTarget(
                    repsLow: repsLow,
                    repsHigh: repsHigh,
                    load: .chooseLoad,
                    repsInReserve: repsInReserve(week: week),
                    perSide: perSide
                ),
                rest: rest,
                cue: cue
            )
        }
    }

    static func set(
        _ label: String,
        _ kind: ActivityKind,
        _ stepType: StepType,
        _ target: SetTarget,
        rest: RestRange = .none,
        optional: Bool = false,
        cue: String? = nil
    ) -> PlannedSet {
        PlannedSet(
            label: label,
            kind: kind,
            stepType: stepType,
            target: target,
            rest: rest,
            isOptional: optional,
            cue: cue
        )
    }
}
