import XCTest
@testable import SetlineCore

final class SetlineCoreTests: XCTestCase {
    // MARK: - Session mechanics

    func testCloudDocumentExcludesDeviceSyncMetadata() {
        var first = SetlineDocument.sample
        first.syncState = .pending
        first.lastSyncedAt = Date(timeIntervalSince1970: 100)
        var second = first
        second.syncState = .failed
        second.lastSyncedAt = Date(timeIntervalSince1970: 200)

        XCTAssertEqual(SetlineCloudDocument(document: first), SetlineCloudDocument(document: second))
    }

    func testCloudDocumentRestoresAsSyncedLocalDocument() {
        let cloud = SetlineCloudDocument(document: .sample)
        let restored = cloud.localDocument(lastSyncedAt: Date(timeIntervalSince1970: 300))

        XCTAssertEqual(restored.syncState, .synced)
        XCTAssertEqual(restored.lastSyncedAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(SetlineCloudDocument(document: restored), cloud)
    }

    func testSessionSnapshotKeepsAuthoredOrderWhenTemplateChanges() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        let authoredNames = try XCTUnwrap(document.templates.first).exercises.flatMap { exercise in
            exercise.sets.map { _ in exercise.name }
        }

        try document.startWorkout(templateID: templateID, at: Date(timeIntervalSince1970: 100))
        document.templates[0].exercises[0].name = "Changed later"

        XCTAssertEqual(document.activeSession?.steps.map(\.exerciseName), authoredNames)
    }

    /// The headline requirement: `5 reps × 40 kg` then `2 reps × 30 kg` is one set.
    func testMultipleSegmentsRecordAsOneSet() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        try document.startWorkout(templateID: templateID)

        let segments = [
            SetSegment(weight: 40, repetitions: 5),
            SetSegment(weight: 30, repetitions: 2),
        ]
        try document.completeCurrent(with: segments, at: Date(timeIntervalSince1970: 500))

