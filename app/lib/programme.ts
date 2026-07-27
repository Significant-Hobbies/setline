export type WorkoutId =
  | "upper"
  | "lower"
  | "easy-mobility"
  | "upper-hard"
  | "mobility"
  | "legacy-upper-a";

export type TrackingKind =
  | "weight-reps"
  | "reps"
  | "duration"
  | "weight-duration"
  | "completion";

export type StepType =
  | "Preparation"
  | "Warm-up"
  | "Working"
  | "Cardio"
  | "Mobility"
  | "Cooldown"
  | "Check";

export type PlannedStep = {
  id: string;
  exercise: string;
  setType: StepType;
  setLabel: string;
  tracking: TrackingKind;
  targetWeight: number | null;
  targetReps: number | null;
  targetRepsMax: number | null;
  targetDurationSeconds: number | null;
  restSeconds: number;
  targetRpe?: number;
  cue: string;
  optional?: boolean;
};

export type WorkoutTemplate = {
  id: WorkoutId;
  name: string;
  scheduleName: string;
  expectedMinutes: number;
  steps: PlannedStep[];
  notes: string[];
};

export type ScheduleEntry = {
  dayIndex: number;
  day: string;
  name: string;
  time: string;
  workoutId: Exclude<WorkoutId, "legacy-upper-a">;
  required: boolean;
};

export const PROGRAMME = {
  name: "Sarthak’s 12-Week Strength, Cardio & Mobility Plan",
  shortName: "12-Week Strength · Cardio · Mobility",
  startLabel: "27 Jul 2026",
  endLabel: "18 Oct 2026",
  durationWeeks: 12,
} as const;

export const PROGRAMME_SCHEDULE: ScheduleEntry[] = [
  { dayIndex: 0, day: "MON", name: "Upper", time: "19:00", workoutId: "upper", required: true },
  { dayIndex: 1, day: "TUE", name: "Lower", time: "19:00", workoutId: "lower", required: true },
  {
    dayIndex: 2,
    day: "WED",
    name: "Easy + mobility",
    time: "Flexible",
    workoutId: "easy-mobility",
    required: true,
  },
  {
    dayIndex: 3,
    day: "THU",
    name: "Upper + hard",
    time: "19:00",
    workoutId: "upper-hard",
    required: true,
  },
  {
    dayIndex: 4,
    day: "FRI",
    name: "Mobility",
    time: "Flexible",
    workoutId: "mobility",
    required: true,
  },
  { dayIndex: 5, day: "SAT", name: "Lower", time: "11:00", workoutId: "lower", required: true },
  {
    dayIndex: 6,
    day: "SUN",
    name: "Easy + mobility",
    time: "Flexible",
    workoutId: "easy-mobility",
    required: true,
  },
];

const step = (
  id: string,
  exercise: string,
  setType: StepType,
  setLabel: string,
  tracking: TrackingKind,
  targets: Partial<
    Pick<
      PlannedStep,
      | "targetWeight"
      | "targetReps"
      | "targetRepsMax"
      | "targetDurationSeconds"
      | "restSeconds"
      | "targetRpe"
      | "optional"
    >
  >,
  cue: string,
): PlannedStep => ({
  id,
  exercise,
  setType,
  setLabel,
  tracking,
  targetWeight: targets.targetWeight ?? null,
  targetReps: targets.targetReps ?? null,
  targetRepsMax: targets.targetRepsMax ?? null,
  targetDurationSeconds: targets.targetDurationSeconds ?? null,
  restSeconds: targets.restSeconds ?? 0,
  targetRpe: targets.targetRpe,
  optional: targets.optional,
  cue,
});

const repeated = (
  prefix: string,
  count: number,
  make: (index: number) => PlannedStep,
) => Array.from({ length: count }, (_, index) => make(index + 1));

