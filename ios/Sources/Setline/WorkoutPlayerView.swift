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
            Text("\(session.completedCount) completed · \(session.steps.count - session.completedCount) skipped")
                .font(.headline.monospacedDigit())
            Button("Save workout") { Task { await model.finishWorkout() } }
                .buttonStyle(ActionSlabStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
    }
}

private struct AttemptBoard: View {
    @Environment(AppModel.self) private var model
    let step: WorkoutStep
    @State private var weight = ""
    @State private var repetitions = ""
    @State private var duration = ""
    @State private var distance = ""
    @State private var hasDropSegment = false
    @State private var dropWeight = ""
    @State private var dropRepetitions = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(text: step.isExtra ? "Session-only extra" : "\(step.label) · planned")
                        Text(step.exerciseName)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .tracking(-0.7)
                    }
                    Spacer()
                    Text("#\(step.authoredPosition + 1)")
                        .font(.headline.monospacedDigit().weight(.black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(SetlinePalette.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("TARGET")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                    Text(step.target)
                        .font(.system(size: 42, weight: .black, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(step.cue)
                        .font(.body.weight(.medium))
                        .foregroundStyle(SetlinePalette.ink.opacity(0.65))
                }
                .padding(.vertical, 4)
                InkRule()
                actualInputs
                if step.kind == .strength {
                    Button(hasDropSegment ? "Remove drop segment" : "Add drop segment") {
                        hasDropSegment.toggle()
                    }
                    .font(.subheadline.weight(.bold))
                    .frame(minHeight: 44)
                }
                Button {
                    Task { await model.completeCurrent(segments: segments) }
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
    }

    @ViewBuilder
    private var actualInputs: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Recorded actuals")
            switch step.kind {
            case .strength:
                HStack(spacing: 12) {
                    numericField("Weight", value: $weight, unit: "kg")
                    numericField("Reps", value: $repetitions, unit: "reps")
                }
                if hasDropSegment {
                    HStack(spacing: 12) {
                        numericField("Drop weight", value: $dropWeight, unit: "kg")
                        numericField("Drop reps", value: $dropRepetitions, unit: "reps")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            case .repetitions, .mobility:
                numericField("Repetitions", value: $repetitions, unit: "reps")
            case .timed:
                numericField("Duration", value: $duration, unit: "seconds")
            case .cardio:
                HStack(spacing: 12) {
                    numericField("Duration", value: $duration, unit: "minutes")
                    numericField("Distance", value: $distance, unit: "km")
                }
            }
        }
    }

    private func numericField(_ title: String, value: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                TextField("0", text: value)
                    .keyboardType(.decimalPad)
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

    private var canComplete: Bool {
        switch step.kind {
        case .strength: Double(weight) != nil && Int(repetitions) != nil
        case .repetitions, .mobility: Int(repetitions) != nil
        case .timed: Int(duration) != nil
        case .cardio: Int(duration) != nil || Double(distance) != nil
        }
    }

    private var segments: [SetSegment] {
        var result = [SetSegment(
            weight: Double(weight),
            repetitions: Int(repetitions),
            durationSeconds: durationSeconds,
            distanceKilometres: Double(distance)
        )]
        if hasDropSegment, let dropWeight = Double(dropWeight), let dropRepetitions = Int(dropRepetitions) {
            result.append(SetSegment(weight: dropWeight, repetitions: dropRepetitions))
        }
        return result
    }

    private var durationSeconds: Int? {
        guard let value = Int(duration) else { return nil }
        return step.kind == .cardio ? value * 60 : value
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
                        Text("\(next.label) · \(next.target)")
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

private extension TimeInterval {
    var durationClock: String {
        let total = max(0, Int(self))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
