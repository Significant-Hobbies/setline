import SetlineCore
import SwiftUI
import SaaSMakerUI

struct WorkoutPlayerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        .disabled(model.isSaving)
        .safeAreaInset(edge: .top) {
            if let message = model.message {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(SetlineType.footnote)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SetlinePalette.chalk)
            }
        }
        .interactiveDismissDisabled(model.document.activeSession != nil)
        .confirmationDialog("Finish this workout?", isPresented: $showFinishConfirmation) {
            Button("Finish and save") { Task { await model.finishWorkout() } }
                .textCase(.lowercase)
                .accessibilityLabel("Finish and save")
            Button("Keep training", role: .cancel) {}
                .textCase(.lowercase)
                .accessibilityLabel("Keep training")
        } message: {
            Text("Any remaining planned sets will be recorded as skipped.")
        }
    }

    private func sessionBar(_ session: WorkoutSession) -> some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 14))) {
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
                    .font(SetlineType.headline.weight(.black))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(session.completedCount) / \(session.steps.count) recorded")
                    .font(SetlineType.caption.monospacedDigit())
                    .foregroundStyle(SetlinePalette.chalk.opacity(0.68))
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date.timeIntervalSince(session.startedAt).durationClock)
                    .font(SetlineType.headline.monospacedDigit().weight(.black))
                    .accessibilityLabel("Workout elapsed time")
            }
            Button("Finish") { showFinishConfirmation = true }
                .textCase(.lowercase)
                .accessibilityLabel("Finish")
                .font(SetlineType.subheadline.weight(.bold))
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
            SMSectionHeader("the plan is recorded.", size: 34)
            Text("\(session.completedWorkingSetCount) working sets · \(session.completedCount) steps completed · \(session.steps.count - session.completedCount) skipped")
                .font(SetlineType.headline.monospacedDigit())
            if session.tonnage > 0 {
                Text("\(session.tonnage.trimmedString) kg total load moved")
                    .font(SetlineType.subheadline.monospacedDigit())
                    .foregroundStyle(SetlinePalette.ink.opacity(0.7))
            }
            Button { Task { await model.finishWorkout() } } label: {
                Text("save workout").frame(maxWidth: .infinity)
            }
                .textCase(.lowercase)
                .accessibilityLabel("Save workout")
                .buttonStyle(SetlineBrandButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}

/// Identifies one numeric field so focus can move between them unambiguously.
private enum EntryField: Hashable {
    case reps(UUID)
    case weight(UUID)
    case duration(UUID)
    case distance(UUID)
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
            loadMetrics: .init(weight: Double(weight), repetitions: Int(repetitions), rpe: Double(rpe)),
            enduranceMetrics: .init(durationSeconds: seconds, distanceKilometres: Double(distance)),
            side: side
        )
        return segment.isEmpty ? nil : segment
    }
}