function fullMobility(prefix: string): PlannedStep[] {
  return [
    ...repeated(`${prefix}-ankle`, 2, (setNumber) =>
      step(
        `${prefix}-ankle-${setNumber}`,
        "Knee-to-wall ankle rocks",
        "Mobility",
        `Set ${setNumber} of 2 · each side`,
        "reps",
        { targetReps: 10 },
        "Use controlled ankle travel; keep the heel down.",
      ),
    ),
    ...repeated(`${prefix}-squat-hold`, 2, (setNumber) =>
      step(
        `${prefix}-squat-hold-${setNumber}`,
        "Supported squat hold",
        "Mobility",
        `Hold ${setNumber} of 2`,
        "duration",
        { targetDurationSeconds: 45 },
        "Hold a rack or post. Elevate heels when needed; do not force depth.",
      ),
    ),
    ...repeated(`${prefix}-goblet`, 2, (setNumber) =>
      step(
        `${prefix}-goblet-${setNumber}`,
        "Light goblet squat",
        "Mobility",
        `Set ${setNumber} of 2`,
        "weight-reps",
        { targetReps: 6 },
        "Use a slow descent and control the available range.",
      ),
    ),
    ...repeated(`${prefix}-9090`, 2, (setNumber) =>
      step(
        `${prefix}-9090-${setNumber}`,
        "90/90 hip switches",
        "Mobility",
        `Set ${setNumber} of 2 · each side`,
        "reps",
        { targetReps: 6 },
        "Move through hip rotation without forcing the knees.",
      ),
    ),
    step(
      `${prefix}-hip-flexor`,
      "Half-kneeling hip-flexor stretch",
      "Mobility",
      "1 hold per side",
      "duration",
      { targetDurationSeconds: 90 },
      "Use 45 seconds per side without arching the lower back.",
    ),
    ...repeated(`${prefix}-wall-slide`, 2, (setNumber) =>
      step(
        `${prefix}-wall-slide-${setNumber}`,
        "Wall slides",
        "Mobility",
        `Set ${setNumber} of 2`,
        "reps",
        { targetReps: 8 },
        "Move smoothly through a comfortable shoulder range.",
      ),
    ),
    step(
      `${prefix}-lat-stretch`,
      "Bench lat stretch",
      "Mobility",
      "1 hold",
      "duration",
      { targetDurationSeconds: 45 },
      "Keep the ribs controlled while reaching overhead.",
    ),
    step(
      `${prefix}-pec-stretch`,
      "Doorway pec stretch",
      "Mobility",
      "1 hold per side",
      "duration",
      { targetDurationSeconds: 90 },
      "Use 30–45 seconds per side; stop for sharp or radiating pain.",
    ),
  ];
}

