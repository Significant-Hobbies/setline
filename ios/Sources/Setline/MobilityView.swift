import SetlineCore
import SwiftUI

/// Head-to-toe mobility curriculum — a periodic movement baseline alongside the
/// Benchmarks scorecard. Three views: cards (record the 15 checks), snapshots
/// (saved assessments), and guide (protocol, safety, and sources).
///
/// This is a movement-check curriculum, not a validated clinical assessment:
/// there is deliberately no composite score and no normative pass mark.
struct MobilityView: View {
    @Environment(AppModel.self) private var model
    @State private var activeView: MobilitySubview = .cards
    @State private var snapshotDate = Date.now
    @State private var showClearConfirmation = false

    enum MobilitySubview: String, CaseIterable {
        case cards, snapshots, guide

        var label: String {
            switch self {
            case .cards: "Cards"
            case .snapshots: "Snapshots"
            case .guide: "Guide"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Establish a starting point on every card, practise the few that need it, and retest under the same setup.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                subviewNav
                switch activeView {
                case .cards: cardsContent
                case .snapshots: snapshotsContent
                case .guide: guideContent
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .setlineBackground()
        .navigationTitle("Mobility")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear current mobility records?", isPresented: $showClearConfirmation) {
            Button("Clear records", role: .destructive) {
                Task { await model.clearMobilityRecords() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved snapshots and your practice set will be kept.")
        }
    }

    // MARK: - Subview navigation

    private var subviewNav: some View {
        HStack(spacing: 0) {
            ForEach(MobilitySubview.allCases, id: \.self) { subview in
                Button {
                    activeView = subview
                } label: {
                    Text(subview.label)
                        .font(.subheadline.weight(activeView == subview ? .black : .semibold))
                        .foregroundStyle(activeView == subview ? SetlinePalette.ink : SetlinePalette.ink.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(activeView == subview ? SetlinePalette.lime : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(SetlinePalette.steel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }

    // MARK: - Cards

    @ViewBuilder
    private var cardsContent: some View {
        statsRow
        practiseSetSection
        retestNote
        cardGroup("Main progression tracks", cards: MobilityCatalog.cards.filter { $0.role == .mainTrack })
        cardGroup("Full-body checks", cards: MobilityCatalog.cards.filter { $0.role == .coverageCheck })
        cardGroup("Functional benchmarks", cards: MobilityCatalog.functionalBenchmarks)
        snapshotBar
        bottomNote
    }

    private var statsRow: some View {
        let coverage = MobilityEngine.coverage(in: model.document.mobility)
        return HStack(spacing: 10) {
            mobilityStat("\(coverage.cardsStarted)", "/ 15", "Cards started", SetlinePalette.lime)
            mobilityStat("\(coverage.recorded)", "/ \(coverage.total)", "Checks recorded", SetlinePalette.blue)
            mobilityStat("\(model.document.mobility.practising.count)", "/ \(MobilityEngine.maxPractising)", "Practising", SetlinePalette.paper)
        }
    }

    private func mobilityStat(_ value: String, _ suffix: String?, _ label: String, _ bg: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                if let suffix {
                    Text(suffix)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// The chosen practice set — a few tracks, not the whole library.
    @ViewBuilder
    private var practiseSetSection: some View {
        let practising = model.document.mobility.practising.compactMap { MobilityCatalog.card(for: $0) }
        if !practising.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Your practice set")
                ForEach(practising) { card in
                    NavigationLink {
                        MobilityCardView(card: card)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "repeat")
                                .font(.subheadline)
                                .frame(width: 32, height: 32)
                                .background(SetlinePalette.lime.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(card.name).font(.subheadline.weight(.bold))
                                Text(MobilityEngine.nextCheckpoint(for: card, in: model.document.mobility))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(SetlinePalette.ink)
                    }
                    .frame(minHeight: 44)
                }
            }
        }
    }

    @ViewBuilder
    private var retestNote: some View {
        if let due = MobilityEngine.retestDueDate(in: model.document.mobility) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.7))
                Text(
                    due <= .now
                        ? "A retest under the same setup is due — the suggested cadence is about every two weeks."
                        : "Next suggested retest under the same setup: \(due.formatted(date: .abbreviated, time: .omitted))."
                )
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.75))
            }
            .padding(14)
            .background(SetlinePalette.blue.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func cardGroup(_ title: String, cards: [MobilityCardDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            VStack(spacing: 0) {
                ForEach(cards) { card in
                    NavigationLink {
                        MobilityCardView(card: card)
                    } label: {
                        MobilityCardRow(card: card)
                    }
                    if card.id != cards.last?.id {
                        InkRule()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(SetlinePalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var snapshotBar: some View {
        HStack {
            DatePicker("", selection: $snapshotDate, in: ...Date.now, displayedComponents: .date)
                .labelsHidden()
                .frame(minHeight: 36)
            Button {
                Task { await model.saveMobilityAssessment(date: snapshotDate) }
            } label: {
                Label("Save snapshot", systemImage: "plus")
                    .font(.caption.weight(.bold))
            }
            .frame(minHeight: 36)
        }
    }

    private var bottomNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            Text("A starting point for practice, not a diagnosis or a percentage of normal mobility. A blank check is unknown, and a symptom stop is a reason to pause — never a score of zero.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.72))
        }
        .padding(.top, 8)
    }

    // MARK: - Snapshots

    @ViewBuilder
    private var snapshotsContent: some View {
        let history = model.document.mobility.history
        if history.isEmpty {
            ContentUnavailableView(
                "No snapshots yet",
                systemImage: "calendar.badge.plus",
                description: Text("Record your checks on the Cards tab, then save a snapshot. Snapshots preserve the setups and results as they stood that day.")
            )
            .frame(minHeight: 260)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(history) { snapshot in
                    MobilitySnapshotRow(snapshot: snapshot)
                }
            }
            Text("A snapshot is a logging date, not proof that every check was performed that day. Untested checks stay untested inside it.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.72))
                .padding(.top, 8)
        }
    }

    // MARK: - Guide

    private var guideContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find something achievable. Progress from there.")
                .font(.system(.title, design: .rounded, weight: .black))
                .tracking(-0.8)
            Text("A bounded head-to-toe curriculum — not a diagnostic battery, a rehabilitation protocol, or a population score.")
                .font(.body)
                .foregroundStyle(.secondary)
            guideCard("Who this is for", body: MobilityCatalog.eligibility)
            guideCard("When to stop", body: MobilityCatalog.stopRule + " Marking a check “Stopped by symptoms” records that honestly — it is never zero mobility and never an instruction to stretch harder.")
            guideCard("Progress, not maximum range", body: MobilityCatalog.rangeLimit + " When a direction is already comfortable and useful, maintenance is a valid outcome.")
            guideCard("How to assess", body: MobilityCatalog.protocolNotes.joined(separator: " "))
            guideCard("What a result means", body: "Record the highest repeatable checkpoint within a defined setup. A different chair height, arm position, or stance starts a new measurement series — it is not automatically more range. Confidence and symptoms stay separate from the result.")
            guideCard("Functional benchmarks", body: "The squat-to-target and floor-transfer cards show whether practice transfers into useful movement. They record the route, support, and setup you used — a milestone in practical capability, not a verdict on any single joint.")
            sourcesCard
            Button {
                showClearConfirmation = true
            } label: {
                Label("Clear current records", systemImage: "trash")
                    .font(.caption.weight(.bold))
            }
            .frame(minHeight: 40)
            .padding(.top, 8)
        }
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources").font(.headline.weight(.black))
            Text("These references support the underlying exercises and published protocols — not this assembled curriculum or its checkpoints.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.75))
            ForEach(MobilityCatalog.sources) { source in
                if let url = URL(string: source.url) {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.title)
                                .font(.footnote.weight(.semibold))
                            Text(source.supports)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 36)
                }
            }
        }
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func guideCard(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline.weight(.black))
            Text(body)
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.75))
        }
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Card row

/// One catalogue row in the overview: coverage, symptom flags, and the next
/// checkpoint — never a score.
struct MobilityCardRow: View {
    @Environment(AppModel.self) private var model
    let card: MobilityCardDefinition

    var body: some View {
        let summary = MobilityEngine.summary(for: card, in: model.document.mobility)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(card.name).font(.headline.weight(.black))
                    if model.document.mobility.practising.contains(card.id) {
                        Text("PRACTISING")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(SetlinePalette.lime)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                HStack(spacing: 8) {
                    Text(summary.hasBaseline ? "\(summary.recorded) of \(summary.total) checks recorded" : "Not tested")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.secondary)
                    if summary.symptomBlocked > 0 {
                        Text("\(summary.symptomBlocked) stopped by symptoms")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(SetlinePalette.coral.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                if summary.hasBaseline {
                    Text("Next: \(MobilityEngine.nextCheckpoint(for: card, in: model.document.mobility))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(SetlinePalette.ink)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card detail

/// One card: the setup, its separately-recorded checks, valid-attempt rules,
/// practice options, and the measurement caveat.
struct MobilityCardView: View {
    @Environment(AppModel.self) private var model
    let card: MobilityCardDefinition

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                setupBlock
                checksBlock
                rulesBlock
                practiceBlock
                sourcesBlock
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .setlineBackground()
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(card.role.title.uppercased())
                    .font(.caption2.weight(.black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(card.role == .functionalBenchmark ? SetlinePalette.blue.opacity(0.7) : SetlinePalette.steel.opacity(0.7))
                    .clipShape(Capsule())
                Text(card.regions.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.6))
                Text(card.measurementCaveat)
                    .font(.footnote)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.75))
            }
            .padding(12)
            .background(SetlinePalette.blue.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var setupBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Assessment setup")
            Text(card.assessmentSetup)
                .font(.subheadline)
                .foregroundStyle(SetlinePalette.ink.opacity(0.85))
            Text("Keep separate: \(card.recordSeparately.joined(separator: " · ")).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var checksBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Checks")
            ForEach(card.checks) { check in
                MobilityCheckEditor(card: card, check: check)
            }
        }
    }

    private var rulesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "A valid attempt")
            ForEach(card.validAttemptRules, id: \.self) { rule in
                Label(rule, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.75))
            }
        }
    }

    private var practiceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Practice")
                Spacer()
                practiseToggle
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Start: \(card.easyPractice)")
                    .font(.footnote.weight(.semibold))
                ForEach(card.progressionOptions, id: \.self) { option in
                    Label(option, systemImage: "arrow.right")
                        .font(.footnote)
                        .foregroundStyle(SetlinePalette.ink.opacity(0.75))
                }
            }
            let exercises = MobilityEngine.practiceExercises(for: card)
            if !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("In the exercise catalogue")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SetlinePalette.ink.opacity(0.6))
                    ForEach(exercises) { definition in
                        NavigationLink {
                            ExerciseDetailView(exerciseName: definition.name)
                        } label: {
                            Label(definition.name, systemImage: "figure.cooldown")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 32)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var practiseToggle: some View {
        let isPractising = model.document.mobility.practising.contains(card.id)
        Button {
            Task { await model.toggleMobilityPractice(cardID: card.id) }
        } label: {
            Text(isPractising ? "Practising" : "Practise this")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isPractising ? SetlinePalette.lime : SetlinePalette.ink)
                .foregroundStyle(isPractising ? SetlinePalette.ink : SetlinePalette.chalk)
                .clipShape(Capsule())
        }
        .disabled(!isPractising && !MobilityEngine.canPractise(card.id, in: model.document.mobility))
        .frame(minHeight: 32)
    }

    @ViewBuilder
    private var sourcesBlock: some View {
        let sources = card.sourceIDs.compactMap { MobilityCatalog.source(for: $0) }
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Sources")
                ForEach(sources) { source in
                    if let url = URL(string: source.url) {
                        Link(destination: url) {
                            Text(source.title)
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 32)
                    }
                }
            }
        }
    }
}

// MARK: - Check editor

/// Recording UI for one check: a status picker per side, then setup, endpoint,
/// assistance, confidence, and a separate symptom field.
struct MobilityCheckEditor: View {
    @Environment(AppModel.self) private var model
    let card: MobilityCardDefinition
    let check: MobilityCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(check.label)
                .font(.subheadline.weight(.bold))
            if check.perSide {
                slotEditor(side: .left)
                slotEditor(side: .right)
            } else {
                slotEditor(side: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func slotEditor(side: BodySide?) -> some View {
        MobilitySlotEditor(card: card, check: check, side: side)
    }
}

/// One check × side slot. Edits push straight into the document; a re-recorded
/// slot keeps its earlier results in the card's superseded series.
struct MobilitySlotEditor: View {
    @Environment(AppModel.self) private var model
    let card: MobilityCardDefinition
    let check: MobilityCheck
    let side: BodySide?

    private var slot: String {
        MobilityCardState.key(checkID: check.id, side: side)
    }

    private var record: MobilityCheckRecord {
        model.document.mobility.cards[card.id]?.results[slot] ?? .init()
    }

    private var superseded: [MobilityCheckRecord] {
        model.document.mobility.cards[card.id]?.superseded[slot] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let side {
                    Text(side.title.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(SetlinePalette.ink.opacity(0.55))
                }
                Spacer()
                statusPicker
            }
            if record.isRecorded {
                recordedFields
            }
            seriesNote
        }
        .padding(10)
        .background(SetlinePalette.chalk)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var statusPicker: some View {
        Menu {
            ForEach(MobilityResultStatus.allCases, id: \.self) { status in
                Button(status.title) {
                    // "Not tested" clears the slot rather than leaving a stale
                    // result carrying a timestamp.
                    var next = status == .notTested ? MobilityCheckRecord() : record
                    next.status = status
                    Task { await model.recordMobilityCheck(cardID: card.id, checkID: check.id, side: side, record: next) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(record.status.title)
                    .font(.caption.weight(.bold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(record.status == .symptomBlocked ? SetlinePalette.coral.opacity(0.3) : SetlinePalette.steel.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("\(check.label)\(side.map { " \($0.title)" } ?? "") result")
    }

    @ViewBuilder
    private var recordedFields: some View {
        MobilitySlotFields(card: card, check: check, side: side, record: record)
        if record.status == .symptomBlocked {
            Text("Stopped by symptoms. " + MobilityCatalog.stopRule)
                .font(.caption)
                .foregroundStyle(SetlinePalette.coral)
        }
    }

    @ViewBuilder
    private var seriesNote: some View {
        if let previous = MobilityEngine.previousSameSetup(cardID: card.id, slot: slot, in: model.document.mobility) {
            Text("Earlier, same setup: \(previous.status.title)\(previous.distanceCentimetres.map { " · \($0.trimmedString) cm" } ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if !superseded.isEmpty {
            Text("Earlier results used a different setup — kept as a separate series.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Editable fields on a recorded slot: setup, endpoint, assistance, confidence,
/// and symptoms. Each pushes into the document on change.
struct MobilitySlotFields: View {
    @Environment(AppModel.self) private var model
    let card: MobilityCardDefinition
    let check: MobilityCheck
    let side: BodySide?

    @State private var setupText: String
    @State private var endpointText: String
    @State private var distanceText: String
    @State private var assistanceText: String
    @State private var symptomsText: String

    init(card: MobilityCardDefinition, check: MobilityCheck, side: BodySide?, record: MobilityCheckRecord) {
        self.card = card
        self.check = check
        self.side = side
        _setupText = State(initialValue: record.setup)
        _endpointText = State(initialValue: record.endpoint)
        _distanceText = State(initialValue: record.distanceCentimetres.map { $0.trimmedString } ?? "")
        _assistanceText = State(initialValue: record.assistance)
        _symptomsText = State(initialValue: record.symptoms)
    }

    private var record: MobilityCheckRecord {
        model.document.mobility.cards[card.id]?.results[
            MobilityCardState.key(checkID: check.id, side: side)
        ] ?? .init()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            field("Setup", text: $setupText, prompt: "Position, support, surface") { value in
                update { $0.setup = value }
            }
            switch check.endpoint {
            case .centimetres:
                HStack(spacing: 6) {
                    TextField("", text: $distanceText)
                        .keyboardType(.decimalPad)
                        .font(.system(.title3, design: .rounded).monospacedDigit().weight(.black))
                        .frame(minHeight: 40)
                        .padding(.horizontal, 10)
                        .background(SetlinePalette.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("\(check.label)\(side.map { " \($0.title)" } ?? "") centimetres")
                        .onChange(of: distanceText) { _, newValue in
                            update { $0.distanceCentimetres = Double(newValue.trimmingCharacters(in: .whitespaces)) }
                        }
                    Text("cm toe-to-wall")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            case .landmark:
                field("Endpoint", text: $endpointText, prompt: "Where the movement ended") { value in
                    update { $0.endpoint = value }
                }
            case .completion:
                EmptyView()
            }
            field("Assistance", text: $assistanceText, prompt: "None, or what helped") { value in
                update { $0.assistance = value }
            }
            HStack {
                Text("Confidence")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.6))
                Spacer()
                Picker("Confidence", selection: confidenceBinding) {
                    ForEach(MobilityConfidence.allCases, id: \.self) { confidence in
                        Text(confidence.title).tag(confidence)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
            }
            field("Symptoms", text: $symptomsText, prompt: "None, or what you felt") { value in
                update { $0.symptoms = value }
            }
        }
    }

    private var confidenceBinding: Binding<MobilityConfidence> {
        Binding(
            get: { record.confidence },
            set: { value in update { $0.confidence = value } }
        )
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        prompt: String,
        onCommit: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(SetlinePalette.ink.opacity(0.55))
            TextField(prompt, text: text)
                .font(.subheadline)
                .frame(minHeight: 40)
                .padding(.horizontal, 10)
                .background(SetlinePalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: text.wrappedValue) { _, newValue in onCommit(newValue) }
        }
    }

    private func update(_ change: (inout MobilityCheckRecord) -> Void) {
        var next = record
        change(&next)
        Task { await model.recordMobilityCheck(cardID: card.id, checkID: check.id, side: side, record: next) }
    }
}

// MARK: - Snapshot row

struct MobilitySnapshotRow: View {
    let snapshot: MobilityAssessment

    var body: some View {
        let coverage = MobilityEngine.coverage(
            in: MobilityState(cards: snapshot.cards, practising: snapshot.practising)
        )
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(coverage.cardsStarted) of 15 cards")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text("\(coverage.recorded) of \(coverage.total) checks recorded · \(snapshot.practising.count) in the practice set")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
