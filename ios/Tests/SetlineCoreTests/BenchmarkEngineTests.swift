import XCTest
@testable import SetlineCore

final class BenchmarkEngineTests: XCTestCase {
    // MARK: - Catalog

    func testCatalogHasFifteenMetrics() {
        XCTAssertEqual(BenchmarkCatalog.metrics.count, 15, "Baseline defines 15 benchmarks")
    }

    func testEveryMetricHasDefaultTargets() {
        for metric in BenchmarkCatalog.metrics {
            XCTAssertNotNil(
                BenchmarkCatalog.defaultTargets[metric.id],
                "\(metric.name) is missing default targets"
            )
        }
    }

    func testEveryMetricHasInitialState() {
        for metric in BenchmarkCatalog.metrics {
            XCTAssertNotNil(
                BenchmarksState.initial.metrics[metric.id],
                "\(metric.name) is missing initial state"
            )
        }
    }

    func testAllMetricIDsAreUnique() {
        let ids = BenchmarkCatalog.metrics.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Metric IDs must be unique")
    }

    // MARK: - Assessment: unrecorded

    func testUnrecordedMetricIsNotReached() {
        let state = BenchmarksState(
            profile: .init(weight: 80, height: 180),
            metrics: ["pullups": .init()],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("pullups", state: state)
        XCTAssertFalse(result.reached)
        XCTAssertFalse(result.recorded)
        XCTAssertEqual(result.status, "Not tested")
    }

    // MARK: - Assessment: pull-ups

    func testPullupsAtTargetIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["pullups": .init(numbers: ["reps": 15])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("pullups", state: state)
        XCTAssertTrue(result.reached)
        XCTAssertTrue(result.recorded)
        XCTAssertEqual(result.status, "Target reached")
    }

    func testPullupsBelowTargetIsBuilding() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["pullups": .init(numbers: ["reps": 10])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("pullups", state: state)
        XCTAssertFalse(result.reached)
        XCTAssertTrue(result.recorded)
        XCTAssertEqual(result.status, "Building")
    }

    // MARK: - Assessment: bench press

    func testBenchAtBodyweightRatioIsReached() {
        let weight = 80.0
        let ratio = 1.25
        let targetLoad = weight * ratio // 100 kg
        let state = BenchmarksState(
            profile: .init(weight: weight, height: 180),
            metrics: ["bench": .init(numbers: ["load": targetLoad, "reps": 1])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("bench", state: state)
        XCTAssertTrue(result.reached, "Lifting the target load for 1 rep should reach the goal")
    }

    func testBenchEstimateIsNotReached() {
        let state = BenchmarksState(
            profile: .init(weight: 80, height: 180),
            metrics: ["bench": .init(numbers: ["load": 80, "reps": 8])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("bench", state: state)
        XCTAssertFalse(result.reached, "An estimated 1RM from a set of 8 should not count as a passed target")
        XCTAssertEqual(result.status, "Estimate only")
        XCTAssertEqual(result.tone, .caution)
    }

    func testBenchWithoutBodyweightShowsSetWeight() {
        let state = BenchmarksState(
            profile: .init(weight: nil, height: 180),
            metrics: ["bench": .init(numbers: ["load": 80, "reps": 1])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("bench", state: state)
        XCTAssertEqual(result.target, "Set weight")
        XCTAssertFalse(result.reached)
    }

    // MARK: - Assessment: run

    func testRunShorterDistanceIsNotExtrapolated() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["run": .init(numbers: ["distance": 5], texts: ["time": "25:00", "qualifier": "Exact time"], flags: ["continuous": true])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("run", state: state)
        XCTAssertFalse(result.reached)
        XCTAssertEqual(result.status, "Shorter effort")
        XCTAssertTrue(result.message.contains("Not extrapolated"))
    }

    func testRunFullDistanceContinuousUnderTimeIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["run": .init(numbers: ["distance": 10], texts: ["time": "45:00", "qualifier": "Exact time"], flags: ["continuous": true])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("run", state: state)
        XCTAssertTrue(result.reached)
    }

    // MARK: - Assessment: reported values

    func testReportedBalanceIsCaution() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["balance": .init(texts: ["condition": "Not confirmed"], reported: true)],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("balance", state: state)
        XCTAssertTrue(result.recorded)
        XCTAssertEqual(result.status, "Check protocol")
        XCTAssertEqual(result.tone, .caution)
    }

    func testReportedAnkleIsNeedsMeasure() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["ankle": .init(reported: true)],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("ankle", state: state)
        XCTAssertTrue(result.recorded)
        XCTAssertEqual(result.status, "Needs measure")
    }

    // MARK: - Assessment: overhead

    func testOverheadMeetsStandardIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["overhead": .init(texts: ["status": "Meets standard"])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("overhead", state: state)
        XCTAssertTrue(result.reached)
        XCTAssertTrue(result.recorded)
    }

    func testOverheadNotTestedIsNotRecorded() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["overhead": .init(texts: ["status": "Not tested"])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("overhead", state: state)
        XCTAssertFalse(result.recorded)
    }

    // MARK: - Assessment: waist

    func testWaistBelowRatioIsReached() {
        let height = 180.0
        let ratio = 0.5
        let target = height * ratio // 90 cm
        let state = BenchmarksState(
            profile: .init(weight: 80, height: height),
            metrics: ["waist": .init(numbers: ["waist": 85])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("waist", state: state)
        XCTAssertTrue(result.reached, "85 cm waist with 180 cm height (ratio 0.47) should be below the 0.50 target")
    }

    func testWaistAboveRatioIsNotReached() {
        let state = BenchmarksState(
            profile: .init(weight: 80, height: 180),
            metrics: ["waist": .init(numbers: ["waist": 95])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("waist", state: state)
        XCTAssertFalse(result.reached)
        XCTAssertEqual(result.status, "Above target")
    }

    // MARK: - Assessment: reaction (lower is better)

    func testReactionAtOrBelowTargetIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["reaction": .init(numbers: ["cm": 15])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("reaction", state: state)
        XCTAssertTrue(result.reached, "15 cm is below the 20 cm target; lower is faster")
    }

    func testReactionAboveTargetIsNotReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["reaction": .init(numbers: ["cm": 25])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("reaction", state: state)
        XCTAssertFalse(result.reached)
    }

    // MARK: - Assessment: split squat

    func testSplitSquatMeetingLoadAndRepsIsReached() {
        let weight = 80.0
        let ratio = 0.5
        let targetPerHand = weight * ratio / 2 // 20 kg per hand
        let state = BenchmarksState(
            profile: .init(weight: weight, height: 180),
            metrics: ["split": .init(numbers: ["load": targetPerHand, "reps": 8])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("split", state: state)
        XCTAssertTrue(result.reached)
    }

    func testSplitSquatMissingRepsIsNotReached() {
        let state = BenchmarksState(
            profile: .init(weight: 80, height: 180),
            metrics: ["split": .init(numbers: ["load": 20])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("split", state: state)
        XCTAssertFalse(result.reached)
    }

    // MARK: - Assessment: jump

    func testJumpAtTargetIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["jump": .init(numbers: ["distance": 2.3], texts: ["effort": "Best of three"])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("jump", state: state)
        XCTAssertTrue(result.reached)
    }

    func testJumpComfortableAttemptIsNotReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["jump": .init(numbers: ["distance": 2.3], texts: ["effort": "Comfortable attempt"])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("jump", state: state)
        XCTAssertFalse(result.reached)
        XCTAssertEqual(result.status, "Easy attempt")
    }

    // MARK: - Assessment: carry

    func testCarryMeetingLoadAndDistanceIsReached() {
        let weight = 80.0
        let ratio = 0.5
        let targetPerHand = weight * ratio // 40 kg per hand
        let state = BenchmarksState(
            profile: .init(weight: weight, height: 180),
            metrics: ["carry": .init(numbers: ["load": targetPerHand, "distance": 50], texts: ["effort": "Tested effort"])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("carry", state: state)
        XCTAssertTrue(result.reached)
    }

    func testCarryWithoutDistanceIsNeedDistance() {
        let state = BenchmarksState(
            profile: .init(weight: 80, height: 180),
            metrics: ["carry": .init(numbers: ["load": 40], texts: ["effort": "Comfortable attempt"])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("carry", state: state)
        XCTAssertFalse(result.reached)
        XCTAssertEqual(result.status, "Need distance")
    }

    // MARK: - Assessment: squat

    func testSquatWithCleanHoldIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["squat": .init(numbers: ["seconds": 60], flags: ["clean": true])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("squat", state: state)
        XCTAssertTrue(result.reached)
    }

    func testSquatWithoutCleanFlagIsNotReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["squat": .init(numbers: ["seconds": 120], flags: ["clean": false])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("squat", state: state)
        XCTAssertFalse(result.reached)
    }

    // MARK: - Assessment: swim

    func testSwimMeetingAllGoalsIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["swim": .init(numbers: ["distance": 400, "tread": 120], flags: ["basics": true])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("swim", state: state)
        XCTAssertTrue(result.reached)
    }

    func testSwimMissingBasicsIsNotReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["swim": .init(numbers: ["distance": 400, "tread": 120], flags: ["basics": false])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("swim", state: state)
        XCTAssertFalse(result.reached)
    }

    // MARK: - Assessment: coordination

    func testCoordinationAtTargetIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["coordination": .init(numbers: ["catches": 30])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("coordination", state: state)
        XCTAssertTrue(result.reached)
    }

    func testCoordinationBelowTargetIsNotReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["coordination": .init(numbers: ["catches": 20])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("coordination", state: state)
        XCTAssertFalse(result.reached)
    }

    // MARK: - Assessment: agility

    func testAgilityAtOrBelowTargetIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["agility": .init(numbers: ["seconds": 5.0])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("agility", state: state)
        XCTAssertTrue(result.reached, "5.0 s is below the 5.5 s target; lower is better")
    }

    func testAgilityAboveTargetIsNotReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["agility": .init(numbers: ["seconds": 6.0])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("agility", state: state)
        XCTAssertFalse(result.reached)
    }

    // MARK: - Assessment: balance with eyes open

    func testBalanceEyesOpenIsCheckProtocol() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["balance": .init(numbers: ["left": 30, "right": 30], texts: ["condition": "Eyes open"])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("balance", state: state)
        XCTAssertFalse(result.reached)
        XCTAssertEqual(result.status, "Check protocol")
        XCTAssertEqual(result.tone, .caution)
    }

    func testBalanceEyesClosedBothSidesIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["balance": .init(numbers: ["left": 35, "right": 32], texts: ["condition": "Eyes closed"])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("balance", state: state)
        XCTAssertTrue(result.reached)
    }

    // MARK: - Assessment: ankle both sides

    func testAnkleBothSidesAtTargetIsReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["ankle": .init(numbers: ["left": 10, "right": 11])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("ankle", state: state)
        XCTAssertTrue(result.reached, "Both sides at or above 10 cm should reach the target")
    }

    func testAnkleOneSideOnlyIsNotReached() {
        let state = BenchmarksState(
            profile: .init(),
            metrics: ["ankle": .init(numbers: ["left": 12])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("ankle", state: state)
        XCTAssertFalse(result.reached)
    }

    // MARK: - Catalog helpers

    func testReachedCountInState() {
        let state = BenchmarksState(
            profile: .init(weight: 80, height: 180),
            metrics: [
                "pullups": .init(numbers: ["reps": 15]),
                "overhead": .init(texts: ["status": "Meets standard"]),
            ],
            targets: BenchmarkCatalog.defaultTargets
        )
        XCTAssertEqual(BenchmarkCatalog.reachedCount(in: state), 2)
    }

    func testRecordedCountInState() {
        let state = BenchmarksState(
            profile: .init(weight: 80, height: 180),
            metrics: [
                "pullups": .init(numbers: ["reps": 10]),
                "balance": .init(texts: ["condition": "Not confirmed"], reported: true),
            ],
            targets: BenchmarkCatalog.defaultTargets
        )
        XCTAssertEqual(BenchmarkCatalog.recordedCount(in: state), 2)
    }

    func testReachedCountInCheckIn() {
        let checkIn = BenchmarkCheckIn(
            date: Date(timeIntervalSince1970: 1_000_000),
            profile: .init(),
            metrics: ["pullups": .init(numbers: ["reps": 20])],
            targets: BenchmarkCatalog.defaultTargets
        )
        XCTAssertEqual(BenchmarkCatalog.reachedCount(in: checkIn), 1)
    }

    func testMetricLookupReturnsDefinition() {
        let metric = BenchmarkCatalog.metric(for: "pullups")
        XCTAssertNotNil(metric)
        XCTAssertEqual(metric?.name, "Strict pull-ups")
    }

    func testMetricLookupReturnsNilForUnknownID() {
        XCTAssertNil(BenchmarkCatalog.metric(for: "nonexistent"))
    }

    func testGroupsListContainsAllAndSixCategories() {
        XCTAssertEqual(BenchmarkCatalog.groups.count, 7)
        XCTAssertEqual(BenchmarkCatalog.groups.first?.id, "all")
    }

    func testBenchmarkGroupTitlesAndImages() {
        for group in BenchmarkGroup.allCases {
            XCTAssertFalse(group.title.isEmpty, "Group title must not be empty")
            XCTAssertFalse(group.systemImage.isEmpty, "Group system image must not be empty")
        }
    }

    func testBenchmarkFieldKeyAndLabel() {
        let field = BenchmarkField.number(key: "reps", label: "Repetitions", min: 0, max: 100, step: 1, placeholder: "—")
        XCTAssertEqual(field.key, "reps")
        XCTAssertEqual(field.label, "Repetitions")
    }

    // MARK: - Display time

    func testDisplayTimeMinutesSeconds() {
        XCTAssertEqual(BenchmarkEngine.displayTime(2730), "45:30")
    }

    func testDisplayTimeHoursMinutesSeconds() {
        XCTAssertEqual(BenchmarkEngine.displayTime(5400), "1:30:00")
    }

    // MARK: - Formatting

    func testFmtRoundsToOneDecimal() {
        XCTAssertEqual(BenchmarkEngine.fmt(72.55, 1), "72.6")
    }

    func testFmtHandlesNaN() {
        XCTAssertEqual(BenchmarkEngine.fmt(.nan), "—")
    }

    // MARK: - Initial state

    func testInitialStateHasBlankProfileAndDefaultTargets() {
        let state = BenchmarksState.initial
        XCTAssertNil(state.profile.weight, "A new user starts with no assumed bodyweight")
        XCTAssertNil(state.profile.height, "A new user starts with no assumed height")
        XCTAssertEqual(state.targets.count, 15)
        XCTAssertEqual(state.metrics.count, 15)
    }

    func testInitialStateReachedCountIsZero() {
        // A blank initial state has no recorded values, so nothing is reached.
        let state = BenchmarksState.initial
        XCTAssertEqual(BenchmarkCatalog.reachedCount(in: state), 0)
        XCTAssertEqual(BenchmarkCatalog.recordedCount(in: state), 0)
    }

    // MARK: - Time parsing

    func testParseTimeMinutesSeconds() {
        XCTAssertEqual(BenchmarkEngine.parseTime("45:30"), 2730)
    }

    func testParseTimeHoursMinutesSeconds() {
        XCTAssertEqual(BenchmarkEngine.parseTime("1:30:00"), 5400)
    }

    func testParseTimeBareNumberIsMinutes() {
        XCTAssertEqual(BenchmarkEngine.parseTime("40"), 2400)
    }

    func testParseTimeEmptyIsNil() {
        XCTAssertNil(BenchmarkEngine.parseTime(""))
        XCTAssertNil(BenchmarkEngine.parseTime(nil))
    }

    func testParseTimeInvalidIsNil() {
        XCTAssertNil(BenchmarkEngine.parseTime("abc"))
        XCTAssertNil(BenchmarkEngine.parseTime("1:70"))
    }

    // MARK: - Document round-trip

    func testDocumentWithBenchmarksEncodesAndDecodes() throws {
        var state = BenchmarksState.initial
        state.metrics["pullups"] = .init(numbers: ["reps": 12])
        state.history.append(BenchmarkCheckIn(
            date: Date(timeIntervalSince1970: 1_000_000),
            profile: .init(weight: 85, height: 178),
            metrics: state.metrics,
            targets: state.targets
        ))

        let document = SetlineDocument(benchmarks: state)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SetlineDocument.self, from: data)

        XCTAssertEqual(decoded.benchmarks.metrics["pullups"]?.number("reps"), 12)
        XCTAssertEqual(decoded.benchmarks.history.count, 1)
        XCTAssertNil(decoded.benchmarks.profile.weight, "Initial state has no assumed bodyweight")
    }

    func testDocumentWithoutBenchmarksDecodesToInitial() throws {
        // A document JSON written before benchmarks existed should decode cleanly.
        let json = """
        {"schemaVersion":2,"templates":[],"programme":"none","history":[],"goals":[],"syncState":"deviceOnly"}
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SetlineDocument.self, from: data)

        XCTAssertEqual(decoded.benchmarks, BenchmarksState.initial)
    }

    func testBenchmarksStateIsContentComparison() {
        var first = SetlineDocument.initial
        var second = first
        first.syncState = .pending
        second.syncState = .synced
        XCTAssertTrue(first.hasSameContent(as: second), "Sync metadata must not read as a training change")
    }

    // MARK: - Check-in assessment

    func testCheckInAssessmentUsesSnapshotState() {
        let checkIn = BenchmarkCheckIn(
            date: Date(timeIntervalSince1970: 1_000_000),
            profile: .init(weight: 90, height: 180),
            metrics: ["pullups": .init(numbers: ["reps": 20])],
            targets: BenchmarkCatalog.defaultTargets
        )
        let result = BenchmarkEngine.assess("pullups", checkIn: checkIn)
        XCTAssertTrue(result.reached, "20 pull-ups exceeds the 15 target in the snapshot")
    }

    // MARK: - Blank metrics

    func testBlankMetricsHasNoNumbers() {
        let blank = BenchmarksState.blankMetrics
        for metric in BenchmarkCatalog.metrics {
            let state = blank[metric.id]
            XCTAssertNotNil(state, "\(metric.name) should have a blank state entry")
            for field in metric.fields {
                if case .number(let key, _, _, _, _, _) = field {
                    XCTAssertNil(state?.number(key), "\(metric.name).\(key) should be nil in blank state")
                }
            }
        }
    }

    // MARK: - Custom target detection

    func testDefaultTargetIsNotCustom() {
        let state = BenchmarksState(targets: BenchmarkCatalog.defaultTargets)
        XCTAssertFalse(BenchmarkCatalog.targetIsCustom("pullups", targets: state.targets))
    }

    func testModifiedTargetIsCustom() {
        var targets = BenchmarkCatalog.defaultTargets
        targets["pullups"] = .init(values: ["reps": 20])
        XCTAssertTrue(BenchmarkCatalog.targetIsCustom("pullups", targets: targets))
    }

    // MARK: - Workout history bridge

    func testHistoryBridgeReturnsNoSuggestionsForEmptyHistory() {
        let suggestions = BenchmarkHistoryBridge.suggestions(from: [])
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testHistoryBridgeSuggestsPullupsFromWorkout() {
        let session = TestSessionFactory.makeSession(
            steps: [TestSessionFactory.makeStep(exerciseName: "Strict pull-up", reps: 8)]
        )
        let suggestions = BenchmarkHistoryBridge.suggestions(from: [session])
        let pullup = suggestions.first { $0.metricID == "pullups" }
        XCTAssertNotNil(pullup)
        XCTAssertEqual(pullup?.numbers["reps"], 8)
        XCTAssertEqual(pullup?.sourceExerciseName, "Strict pull-up")
    }

    func testHistoryBridgeSuggestsBenchFromWorkout() {
        let session = TestSessionFactory.makeSession(
            steps: [TestSessionFactory.makeStep(exerciseName: "Bench press", weight: 80, reps: 5)]
        )
        let suggestions = BenchmarkHistoryBridge.suggestions(from: [session])
        let bench = suggestions.first { $0.metricID == "bench" }
        XCTAssertNotNil(bench)
        XCTAssertEqual(bench?.numbers["load"], 80)
        XCTAssertEqual(bench?.numbers["reps"], 5)
        // The source text should mention it's an estimate.
        XCTAssertTrue(bench?.texts["source"]?.contains("Estimated 1RM") == true)
    }

    func testHistoryBridgeSuggestsRunDistanceFromWorkout() {
        let session = TestSessionFactory.makeSession(
            steps: [TestSessionFactory.makeRunStep(distanceKm: 5.0)]
        )
        let suggestions = BenchmarkHistoryBridge.suggestions(from: [session])
        let run = suggestions.first { $0.metricID == "run" }
        XCTAssertNotNil(run)
        XCTAssertEqual(run?.numbers["distance"], 5.0, "5 km run should map to 5.0 km in the benchmark")
    }

    func testHistoryBridgeDoesNotSuggestBenchWithTooManyReps() {
        // Beyond 12 reps, Epley is not a strength estimate, so no suggestion.
        let session = TestSessionFactory.makeSession(
            steps: [TestSessionFactory.makeStep(exerciseName: "Bench press", weight: 40, reps: 15)]
        )
        let suggestions = BenchmarkHistoryBridge.suggestions(from: [session])
        XCTAssertNil(suggestions.first { $0.metricID == "bench" })
    }

    func testHistoryBridgeDoesNotExtrapolateShortRun() {
        // A 3 km run should produce a 3 km suggestion, not a projected 10 km time.
        let session = TestSessionFactory.makeSession(
            steps: [TestSessionFactory.makeRunStep(distanceKm: 3.0)]
        )
        let suggestions = BenchmarkHistoryBridge.suggestions(from: [session])
        let run = suggestions.first { $0.metricID == "run" }
        XCTAssertEqual(run?.numbers["distance"], 3.0)
        // The qualifier should say "More than" since it's not a full 10 km.
        XCTAssertEqual(run?.texts["qualifier"], "More than")
    }

    // MARK: - Scorecard export

    func testScorecardTextContainsHeaderAndAllMetrics() {
        let state = BenchmarksState.initial
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("Baseline scorecard"), "Scorecard should have a title")
        XCTAssertTrue(scorecard.contains("STRENGTH"), "Scorecard should group by strength")
        XCTAssertTrue(scorecard.contains("ENDURANCE"), "Scorecard should group by endurance")
        // Every metric name should appear in the scorecard.
        for metric in BenchmarkCatalog.metrics {
            XCTAssertTrue(scorecard.contains(metric.name), "\(metric.name) should be in the scorecard")
        }
    }

    func testScorecardTextWithWeightOnlyProfile() {
        var state = BenchmarksState.initial
        state.profile = BenchmarkProfile(weight: 82)
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("82"), "Scorecard should show weight")
        XCTAssertTrue(scorecard.contains("kg"), "Scorecard should show kg unit")
    }

    func testScorecardTextWithHeightOnlyProfile() {
        var state = BenchmarksState.initial
        state.profile = BenchmarkProfile(height: 180)
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("180"), "Scorecard should show height")
        XCTAssertTrue(scorecard.contains("cm"), "Scorecard should show cm unit")
    }

    func testScorecardTextWithFullProfile() {
        var state = BenchmarksState.initial
        state.profile = BenchmarkProfile(weight: 82, height: 180)
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("82"), "Scorecard should show weight")
        XCTAssertTrue(scorecard.contains("180"), "Scorecard should show height")
    }

    func testScorecardTextWithCurrentSub() {
        var state = BenchmarksState.initial
        state.metrics["bench"] = .init(numbers: ["load": 80, "reps": 5])
        let scorecard = BenchmarkScorecard.text(for: state)
        // The bench assessment should include a currentSub line in the scorecard.
        XCTAssertTrue(scorecard.contains("Bench press"), "Bench should be in scorecard")
        // Bench with load+reps should produce a currentSub with "kg × repetitions".
        XCTAssertTrue(scorecard.contains("kg \u{00D7} repetitions"), "Bench currentSub should show kg × repetitions")
    }

    func testScorecardTextWithRecordedButNotReachedBox() {
        var state = BenchmarksState.initial
        // Pull-ups: 5 reps — recorded but below the default target of 15.
        state.metrics["pullups"] = .init(numbers: ["reps": 5])
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("[ ] Strict pull-ups"), "Recorded-but-not-reached should show empty box")
    }

    func testScorecardTextSummaryLine() {
        var state = BenchmarksState.initial
        state.metrics["pullups"] = .init(numbers: ["reps": 20])
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("1/15 targets reached"), "Summary should show 1/15")
        XCTAssertTrue(scorecard.contains("1 recorded"), "Summary should show 1 recorded")
    }

    func testScorecardTextShowsReachedCheckmark() {
        var state = BenchmarksState.initial
        state.metrics["pullups"] = .init(numbers: ["reps": 20]) // exceeds default target of 15
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("[\u{2713}] Strict pull-ups"), "Reached target should show a checkmark")
    }

    func testScorecardTextShowsUnknownDashForBlankState() {
        let state = BenchmarksState.initial
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("[\u{2014}]"), "Blank state should show dashes for unrecorded metrics")
    }

    func testScorecardTextIncludesDisclaimer() {
        let state = BenchmarksState.initial
        let scorecard = BenchmarkScorecard.text(for: state)
        XCTAssertTrue(scorecard.contains("not a"), "Scorecard should include the honesty disclaimer")
        XCTAssertTrue(scorecard.contains("tested maximum"), "Scorecard should warn about estimates")
    }

    // MARK: - Focus model

    func testFocusBlankStateHasNoContent() {
        let state = BenchmarksState.initial
        let focus = BenchmarkFocus.compute(from: state)
        XCTAssertFalse(focus.hasContent, "Blank state should not show focus sections")
        XCTAssertTrue(focus.inProgress.isEmpty)
        XCTAssertTrue(focus.reached.isEmpty)
        XCTAssertEqual(focus.notStarted.count, 15, "All 15 should be not-started in blank state")
    }

    func testFocusPartitionsCorrectlyWithSomeData() {
        var state = BenchmarksState.initial
        // Pull-ups: 20 reps — exceeds default target of 15, so reached.
        state.metrics["pullups"] = .init(numbers: ["reps": 20])
        // Bench: 60 kg × 5 — recorded but not reached (target is 1.25× bodyweight,
        // and with no bodyweight entered, the target can't be met).
        state.metrics["bench"] = .init(numbers: ["load": 60, "reps": 5])
        let focus = BenchmarkFocus.compute(from: state)
        XCTAssertTrue(focus.hasContent)
        XCTAssertTrue(focus.reached.contains { $0.id == "pullups" })
        XCTAssertTrue(focus.inProgress.contains { $0.id == "bench" })
        XCTAssertEqual(focus.notStarted.count, 13, "Remaining 13 should be not-started")
    }

    func testFocusAllReached() {
        var state = BenchmarksState.initial
        // Set pull-ups and run to reached values.
        state.metrics["pullups"] = .init(numbers: ["reps": 20])
        state.metrics["run"] = .init(numbers: ["distance": 10], texts: ["time": "45:00", "qualifier": "Exact time"], flags: ["continuous": true])
        let focus = BenchmarkFocus.compute(from: state)
        XCTAssertEqual(focus.reached.count, 2)
        XCTAssertEqual(focus.inProgress.count, 0)
        XCTAssertEqual(focus.notStarted.count, 13)
    }
}

// MARK: - Test session factory

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