function upperSteps(prefix: string, includePullUpTest: boolean): PlannedStep[] {
  const preparation = [
    step(
      `${prefix}-prep-cardio`,
      "Easy treadmill, bike or rower",
      "Preparation",
      "General preparation · 1 of 4",
      "duration",
      { targetDurationSeconds: 180 },
      "Use an easy pace for 2–3 minutes.",
    ),
    step(
      `${prefix}-prep-circles`,
      "Arm circles",
      "Preparation",
      "General preparation · 2 of 4",
      "reps",
      { targetReps: 20 },
      "Complete 10 forward and 10 backward.",
    ),
    step(
      `${prefix}-prep-wall-slides`,
      "Wall slides",
      "Preparation",
      "General preparation · 3 of 4",
      "reps",
      { targetReps: 8 },
      "Stay controlled through a comfortable range.",
    ),
    step(
      `${prefix}-prep-scapular`,
      "Very light scapular pulldown",
      "Preparation",
      "General preparation · 4 of 4",
      "weight-reps",
      { targetReps: 10 },
      "Move the shoulder blades without turning this into a working set.",
    ),
  ];

  const bench = [
    step(
      `${prefix}-bench-warmup-1`,
      "Bench press",
      "Warm-up",
      "20 kg bar · ramp 1 of 3",
      "weight-reps",
      { targetWeight: 20, targetReps: 10, restSeconds: 60 },
      "Set shoulder blades and repeat the same touch point.",
    ),
    step(
      `${prefix}-bench-warmup-2`,
      "Bench press",
      "Warm-up",
      "40 kg · ramp 2 of 3",
      "weight-reps",
      { targetWeight: 40, targetReps: 5, restSeconds: 60 },
      "Keep the setup identical to the working sets.",
    ),
    step(
      `${prefix}-bench-warmup-3`,
      "Bench press",
      "Warm-up",
      "55 kg · ramp 3 of 3",
      "weight-reps",
      { targetWeight: 55, targetReps: 3, targetRepsMax: 3, restSeconds: 90 },
      "Use 2–3 clean repetitions; warm up without accumulating fatigue.",
    ),
    ...repeated(`${prefix}-bench-working`, 3, (setNumber) =>
      step(
        `${prefix}-bench-working-${setNumber}`,
        "Bench press",
        "Working",
        `Working set ${setNumber} of 3`,
        "weight-reps",
        {
          targetWeight: 65,
          targetReps: 5,
          targetRepsMax: 8,
          restSeconds: 180,
          targetRpe: 8,
        },
        "Keep 2–3 reps in reserve in Weeks 1–2; do not train to failure.",
      ),
    ),
  ];

  const pullUpTest = includePullUpTest
    ? [
        step(
          `${prefix}-pullup-test`,
          "Strict pull-up checkpoint",
          "Check",
          "One test before pulldowns",
          "reps",
          { targetReps: 1, optional: true },
          "Attempt one clean strict pull-up only. Do not repeat-test.",
        ),
      ]
    : [];

  return [
    ...preparation,
    ...bench,
    ...pullUpTest,
    step(
      `${prefix}-pulldown-warmup`,
      "Lat pulldown",
      "Warm-up",
      "1 light set",
      "weight-reps",
      { targetReps: 8, restSeconds: 60 },
      "Use a comfortable neutral or shoulder-width grip.",
    ),
    ...repeated(`${prefix}-pulldown-working`, 3, (setNumber) =>
      step(
        `${prefix}-pulldown-working-${setNumber}`,
        "Lat pulldown",
        "Working",
        `Working set ${setNumber} of 3`,
        "weight-reps",
        { targetReps: 6, targetRepsMax: 10, restSeconds: 120, targetRpe: 8 },
        "Lead with the elbows; do not shorten the range.",
      ),
    ),
    step(
      `${prefix}-press-warmup`,
      "Machine or DB shoulder press",
      "Warm-up",
      "1 light set",
      "weight-reps",
      { targetReps: 6, targetRepsMax: 8, restSeconds: 60 },
      "Choose a machine or neutral-grip dumbbells; do not force a barbell position.",
    ),
    ...repeated(`${prefix}-press-working`, 2, (setNumber) =>
      step(
        `${prefix}-press-working-${setNumber}`,
        "Machine or DB shoulder press",
        "Working",
        `Working set ${setNumber} of 2`,
        "weight-reps",
        { targetReps: 6, targetRepsMax: 10, restSeconds: 120, targetRpe: 8 },
        "Protect technique and shoulder comfort.",
      ),
    ),
    step(
      `${prefix}-row-warmup`,
      "Chest-supported or cable row",
      "Warm-up",
      "Optional light set",
      "weight-reps",
      { targetReps: 8, restSeconds: 60, optional: true },
      "Use this familiarisation set only if needed.",
    ),
    ...repeated(`${prefix}-row-working`, 3, (setNumber) =>
      step(
        `${prefix}-row-working-${setNumber}`,
        "Chest-supported or cable row",
        "Working",
        `Working set ${setNumber} of 3`,
        "weight-reps",
        { targetReps: 8, targetRepsMax: 12, restSeconds: 120, targetRpe: 8 },
        "Row without using lower-back momentum.",
      ),
    ),
    ...repeated(`${prefix}-ab-wheel`, 2, (setNumber) =>
      step(
        `${prefix}-ab-wheel-${setNumber}`,
        "Ab wheel from knees",
        "Working",
        `Working set ${setNumber} of 2`,
        "reps",
        { targetReps: 6, targetRepsMax: 12, restSeconds: 90 },
        "Stop before the lower back sags or arches.",
      ),
    ),
    ...repeated(`${prefix}-farmer`, 2, (setNumber) =>
      step(
        `${prefix}-farmer-${setNumber}`,
        "Farmer carry",
        "Working",
        `Carry ${setNumber} of 2`,
        "weight-duration",
        { targetDurationSeconds: 30, restSeconds: 120 },
        "Stay tall; avoid leaning or excessive shrugging. Build toward 45 seconds.",
      ),
    ),
    step(
      `${prefix}-pec-stretch`,
      "Doorway pec stretch",
      "Cooldown",
      "1 hold per side",
      "duration",
      { targetDurationSeconds: 90 },
      "Use 30–45 seconds per side.",
    ),
    step(
      `${prefix}-lat-stretch`,
      "Bench lat stretch",
      "Cooldown",
      "1 hold",
      "duration",
      { targetDurationSeconds: 45 },
      "Keep the ribs controlled.",
    ),
    step(
      `${prefix}-open-book`,
      "Open-book rotation",
      "Cooldown",
      "Optional · each side",
      "reps",
      { targetReps: 5, optional: true },
      "Use only if it feels useful; do not force range.",
    ),
  ];
}

