import XCTest
@testable import SetlineCore

final class MobilityTests: XCTestCase {
    // MARK: - Catalogue

    func testCatalogueHasFifteenCardsAndTwoBenchmarks() {
        XCTAssertEqual(MobilityCatalog.cards.count, 15)
        XCTAssertEqual(MobilityCatalog.functionalBenchmarks.count, 2)
        XCTAssertEqual(MobilityCatalog.cards.filter { $0.role == .mainTrack }.count, 10)
        XCTAssertEqual(MobilityCatalog.cards.filter { $0.role == .coverageCheck }.count, 5)
    }

    func testAllCardAndCheckIDsAreUnique() {
        let cardIDs = MobilityCatalog.all.map(\.id)
        XCTAssertEqual(Set(cardIDs).count, cardIDs.count)
        for card in MobilityCatalog.all {
            let checkIDs = card.checks.map(\.id)
            XCTAssertEqual(Set(checkIDs).count, checkIDs.count, "\(card.id) has duplicate check ids")
        }
    }

    func testEveryPracticeSlugResolvesToACatalogueExercise() {
        for card in MobilityCatalog.all {
            for slug in card.practiceSlugs {
                XCTAssertNotNil(
                    ExerciseCatalogue.definition(slug: slug),
                    "\(card.id) practice slug \(slug) is not in ExerciseCatalogue"
                )
            }
        }
    }

    func testEverySourceIDResolves() {
        for card in MobilityCatalog.all {
            for sourceID in card.sourceIDs {
                XCTAssertNotNil(MobilityCatalog.source(for: sourceID), "\(card.id) references missing source \(sourceID)")
            }
        }
    }

    func testKneeToWallIsTheOnlyNumericEndpoint() {
        let numeric = MobilityCatalog.all.flatMap(\.checks).filter { $0.endpoint == .centimetres }
        XCTAssertEqual(numeric.count, 1)
        XCTAssertEqual(numeric.first?.id, "dorsiflexion")
    }

    // MARK: - Recording

    func testPerSideResultsAreIndependent() {
        var cardState = MobilityCardState()
        cardState.record(
            MobilityCheckRecord(status: .completedAsShown),
            checkID: "internal-rotation",
            side: .left
        )
        cardState.record(
            MobilityCheckRecord(status: .unsure),
            checkID: "internal-rotation",
            side: .right
        )
        XCTAssertEqual(
            cardState.results["internal-rotation.left"]?.status,
            .completedAsShown
        )
        XCTAssertEqual(
            cardState.results["internal-rotation.right"]?.status,
            .unsure
        )
    }

    func testReRecordingKeepsThePreviousResultInTheSeries() {
        var cardState = MobilityCardState()
        cardState.record(
            MobilityCheckRecord(status: .modifiedOrAssisted, setup: "towel, 45°"),
            checkID: "external-rotation",
            side: .left
        )
        cardState.record(
            MobilityCheckRecord(status: .completedAsShown, setup: "towel, 45°"),
            checkID: "external-rotation",
            side: .left
        )
        let slot = "external-rotation.left"
        XCTAssertEqual(cardState.results[slot]?.status, .completedAsShown)
        XCTAssertEqual(cardState.superseded[slot]?.count, 1)
        XCTAssertEqual(cardState.superseded[slot]?.first?.status, .modifiedOrAssisted)
    }

    func testIdenticalReRecordDoesNotGrowTheSeries() {
        var cardState = MobilityCardState()
        let record = MobilityCheckRecord(status: .completedAsShown, setup: "chair")
        cardState.record(record, checkID: "rotation", side: .left)
        let stamped = cardState.results["rotation.left"]
        XCTAssertNotNil(stamped?.recordedAt, "A recorded result gets a timestamp")
        let changed = cardState.record(stamped!, checkID: "rotation", side: .left)
        XCTAssertFalse(changed)
        XCTAssertEqual(cardState.superseded["rotation.left"]?.count ?? 0, 0)
    }

    // MARK: - Engine

    func testCoverageCountsSlotsNotCards() {
        var state = MobilityState()
        var m07 = MobilityCardState()
        // M07 seated hip rotations: two per-side checks = four slots.
        m07.record(.init(status: .completedAsShown), checkID: "internal-rotation", side: .left)
        m07.record(.init(status: .unsure), checkID: "internal-rotation", side: .right)
        state.cards["M07"] = m07

        let summary = MobilityEngine.summary(for: MobilityCatalog.card(for: "M07")!, in: state)
        XCTAssertEqual(summary.total, 4)
        XCTAssertEqual(summary.recorded, 2)
        XCTAssertEqual(summary.demonstrated, 1)
        XCTAssertEqual(summary.unsure, 1)

        let coverage = MobilityEngine.coverage(in: state)
        XCTAssertEqual(coverage.cardsStarted, 1)
        XCTAssertEqual(coverage.recorded, 2)
    }

