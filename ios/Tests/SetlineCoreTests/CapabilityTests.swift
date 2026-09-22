import XCTest
@testable import SetlineCore

final class CapabilityTests: XCTestCase {
    // MARK: - Catalogue

    func testEveryAxisHasAssessments() {
        for axis in AbilityAxis.allCases {
            XCTAssertFalse(
                CapabilityAssessmentCatalog.assessments(for: axis).isEmpty,
                "\(axis) has no assessments"
            )
        }
        // Mobility contributes the whole catalogue: 15 cards + 2 benchmarks.
        XCTAssertEqual(CapabilityAssessmentCatalog.assessments(for: .mobility).count, 17)
    }

    func testAssessmentIDsAreUnique() {
        let ids = CapabilityAssessmentCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryAssessmentSourceResolves() {
        for assessment in CapabilityAssessmentCatalog.all {
            switch assessment.source {
            case let .benchmark(id):
                XCTAssertNotNil(BenchmarkCatalog.metric(for: id), "\(assessment.id) missing benchmark \(id)")
            case let .mobilityCard(id):
                XCTAssertNotNil(MobilityCatalog.card(for: id), "\(assessment.id) missing card \(id)")
            case let .loggedMetric(exercise, _):
                XCTAssertNotNil(ExerciseCatalogue.match(name: exercise), "\(assessment.id) missing exercise \(exercise)")
            }
            XCTAssertFalse(assessment.passingCriteria.isEmpty)
            XCTAssertFalse(assessment.easierVariation.isEmpty)
            XCTAssertFalse(assessment.nextProgression.isEmpty)
        }
    }

    // MARK: - Evidence kinds

    func testFreshDocumentLeavesEveryAxisUnassessed() {
        let document = SetlineDocument.initial
        for axis in AbilityAxis.allCases {
            let score = CapabilityEngine.axisScore(axis, in: document)
            XCTAssertEqual(score.assessed, 0)
            XCTAssertEqual(score.score, 0)
            XCTAssertNil(score.lastVerified)
        }
        let plan = CapabilityEngine.plan(in: document)
        XCTAssertTrue(plan.axes.allSatisfy { $0.status == .unassessed })
        // Baselines still get selected — an unassessed axis is a priority to
        // assess, not a scored failure.
        XCTAssertEqual(plan.priorities.count, 2)
    }

    func testRecordedBenchmarkResultIsMeasuredEvidence() {
        var document = SetlineDocument.initial
        document.benchmarks.metrics["pullups"] = .init(numbers: ["reps": 16])
        let result = CapabilityEngine.resolve(
            CapabilityAssessmentCatalog.assessment(for: "S-pullups")!,
            in: document
        )
        XCTAssertEqual(result.evidence.kind, .measured)
        XCTAssertEqual(result.evidence.value, 16)
        XCTAssertTrue(result.isPassed, "16 clean reps meets the default 15-rep target")
    }

    func testReportedBenchmarkResultIsSelfReportedEvidence() {
        var document = SetlineDocument.initial
        document.benchmarks.metrics["pullups"] = .init(numbers: ["reps": 20], reported: true)
        let result = CapabilityEngine.resolve(
            CapabilityAssessmentCatalog.assessment(for: "S-pullups")!,
            in: document
        )
        XCTAssertEqual(result.evidence.kind, .selfReported)
        XCTAssertTrue(result.isPassed)
    }

    func testLoggedPerformanceUnlocksSingleCriterionMilestone() {
        var document = SetlineDocument.initial
        document.history = [TestSessionFactory.makeSession(steps: [
            TestSessionFactory.makeStep(exerciseName: "Strict pull-up", reps: 16)
        ])]
        let result = CapabilityEngine.resolve(
            CapabilityAssessmentCatalog.assessment(for: "S-pullups")!,
            in: document
        )
        XCTAssertEqual(result.evidence.kind, .measured)
        XCTAssertTrue(result.isPassed, "A logged 16-rep pull-up set unlocks the milestone directly")
        XCTAssertTrue(result.evidence.provenance?.contains("Strict pull-up") ?? false)
    }

    func testLoggedDistanceDoesNotUnlockPairedCriterion() {
        var document = SetlineDocument.initial
        document.history = [TestSessionFactory.makeSession(steps: [
            TestSessionFactory.makeRunStep(distanceKm: 12)
        ])]
        let result = CapabilityEngine.resolve(
            CapabilityAssessmentCatalog.assessment(for: "E-run")!,
            in: document
        )
        // A 12 km log is real evidence, but the run checkpoint pairs distance
        // with a time limit — distance alone cannot pass it.
        XCTAssertEqual(result.evidence.kind, .measured)
        XCTAssertEqual(result.evidence.value, 12)
        XCTAssertFalse(result.isPassed)
    }

    // MARK: - Mobility scoring

    func testPartialMobilityCardContributesFractionNotFailure() {
        var document = SetlineDocument.initial
        var cardState = MobilityCardState()
        // M10 has one per-side check: demonstrate left, leave right untested.
        cardState.record(.init(status: .completedAsShown), checkID: "dorsiflexion", side: .left)
        document.mobility.cards["M10"] = cardState

        let result = CapabilityEngine.resolve(
            CapabilityAssessmentCatalog.assessment(for: "M10")!,
            in: document
        )
        XCTAssertEqual(result.evidence.kind, .measured)
        XCTAssertEqual(result.fraction, 0.5)
        XCTAssertFalse(result.isPassed, "Half-demonstrated is progress, not a pass or a zero")
    }

    func testSymptomBlockedCardIsAssessedButNotPassed() {
        var document = SetlineDocument.initial
        var cardState = MobilityCardState()
        cardState.record(.init(status: .symptomBlocked), checkID: "dorsiflexion", side: .left)
        cardState.record(.init(status: .completedAsShown), checkID: "dorsiflexion", side: .right)
        document.mobility.cards["M10"] = cardState

        let result = CapabilityEngine.resolve(
            CapabilityAssessmentCatalog.assessment(for: "M10")!,
            in: document
        )
        XCTAssertTrue(result.isAssessed)
        XCTAssertFalse(result.isPassed, "A symptom stop is never silently passed")
    }

    // MARK: - Scoring and coverage

    func testAxisScoreKeepsCoverageVisible() {
        var document = SetlineDocument.initial
        document.benchmarks.metrics["pullups"] = .init(numbers: ["reps": 15])
        let score = CapabilityEngine.axisScore(.strength, in: document)
        XCTAssertEqual(score.assessed, 1)
        XCTAssertEqual(score.total, 4)
        XCTAssertEqual(score.score, 25, "1 of 4 equal-weight checkpoints demonstrated")
        XCTAssertFalse(score.isFullyCovered)
    }

    // MARK: - Prioritization

    func testMaintainWhenEveryCheckpointIsMet() {
        var document = SetlineDocument.initial
        document.benchmarks.metrics["run"] = .init(
            numbers: ["distance": 10],
            texts: ["time": "45:00", "qualifier": "Exact time"],
            flags: ["continuous": true]
        )
        document.benchmarks.metrics["swim"] = .init(
            numbers: ["distance": 400, "tread": 120],
            flags: ["basics": true]
        )
        let plan = CapabilityEngine.plan(in: document)
        let endurance = plan.axes.first { $0.axis == .endurance }
        XCTAssertEqual(endurance?.status, .maintain)
        XCTAssertFalse(plan.priorities.contains(.endurance), "A met curriculum needs no priority slot")
    }

    func testGoalRelevantAxisOutranksLowerScore() {
        var document = SetlineDocument.initial
        // Give strength a pass so it is not the lowest-scored axis, then aim a
        // goal at mobility.
        document.benchmarks.metrics["pullups"] = .init(numbers: ["reps": 15])
        document.goals = [
            ExerciseGoal(exerciseName: "Cat-camel", metric: .maxRepetitions, targetValue: 10)
        ]
        let plan = CapabilityEngine.plan(in: document)
        XCTAssertTrue(plan.priorities.contains(.mobility), "A goal on a mobility exercise makes mobility goal-relevant")
    }

    func testFocusAxisBecomesSpecialize() {
        var document = SetlineDocument.initial
        document.capability.focusAxes = [.mobility]
        let plan = CapabilityEngine.plan(in: document)
        let mobility = plan.axes.first { $0.axis == .mobility }
        XCTAssertEqual(mobility?.status, .specialize)
        XCTAssertEqual(mobility?.priorityRank, 1, "A selected focus outranks everything")
    }

    func testPrioritiesNeverExceedTwo() {
        var document = SetlineDocument.initial
        document.goals = [
            ExerciseGoal(exerciseName: "Bench press", metric: .estimatedOneRepMax, targetValue: 100),
            ExerciseGoal(exerciseName: "Run", metric: .longestDistanceMetres, targetValue: 10_000),
            ExerciseGoal(exerciseName: "Cat-camel", metric: .maxRepetitions, targetValue: 10),
        ]
        document.capability.focusAxes = [.balanceControl]
        let plan = CapabilityEngine.plan(in: document)
        XCTAssertLessThanOrEqual(plan.priorities.count, 2)
        XCTAssertEqual(plan.priorities.first, .balanceControl)
    }

    // MARK: - Pain blocking

    func testPainReportBlocksProgressionAndMarksResult() {
        var document = SetlineDocument.initial
        document.capability.painReports["S-pullups"] = .now
        let result = CapabilityEngine.resolve(
            CapabilityAssessmentCatalog.assessment(for: "S-pullups")!,
            in: document
        )
        XCTAssertTrue(result.isPainBlocked)
        // The axis template must not include the painful movement.
        let template = CapabilityEngine.axisTemplate(.strength, in: document)
        XCTAssertFalse(template?.exercises.contains { $0.definitionSlug == "pull-up" } ?? true)
    }

    // MARK: - Sessions and programmes

    func testAxisTemplateUsesUnmetCheckpoints() {
        let document = SetlineDocument.initial
        let template = CapabilityEngine.axisTemplate(.strength, in: document)
        XCTAssertEqual(template?.name, "Strength practice")
        XCTAssertEqual(template?.exercises.count, 4, "All four strength checkpoints are unmet")
        XCTAssertEqual(template?.exercises.first?.definitionSlug, "pull-up")
    }

    func testAxisTemplateExcludesPassedCheckpoints() {
        var document = SetlineDocument.initial
        document.benchmarks.metrics["pullups"] = .init(numbers: ["reps": 15])
        let template = CapabilityEngine.axisTemplate(.strength, in: document)
        XCTAssertEqual(template?.exercises.count, 3)
        XCTAssertFalse(template?.exercises.contains { $0.definitionSlug == "pull-up" } ?? true)
    }

    func testGenerateProgrammeSchedulesWithinDayBudget() {
        var document = SetlineDocument.initial
        document.capability.availableDays = 2
        let generated = CapabilityEngine.generateProgramme(in: document)
        XCTAssertEqual(generated?.templates.count, 2, "Two days means two sessions")
        let programme = generated?.programme
        XCTAssertEqual(programme?.days.count, 7)
        XCTAssertEqual(programme?.days.filter { $0.templateID != nil }.count, 2)
        XCTAssertEqual(programme?.name, "Capability block")
    }

    func testGenerateProgrammeReusesMobilityPracticeSet() {
        var document = SetlineDocument.initial
        document.mobility.practising = ["M10"]
        let generated = CapabilityEngine.generateProgramme(in: document)
        XCTAssertTrue(generated?.templates.contains { $0.name == "Mobility practice" } ?? false)
    }

    // MARK: - Projections

    func testProjectedScoreAddsNextCheckpointOnly() {
        let document = SetlineDocument.initial
        XCTAssertEqual(CapabilityEngine.projectedScore(.strength, in: document), 25, "One of four equal-weight checkpoints")
    }

    func testGoalMarkerTracksGoalRelevantCheckpoints() {
        var document = SetlineDocument.initial
        XCTAssertNil(CapabilityEngine.goalProjectedScore(.strength, in: document))
        document.goals = [
            ExerciseGoal(exerciseName: "Strict pull-up", metric: .maxRepetitions, targetValue: 15)
        ]
        XCTAssertEqual(CapabilityEngine.goalProjectedScore(.strength, in: document), 25)
    }

    func testUserEditedTargetsCannotInflateTheScore() {
        var document = SetlineDocument.initial
        // The user lowers their benchmark target to 1 rep and records 3 — the
        // scorecard reaches it, but the curriculum checkpoint stays fixed at
        // the authored 15.
        document.benchmarks.targets["pullups"] = .init(values: ["reps": 1])
        document.benchmarks.metrics["pullups"] = .init(numbers: ["reps": 3])
        let result = CapabilityEngine.resolve(
            CapabilityAssessmentCatalog.assessment(for: "S-pullups")!,
            in: document
        )
        XCTAssertTrue(BenchmarkEngine.assess("pullups", state: document.benchmarks).reached, "User target is reached")
        XCTAssertFalse(result.isPassed, "Curriculum checkpoint is not")
        XCTAssertEqual(CapabilityEngine.axisScore(.strength, in: document).score, 0)
    }

    // MARK: - Feedback

    func testTooHardRegressesOneVariable() {
        var document = SetlineDocument.initial
        document.capability.feedback["S-pullups"] = .tooHard
        let template = CapabilityEngine.axisTemplate(.strength, in: document)
        let pullups = template?.exercises.first { $0.definitionSlug == "pull-up" }
        XCTAssertEqual(pullups?.sets.first?.target.repsLow, 5, "Too hard drops reps 8 → 5, nothing else")
        XCTAssertEqual(pullups?.cue, "Band-assisted or bodyweight-row practice.", "Easier variation is the cue")
    }

    func testTooEasyPointsAtNextProgression() {
        var document = SetlineDocument.initial
        document.capability.feedback["S-pullups"] = .tooEasy
        let template = CapabilityEngine.axisTemplate(.strength, in: document)
        let pullups = template?.exercises.first { $0.definitionSlug == "pull-up" }
        XCTAssertEqual(pullups?.sets.first?.target.repsLow, 12)
        XCTAssertEqual(pullups?.cue, "More clean reps, then added load.")
    }

    func testMaintainAxisGetsVerificationDate() {
        var document = SetlineDocument.initial
        document.benchmarks.metrics["run"] = .init(
            numbers: ["distance": 10],
            texts: ["time": "45:00", "qualifier": "Exact time"],
            flags: ["continuous": true]
        )
        document.benchmarks.metrics["swim"] = .init(
            numbers: ["distance": 400, "tread": 120],
            flags: ["basics": true]
        )
        document.benchmarks.updated["run"] = Date(timeIntervalSince1970: 1_000_000)
        document.benchmarks.updated["swim"] = Date(timeIntervalSince1970: 1_000_000)
        let plan = CapabilityEngine.plan(in: document)
        let endurance = plan.axes.first { $0.axis == .endurance }
        XCTAssertEqual(endurance?.status, .maintain)
        XCTAssertEqual(
            endurance?.verificationDue?.timeIntervalSince1970,
            1_000_000 + CapabilityEngine.maintenanceVerificationInterval
        )
    }

    // MARK: - Population references

    func testPopulationReferenceDisclosedOrUnavailable() {
        XCTAssertNotNil(PopulationComparisons.reference(for: "M10"), "Knee-to-wall has an exact-protocol reference")
        XCTAssertNil(PopulationComparisons.reference(for: "S-pullups"), "No pull-up dataset → unavailable, never extrapolated")
    }

    // MARK: - Persistence

    func testDocumentDecodesWithoutCapability() throws {
        let document = SetlineDocument.initial
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try JSONSerialization.jsonObject(with: encoder.encode(document)) as! [String: Any]
        json.removeValue(forKey: "capability")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SetlineDocument.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.capability, .initial)
    }
}