function lowerSteps(weekNumber: number): PlannedStep[] {
  const rdlSets = weekNumber <= 2 ? 2 : 3;
  return [
    step(
      "lower-prep-cardio",
      "Easy bike or treadmill",
      "Preparation",
      "General preparation · 1 of 5",
      "duration",
      { targetDurationSeconds: 180 },
      "Use an easy pace for 3 minutes.",
    ),
    step(
      "lower-prep-ankle",
      "Knee-to-wall ankle rocks",
      "Preparation",
      "General preparation · 2 of 5 · each side",
      "reps",
      { targetReps: 10 },
      "Keep the heel down and movement controlled.",
    ),
    step(
      "lower-prep-squat",
      "Supported squat repetitions",
      "Preparation",
      "General preparation · 3 of 5",
      "reps",
      { targetReps: 5 },
      "Use a short pause and heel elevation when needed.",
    ),
    step(
      "lower-prep-goblet",
      "Light goblet squat",
      "Preparation",
      "General preparation · 4 of 5",
      "weight-reps",
      { targetReps: 6, targetRepsMax: 8 },
      "Elevate the heels when needed.",
    ),
    step(
      "lower-prep-hinge",
      "Unloaded hip hinges",
      "Preparation",
      "General preparation · 5 of 5",
      "reps",
      { targetReps: 8 },
      "Push the hips back while keeping a small knee bend.",
    ),
    step(
      "lower-squat-warmup-1",
      "Hack squat or leg press",
      "Warm-up",
      "Light × 10 · ramp 1 of 3",
      "weight-reps",
      { targetReps: 10, restSeconds: 60 },
      "Keep the same chosen machine and repeatable depth for the full block.",
    ),
    step(
      "lower-squat-warmup-2",
      "Hack squat or leg press",
      "Warm-up",
      "About 50% × 5 · ramp 2 of 3",
      "weight-reps",
      { targetReps: 5, restSeconds: 60 },
      "Warm up without turning this into a working set.",
    ),
    step(
      "lower-squat-warmup-3",
      "Hack squat or leg press",
      "Warm-up",
      "About 70% × 3 · ramp 3 of 3",
      "weight-reps",
      { targetReps: 3, restSeconds: 90 },
      "Repeat the working-set stance and depth.",
    ),
    ...repeated("lower-squat-working", 3, (setNumber) =>
      step(
        `lower-squat-working-${setNumber}`,
        "Hack squat or leg press",
        "Working",
        `Working set ${setNumber} of 3`,
        "weight-reps",
        { targetReps: 6, targetRepsMax: 10, restSeconds: 180, targetRpe: 8 },
        "Do not train to failure; keep depth repeatable.",
      ),
    ),
    step(
      "lower-rdl-warmup-1",
      "Romanian deadlift",
      "Warm-up",
      "Bar × 8 · ramp 1 of 2",
      "weight-reps",
      { targetWeight: 20, targetReps: 8, restSeconds: 60 },
      "Push hips backward and keep the bar close.",
    ),
    step(
      "lower-rdl-warmup-2",
      "Romanian deadlift",
      "Warm-up",
      "50–60% × 5 · ramp 2 of 2",
      "weight-reps",
      { targetReps: 5, restSeconds: 90 },
      "Stop when further descent would require spinal movement.",
    ),
    ...repeated("lower-rdl-working", rdlSets, (setNumber) =>
      step(
        `lower-rdl-working-${setNumber}`,
        "Romanian deadlift",
        "Working",
        setNumber === 3
          ? "Conditional working set 3 of 3"
          : `Working set ${setNumber} of ${rdlSets}`,
        "weight-reps",
        {
          targetReps: 6,
          targetRepsMax: 10,
          restSeconds: 180,
          targetRpe: 8,
          optional: setNumber === 3,
        },
        setNumber === 3
          ? "Complete only when technique is stable and lower-back fatigue is reasonable."
          : "Keep the hinge in hamstrings and glutes; never train this to failure.",
      ),
    ),
    step(
      "lower-bulgarian-warmup",
      "Supported Bulgarian split squat",
      "Warm-up",
      "Bodyweight or light × 5 per leg",
      "weight-reps",
      { targetReps: 5, restSeconds: 60 },
      "Use support so balance does not limit the legs.",
    ),
    ...repeated("lower-bulgarian-working", 2, (setNumber) =>
      step(
        `lower-bulgarian-working-${setNumber}`,
        "Supported Bulgarian split squat",
        "Working",
        `Working set ${setNumber} of 2 · per leg`,
        "weight-reps",
        { targetReps: 8, targetRepsMax: 12, restSeconds: 150, targetRpe: 8 },
        "Keep 1–2 reps in reserve and let the legs, not balance, limit the set.",
      ),
    ),
    step(
      "lower-curl-warmup",
      "Lying leg curl",
      "Warm-up",
      "1 light set",
      "weight-reps",
      { targetReps: 8, targetRepsMax: 10, restSeconds: 60 },
      "Use a controlled eccentric.",
    ),
    ...repeated("lower-curl-working", 2, (setNumber) =>
      step(
        `lower-curl-working-${setNumber}`,
        "Lying leg curl",
        "Working",
        `Working set ${setNumber} of 2`,
        "weight-reps",
        { targetReps: 10, targetRepsMax: 15, restSeconds: 90, targetRpe: 8 },
        "Control the return; do not shorten range.",
      ),
    ),
    step(
      "lower-calf-warmup",
      "Standing calf raise",
      "Warm-up",
      "Bodyweight × 10",
      "reps",
      { targetReps: 10, restSeconds: 60 },
      "Use a Smith machine, single-leg dumbbell raise, or straight-knee leg-press calf press.",
    ),
    ...repeated("lower-calf-working", 3, (setNumber) =>
      step(
        `lower-calf-working-${setNumber}`,
        "Standing calf raise",
        "Working",
        `Working set ${setNumber} of 3`,
        "weight-reps",
        { targetReps: 10, targetRepsMax: 20, restSeconds: 90, targetRpe: 8 },
        "Control the descent, pause in the stretch, rise fully, and do not bounce.",
      ),
    ),
    step(
      "lower-cooldown-calf-straight",
      "Straight-knee calf stretch",
      "Cooldown",
      "1 hold per side",
      "duration",
      { targetDurationSeconds: 90 },
      "Use 30–45 seconds per side.",
    ),
    step(
      "lower-cooldown-calf-bent",
      "Bent-knee calf stretch",
      "Cooldown",
      "1 hold per side",
      "duration",
      { targetDurationSeconds: 90 },
      "Use 30–45 seconds per side.",
    ),
    step(
      "lower-cooldown-hip",
      "Half-kneeling hip-flexor stretch",
      "Cooldown",
      "1 hold per side",
      "duration",
      { targetDurationSeconds: 90 },
      "Avoid arching the lower back.",
    ),
  ];
}

