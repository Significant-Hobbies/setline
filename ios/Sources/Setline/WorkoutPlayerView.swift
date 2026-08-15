import SetlineCore
import SwiftUI

struct WorkoutPlayerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showFinishConfirmation = false

    var body: some View {
        NavigationStack {
            if let session = model.document.activeSession {
                VStack(spacing: 0) {
                    sessionBar(session)
                    if let rest = session.rest {
                        RestBoard(rest: rest, next: session.currentStep)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    } else if let step = session.currentStep {
                        AttemptBoard(step: step)
                            .id(step.id)
                    } else {
                        completionBoard(session)
                    }
                    SetRail(session: session)
                }
                .background(SetlinePalette.chalk)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: session.rest != nil)
            } else {
                ContentUnavailableView("Workout complete", systemImage: "checkmark.seal.fill")
            }
        }
        .interactiveDismissDisabled(model.document.activeSession != nil)
        .confirmationDialog("Finish this workout?", isPresented: $showFinishConfirmation) {
            Button("Finish and save") { Task { await model.finishWorkout() } }
            Button("Keep training", role: .cancel) {}
        } message: {
            Text("Any remaining planned sets will be recorded as skipped.")
        }
    }

    private func sessionBar(_ session: WorkoutSession) -> some View {
        HStack(spacing: 14) {
            Button {
                model.isWorkoutPresented = false
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 44, height: 44)
                    .background(SetlinePalette.chalk.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Return to Today")
            VStack(alignment: .leading, spacing: 2) {
                Text(session.templateName)
                    .font(.headline.weight(.black))
                    .lineLimit(1)
                Text("\(session.completedCount) / \(session.steps.count) recorded")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(SetlinePalette.chalk.opacity(0.68))
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date.timeIntervalSince(session.startedAt).durationClock)
                    .font(.headline.monospacedDigit().weight(.black))
                    .accessibilityLabel("Workout elapsed time")
            }
            Button("Finish") { showFinishConfirmation = true }
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(SetlinePalette.ink)
        .foregroundStyle(SetlinePalette.chalk)
    }

    private func completionBoard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 42))
                .foregroundStyle(SetlinePalette.lime)
            Text("The plan is recorded.")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
            Text("\(session.completedWorkingSetCount) working sets · \(session.completedCount) steps completed · \(session.steps.count - session.completedCount) skipped")
                .font(.headline.monospacedDigit())
            if session.tonnage > 0 {
                Text("\(session.tonnage.trimmedString) kg total load moved")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(SetlinePalette.ink.opacity(0.7))
            }
            Button("Save workout") { Task { await model.finishWorkout() } }
                .buttonStyle(ActionSlabStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}

/// One editable piece of the set being recorded.
private struct SegmentDraft: Identifiable, Equatable {
    let id = UUID()
    var weight = ""
    var repetitions = ""
    var duration = ""
    var distance = ""
    var rpe = ""
    var side: BodySide?

    var isBlank: Bool {
        weight.isEmpty && repetitions.isEmpty && duration.isEmpty && distance.isEmpty
    }

    func segment(kind: ActivityKind) -> SetSegment? {
        let seconds = Int(duration).map { kind == .cardio ? $0 * 60 : $0 }
        let segment = SetSegment(
            weight: Double(weight),
            repetitions: Int(repetitions),
            durationSeconds: seconds,
            distanceKilometres: Double(distance),
            rpe: Double(rpe),
            side: side
        )
        return segment.isEmpty ? nil : segment
    }
}

private struct AttemptBoard: View {
    @Environment(AppModel.self) private var model
    let step: WorkoutStep