    func testSymptomBlockedIsNotDemonstrated() {
        var state = MobilityState()
        var m10 = MobilityCardState()
        m10.record(.init(status: .symptomBlocked, symptoms: "pinching"), checkID: "dorsiflexion", side: .left)
        state.cards["M10"] = m10

        let summary = MobilityEngine.summary(for: MobilityCatalog.card(for: "M10")!, in: state)
        XCTAssertEqual(summary.symptomBlocked, 1)
        XCTAssertEqual(summary.demonstrated, 0)
    }

    func testSameSeriesRequiresMatchingSetup() {
        let a = MobilityCheckRecord(status: .completedAsShown, setup: "towel, 45°")
        let b = MobilityCheckRecord(status: .completedAsShown, setup: "towel, 45° ")
        let c = MobilityCheckRecord(status: .completedAsShown, setup: "towel, 90°")
        XCTAssertTrue(MobilityEngine.sameSeries(a, b))
        XCTAssertFalse(MobilityEngine.sameSeries(a, c))
    }

    func testPreviousSameSetupSkipsDifferentSetupRecords() {
        var state = MobilityState()
        var cardState = MobilityCardState()
        let slot = MobilityCardState.key(checkID: "dorsiflexion", side: .left)
        cardState.record(.init(status: .completedAsShown, setup: "barefoot", distanceCentimetres: 8), checkID: "dorsiflexion", side: .left)
        cardState.record(.init(status: .completedAsShown, setup: "shoes", distanceCentimetres: 12), checkID: "dorsiflexion", side: .left)
        cardState.record(.init(status: .completedAsShown, setup: "barefoot", distanceCentimetres: 9), checkID: "dorsiflexion", side: .left)
        state.cards["M10"] = cardState

        let previous = MobilityEngine.previousSameSetup(cardID: "M10", slot: slot, in: state)
        XCTAssertEqual(previous?.distanceCentimetres, 8, "Only the same-setup record is comparable")
    }

    func testPractiseSelectionIsCappedAtFour() {
        var state = MobilityState()
        state.practising = ["M01", "M03", "M05", "M10"]
        XCTAssertFalse(MobilityEngine.canPractise("M07", in: state))
        XCTAssertTrue(MobilityEngine.canPractise("M01", in: state), "Already-selected cards can be deselected")
        state.practising.removeLast()
        XCTAssertTrue(MobilityEngine.canPractise("M07", in: state))
    }

    func testNextCheckpointStartsAtEasyPractice() {
        let card = MobilityCatalog.card(for: "M05")!
        let state = MobilityState()
        XCTAssertEqual(MobilityEngine.nextCheckpoint(for: card, in: state), card.easyPractice)

        var progressed = state
        var cardState = MobilityCardState()
        cardState.record(.init(status: .completedAsShown), checkID: "hip-flexion", side: .left)
        progressed.cards["M05"] = cardState
        XCTAssertEqual(MobilityEngine.nextCheckpoint(for: card, in: progressed), card.progressionOptions.first)
    }

    func testRetestGuidanceNeedsARecord() {
        XCTAssertNil(MobilityEngine.retestDueDate(in: MobilityState()))
        var state = MobilityState()
        state.updated["M01"] = .now
        XCTAssertNotNil(MobilityEngine.retestDueDate(in: state))
    }

    // MARK: - Document and persistence

    func testDocumentDecodesWithoutMobility() throws {
        let document = SetlineDocument.initial
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: encoder.encode(document)) as? [String: Any]
        )
        object.removeValue(forKey: "mobility")
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SetlineDocument.self, from: data)
        XCTAssertEqual(decoded.mobility, .initial)
    }

    func testMobilityStateSurvivesExportRoundTrip() throws {
        // ISO 8601 export truncates to whole seconds, so the fixture uses them.
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        var document = SetlineDocument.initial
        var cardState = MobilityCardState()
        cardState.record(
            .init(status: .completedAsShown, setup: "barefoot", distanceCentimetres: 9.5, recordedAt: day),
            checkID: "dorsiflexion",
            side: .right
        )
        document.mobility.cards["M10"] = cardState
        document.mobility.updated["M10"] = day
        document.mobility.practising = ["M10"]
        document.mobility.history.append(
            MobilityAssessment(date: day, cards: document.mobility.cards, practising: ["M10"])
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SetlineDocument.self, from: data)

        XCTAssertEqual(decoded.mobility, document.mobility)
    }
}
