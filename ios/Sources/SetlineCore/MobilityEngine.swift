import Foundation

/// Derives the curriculum view: per-card rollups, coverage, next checkpoints,
/// and the practise-selection cap. Pure functions over `MobilityState` —
/// no scores, no normative comparisons.
public enum MobilityEngine {
    /// The practise-selection cap from the programme design: assess all 15
    /// cards, then practise three or four — not the whole library at once.
    public static let maxPractising = 4

    /// Proposed retest cadence, surfaced as guidance only. This is a product
    /// choice, not a validated clinical rule.
    public static let suggestedRetestInterval: TimeInterval = 14 * 86_400

    /// Per-card rollup for list rows and detail headers.
    public struct CardSummary: Equatable, Sendable {
        /// Result slots with any recorded outcome.
        public var recorded: Int = 0
        /// Total result slots (checks × sides where per-side).
        public var total: Int = 0
        /// Slots recorded as completed as shown.
        public var demonstrated: Int = 0
        /// Slots stopped by symptoms — always surfaced, never scored as zero.
        public var symptomBlocked: Int = 0
        /// Slots the user was unsure about.
        public var unsure: Int = 0

        public init() {}

        public var hasBaseline: Bool { recorded > 0 }
        public var isFullyRecorded: Bool { total > 0 && recorded == total }
    }

    /// Every result slot key a card defines, expanding per-side checks.
    public static func slotKeys(for card: MobilityCardDefinition) -> [String] {
        card.checks.flatMap { check in
            check.perSide
                ? [BodySide.left, BodySide.right].map {
                    MobilityCardState.key(checkID: check.id, side: $0)
                }
                : [MobilityCardState.key(checkID: check.id, side: nil)]
        }
    }

    /// Rolls up one card's recorded state.
    public static func summary(for card: MobilityCardDefinition, in state: MobilityState) -> CardSummary {
        var summary = CardSummary()
        summary.total = slotKeys(for: card).count
        let cardState = state.cards[card.id] ?? .init()
        for slot in slotKeys(for: card) {
            guard let record = cardState.results[slot], record.isRecorded else { continue }
            summary.recorded += 1
            switch record.status {
            case .completedAsShown, .modifiedOrAssisted:
                summary.demonstrated += 1
            case .symptomBlocked:
                summary.symptomBlocked += 1
            case .unsure:
                summary.unsure += 1
            case .notTested, .notYet, .notApplicable:
                break
            }
        }
        return summary
    }

    /// Head-to-toe coverage across the 15 assessment cards (functional
    /// benchmarks are optional and excluded).
    public static func coverage(in state: MobilityState) -> (recorded: Int, total: Int, cardsStarted: Int) {
        var recorded = 0
        var total = 0
        var started = 0
        for card in MobilityCatalog.cards {
            let summary = summary(for: card, in: state)
            recorded += summary.recorded
            total += summary.total
            if summary.hasBaseline { started += 1 }
        }
        return (recorded, total, started)
    }

    /// The next thing to practise on a card. A card with no baseline starts at
    /// its easy entry; once something is recorded the first progression option
    /// is the next personal checkpoint — within the same setup, never a
    /// redefined task.
    public static func nextCheckpoint(for card: MobilityCardDefinition, in state: MobilityState) -> String {
        let summary = summary(for: card, in: state)
        if !summary.hasBaseline {
            return card.easyPractice
        }
        return card.progressionOptions.first ?? card.easyPractice
    }

    /// Two records belong to the same measurement series only when the setup
    /// text matches. A different chair height, arm position, or stance is a
    /// different measurement — not comparable improvement.
    public static func sameSeries(_ a: MobilityCheckRecord, _ b: MobilityCheckRecord) -> Bool {
        a.setup.trimmingCharacters(in: .whitespacesAndNewlines)
            == b.setup.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The most recent prior record for a slot that used the same setup as the
    /// current record — the only honest comparison point.
    public static func previousSameSetup(
        cardID: String,
        slot: String,
        in state: MobilityState
    ) -> MobilityCheckRecord? {
        guard let cardState = state.cards[cardID],
              let current = cardState.results[slot] else { return nil }
        return cardState.superseded[slot]?.first { sameSeries($0, current) }
    }

    /// Whether a card can join the practise set.
    public static func canPractise(_ cardID: String, in state: MobilityState) -> Bool {
        state.practising.contains(cardID) || state.practising.count < maxPractising
    }

    /// When a retest is suggested, based on the most recent card update.
    /// Returns nil until anything has been recorded.
    public static func retestDueDate(in state: MobilityState) -> Date? {
        state.updated.values.max()?.addingTimeInterval(suggestedRetestInterval)
    }

    /// Practice catalogue entries for a card, resolved to definitions.
    public static func practiceExercises(for card: MobilityCardDefinition) -> [ExerciseDefinition] {
        card.practiceSlugs.compactMap { ExerciseCatalogue.definition(slug: $0) }
    }

    /// A workout template built from the current practice set: each selected
    /// card contributes its entry-point exercise (the first practice slug),
    /// in the user's selection order. Returns nil when nothing is selected or
    /// no card resolves to a practice movement.
    ///
    /// The template is derived, never stored — change the practice set and the
    /// next session reflects it. Sets are authored as mobility work, so they
    /// deliberately do not count as working sets for strength metrics.
    public static func practiceTemplate(in state: MobilityState) -> WorkoutTemplate? {
        let cards = state.practising.compactMap { MobilityCatalog.card(for: $0) }
        guard !cards.isEmpty else { return nil }
        let exercises = cards.compactMap { card -> Exercise? in
            guard let slug = card.practiceSlugs.first,
                  let definition = ExerciseCatalogue.definition(slug: slug) else { return nil }
            let set = PlannedSet(
                label: "Practice",
                kind: .mobility,
                target: SetTarget(
                    repTarget: .init(repsLow: 8),
                    perSide: definition.isUnilateral
                ),
                rest: definition.defaultRest,
                config: .init(stepType: .mobility)
            )
            return Exercise(
                name: definition.name,
                cue: definition.cue.isEmpty ? card.easyPractice : definition.cue,
                sets: [set, set],
                definitionSlug: definition.slug,
                pillars: definition.pillars
            )
        }
        guard !exercises.isEmpty else { return nil }
        return WorkoutTemplate(
            name: "Mobility practice",
            detail: "Entry-point practice for the cards you selected",
            isBundled: false,
            exercises: exercises,
            notes: ["Built from your mobility practice set. Practise the demonstrated range; do not chase extra range."],
            expectedMinutes: nil
        )
    }
}