    @State private var drafts: [SegmentDraft] = []
    @State private var quickEntry = ""
    @State private var isQuickEntryShown = false
    @State private var workStartedAt: Date?
    @State private var accumulatedWorkSeconds = 0
    /// The decimal keypad has no return key, so entry needs an explicit way out.
    @FocusState private var isEnteringNumbers: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heading
                targetBlock
                InkRule()
                workTimer
                InkRule()
                actualInputs
                quickEntryBlock
                Button {
                    Task {
                        await model.completeCurrent(segments: segments, workSeconds: recordedWorkSeconds)
                    }
                } label: {
                    Label("Record set · start rest", systemImage: "checkmark")
                }
                .buttonStyle(ActionSlabStyle())
                .disabled(!canComplete)
                .opacity(canComplete ? 1 : 0.48)
                HStack(spacing: 12) {
                    Button("Do later") { Task { await model.deferCurrent() } }
                        .buttonStyle(.bordered)
                    Button("Add another set") { Task { await model.addExtraSet() } }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Skip", role: .destructive) { Task { await model.skipCurrent() } }
                        .frame(minHeight: 44)
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(20)
        }
        .background(SetlinePalette.paper)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEnteringNumbers = false }
                    .font(.subheadline.weight(.bold))
            }
        }
        .onAppear(perform: seedDrafts)
    }

    private var heading: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                SectionLabel(text: headingLabel)
                Text(step.exerciseName)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .tracking(-0.7)
            }
            Spacer()
            VStack(spacing: 4) {
                Text("#\(step.authoredPosition + 1)")
                    .font(.headline.monospacedDigit().weight(.black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(step.stepType.countsAsWorkingSet ? SetlinePalette.lime : SetlinePalette.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                if step.isOptional {
                    Text("OPTIONAL")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(SetlinePalette.ink.opacity(0.55))
                }
            }
        }
    }

    /// The set label already names its own kind on most authored sets ("Warm-up",
    /// "Working set 2 of 3"), so the step type is only appended when it adds something.
    private var headingLabel: String {
        if step.isExtra { return "Session-only extra" }
        let type = step.stepType.title
        guard !step.label.localizedCaseInsensitiveContains(type) else { return step.label }
        return "\(step.label) · \(type.lowercased())"
    }

    private var targetBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("TARGET")
                .font(.caption.weight(.bold))
                .tracking(1.1)
            Text(step.target.displayString)
                .font(.system(size: 42, weight: .black, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            if !step.target.qualifiers.isEmpty {
                Text(step.target.qualifiers.joined(separator: " · "))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.7))
            }
            if !step.rest.isEmpty {
                Text("Authored rest \(step.rest.displayString)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(SetlinePalette.ink.opacity(0.55))
            }
            if !step.cue.isEmpty {
                Text(step.cue)
                    .font(.body.weight(.medium))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.65))
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Work timer

    private var workTimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Set timer")
            HStack(spacing: 14) {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    Text(TimeInterval(liveWorkSeconds(at: context.date)).durationClock)
                        .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                        .accessibilityLabel("Set duration \(liveWorkSeconds(at: context.date)) seconds")
                }
                Spacer()
                Button(workStartedAt == nil ? "Start set" : "Stop") {
                    toggleWorkTimer()
                }
                .font(.subheadline.weight(.bold))
                .frame(minWidth: 96, minHeight: 44)
                .background(workStartedAt == nil ? SetlinePalette.blue : SetlinePalette.coral.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                if accumulatedWorkSeconds > 0 || workStartedAt != nil {
                    Button("Reset") { resetWorkTimer() }
                        .font(.subheadline.weight(.bold))
                        .frame(minHeight: 44)
                }
            }
            Text("Timed independently of rest, so time under load is recorded rather than estimated.")
                .font(.caption)
                .foregroundStyle(SetlinePalette.ink.opacity(0.55))
        }
    }

    private func liveWorkSeconds(at date: Date) -> Int {
        guard let workStartedAt else { return accumulatedWorkSeconds }
        return accumulatedWorkSeconds + max(0, Int(date.timeIntervalSince(workStartedAt)))
    }

    private func toggleWorkTimer() {
        if let workStartedAt {
            accumulatedWorkSeconds += max(0, Int(Date.now.timeIntervalSince(workStartedAt)))
            self.workStartedAt = nil
        } else {
            workStartedAt = .now
        }
    }

    private func resetWorkTimer() {
        workStartedAt = nil
        accumulatedWorkSeconds = 0
    }

    private var recordedWorkSeconds: Int? {
        let total = liveWorkSeconds(at: .now)
        return total > 0 ? total : nil
    }

    // MARK: - Segment entry

    @ViewBuilder
    private var actualInputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(text: "Recorded actuals")
                Spacer()
                Button {
                    isQuickEntryShown.toggle()
                } label: {
                    Label("Type it", systemImage: "text.cursor")
                        .font(.caption.weight(.bold))
                }
                .frame(minHeight: 32)
            }
            ForEach($drafts) { $draft in
                segmentRow($draft, index: drafts.firstIndex(where: { $0.id == draft.id }) ?? 0)
            }
            HStack(spacing: 12) {
                Button {
                    drafts.append(SegmentDraft(side: step.target.perSide ? .right : nil))
                } label: {
                    Label("Add segment", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                }
                .frame(minHeight: 44)
                if drafts.count > 1 {
                    Button(role: .destructive) {
                        _ = drafts.popLast()
                    } label: {
                        Label("Remove last", systemImage: "minus")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(minHeight: 44)
                }
            }
            if drafts.count > 1 {
                Text("All \(drafts.count) segments record as one set.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private func segmentRow(_ draft: Binding<SegmentDraft>, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if drafts.count > 1 || step.target.perSide {
                HStack {
                    Text("SEGMENT \(index + 1)")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(SetlinePalette.ink.opacity(0.5))
                    Spacer()
                    if step.target.perSide {
                        Picker("Side", selection: draft.side) {
                            Text("Left").tag(BodySide?.some(.left))
                            Text("Right").tag(BodySide?.some(.right))
                            Text("Both").tag(BodySide?.some(.both))
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                    }
                }
            }
            switch step.kind {
            case .strength:
                HStack(spacing: 12) {
                    numericField("Reps", value: draft.repetitions, unit: "reps")
                    numericField("Weight", value: draft.weight, unit: "kg")
                }
            case .repetitions, .mobility:
                numericField("Repetitions", value: draft.repetitions, unit: "reps")
            case .timed:
                HStack(spacing: 12) {
                    numericField("Duration", value: draft.duration, unit: "seconds")
                    numericField("Weight", value: draft.weight, unit: "kg")
                }
            case .cardio:
                HStack(spacing: 12) {
                    numericField("Duration", value: draft.duration, unit: "minutes")
                    numericField("Distance", value: draft.distance, unit: "km")
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Quick entry

    @ViewBuilder
    private var quickEntryBlock: some View {
        if isQuickEntryShown {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Quick entry")
                TextField("5x40, 2x30", text: $quickEntry)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.body.monospaced())
                    .accessibilityLabel("Shorthand set entry")
                let parsed = SetEntryParser.parse(quickEntry)
                if !quickEntry.isEmpty {
                    // The interpretation is always shown before it is applied, so
                    // shorthand never silently records the wrong thing.
                    Text(parsed.segments.isEmpty
                        ? "Not understood yet."
                        : "Reads as: " + parsed.segments.map(describe).joined(separator: " + "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(parsed.segments.isEmpty
                            ? SetlinePalette.coral
                            : SetlinePalette.ink.opacity(0.75))
                    if !parsed.unrecognised.isEmpty {
                        Text("Ignored: \(parsed.unrecognised.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(SetlinePalette.coral)
                    }
                }
                Button("Apply to segments") {
                    applyQuickEntry(parsed)
                }
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
                .disabled(parsed.segments.isEmpty)
            }
            .padding(14)
            .background(SetlinePalette.chalk)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func applyQuickEntry(_ parsed: SetEntryParser.Result) {
        guard !parsed.segments.isEmpty else { return }
        drafts = parsed.segments.map { segment in
            SegmentDraft(
                weight: segment.weight.map(\.trimmedString) ?? "",
                repetitions: segment.repetitions.map(String.init) ?? "",
                duration: segment.durationSeconds.map { step.kind == .cardio ? String($0 / 60) : String($0) } ?? "",
                distance: segment.distanceKilometres.map(\.trimmedString) ?? "",
                rpe: segment.rpe.map(\.trimmedString) ?? "",
                side: segment.side
            )
        }
        quickEntry = ""
        isQuickEntryShown = false
    }

    private func describe(_ segment: SetSegment) -> String {
        var parts: [String] = []
        if let side = segment.side, side != .both { parts.append(side.title) }
        if let reps = segment.repetitions, let weight = segment.weight {
            parts.append("\(reps) × \(weight.trimmedString) kg")
        } else if let reps = segment.repetitions {
            parts.append("\(reps) reps")
        } else if let weight = segment.weight {
            parts.append("\(weight.trimmedString) kg")
        }
        if let seconds = segment.durationSeconds { parts.append(seconds.durationLabel) }
        if let kilometres = segment.distanceKilometres { parts.append("\(kilometres.trimmedString) km") }
        if let rpe = segment.rpe { parts.append("RPE \(rpe.trimmedString)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - State

    /// Per-side work starts with a left and a right segment; everything else with one.
    private func seedDrafts() {
        guard drafts.isEmpty else { return }
        if step.target.perSide {
            drafts = [SegmentDraft(side: .left), SegmentDraft(side: .right)]
        } else {
            drafts = [SegmentDraft()]
        }
    }

    private var segments: [SetSegment] {
        drafts.compactMap { $0.segment(kind: step.kind) }
    }

    private var canComplete: Bool {
        guard let first = segments.first else { return false }
        switch step.kind {
        case .strength: return first.repetitions != nil
        case .repetitions, .mobility: return first.repetitions != nil
        case .timed: return first.durationSeconds != nil
        case .cardio: return first.durationSeconds != nil || first.distanceKilometres != nil
        }
    }

    private func numericField(_ title: String, value: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                TextField("0", text: value)
                    .keyboardType(.decimalPad)
                    .focused($isEnteringNumbers)
                    .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                    .accessibilityLabel(title)
                Text(unit)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 58)
            .background(SetlinePalette.chalk)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RestBoard: View {
    @Environment(AppModel.self) private var model
    let rest: RestState
    let next: WorkoutStep?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = rest.remaining(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionLabel(text: remaining > 0 ? "Rest · wall clock" : "Rest target complete")
                    Text(TimeInterval(remaining).durationClock)
                        .font(.system(size: 78, weight: .black, design: .rounded).monospacedDigit())
                        .tracking(-2)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("\(remaining) seconds remaining")
                    HStack(spacing: 10) {
                        Button("−15 sec") { Task { await model.adjustRest(by: -15) } }
                        Button("+15 sec") { Task { await model.adjustRest(by: 15) } }
                        Button("+30 sec") { Task { await model.adjustRest(by: 30) } }
                    }
                    .buttonStyle(.bordered)
                    .font(.subheadline.weight(.bold))
                    .tint(SetlinePalette.ink)
                    if let next {
                        InkRule()
                        SectionLabel(text: "Next in authored order")
                        Text(next.exerciseName)
                            .font(.system(.title, design: .rounded, weight: .black))
                        Text("\(next.label) · \(next.target.displayString)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                        Button(remaining > 0 ? "Start next early" : "Start next set") {
                            Task { await model.endRest() }
                        }
                        .buttonStyle(ActionSlabStyle())
                    }
                    Text("Authored \(rest.authoredSeconds)s · adjusted \(rest.adjustedSeconds)s · actual \(rest.actual(at: context.date))s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(SetlinePalette.ink.opacity(0.62))
                }
                .padding(24)
            }
        }
        .background(SetlinePalette.lime)
    }
}

private struct SetRail: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "Session rail")
                Spacer()
                Text("Authored position retained")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(session.steps.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(step.authoredPosition + 1)")
                                .font(.caption2.monospacedDigit().weight(.black))
                            Text(step.exerciseName)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            Text(step.status == .planned && index == session.activeIndex ? "ACTIVE" : step.status.rawValue.uppercased())
                                .font(.system(size: 9, weight: .black))
                        }
                        .frame(width: 112, alignment: .leading)
                        .padding(9)
                        .background(railColor(step, index: index))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(12)
        .background(SetlinePalette.chalk)
    }

    private func railColor(_ step: WorkoutStep, index: Int) -> Color {
        if index == session.activeIndex { return SetlinePalette.lime }
        return switch step.status {
        case .complete: SetlinePalette.blue
        case .skipped: SetlinePalette.coral.opacity(0.5)
        case .deferred: SetlinePalette.steel
        case .planned: SetlinePalette.paper
        }
    }
}

extension TimeInterval {
    var durationClock: String {
        let total = max(0, Int(self))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