// MARK: - Test session factory (mirrors BenchmarkEngineTests)

private enum TestSessionFactory {
    static func makeSession(steps: [WorkoutStep]) -> WorkoutSession {
        WorkoutSession(
            context: .init(
                templateID: UUID(),
                templateName: "Test",
                startedAt: Date(timeIntervalSince1970: 1_000_000),
                completedAt: Date(timeIntervalSince1970: 1_001_000)
            ),
            state: .init(steps: steps)
        )
    }

    static func makeStep(exerciseName: String, weight: Double? = nil, reps: Int? = nil) -> WorkoutStep {
        WorkoutStep(
            exerciseRef: .init(
                plannedSetID: nil,
                exerciseName: exerciseName,
                exerciseSlug: nil,
                cue: "",
                label: "",
                kind: .strength
            ),
            config: .init(target: .init(), authoredPosition: 0, rest: .init(lowSeconds: 60, highSeconds: 90)),
            state: .init(
                status: .complete,
                segments: [SetSegment(loadMetrics: .init(weight: weight, repetitions: reps))]
            )
        )
    }

    static func makeRunStep(distanceKm: Double) -> WorkoutStep {
        WorkoutStep(
            exerciseRef: .init(
                plannedSetID: nil,
                exerciseName: "Run",
                exerciseSlug: nil,
                cue: "",
                label: "",
                kind: .cardio
            ),
            config: .init(target: .init(), authoredPosition: 0, rest: .init(lowSeconds: 60, highSeconds: 90)),
            state: .init(
                status: .complete,
                segments: [SetSegment(enduranceMetrics: .init(distanceKilometres: distanceKm))]
            )
        )
    }
}