        let step = try XCTUnwrap(document.activeSession?.steps.first)
        XCTAssertEqual(step.segments, segments)
        XCTAssertEqual(step.status, .complete)
        XCTAssertEqual(step.segments.count, 2, "Both segments belong to the same recorded set")
    }

    func testWorkSecondsAreRecordedSeparatelyFromRest() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        try document.startWorkout(templateID: templateID)

        try document.completeCurrent(
            with: [SetSegment(weight: 40, repetitions: 8)],
            workSeconds: 37,
            at: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(document.activeSession?.steps.first?.workSeconds, 37)
        XCTAssertEqual(document.activeSession?.rest?.authoredSeconds, 60)
    }

    func testDeferringChangesQueueButRetainsAuthoredPosition() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        try document.startWorkout(templateID: templateID)
        let firstID = try XCTUnwrap(document.activeSession?.steps.first?.id)

        try document.deferCurrent()

        XCTAssertEqual(document.activeSession?.steps.last?.id, firstID)
        XCTAssertEqual(document.activeSession?.steps.last?.authoredPosition, 0)
        XCTAssertEqual(document.activeSession?.steps.last?.status, .deferred)
    }

    func testExtraSetDoesNotModifyTemplate() throws {
        var document = SetlineDocument.sample
        let template = try XCTUnwrap(document.templates.first)
        let originalSetCount = template.plannedSetCount
        try document.startWorkout(templateID: template.id)

        try document.addExtraSet()

        XCTAssertEqual(document.activeSession?.steps.count, originalSetCount + 1)
        XCTAssertEqual(document.templates.first?.plannedSetCount, originalSetCount)
        XCTAssertTrue(document.activeSession?.steps[1].isExtra == true)
    }

    func testRestUsesWallClockTimestamps() throws {
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        let start = Date(timeIntervalSince1970: 1_000)
        try document.startWorkout(templateID: templateID, at: start)
        try document.completeCurrent(with: [SetSegment(weight: 40, repetitions: 8)], at: start)
        let rest = try XCTUnwrap(document.activeSession?.rest)

        XCTAssertEqual(rest.remaining(at: start.addingTimeInterval(17)), rest.adjustedSeconds - 17)
        XCTAssertEqual(rest.actual(at: start.addingTimeInterval(31)), 31)
    }

    func testPersistenceRestoresActiveSession() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "setline.json")
        let store = SetlineStore(fileURL: url)
        var document = SetlineDocument.sample
        let templateID = try XCTUnwrap(document.templates.first?.id)
        let timestamp = Date(timeIntervalSince1970: 10_000)
        try document.startWorkout(templateID: templateID, at: timestamp)
        try document.completeCurrent(with: [SetSegment(weight: 40, repetitions: 8)], at: timestamp)

        try await store.save(document)
        let restored = try await store.load()

        XCTAssertEqual(restored, document)
        XCTAssertNotNil(restored.activeSession?.rest)
    }

    func testFreshInstallOpensOnTheAuthoredBlock() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "setline.json")
        let store = SetlineStore(fileURL: url)

        let document = try await store.load()

        XCTAssertEqual(document.programme, .bundled(.twelveWeekStrengthCardioMobility))
    }

    func testDuplicateTemplateIsIndependent() throws {
        var document = SetlineDocument.sample
        let original = try XCTUnwrap(document.templates.first)
        try document.duplicateTemplate(original.id)

        let copy = try XCTUnwrap(document.templates.last)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.exercises.first?.id, original.exercises.first?.id)
        XCTAssertFalse(copy.isBundled)
    }

    // MARK: - Version 1 migration

    /// Version 1 wrote free-text targets, scalar rest and a bare custom programme.
    /// None of that may be lost when the document is read by the current schema.
    func testVersionOneDocumentMigratesWithoutLosingRecordedWork() throws {
        let legacy = """
        {
          "schemaVersion": 1,
          "syncState": "deviceOnly",
          "templates": [
            {
              "id": "11111111-1111-4111-8111-111111111111",
              "name": "Legacy upper",
              "detail": "Sample",
              "isBundled": true,
              "exercises": [
                {
                  "id": "22222222-2222-4222-8222-222222222222",
                  "name": "Bench press",
                  "cue": "Old cue",
                  "sets": [
                    {
                      "id": "33333333-3333-4333-8333-333333333333",
                      "label": "Working 1",
                      "kind": "strength",
                      "target": "70 kg × 5",
                      "restSeconds": 180
                    }
                  ]
                }
              ]
            }
          ],
          "programme": {
            "id": "44444444-4444-4444-8444-444444444444",
            "name": "Old block",
            "weekCount": 8,
            "enabled": true,
            "days": []
          },
          "history": [
            {
              "id": "55555555-5555-4555-8555-555555555555",
              "templateID": "11111111-1111-4111-8111-111111111111",
              "templateName": "Legacy upper",
              "startedAt": "2026-07-01T10:00:00Z",
              "completedAt": "2026-07-01T11:00:00Z",
              "activeIndex": 1,
              "steps": [
                {
                  "id": "66666666-6666-4666-8666-666666666666",
                  "exerciseName": "Bench press",
                  "cue": "Old cue",
                  "label": "Working 1",
                  "kind": "strength",
                  "target": "70 kg × 5",
                  "authoredPosition": 0,
                  "restSeconds": 180,
                  "status": "complete",
                  "isExtra": false,
                  "segments": [{ "id": "77777777-7777-4777-8777-777777777777", "weight": 70, "repetitions": 5 }]
                }
              ]
            }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SetlineDocument.self, from: Data(legacy.utf8))
        let migrated = try SetlineStore.migrate(decoded)

        XCTAssertEqual(migrated.schemaVersion, SetlineDocument.currentSchemaVersion)
        // The free-text target survives verbatim rather than being reinterpreted.
        let plannedTarget = try XCTUnwrap(migrated.templates.first?.exercises.first?.sets.first?.target)
        XCTAssertEqual(plannedTarget.displayString, "70 kg × 5")
        XCTAssertEqual(migrated.templates.first?.exercises.first?.sets.first?.rest, RestRange(180))
        XCTAssertEqual(migrated.programme.customProgramme?.name, "Old block")
        // The recorded set is intact and now linked to the catalogue.
        let step = try XCTUnwrap(migrated.history.first?.steps.first)
        XCTAssertEqual(step.segments.first?.weight, 70)
        XCTAssertEqual(step.segments.first?.repetitions, 5)
        XCTAssertEqual(step.exerciseSlug, "bench-press")
        XCTAssertTrue(step.pillars.contains(.strength))
    }

    func testUnknownFutureSchemaIsRejected() {
        var document = SetlineDocument.sample
        document.schemaVersion = 99

        XCTAssertThrowsError(try SetlineStore.migrate(document)) { error in
            XCTAssertEqual(error as? SetlineError, .unsupportedSchema(99))
        }
    }
}

// MARK: - The authored twelve-week block

final class TwelveWeekProgrammeTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testBlockStartsOnMondayTwentySeventhJuly() {
        let position = TwelveWeekProgramme.position(for: date(2026, 7, 27), calendar: calendar)

        XCTAssertEqual(position.weekNumber, 1)
        XCTAssertEqual(position.dayIndex, 0)
        XCTAssertTrue(position.inBlock)
        XCTAssertEqual(position.schedule.kind, .upper)
    }

    func testBlockEndsOnSundayEighteenthOctober() {
        let position = TwelveWeekProgramme.position(for: date(2026, 10, 18), calendar: calendar)

        XCTAssertEqual(position.weekNumber, 12)
        XCTAssertEqual(position.dayIndex, 6)
        XCTAssertTrue(position.inBlock)
        XCTAssertEqual(position.schedule.kind, .easyCardioMobility)
    }

    func testDatesOutsideTheBlockAreReportedRatherThanClampedSilently() {
        let before = TwelveWeekProgramme.position(for: date(2026, 7, 26), calendar: calendar)
        let after = TwelveWeekProgramme.position(for: date(2026, 10, 19), calendar: calendar)

        XCTAssertTrue(before.beforeBlock)
        XCTAssertFalse(before.inBlock)
        XCTAssertTrue(after.afterBlock)
        XCTAssertFalse(after.inBlock)
    }

    /// Every one of the 84 dated days resolves to the authored weekday session.
    func testEveryDayOfTheBlockResolvesToItsAuthoredSession() throws {
        let start = date(2026, 7, 27)
        for offset in 0..<TwelveWeekProgramme.dayCount {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: start))
            let position = TwelveWeekProgramme.position(for: day, calendar: calendar)

            XCTAssertEqual(position.weekNumber, offset / 7 + 1, "offset \(offset)")
            XCTAssertEqual(position.dayIndex, offset % 7, "offset \(offset)")
            XCTAssertEqual(
                position.schedule.kind,
                TwelveWeekProgramme.schedule[offset % 7].kind,
                "offset \(offset)"
            )
            XCTAssertFalse(position.template.exercises.isEmpty, "offset \(offset)")
            // Monday-based day 0 must always land on a real Monday.
            if offset % 7 == 0 {
                XCTAssertEqual(calendar.component(.weekday, from: day), 2, "offset \(offset)")
            }
        }
    }

    func testRomanianDeadliftUsesTwoWorkingSetsInWeeksOneAndTwoThenThree() {
        for week in 1...TwelveWeekProgramme.weekCount {
            let template = TwelveWeekProgramme.template(for: .lower, week: week)
            let rdl = template.exercises.first { $0.definitionSlug == "romanian-deadlift" }
            let workingSets = rdl?.workingSets.count

            XCTAssertEqual(workingSets, week <= 2 ? 2 : 3, "week \(week)")
            if week >= 3 {
                // The third set is offered, never silently inserted.
                XCTAssertEqual(rdl?.workingSets.last?.isOptional, true, "week \(week)")
            }
        }
    }

    func testHardCardioUsesFourRoundsInWeeksOneAndTwoThenFive() {
        for week in 1...TwelveWeekProgramme.weekCount {
            let template = TwelveWeekProgramme.template(for: .upperPlusHardCardio, week: week, dayIndex: 3)
            let intervals = template.exercises.first { $0.definitionSlug == "controlled-hard-interval" }

            XCTAssertEqual(intervals?.sets.count, week <= 2 ? 4 : 5, "week \(week)")
            XCTAssertEqual(intervals?.sets.first?.target.timeSeconds, 120, "week \(week)")
            XCTAssertEqual(intervals?.sets.first?.rest, RestRange(180), "week \(week)")
        }
    }

    func testPullUpIsTestedOnlyAtWeeksFiveNineAndTheEndOfWeekTwelve() {
        for week in 1...TwelveWeekProgramme.weekCount {
            for dayIndex in [0, 3] {
                let kind: ProgrammeSessionKind = dayIndex == 0 ? .upper : .upperPlusHardCardio
                let template = TwelveWeekProgramme.template(for: kind, week: week, dayIndex: dayIndex)
                let testsPullUp = template.exercises.contains {
                    $0.sets.contains { $0.stepType == .check }
                }
                let expected = (dayIndex == 0 && (week == 5 || week == 9)) || (dayIndex == 3 && week == 12)

                XCTAssertEqual(testsPullUp, expected, "week \(week) day \(dayIndex)")
            }
        }
    }

    func testOptionalLateralRaiseAppearsOnlyFromWeekFive() {
        for week in 1...TwelveWeekProgramme.weekCount {
            let template = TwelveWeekProgramme.template(for: .upper, week: week)
            let hasLateralRaise = template.exercises.contains { $0.definitionSlug == "lateral-raise" }

            XCTAssertEqual(hasLateralRaise, week >= 5, "week \(week)")
            if hasLateralRaise {
                let raise = template.exercises.first { $0.definitionSlug == "lateral-raise" }
                XCTAssertTrue(raise?.sets.allSatisfy(\.isOptional) == true)
            }
        }
    }

    func testBenchRampAndWorkingSetsMatchTheAuthoredPlan() throws {
        let template = TwelveWeekProgramme.template(for: .upper, week: 1)
        let bench = try XCTUnwrap(template.exercises.first { $0.definitionSlug == "bench-press" })
        let warmUps = bench.sets.filter { $0.stepType == .warmUp }

        XCTAssertEqual(warmUps.count, 3)
        XCTAssertEqual(warmUps[0].target.load, .absolute(kilograms: 20))
        XCTAssertEqual(warmUps[0].target.repsLow, 10)
        XCTAssertEqual(warmUps[1].target.load, .absolute(kilograms: 40))
        XCTAssertEqual(warmUps[1].target.repsLow, 5)
        XCTAssertEqual(warmUps[2].target.load, .absolute(kilograms: 55))
        XCTAssertEqual(warmUps[2].target.repsLow, 2)
        XCTAssertEqual(warmUps[2].target.repsHigh, 3)

        let working = bench.workingSets
        XCTAssertEqual(working.count, 3)
        XCTAssertEqual(working[0].target.load, .absolute(kilograms: 65))
        XCTAssertEqual(working[0].target.repsLow, 5)
        XCTAssertEqual(working[0].target.repsHigh, 8)
        XCTAssertEqual(working[0].rest, RestRange(lowSeconds: 150, highSeconds: 180))
    }

    func testRepsInReserveTightensAfterTheLearningWeeks() {
        let earlyBench = TwelveWeekProgramme.template(for: .upper, week: 1)
            .exercises.first { $0.definitionSlug == "bench-press" }?.workingSets.first
        let laterBench = TwelveWeekProgramme.template(for: .upper, week: 6)
            .exercises.first { $0.definitionSlug == "bench-press" }?.workingSets.first

        XCTAssertEqual(earlyBench?.target.repsInReserve, 2)
        XCTAssertEqual(laterBench?.target.repsInReserve, 1)
    }

    func testFullMobilityRoutineCarriesAllEightAuthoredMovements() {
        let template = TwelveWeekProgramme.template(for: .fullMobility, week: 1)

        XCTAssertEqual(template.exercises.count, 8)
        XCTAssertEqual(template.exercises.map(\.definitionSlug), [
            "knee-to-wall-ankle-rocks",
            "supported-squat-hold",
            "goblet-squat",
            "ninety-ninety-hip-switches",
            "half-kneeling-hip-flexor-stretch",
            "wall-slides",
            "bench-lat-stretch",
            "doorway-pec-stretch",
        ])
    }

    func testEasyCardioSessionTotalsFortyFiveMinutes() throws {
        let template = TwelveWeekProgramme.template(for: .easyCardioMobility, week: 1)
        let cardio = try XCTUnwrap(template.exercises.first { $0.definitionSlug == "easy-cardio" })
        let seconds = cardio.sets.compactMap(\.target.timeSeconds).reduce(0, +)

        XCTAssertEqual(seconds, 45 * 60)
    }

    /// A movement authored into the block but missing from the catalogue would lose
    /// its pillars and measurements, so the two must never drift apart.
    func testEveryAuthoredMovementExistsInTheCatalogue() {
        for kind in ProgrammeSessionKind.allCases {
            for week in [1, 3, 5, 9, 12] {
                for dayIndex in [0, 3] {
                    let template = TwelveWeekProgramme.template(for: kind, week: week, dayIndex: dayIndex)
                    for exercise in template.exercises {
                        let slug = exercise.definitionSlug
                        XCTAssertNotNil(slug, "\(kind) week \(week): \(exercise.name) has no slug")
                        XCTAssertNotNil(
                            slug.flatMap { ExerciseCatalogue.definition(slug: $0) },
                            "\(kind) week \(week): \(slug ?? "nil") missing from the catalogue"
                        )
                    }
                }
            }
        }
    }

    func testCheckpointsFallOnTheAuthoredDates() {
        let expected = [
            ("Baseline", date(2026, 7, 27)),
            ("Week 5", date(2026, 8, 24)),
            ("Week 9", date(2026, 9, 21)),
            ("End of block", date(2026, 10, 18)),
        ]
        for (index, checkpoint) in TwelveWeekProgramme.checkpoints.enumerated() {
            XCTAssertEqual(checkpoint.name, expected[index].0)
            XCTAssertEqual(
                TwelveWeekProgramme.checkpointDate(checkpoint, calendar: calendar),
                expected[index].1
            )
        }
    }

    func testTodayResolutionUsesTheBundledBlock() throws {
        let document = SetlineDocument.initial
        let resolved = try XCTUnwrap(document.session(on: date(2026, 8, 4), calendar: calendar))

        // 4 August 2026 is the Tuesday of week 2.
        XCTAssertEqual(resolved.programmeWeek, 2)
        XCTAssertEqual(resolved.programmeDayIndex, 1)
        XCTAssertEqual(resolved.template.name, "Lower")
        XCTAssertNil(resolved.outOfBlockNotice)
    }

    func testWeekStripReturnsSevenBundledDays() {
        let week = SetlineDocument.initial.week(containing: date(2026, 8, 4), calendar: calendar)

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.compactMap { $0?.template.name }, [
            "Upper",
            "Lower",
            "Easy cardio + full mobility",
            "Upper + hard cardio",
            "Full mobility",
            "Lower",
            "Easy cardio + full mobility",
        ])
    }
}

// MARK: - Shorthand set entry

final class SetEntryParserTests: XCTestCase {
    func testRepsFirstPairMatchesTheAuthoredConvention() {
        let result = SetEntryParser.parse("5x40")

        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.segments.first?.repetitions, 5)
        XCTAssertEqual(result.segments.first?.weight, 40)
        XCTAssertTrue(result.isFullyUnderstood)
    }

    /// The exact requirement: two segments, one set.
    func testTwoSegmentsParseAsOneSet() {
        let result = SetEntryParser.parse("5x40, 2x30")

        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.segments[0].repetitions, 5)
        XCTAssertEqual(result.segments[0].weight, 40)
        XCTAssertEqual(result.segments[1].repetitions, 2)
        XCTAssertEqual(result.segments[1].weight, 30)
    }

    func testExplicitUnitsDisambiguateOrder() {
        let weightFirst = SetEntryParser.parse("40kg x 5")

        XCTAssertEqual(weightFirst.segments.first?.weight, 40)
        XCTAssertEqual(weightFirst.segments.first?.repetitions, 5)
    }

    func testExplicitRepsAndWeightInEitherOrder() {
        let a = SetEntryParser.parse("5 reps 40 kg")
        let b = SetEntryParser.parse("40 kg 5 reps")

        XCTAssertEqual(a.segments.first?.repetitions, 5)
        XCTAssertEqual(a.segments.first?.weight, 40)
        XCTAssertEqual(b.segments.first?.repetitions, 5)
        XCTAssertEqual(b.segments.first?.weight, 40)
    }

    func testBodyweightWithAddedLoad() {
        let bare = SetEntryParser.parse("bw x 8")
        let loaded = SetEntryParser.parse("bw+10 x 8")

        XCTAssertEqual(bare.segments.first?.repetitions, 8)
        XCTAssertNil(bare.segments.first?.weight)
        XCTAssertEqual(loaded.segments.first?.repetitions, 8)
        XCTAssertEqual(loaded.segments.first?.weight, 10)
    }

    func testAssistedRepetitions() {
        let result = SetEntryParser.parse("assist 15kg x 6")

        XCTAssertEqual(result.segments.first?.assistanceKilograms, 15)
        XCTAssertEqual(result.segments.first?.repetitions, 6)
    }

    func testDurationsAndDistances() {
        XCTAssertEqual(SetEntryParser.parse("45s").segments.first?.durationSeconds, 45)
        XCTAssertEqual(SetEntryParser.parse("2min").segments.first?.durationSeconds, 120)
        XCTAssertEqual(SetEntryParser.parse("5km 25min").segments.first?.distanceKilometres, 5)
        XCTAssertEqual(SetEntryParser.parse("5km 25min").segments.first?.durationSeconds, 1_500)
    }

    func testEffortQualifiers() {
        let result = SetEntryParser.parse("5x40 @rpe8 rir1")

        XCTAssertEqual(result.segments.first?.rpe, 8)
        XCTAssertEqual(result.segments.first?.repsInReserve, 1)
        XCTAssertEqual(result.segments.first?.repetitions, 5)
        XCTAssertEqual(result.segments.first?.weight, 40)
    }

    func testPerSideEntry() {
        let result = SetEntryParser.parse("left 8x20, right 8x20")

        XCTAssertEqual(result.segments.count, 2)
        XCTAssertEqual(result.segments[0].side, .left)
        XCTAssertEqual(result.segments[1].side, .right)
        XCTAssertEqual(result.segments[0].repetitions, 8)
    }

    func testFailureIsFlagged() {
        XCTAssertEqual(SetEntryParser.parse("8x60 fail").segments.first?.reachedFailure, true)
    }

    /// Nonsense is reported, never silently turned into a recorded number.
    func testUnparseableTextIsReportedRatherThanGuessed() {
        let result = SetEntryParser.parse("something odd")

        XCTAssertTrue(result.segments.isEmpty)
        XCTAssertEqual(result.unrecognised, ["something odd"])
        XCTAssertFalse(result.isFullyUnderstood)
    }

    func testShorthandRoundTrips() {
        let original = SetEntryParser.parse("5x40, 2x30").segments
        let round = SetEntryParser.parse(SetEntryParser.shorthand(for: original)).segments

        XCTAssertEqual(round.map(\.repetitions), original.map(\.repetitions))
        XCTAssertEqual(round.map(\.weight), original.map(\.weight))
    }
}

// MARK: - Measurement, goals and progression

final class ExerciseMetricsTests: XCTestCase {
    private let sessionDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func step(
        _ name: String,
        reps: Int,
        kilograms: Double?,
        type: StepType = .working,
        position: Int = 0,
        completedAt: Date
    ) -> WorkoutStep {
        WorkoutStep(
            plannedSetID: UUID(),
            exerciseName: name,
            exerciseSlug: ExerciseCatalogue.match(name: name)?.slug,
            cue: "",
            label: "Working",
            kind: .strength,
            stepType: type,
            target: SetTarget(repsLow: reps, load: kilograms.map { .absolute(kilograms: $0) }),
            authoredPosition: position,
            rest: RestRange(120),
            status: .complete,
            segments: [SetSegment(weight: kilograms, repetitions: reps)],
            completedAt: completedAt
        )
    }

    private func session(_ steps: [WorkoutStep], at date: Date) -> WorkoutSession {
        WorkoutSession(
            templateID: UUID(),
            templateName: "Upper",
            startedAt: date,
            completedAt: date,
            steps: steps
        )
    }

    func testEpleyEstimateAndItsRepetitionCeiling() {
        XCTAssertEqual(ExerciseMetrics.estimatedOneRepMax(kilograms: 100, repetitions: 1), 100)
        XCTAssertEqual(ExerciseMetrics.estimatedOneRepMax(kilograms: 60, repetitions: 5)!, 70, accuracy: 0.001)
        // Past twelve repetitions the estimate stops measuring strength.
        XCTAssertNil(ExerciseMetrics.estimatedOneRepMax(kilograms: 40, repetitions: 20))
        XCTAssertNil(ExerciseMetrics.estimatedOneRepMax(kilograms: 0, repetitions: 5))
    }

    /// Warm-up ramps must not create records, volume or progression evidence.
    func testWarmUpSetsAreInvisibleToMeasurement() {
        let history = [session([
            step("Bench press", reps: 10, kilograms: 200, type: .warmUp, completedAt: sessionDate),
            step("Bench press", reps: 5, kilograms: 65, type: .working, position: 1, completedAt: sessionDate),
        ], at: sessionDate)]

        let top = ExerciseMetrics.current(for: "Bench press", metric: .topSetLoad, history: history)

        XCTAssertEqual(top?.value, 65, "The 200 kg warm-up must never become a record")
        XCTAssertEqual(history[0].tonnage, 65 * 5)
        XCTAssertEqual(history[0].completedWorkingSetCount, 1)
    }

    func testMeasuredValuesCarryTheirProvenance() throws {
        let history = [session([
            step("Bench press", reps: 5, kilograms: 70, completedAt: sessionDate),
        ], at: sessionDate)]

        let value = try XCTUnwrap(
            ExerciseMetrics.current(for: "bench PRESS", metric: .topSetLoad, history: history)
        )

        XCTAssertEqual(value.value, 70)
        XCTAssertEqual(value.sessionName, "Upper")
        XCTAssertTrue(value.provenance.contains("Upper"))
    }

    func testMaxRepetitionsSumsSegmentsWithinOneSet() {
        var step = step("Ab wheel from knees", reps: 5, kilograms: nil, completedAt: sessionDate)
        step.segments = [SetSegment(repetitions: 5), SetSegment(repetitions: 2)]
        let history = [session([step], at: sessionDate)]

        let value = ExerciseMetrics.current(for: "Ab wheel from knees", metric: .maxRepetitions, history: history)

        XCTAssertEqual(value?.value, 7)
    }

    func testGoalProgressMeasuresFromBaselineAndProjectsForward() throws {
        let week0 = sessionDate
        let week1 = sessionDate.addingTimeInterval(604_800)
        let week2 = sessionDate.addingTimeInterval(2 * 604_800)
        let history = [
            session([step("Bench press", reps: 5, kilograms: 70, completedAt: week2)], at: week2),
            session([step("Bench press", reps: 5, kilograms: 67.5, completedAt: week1)], at: week1),
            session([step("Bench press", reps: 5, kilograms: 65, completedAt: week0)], at: week0),
        ]
        let goal = ExerciseGoal(
            exerciseName: "Bench press",
            metric: .topSetLoad,
            targetValue: 80,
            referenceRepetitions: 5,
            createdAt: week0
        )

        let progress = ExerciseMetrics.progress(for: goal, history: history)

        XCTAssertEqual(progress.current?.value, 70)
        XCTAssertEqual(progress.baseline?.value, 65)
        XCTAssertEqual(try XCTUnwrap(progress.fraction), (70 - 65) / (80 - 65), accuracy: 0.001)
        XCTAssertEqual(progress.remaining, 10)
        XCTAssertEqual(try XCTUnwrap(progress.ratePerWeek), 2.5, accuracy: 0.001)
        XCTAssertNotNil(progress.projectedDate)
        XCTAssertFalse(progress.isAchieved)
        XCTAssertEqual(progress.evidenceCount, 3)
    }

    func testGoalWithoutEvidenceReportsNothingRatherThanZero() {
        let goal = ExerciseGoal(exerciseName: "Snatch", metric: .estimatedOneRepMax, targetValue: 60)

        let progress = ExerciseMetrics.progress(for: goal, history: [])

        XCTAssertNil(progress.current)
        XCTAssertNil(progress.fraction)
        XCTAssertNil(progress.ratePerWeek)
        XCTAssertNil(progress.projectedDate)
        XCTAssertEqual(progress.evidenceCount, 0)
        XCTAssertFalse(progress.isAchieved)
    }

    func testAchievedGoalIsRecognisedInBothDirections() {
        let history = [session([step("Bench press", reps: 5, kilograms: 85, completedAt: sessionDate)], at: sessionDate)]
        let rising = ExerciseGoal(exerciseName: "Bench press", metric: .topSetLoad, targetValue: 80)

        XCTAssertTrue(ExerciseMetrics.progress(for: rising, history: history).isAchieved)

        var paceStep = step("Run", reps: 1, kilograms: nil, completedAt: sessionDate)
        paceStep.segments = [SetSegment(durationSeconds: 1_500, distanceKilometres: 5)]
        let paceHistory = [session([paceStep], at: sessionDate)]
        // 300 s/km recorded against a 330 s/km target: lower is better.
        let falling = ExerciseGoal(
            exerciseName: "Run",
            metric: .bestPaceSecondsPerKilometre,
            targetValue: 330
        )

        XCTAssertTrue(ExerciseMetrics.progress(for: falling, history: paceHistory).isAchieved)
    }

    func testTrendMovingAwayFromTheGoalProducesNoArrivalDate() {
        let week0 = sessionDate
        let week1 = sessionDate.addingTimeInterval(604_800)
        let history = [
            session([step("Bench press", reps: 5, kilograms: 60, completedAt: week1)], at: week1),
            session([step("Bench press", reps: 5, kilograms: 70, completedAt: week0)], at: week0),
        ]
        let goal = ExerciseGoal(
            exerciseName: "Bench press",
            metric: .topSetLoad,
            targetValue: 90,
            createdAt: week0
        )

        let progress = ExerciseMetrics.progress(for: goal, history: history)

        XCTAssertNil(progress.projectedDate, "A declining trend cannot arrive at a higher target")
    }
}

final class ProgressionEngineTests: XCTestCase {
    private let sessionDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func benchSession(reps: [Int], kilograms: Double) -> WorkoutSession {
        WorkoutSession(
            templateID: UUID(),
            templateName: "Upper",
            startedAt: sessionDate,
            completedAt: sessionDate,
            steps: reps.enumerated().map { index, count in
                WorkoutStep(
                    plannedSetID: UUID(),
                    exerciseName: "Bench press",
                    exerciseSlug: "bench-press",
                    cue: "",
                    label: "Working set \(index + 1) of 3",
                    kind: .strength,
                    stepType: .working,
                    target: SetTarget(repsLow: 5, repsHigh: 8, load: .absolute(kilograms: kilograms)),
                    authoredPosition: index,
                    rest: RestRange(180),
                    status: .complete,
                    segments: [SetSegment(weight: kilograms, repetitions: count)],
                    completedAt: sessionDate
                )
            }
        )
    }

    /// 8, 8, 8 clean at 65 kg is the authored trigger for 67.5 kg.
    func testAllSetsAtTopOfRangeAddsTheAuthoredIncrement() throws {
        let recommendation = try XCTUnwrap(ProgressionEngine.recommendation(
            for: "Bench press",
            rule: nil,
            history: [benchSession(reps: [8, 8, 8], kilograms: 65)]
        ))

        XCTAssertEqual(recommendation.action, .addLoad)
        XCTAssertEqual(recommendation.currentLoad, 65)
        XCTAssertEqual(recommendation.recommendedLoad, 67.5)
        XCTAssertEqual(recommendation.lastSessionRepetitions, [8, 8, 8])
        XCTAssertTrue(recommendation.rationale.contains("3 × 8"))
    }

    /// 8, 7, 6 stays at 65 kg and adds repetitions instead.
    func testMidRangeHoldsTheLoadAndAddsRepetitions() throws {
        let recommendation = try XCTUnwrap(ProgressionEngine.recommendation(
            for: "Bench press",
            rule: nil,
            history: [benchSession(reps: [8, 7, 6], kilograms: 65)]
        ))

        XCTAssertEqual(recommendation.action, .addRepetitions)
        XCTAssertEqual(recommendation.recommendedLoad, 65)
        XCTAssertEqual(recommendation.evidenceSummary, "8, 7, 6 at 65 kg")
    }

    /// 5, 4, 3 falls below the range floor, so the load comes down.
    func testFallingBelowTheRangeReducesTheLoad() throws {
        let recommendation = try XCTUnwrap(ProgressionEngine.recommendation(
            for: "Bench press",
            rule: nil,
            history: [benchSession(reps: [5, 4, 3], kilograms: 65)]
        ))

        XCTAssertEqual(recommendation.action, .reduceLoad)
        XCTAssertEqual(recommendation.recommendedLoad, 62.5)
    }

    func testNoEvidenceProducesNoRecommendation() {
        XCTAssertNil(ProgressionEngine.recommendation(for: "Bench press", rule: nil, history: []))
    }

    func testOnlyTheMostRecentSessionInformsTheSuggestion() throws {
        let older = benchSession(reps: [8, 8, 8], kilograms: 65)
        var recent = benchSession(reps: [6, 6, 6], kilograms: 67.5)
        recent.startedAt = sessionDate.addingTimeInterval(604_800)
        recent.completedAt = recent.startedAt
        recent.steps = recent.steps.map { step in
            var next = step
            next.completedAt = recent.startedAt
            return next
        }

        let recommendation = try XCTUnwrap(ProgressionEngine.recommendation(
            for: "Bench press",
            rule: nil,
            history: [recent, older]
        ))

        XCTAssertEqual(recommendation.action, .addRepetitions)
        XCTAssertEqual(recommendation.currentLoad, 67.5)
    }
}

// MARK: - Catalogue

final class FormattingTests: XCTestCase {
    /// An estimated 1RM of 72.5 x (1 + 8/30) is 91.8333... — binary floating-point
    /// precision must never reach the interface.
    func testTrimmedStringNeverLeaksFloatingPointPrecision() {
        XCTAssertEqual((72.5 * (1 + 8.0 / 30)).trimmedString, "91.83")
        XCTAssertEqual(2.5000000000000007.trimmedString, "2.5")
        XCTAssertEqual(65.0.trimmedString, "65")
        XCTAssertEqual(72.5.trimmedString, "72.5")
        XCTAssertEqual(0.trimmedString, "0")
        XCTAssertEqual(Double.infinity.trimmedString, "—")
    }

    func testKilogramValuesRoundToOneDecimal() {
        XCTAssertEqual((72.5 * (1 + 8.0 / 30)).kilogramString, "91.8")
        XCTAssertEqual(72.5.kilogramString, "72.5")
        XCTAssertEqual(65.0.kilogramString, "65")
        XCTAssertEqual(MetricKind.estimatedOneRepMax.format(72.5 * (1 + 8.0 / 30)), "91.8 kg")
        XCTAssertEqual(MetricKind.topSetLoad.format(72.5), "72.5 kg")
    }

    func testDurationAndRestLabels() {
        XCTAssertEqual(45.durationLabel, "45 sec")
        XCTAssertEqual(120.durationLabel, "2 min")
        XCTAssertEqual(150.durationLabel, "2 min 30 sec")
        XCTAssertEqual(RestRange(lowSeconds: 150, highSeconds: 180).displayString, "2.5–3 min")
        XCTAssertEqual(RestRange(90).displayString, "1.5 min")
        XCTAssertEqual(RestRange.none.displayString, "No rest")
    }

    func testTargetDisplayCombinesLoadAndRepetitionRange() {
        let target = SetTarget(
            repsLow: 5,
            repsHigh: 8,
            load: .absolute(kilograms: 65),
            repsInReserve: 2
        )

        XCTAssertEqual(target.displayString, "65 kg · 5–8 reps")
        XCTAssertEqual(target.qualifiers, ["2 RIR"])
    }

    func testPerSideAndRelativeLoadTargetsReadCorrectly() {
        XCTAssertEqual(
            SetTarget(repsLow: 8, repsHigh: 12, load: .chooseLoad, perSide: true).displayString,
            "Choose load · 8–12 reps per side"
        )
        XCTAssertEqual(
            SetTarget(repsLow: 3, load: .percentOfOneRepMax(70)).displayString,
            "70% 1RM · 3 reps"
        )
        XCTAssertEqual(
            SetTarget(repsLow: 8, load: .bodyweight(plusKilograms: 10)).displayString,
            "Bodyweight + 10 kg · 8 reps"
        )
        XCTAssertEqual(SetTarget().displayString, "Complete")
    }
}

final class ExerciseCatalogueTests: XCTestCase {
    func testEverySlugIsUnique() {
        let slugs = ExerciseCatalogue.all.map(\.slug)

        XCTAssertEqual(Set(slugs).count, slugs.count)
    }

    func testEveryDefinitionDeclaresAtLeastOnePillar() {
        for definition in ExerciseCatalogue.all {
            XCTAssertFalse(definition.pillars.isEmpty, definition.slug)
        }
    }

    func testAllFourPillarsAreCovered() {
        for pillar in Pillar.allCases {
            XCTAssertFalse(
                ExerciseCatalogue.definitions(for: pillar).isEmpty,
                "No movements train \(pillar.title)"
            )
        }
    }

    func testNameAndAliasLookupIsCaseInsensitive() {
        XCTAssertEqual(ExerciseCatalogue.match(name: "  BENCH PRESS ")?.slug, "bench-press")
        XCTAssertEqual(ExerciseCatalogue.match(name: "rdl")?.slug, "romanian-deadlift")
        XCTAssertEqual(ExerciseCatalogue.match(name: "leg press")?.slug, "hack-squat-or-leg-press")
        XCTAssertNil(ExerciseCatalogue.match(name: "not a movement"))
    }

    func testSearchMatchesNamesAndAliases() {
        XCTAssertTrue(ExerciseCatalogue.search("squat").contains { $0.slug == "front-squat" })
        XCTAssertTrue(ExerciseCatalogue.search("rdl").contains { $0.slug == "romanian-deadlift" })
    }
}