function hardCardioSteps(weekNumber: number): PlannedStep[] {
  const rounds = weekNumber <= 2 ? 4 : 5;
  return [
    step(
      "hard-cardio-warmup",
      "Bike or elliptical",
      "Cardio",
      "Easy warm-up",
      "duration",
      { targetDurationSeconds: 480 },
      "Use 7–8 easy minutes after the full Upper session.",
    ),
    ...Array.from({ length: rounds }, (_, index) => {
      const round = index + 1;
      return [
        step(
          `hard-cardio-${round}`,
          "Controlled hard interval",
          "Cardio",
          `Hard round ${round} of ${rounds}`,
          "duration",
          { targetDurationSeconds: 120 },
          "Use 8/10 effort: demanding and controlled, never all-out.",
        ),
        step(
          `hard-cardio-recovery-${round}`,
          "Easy interval recovery",
          "Cardio",
          `Easy recovery ${round} of ${rounds}`,
          "duration",
          { targetDurationSeconds: 180 },
          "Recover at an easy pace for 3 minutes.",
        ),
      ];
    }).flat(),
    step(
      "hard-cardio-cooldown",
      "Bike or elliptical cooldown",
      "Cooldown",
      "Easy cooldown",
      "duration",
      { targetDurationSeconds: 300 },
      "Finish with 5 easy minutes.",
    ),
  ];
}