private struct AttemptBoard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let step: WorkoutStep

    @State private var drafts: [SegmentDraft] = []
    @State private var quickEntry = ""
    @State private var isQuickEntryShown = false
    @State private var workStartedAt: Date?
    @State private var accumulatedWorkSeconds = 0
    /// The decimal keypad has no return key, so entry needs an explicit way out.
    /// Focus is tracked per field rather than as one flag, so moving between Reps
    /// and Weight actually transfers focus instead of leaving it ambiguous.
    @FocusState private var focusedField: EntryField?

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
                    Label("record set · start rest", systemImage: "checkmark").accessibilityLabel("Record set · start rest")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SetlineBrandButtonStyle())
                .disabled(!canComplete)
                .opacity(canComplete ? 1 : 0.48)
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
                    Button("Do later") { Task { await model.deferCurrent() } }
                        .textCase(.lowercase)
                        .accessibilityLabel("Do later")
                        .buttonStyle(.bordered)
                    Button("Add another set") { Task { await model.addExtraSet() } }
                        .textCase(.lowercase)
                        .accessibilityLabel("Add another set")
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Skip", role: .destructive) { Task { await model.skipCurrent() } }
                        .textCase(.lowercase)
                        .accessibilityLabel("Skip")
                        .frame(minHeight: 44)
                }
                .font(SetlineType.subheadline.weight(.semibold))
            }
            .padding(20)
        }
        .background(SetlinePalette.paper)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focusedField != nil {
                HStack {
                    Spacer()
                    // Keep dismissal in the app's safe area instead of the
                    // system keyboard accessory, whose transient zero-width
                    // layout can produce invalid frame warnings.
                    Button("Done") { focusedField = nil }
                        .textCase(.lowercase)
                        .accessibilityLabel("Done")
                        .font(SetlineType.subheadline.weight(.bold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear(perform: seedDrafts)
    }

    private var heading: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                SectionLabel(text: headingLabel)
                Text(step.exerciseName)
                    .font(SetlineType.title)
                    .tracking(-0.7)
            }
            Spacer()
            VStack(spacing: 4) {
                Text("#\(step.authoredPosition + 1)")
                    .font(SetlineType.headline.monospacedDigit().weight(.black))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(step.stepType.countsAsWorkingSet ? SetlinePalette.lime : SetlinePalette.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                if step.isOptional {
                    Text("optional")
                        .font(.custom(SetlinePalette.theme.sansFont, size: 9, relativeTo: .caption2).weight(.heavy))
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
            Text("target")
                .font(SetlineType.caption.weight(.bold))
                .tracking(1.1)
            Text(step.target.displayString)
                .font(.custom(SetlinePalette.theme.monoFont, size: 42, relativeTo: .title).weight(.heavy).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            if !step.target.qualifiers.isEmpty {
                Text(step.target.qualifiers.joined(separator: " · "))
                    .font(SetlineType.subheadline.weight(.bold))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.7))
            }
            if !step.rest.isEmpty {
                Text("Authored rest \(step.rest.displayString)")
                    .font(SetlineType.caption.monospacedDigit())
                    .foregroundStyle(SetlinePalette.ink.opacity(0.55))
            }
            if !step.cue.isEmpty {
                Text(step.cue)
                    .font(SetlineType.body.weight(.medium))
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
                        .font(.custom(SetlinePalette.theme.monoFont, size: 34, relativeTo: .title).weight(.heavy).monospacedDigit())
                        .accessibilityLabel("Set duration \(liveWorkSeconds(at: context.date)) seconds")
                }
                Spacer()
                Button(workStartedAt == nil ? "start set" : "stop") {
                    toggleWorkTimer()
                }
                .accessibilityLabel(workStartedAt == nil ? "Start set" : "Stop")
                .font(SetlineType.subheadline.weight(.bold))
                .frame(minWidth: 96, minHeight: 44)
                .background(workStartedAt == nil ? SetlinePalette.blue : SetlinePalette.coral.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                if accumulatedWorkSeconds > 0 || workStartedAt != nil {
                    Button("Reset") { resetWorkTimer() }
                        .textCase(.lowercase)
                        .accessibilityLabel("Reset")
                        .font(SetlineType.subheadline.weight(.bold))
                        .frame(minHeight: 44)
                }
            }
            Text("Timed independently of rest, so time under load is recorded rather than estimated.")
                .font(SetlineType.caption)
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
                    Label("type it", systemImage: "text.cursor").accessibilityLabel("Type it")
                        .font(SetlineType.caption.weight(.bold))
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
                    Label("add segment", systemImage: "plus").accessibilityLabel("Add segment")
                        .font(SetlineType.subheadline.weight(.bold))
                }
                .frame(minHeight: 44)
                if drafts.count > 1 {
                    Button(role: .destructive) {
                        _ = drafts.popLast()
                    } label: {
                        Label("remove last", systemImage: "minus").accessibilityLabel("Remove last")
                            .font(SetlineType.subheadline.weight(.bold))
                    }
                    .frame(minHeight: 44)
                }
            }
            if drafts.count > 1 {
                Text("All \(drafts.count) segments record as one set.")
                    .font(SetlineType.caption.weight(.semibold))
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
                        .font(.custom(SetlinePalette.theme.sansFont, size: 10, relativeTo: .caption2).weight(.heavy))
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
            let id = draft.wrappedValue.id
            switch step.kind {
            case .strength:
                HStack(spacing: 12) {
                    numericField("Reps", value: draft.repetitions, unit: "reps", field: .reps(id))
                    numericField("Weight", value: draft.weight, unit: "kg", field: .weight(id))
                }
            case .repetitions, .mobility:
                numericField("Repetitions", value: draft.repetitions, unit: "reps", field: .reps(id))
            case .timed:
                HStack(spacing: 12) {
                    numericField("Duration", value: draft.duration, unit: "seconds", field: .duration(id))
                    numericField("Weight", value: draft.weight, unit: "kg", field: .weight(id))
                }
            case .cardio:
                HStack(spacing: 12) {
                    numericField("Duration", value: draft.duration, unit: "minutes", field: .duration(id))
                    numericField("Distance", value: draft.distance, unit: "km", field: .distance(id))
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
                    .font(SetlineType.body.monospaced())
                    .accessibilityLabel("Shorthand set entry")
                let parsed = SetEntryParser.parse(quickEntry)
                if !quickEntry.isEmpty {
                    // The interpretation is always shown before it is applied, so
                    // shorthand never silently records the wrong thing.
                    Text(parsed.segments.isEmpty
                        ? "Not understood yet."
                        : "Reads as: " + parsed.segments.map(describe).joined(separator: " + "))
                        .font(SetlineType.caption.weight(.semibold))
                        .foregroundStyle(parsed.segments.isEmpty
                            ? SetlinePalette.coral
                            : SetlinePalette.ink.opacity(0.75))
                    if !parsed.unrecognised.isEmpty {
                        Text("Ignored: \(parsed.unrecognised.joined(separator: ", "))")
                            .font(SetlineType.caption)
                            .foregroundStyle(SetlinePalette.coral)
                    }
                }
                Button("Apply to segments") {
                    applyQuickEntry(parsed)
                }
                .textCase(.lowercase)
                .accessibilityLabel("Apply to segments")
                .font(SetlineType.subheadline.weight(.bold))
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

    private func numericField(
        _ title: String,
        value: Binding<String>,
        unit: String,
        field: EntryField
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(SetlineType.caption.weight(.bold))
            HStack(alignment: .center, spacing: 5) {
                TextField("0", text: value)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .font(.custom(SetlinePalette.theme.monoFont, size: 30, relativeTo: .title).weight(.heavy).monospacedDigit())
                    .accessibilityLabel(title)
                Text(unit)
                    .font(SetlineType.caption.weight(.bold))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let rest: RestState
    let next: WorkoutStep?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = rest.remaining(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SectionLabel(text: remaining > 0 ? "Rest · wall clock" : "Rest target complete")
                    Text(TimeInterval(remaining).durationClock)
                        .font(.custom(SetlinePalette.theme.monoFont, size: 78, relativeTo: .title).weight(.heavy).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .tracking(-2)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("\(remaining) seconds remaining")
                    (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))) {
                        Button("−15 sec") { Task { await model.adjustRest(by: -15) } }
                            .textCase(.lowercase)
                            .accessibilityLabel("−15 sec")
                        Button("+15 sec") { Task { await model.adjustRest(by: 15) } }
                            .textCase(.lowercase)
                            .accessibilityLabel("+15 sec")
                        Button("+30 sec") { Task { await model.adjustRest(by: 30) } }
                            .textCase(.lowercase)
                            .accessibilityLabel("+30 sec")
                    }
                    .buttonStyle(SMButtonStyle(.outline))
                    .font(SetlineType.subheadline.weight(.bold))
                    .tint(SetlinePalette.ink)
                    if let next {
                        InkRule()
                        SectionLabel(text: "Next in authored order")
                        Text(next.exerciseName)
                            .font(SetlineType.title)
                        Text("\(next.label) · \(next.target.displayString)")
                            .font(SetlineType.title3.weight(.semibold).monospacedDigit())
                        Button {
                            Task { await model.endRest() }
                        } label: {
                            Text(remaining > 0 ? "start next early" : "start next set")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityLabel(remaining > 0 ? "Start next early" : "Start next set")
                        .buttonStyle(SetlineBrandButtonStyle())
                    }
                    Text("Authored \(rest.authoredSeconds)s · adjusted \(rest.adjustedSeconds)s · actual \(rest.actual(at: context.date))s")
                        .font(SetlineType.caption.monospacedDigit())
                        .foregroundStyle(SetlinePalette.ink.opacity(0.62))
                }
                .padding(24)
            }
        }
        .background(SetlinePalette.chalk)
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
                    .font(SetlineType.caption2)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(session.steps.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(step.authoredPosition + 1)")
                                .font(SetlineType.caption2.monospacedDigit().weight(.black))
                            Text(step.exerciseName)
                                .font(SetlineType.caption.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                            SMStatusPill(step.status == .planned && index == session.activeIndex ? "active" : step.status.rawValue.lowercased())
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
