import SetlineCore
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                pageHeader("History", subtitle: "Recorded, calculated, and unavailable stay distinct.")
                totals
                pillarDose
                progressionSection
                if model.document.history.isEmpty {
                    ContentUnavailableView(
                        "No recorded workouts",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Complete a workout to create evidence. Setline will not invent a chart first.")
                    )
                    .frame(minHeight: 320)
                } else {
                    ForEach(model.document.history) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            sessionRow(session)
                        }
                        InkRule()
                    }
                }
            }
            .padding(20)
        }
        .setlineBackground()
        .navigationBarHidden(true)
    }

    private var totals: some View {
        let sessions = model.document.history
        let workingSets = sessions.reduce(0) { $0 + $1.completedWorkingSetCount }
        let tonnage = sessions.reduce(0.0) { $0 + $1.tonnage }
        return HStack(spacing: 10) {
            historyMetric("SESSIONS", "\(sessions.count)", SetlinePalette.blue)
            historyMetric("WORKING SETS", "\(workingSets)", SetlinePalette.lime)
            historyMetric("TONNAGE", tonnage > 0 ? "\(Int(tonnage)) kg" : "—", SetlinePalette.steel)
        }
    }

    /// How many sessions in the last seven days touched each pillar. Recorded, not scored.
    private var pillarDose: some View {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recent = model.document.history.filter { ($0.completedAt ?? $0.startedAt) >= cutoff }
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Last 7 days by pillar")
            if recent.isEmpty {
                Text("No sessions recorded in the last seven days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Pillar.allCases, id: \.self) { pillar in
                    let count = recent.count { $0.pillars.contains(pillar) }
                    HStack {
                        Text(pillar.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(count) session\(count == 1 ? "" : "s")")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(count == 0 ? SetlinePalette.coral : SetlinePalette.ink)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var progressionSection: some View {
        let recommendations = ProgressionEngine.recommendations(history: model.document.history)
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Next-session suggestions")
            if recommendations.isEmpty {
                Text("Unavailable until a completed working set establishes evidence against an authored rep range.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recommendations, id: \.exerciseName) { recommendation in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(recommendation.exerciseName).font(.headline)
                            Spacer()
                            Text(actionLabel(recommendation.action))
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(actionColour(recommendation.action))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        if let current = recommendation.currentLoad, let next = recommendation.recommendedLoad,
                           current != next {
                            Text("\(current.trimmedString) → \(next.trimmedString) kg")
                                .font(.title3.monospacedDigit().weight(.black))
                        }
                        if let evidence = recommendation.evidenceSummary {
                            Text("Last session: \(evidence)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(recommendation.rationale).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(SetlinePalette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func actionLabel(_ action: ProgressionAction) -> String {
        switch action {
        case .addLoad: "ADD LOAD"
        case .addRepetitions: "ADD REPS"
        case .reduceLoad: "REDUCE"
        case .insufficientEvidence: "NO EVIDENCE"
        }
    }

    private func actionColour(_ action: ProgressionAction) -> Color {
        switch action {
        case .addLoad: SetlinePalette.lime
        case .addRepetitions: SetlinePalette.blue
        case .reduceLoad: SetlinePalette.coral.opacity(0.6)
        case .insufficientEvidence: SetlinePalette.steel
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 3) {
                Text(session.completedAt?.formatted(.dateTime.day()) ?? "–")
                    .font(.title2.monospacedDigit().weight(.black))
                Text(session.completedAt?.formatted(.dateTime.month(.abbreviated)) ?? "")
                    .font(.caption.weight(.bold))
            }
            .frame(width: 52, height: 58)
            .background(SetlinePalette.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 5) {
                Text(session.templateName).font(.headline.weight(.black))
                Text("\(session.completedWorkingSetCount) working · \(session.completedCount) completed · \(session.steps.count - session.completedCount) skipped")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let week = session.programmeWeek {
                    Text("Week \(week)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SetlinePalette.ink.opacity(0.55))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
        }
        .foregroundStyle(SetlinePalette.ink)
        .padding(.vertical, 8)
    }

    private func historyMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            SectionLabel(text: label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section("Session receipt") {
                LabeledContent("Workout", value: session.templateName)
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let completedAt = session.completedAt {
                    LabeledContent("Completed", value: completedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let week = session.programmeWeek {
                    LabeledContent("Programme week", value: "\(week)")
                }
                LabeledContent("Working sets", value: "\(session.completedWorkingSetCount)")
                if session.tonnage > 0 {
                    LabeledContent("Load moved", value: "\(session.tonnage.trimmedString) kg")
                }
            }
            Section("Execution ledger") {
                ForEach(session.steps) { step in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(step.exerciseName).font(.headline)
                            Spacer()
                            Text(step.status.rawValue.uppercased()).font(.caption.weight(.black))
                        }
                        Text("\(step.label) · \(step.stepType.title) · planned #\(step.authoredPosition + 1) · performed \(step.performedPosition.map { "#\($0 + 1)" } ?? "—")")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("Target: \(step.target.displayString)").font(.subheadline)
                        if !step.segments.isEmpty {
                            Text("Recorded: " + step.segments.map(\.recordedDescription).joined(separator: " + "))
                                .font(.subheadline.weight(.semibold))
                        }
                        if let workSeconds = step.workSeconds {
                            Text("Set duration: \(workSeconds.durationLabel)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Recorded workout")
    }
}