const easyCardio = [
  step(
    "easy-cardio-warmup",
    "Easy cardio",
    "Cardio",
    "Very easy start · 1 of 3",
    "duration",
    { targetDurationSeconds: 300 },
    "Use treadmill walking, incline walking, bike, or elliptical.",
  ),
  step(
    "easy-cardio-main",
    "Conversational cardio",
    "Cardio",
    "Aerobic work · 2 of 3",
    "duration",
    { targetDurationSeconds: 2100 },
    "Stay around 3–4/10; full sentences should remain possible.",
  ),
  step(
    "easy-cardio-cooldown",
    "Easy cardio cooldown",
    "Cooldown",
    "Easy finish · 3 of 3",
    "duration",
    { targetDurationSeconds: 300 },
    "Finish fresh; do not turn the session into a race.",
  ),
];

export const LEGACY_UPPER_STEPS: PlannedStep[] = [
  ...[
    [20, 15, 45],
    [40, 10, 60],
    [60, 3, 120],
  ].map(([weight, reps, rest], index) =>
    step(
      `bench-warmup-${index + 1}`,
      "Bench press",
      "Warm-up",
      `Warm-up ${index + 1} of 3`,
      "weight-reps",
      { targetWeight: weight, targetReps: reps, restSeconds: rest },
      "Legacy sample session.",
    ),
  ),
  ...repeated("legacy-bench", 3, (setNumber) =>
    step(
      `bench-working-${setNumber}`,
      "Bench press",
      "Working",
      `Working set ${setNumber} of 3`,
      "weight-reps",
      { targetWeight: 70, targetReps: 5, restSeconds: 180, targetRpe: 8 },
      "Legacy sample session.",
    ),
  ),
  ...repeated("legacy-pulldown", 3, (setNumber) =>
    step(
      `pulldown-${setNumber}`,
      "Lat pulldown",
      "Working",
      `Working set ${setNumber} of 3`,
      "weight-reps",
      { targetWeight: 55, targetReps: 10, restSeconds: 90, targetRpe: 8 },
      "Legacy sample session.",
    ),
  ),
  ...repeated("legacy-row", 3, (setNumber) =>
    step(
      `row-${setNumber}`,
      "Seated cable row",
      "Working",
      `Working set ${setNumber} of 3`,
      "weight-reps",
      {
        targetWeight: 50,
        targetReps: 12,
        restSeconds: setNumber === 3 ? 0 : 90,
        targetRpe: 8,
      },
      "Legacy sample session.",
    ),
  ),
];

