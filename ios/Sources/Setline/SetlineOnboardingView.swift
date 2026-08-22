import SetlineCore
import SwiftUI

enum SetlineOnboardingPolicy {
    static func shouldPresent(document: SetlineDocument, completed: Bool) -> Bool {
        guard !completed else { return false }
        guard document.activeSession == nil, document.history.isEmpty else { return false }
        guard document.templates.isEmpty, document.goals.isEmpty else { return false }
        if case .custom = document.programme { return false }
        return true
    }
}

private enum SetlineOnboardingStep {
    case welcome
    case preview
    case recorded
}

struct SetlineOnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: SetlineOnboardingStep = .welcome

    private var preview: ResolvedSession {
        let template = TwelveWeekProgramme.template(for: .lower, week: 1, dayIndex: 1)
        return ResolvedSession(
            template: template,
            programmeWeek: 1,
            programmeDayIndex: 1,
            subtitle: "Week 1 · Lower",
            notes: template.notes
        )
    }

    private var hasRecordedFirstSet: Bool {
        (model.document.activeSession?.completedCount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    brand
                    switch step {
                    case .welcome: welcome
                    case .preview: previewStep
                    case .recorded: recordedStep
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
            }
            .setlineBackground()
            .onChange(of: model.isWorkoutPresented) { _, presented in
                guard !presented, hasRecordedFirstSet else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    step = .recorded
                }
            }
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SETLINE")
                .font(.caption.weight(.black))
                .tracking(2.2)
            InkRule()
        }
        .accessibilityElement(children: .combine)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Your plan, in order")
                Text("Follow the plan.\nRecord the truth.")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .tracking(-1)
                Text("Setline keeps the authored target in view, records only what you enter, and runs entirely on this device during a workout.")
                    .font(.body)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 14) {
                onboardingFact("Authored target", "What the programme asks for.")
                onboardingFact("Recorded actual", "What you really completed.")
                onboardingFact("Set timer and rest", "Work time is recorded separately; rest starts only after a set.")
            }
            .padding(18)
            .background(SetlinePalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button("Use the bundled programme") {
                Task {
                    await model.selectProgramme(.bundled(.twelveWeekStrengthCardioMobility))
                    step = .preview
                }
            }
            .buttonStyle(ActionSlabStyle())
            .accessibilityHint("Reviews a real session before starting")

            Button("I’ll build my own programme") {
                model.completeOnboarding(openPlan: true)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .buttonStyle(.bordered)

            Button("Configure later") {
                model.completeOnboarding()
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Button("Back") { step = .welcome }
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Review before you start")
                Text(preview.template.name)
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                Text(preview.subtitle)
                    .font(.headline)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.65))
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(preview.template.exercises.prefix(4))) { exercise in
                    HStack(alignment: .firstTextBaseline) {
                        Text(exercise.name)
                            .font(.headline)
                        Spacer()
                        Text("\(exercise.sets.count) \(exercise.sets.count == 1 ? "set" : "sets")")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    InkRule()
                }
                Text("+ \(max(0, preview.template.exercises.count - 4)) more exercises in authored order")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(SetlinePalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("The first screen shows the target. Enter your actual result, then Setline starts the authored rest. Notification permission is requested only when that first rest needs an alert.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.68))

            Button("Start this session") {
                Task { await model.startWorkout(preview) }
            }
            .buttonStyle(ActionSlabStyle())
            .accessibilityHint("Starts the real offline workout player")
        }
    }

    private var recordedStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(SetlinePalette.ink)
                .accessibilityHidden(true)
            SectionLabel(text: "First set recorded")
            Text("Your workout is underway.")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
            Text("The set is saved locally, the rest clock is tied to real time, and the authored target remains unchanged.")
                .font(.body)
                .foregroundStyle(SetlinePalette.ink.opacity(0.7))
            Button("See Today") {
                model.completeOnboarding()
            }
            .buttonStyle(ActionSlabStyle())
        }
    }

    private func onboardingFact(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
