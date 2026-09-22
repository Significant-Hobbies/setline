import SetlineCore
import SwiftUI

/// The four-axis capability profile: demonstrated curriculum scores, the next
/// milestone's effect, and the prioritised plan. Scores are curriculum
/// completion — never population percentiles — and missing evidence stays
/// visibly unassessed.
struct CapabilityView: View {
    @Environment(AppModel.self) private var model

    private var plan: CapabilityPlan { CapabilityEngine.plan(in: model.document) }
    private var scores: [AxisScore] { CapabilityEngine.profile(in: model.document) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Where you are, what to prioritise, and what to practise next. Scores are curriculum progress — v\(CapabilityEngine.curriculumVersion) — not health ratings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                diamond
                prioritiesSection
                axesSection
                programmeSection
                bottomNote
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .setlineBackground()
        .navigationTitle("Capability")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Diamond

    /// Solid outline: demonstrated scores. Dashed: the score each axis reaches
    /// if its next checkpoint passes. Markers: user goals.
    private var diamond: some View {
        VStack(alignment: .leading, spacing: 10) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 26
                let axes = AbilityAxis.allCases
                func point(_ index: Int, _ fraction: Double) -> CGPoint {
                    let angle = -Double.pi / 2 + Double(index) * .pi / 2
                    return CGPoint(
                        x: center.x + cos(angle) * radius * fraction,
                        y: center.y + sin(angle) * radius * fraction
                    )
                }
                // Guide rings.
                for ring in [0.33, 0.66, 1.0] {
                    var path = Path()
                    for i in 0..<4 {
                        let p = point(i, ring)
                        i == 0 ? path.move(to: p) : path.addLine(to: p)
                    }
                    path.closeSubpath()
                    context.stroke(path, with: .color(SetlinePalette.steel), lineWidth: ring == 1 ? 1.5 : 0.75)
                }
                // Dashed next-milestone outline.
                var next = Path()
                for i in 0..<4 {
                    let fraction = Double(CapabilityEngine.projectedScore(axes[i], in: model.document)) / 100
                    let p = point(i, max(0.06, fraction))
                    i == 0 ? next.move(to: p) : next.addLine(to: p)
                }
                next.closeSubpath()
                context.stroke(next, with: .color(SetlinePalette.ink.opacity(0.45)), style: StrokeStyle(lineWidth: 1.25, dash: [5, 4]))
                // Solid current outline.
                var current = Path()
                for i in 0..<4 {
                    let fraction = Double(scores[i].score) / 100
                    let p = point(i, max(0.06, fraction))
                    i == 0 ? current.move(to: p) : current.addLine(to: p)
                }
                current.closeSubpath()
                context.fill(current, with: .color(SetlinePalette.lime.opacity(0.25)))
                context.stroke(current, with: .color(SetlinePalette.ink), lineWidth: 2)
                // Goal markers.
                for i in 0..<4 {
                    guard let target = CapabilityEngine.goalProjectedScore(axes[i], in: model.document) else { continue }
                    let p = point(i, max(0.06, Double(target) / 100))
                    let marker = Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
                    context.stroke(marker, with: .color(SetlinePalette.coral), lineWidth: 2.5)
                }
            }
            .frame(height: 230)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Capability diamond. " + scores.map { "\($0.axis.title) \($0.score) of 100" }.joined(separator: ", "))
            axisLabels
            legend
        }
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var axisLabels: some View {
        Text("Strength ↑ · Endurance → · Mobility ↓ · Balance & control ←")
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(SetlinePalette.ink.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            Label("Now", systemImage: "circle.fill")
            Label("Next checkpoint", systemImage: "circle.dashed")
            Label("Your goal", systemImage: "circle")
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(SetlinePalette.ink.opacity(0.6))
    }

    // MARK: - Priorities

    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Priorities")
            if plan.priorities.isEmpty {
                Text("Everything assessed is met. Set a new goal or pick an axis to specialise.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(plan.priorities.map(\.title).joined(separator: " + "))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                ForEach(plan.axes.filter { $0.priorityRank != nil }, id: \.axis) { axisPlan in
                    Text(axisPlan.rationale)
                        .font(.footnote)
                        .foregroundStyle(SetlinePalette.ink.opacity(0.75))
                }
            }
        }
    }

    // MARK: - Axes

    private var axesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Axes")
            VStack(spacing: 0) {
                ForEach(scores, id: \.axis) { score in
                    let axisPlan = plan.axes.first { $0.axis == score.axis }
                    NavigationLink {
                        CapabilityAxisView(score: score, plan: axisPlan)
                    } label: {
                        CapabilityAxisRow(score: score, plan: axisPlan)
                    }
                    if score.axis != scores.last?.axis {
                        InkRule()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(SetlinePalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Programme

    private var programmeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Programme")
            HStack {
                Text("Days per week")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Stepper(
                    "\(model.document.capability.availableDays)",
                    value: Binding(
                        get: { model.document.capability.availableDays },
                        set: { days in Task { await model.setCapabilityDays(days) } }
                    ),
                    in: 1...7
                )
                .frame(minHeight: 36)
            }
            Button {
                Task { await model.applyCapabilityProgramme() }
            } label: {
                Label("Generate coordinated programme", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(ActionSlabStyle())
            Text("One programme across the axes — priorities first, maintenance retained — installed as an ordinary custom programme you can still edit and skip.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.72))
        }
    }

    private var bottomNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            Text("Scores measure this curriculum, version \(CapabilityEngine.curriculumVersion). A symmetrical diamond is not the goal — your selected targets are. Unsupported comparisons are never shown.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.72))
        }
        .padding(.top, 8)
    }
}

// MARK: - Axis row

struct CapabilityAxisRow: View {
    let score: AxisScore
    let plan: AxisPlan?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(score.axis.title).font(.headline.weight(.black))
                    if let status = plan?.status {
                        Text(status.title.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(statusColor.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text("\(score.assessed) of \(score.total) checkpoints assessed")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let verified = score.lastVerified {
                    Text("Last verified \(verified.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never assessed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(score.score)")
                    .font(.system(size: 28, weight: .black, design: .rounded).monospacedDigit())
                Text("of 100")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(SetlinePalette.ink)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch plan?.status {
        case .maintain: SetlinePalette.lime
        case .specialize: SetlinePalette.blue
        case .unassessed: SetlinePalette.steel
        default: SetlinePalette.chalk
        }
    }
}

// MARK: - Axis detail

/// One axis: its checkpoints with evidence, the next checkpoint, practice,
/// and per-assessment pain reporting.
struct CapabilityAxisView: View {
    @Environment(AppModel.self) private var model
    let score: AxisScore
    let plan: AxisPlan?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                controls
                checkpoints
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .setlineBackground()
        .navigationTitle(score.axis.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(score.score)")
                    .font(.system(size: 44, weight: .black, design: .rounded).monospacedDigit())
                Text("of 100")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let status = plan?.status {
                    Text(status.title.uppercased())
                        .font(.caption.weight(.black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(SetlinePalette.blue.opacity(0.5))
                        .clipShape(Capsule())
                }
            }
            if let rationale = plan?.rationale {
                Text(rationale)
                    .font(.subheadline)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.75))
            }
            if let next = plan?.nextCheckpoint {
                Text("Next checkpoint: \(next.title)")
                    .font(.footnote.weight(.semibold))
            }
            if let due = plan?.verificationDue {
                Text("Verify again by \(due.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.7))
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await model.startAxisSession(score.axis) }
            } label: {
                Label("Start \(score.axis.title) session", systemImage: "play.fill")
            }
            .buttonStyle(ActionSlabStyle())
            .disabled(model.document.activeSession != nil)
            let focused = model.document.capability.focusAxes.contains(score.axis)
            Button {
                Task { await model.toggleCapabilityFocus(score.axis) }
            } label: {
                Label(focused ? "Specialising" : "Specialise this axis", systemImage: focused ? "star.fill" : "star")
                    .font(.caption.weight(.bold))
            }
            .frame(minHeight: 36)
        }
    }

    private var checkpoints: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Checkpoints")
            ForEach(score.results, id: \.assessment.id) { result in
                CapabilityCheckpointRow(result: result)
            }
        }
    }
}

/// One assessment in the axis: evidence, criteria, the easier entry point,
/// and the pain toggle.
struct CapabilityCheckpointRow: View {
    @Environment(AppModel.self) private var model
    let result: AssessmentResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.assessment.title).font(.subheadline.weight(.bold))
                    Text(result.isPassed ? "Checkpoint met" : result.assessment.passingCriteria)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }
            if result.isAssessed, let value = result.evidence.value {
                Text("\(result.evidence.kind.title): \(result.assessment.axis == .mobility ? "\(Int((result.fraction ?? 0) * 100))% of checks" : value.trimmedString)")
                    .font(.caption.monospacedDigit().weight(.bold))
            }
            if let provenance = result.evidence.provenance {
                Text(provenance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !result.isPassed {
                Text("Start here: \(result.assessment.easierVariation)")
                    .font(.footnote)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.75))
                Text("Then: \(result.assessment.nextProgression)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            feedbackRow
            populationLine
            painToggle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if result.isPainBlocked {
            Text("PAIN PAUSED")
                .font(.system(size: 9, weight: .black))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(SetlinePalette.coral.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Text(result.isPassed ? "MET" : result.evidence.kind.title.uppercased())
                .font(.system(size: 9, weight: .black))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(result.isPassed ? SetlinePalette.lime : SetlinePalette.steel.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    /// Difficulty verdicts. Each adjusts exactly one variable in generated
    /// sessions; tapping the active verdict clears it.
    private var feedbackRow: some View {
        HStack(spacing: 16) {
            ForEach([CheckpointFeedback.tooHard, .tooEasy], id: \.self) { verdict in
                Button {
                    Task {
                        let next: CheckpointFeedback? = result.feedback == verdict ? nil : verdict
                        await model.setCapabilityFeedback(next, assessmentID: result.assessment.id)
                    }
                } label: {
                    Text(verdict.title)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(result.feedback == verdict ? SetlinePalette.blue : SetlinePalette.steel.opacity(0.4))
                        .clipShape(Capsule())
                }
                .frame(minHeight: 32)
            }
            Spacer()
        }
    }

    /// The population comparison, fully disclosed — or an explicit
    /// "Benchmark unavailable" where no exact-protocol dataset exists.
    private var populationLine: some View {
        Group {
            if !result.isAssessed {
                EmptyView()
            } else if let reference = PopulationComparisons.reference(for: result.assessment.id) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Population: \(reference.finding)")
                        .font(.caption2)
                        .foregroundStyle(SetlinePalette.ink.opacity(0.75))
                    Text("\(reference.population) · \(reference.protocolText) · \(reference.source)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Population benchmark unavailable — no exact-protocol reference exists.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var painToggle: some View {
        Button {
            Task { await model.setCapabilityPain(!result.isPainBlocked, assessmentID: result.assessment.id) }
        } label: {
            Text(result.isPainBlocked ? "Clear pain report" : "Report pain on this")
                .font(.caption2.weight(.bold))
                .foregroundStyle(result.isPainBlocked ? SetlinePalette.coral : .secondary)
        }
        .frame(minHeight: 32)
    }
}