export function resolveWorkout(
  workoutId: WorkoutId,
  weekNumber: number,
  dayIndex = 0,
): WorkoutTemplate {
  const week = Math.min(12, Math.max(1, Math.trunc(weekNumber)));
  if (workoutId === "legacy-upper-a") {
    return {
      id: workoutId,
      name: "Upper A · legacy sample",
      scheduleName: "Legacy Upper A",
      expectedMinutes: 60,
      steps: LEGACY_UPPER_STEPS,
      notes: ["Finish this restored session in its original order."],
    };
  }
  if (workoutId === "upper" || workoutId === "upper-hard") {
    const pullUpTest =
      (dayIndex === 0 && (week === 5 || week === 9)) || (dayIndex === 3 && week === 12);
    const steps = upperSteps("upper", pullUpTest);
    const hard = workoutId === "upper-hard" ? hardCardioSteps(week) : [];
    return {
      id: workoutId,
      name: workoutId === "upper-hard" ? "Upper + hard cardio" : "Upper",
      scheduleName: workoutId === "upper-hard" ? "Upper + hard" : "Upper",
      expectedMinutes: workoutId === "upper-hard" ? 105 : 65,
      steps: [...steps, ...hard],
      notes: [
        "Bench begins at 65 kg for 3 × 5–8. Add load only after 3 × 8 is clean.",
        "Weeks 1–2: keep 2–3 reps in reserve. Thereafter use 1–2 on compounds.",
        ...(week >= 5
          ? ["Optional lateral raises remain excluded unless recovery and shoulders are clearly good."]
          : []),
      ],
    };
  }
  if (workoutId === "lower") {
    return {
      id: workoutId,
      name: "Lower",
      scheduleName: "Lower",
      expectedMinutes: 70,
      steps: lowerSteps(week),
      notes: [
        "Choose hack squat or leg press once and keep it for all 12 weeks.",
        week <= 2
          ? "Weeks 1–2 use exactly two RDL working sets."
          : "The third RDL set is conditional on stable technique and reasonable lower-back fatigue.",
      ],
    };
  }
  if (workoutId === "easy-mobility") {
    return {
      id: workoutId,
      name: "Easy cardio + full mobility",
      scheduleName: "Easy + mobility",
      expectedMinutes: 60,
      steps: [...easyCardio, ...fullMobility("full")],
      notes: [
        "Start around the existing 5 km/h baseline when walking.",
        "Increase speed or incline only after two comfortable weeks.",
      ],
    };
  }
  return {
    id: workoutId,
    name: "Full mobility",
    scheduleName: "Mobility",
    expectedMinutes: 15,
    steps: fullMobility("friday"),
    notes: [
      "An optional 20–40 minute walk is allowed only when recovery is good.",
      "Sharp pain, radiating symptoms, or worsening back pain are stop signals.",
    ],
  };
}

export type ProgrammePosition = {
  weekNumber: number;
  dayIndex: number;
  inBlock: boolean;
  beforeBlock: boolean;
  afterBlock: boolean;
  schedule: ScheduleEntry;
  workout: WorkoutTemplate;
};

export function getProgrammePosition(date: Date): ProgrammePosition {
  const start = new Date(2026, 6, 27);
  start.setHours(0, 0, 0, 0);
  const localDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const offset = Math.floor((localDate.getTime() - start.getTime()) / 86_400_000);
  const beforeBlock = offset < 0;
  const afterBlock = offset >= 84;
  const boundedOffset = Math.min(83, Math.max(0, offset));
  const weekNumber = Math.floor(boundedOffset / 7) + 1;
  const dayIndex = boundedOffset % 7;
  const schedule = PROGRAMME_SCHEDULE[dayIndex];
  return {
    weekNumber,
    dayIndex,
    inBlock: !beforeBlock && !afterBlock,
    beforeBlock,
    afterBlock,
    schedule,
    workout: resolveWorkout(schedule.workoutId, weekNumber, dayIndex),
  };
}

export function formatStepTarget(planned: PlannedStep): string {
  const reps =
    planned.targetReps === null
      ? ""
      : planned.targetRepsMax && planned.targetRepsMax !== planned.targetReps
        ? `${planned.targetReps}–${planned.targetRepsMax} reps`
        : `${planned.targetReps} reps`;
  const duration =
    planned.targetDurationSeconds === null
      ? ""
      : planned.targetDurationSeconds >= 60 &&
          planned.targetDurationSeconds % 60 === 0
        ? `${planned.targetDurationSeconds / 60} min`
        : `${planned.targetDurationSeconds} sec`;
  if (planned.tracking === "weight-reps") {
    return `${planned.targetWeight === null ? "Choose load" : `${planned.targetWeight} kg`} · ${reps}`;
  }
  if (planned.tracking === "weight-duration") {
    return `${planned.targetWeight === null ? "Choose load" : `${planned.targetWeight} kg`} · ${duration}`;
  }
  if (planned.tracking === "reps") return reps;
  if (planned.tracking === "duration") return duration;
  return "Complete";
}
