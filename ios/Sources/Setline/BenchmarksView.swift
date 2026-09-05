import SetlineCore
import SwiftUI

/// Fitness capability benchmarks — a periodic scorecard that complements daily
/// workout execution. Three views: overview (current vs target), check-ins
/// (saved snapshots), and guide (protocols and privacy).
struct BenchmarksView: View {
    @Environment(AppModel.self) private var model
    @State private var activeView: BenchmarkSubview = .overview
    @State private var activeGroup: String = "all"
    @State private var checkInDate = Date.now
    @State private var editingTarget: BenchmarkDefinition?
    @State private var showClearConfirmation = false
    @State private var showAllBenchmarks = false

    enum BenchmarkSubview: String, CaseIterable {
        case overview, checkIns, guide

        var label: String {
            switch self {
            case .overview: "Overview"
            case .checkIns: "Check-ins"
            case .guide: "Guide"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Strength, endurance, movement, and real-world skills. Your current numbers. One clear target for each capability.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                subviewNav
                switch activeView {
                case .overview: overviewContent
                case .checkIns: checkInsContent
                case .guide: guideContent
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .setlineBackground()
        .navigationTitle("Benchmarks")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .benchmarkEditTarget)) { note in
            if let id = note.userInfo?["metricID"] as? String,
               let metric = BenchmarkCatalog.metric(for: id) {
                editingTarget = metric
            }
        }
        .sheet(item: $editingTarget) { metric in
            BenchmarkTargetEditor(metric: metric)
        }
        .confirmationDialog("Clear current measurements?", isPresented: $showClearConfirmation) {
            Button("Clear measurements", role: .destructive) {
                Task { await model.clearBenchmarkMeasurements() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved check-ins, profile, and targets will be kept.")
        }
    }

    // MARK: - Subview navigation

    private var subviewNav: some View {
        HStack(spacing: 0) {
            ForEach(BenchmarkSubview.allCases, id: \.self) { subview in
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

    // MARK: - Overview

    @ViewBuilder
    private var overviewContent: some View {
        let focus = BenchmarkFocus.compute(from: model.document.benchmarks)
        profileCard
        statsRow
        suggestionsRow
        focusStrip
        if focus.hasContent {
            focusSections(focus)
            checkInBar
            allBenchmarksExpansion(focus)
        } else {
            checkInBar
            filterChips
            metricCards
        }
        bottomNote
    }

    /// Progressive disclosure: show in-progress and not-started benchmarks first,
    /// then reached targets collapsed. This avoids the dense 15-card wall on a
    /// phone while keeping every benchmark reachable.
    @ViewBuilder
    private func focusSections(_ focus: BenchmarkFocus) -> some View {
        if !focus.inProgress.isEmpty {
            focusSection(
                "In progress",
                icon: "figure.strengthtraining.traditional",
                tint: SetlinePalette.blue,
                metrics: focus.inProgress
            )
        }
        if !focus.notStarted.isEmpty {
            focusSection(
                "Not yet tested",
                icon: "questionmark.circle",
                tint: SetlinePalette.steel,
                metrics: focus.notStarted
            )
        }
        if !focus.reached.isEmpty {
            focusSection(
                "Targets reached",
                icon: "checkmark.seal",
                tint: SetlinePalette.lime,
                metrics: focus.reached
            )
        }
    }

    private func focusSection(_ title: String, icon: String, tint: Color, metrics: [BenchmarkDefinition]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text("\(title) \u{00B7} \(metrics.count)")
                    .font(.system(size: 11, weight: .black))
            }
            .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            VStack(spacing: 14) {
                ForEach(metrics, id: \.id) { metric in
                    BenchmarkMetricCard(metric: metric)
                }
            }
        }
    }

    /// Collapsible "all 15" section with filter chips, shown below the focus
    /// sections so the full list is always reachable but doesn't dominate.
    @ViewBuilder
    private func allBenchmarksExpansion(_ focus: BenchmarkFocus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.25)) { showAllBenchmarks.toggle() }
            } label: {
                HStack {
                    Text("All \(BenchmarkCatalog.metrics.count) benchmarks")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Image(systemName: showAllBenchmarks ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(SetlinePalette.ink.opacity(0.7))
                .padding(.vertical, 8)
            }
            if showAllBenchmarks {
                filterChips
                metricCards
            }
        }
    }

    private var profileCard: some View {
        BenchmarkProfileCard()
    }

    /// Workout-history suggestions that can pre-fill benchmark values, shown
    /// only when there is recorded workout evidence and the benchmark field is
    /// still blank. Each suggestion is labelled with its source date and
    /// exercise name so the provenance is visible.
    @ViewBuilder
    private var suggestionsRow: some View {
        let suggestions = BenchmarkHistoryBridge.suggestions(from: model.document.history)
        let unapplied = suggestions.filter { suggestion in
            let state = model.document.benchmarks.metrics[suggestion.metricID] ?? .init()
            return state.numbers.isEmpty
        }
        if !unapplied.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.subheadline)
                    Text("From your workouts")
                        .font(.system(size: 11, weight: .black))
                }
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
                ForEach(unapplied, id: \.metricID) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
    }

    private func suggestionCard(_ suggestion: BenchmarkSuggestion) -> some View {
        let metric = BenchmarkCatalog.metric(for: suggestion.metricID)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: metric?.systemImage ?? "questionmark")
                .font(.body)
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(SetlinePalette.lime.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(metric?.name ?? suggestion.metricID)
                    .font(.subheadline.weight(.bold))
                Text(suggestion.texts["source"] ?? "\(suggestion.sourceExerciseName) \u{00B7} \(suggestion.sourceDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await model.applyBenchmarkSuggestion(suggestion) }
            } label: {
                Text("Fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(SetlinePalette.ink)
                    .foregroundStyle(SetlinePalette.chalk)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(SetlinePalette.lime.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statsRow: some View {
        let reached = BenchmarkCatalog.reachedCount(in: model.document.benchmarks)
        let recorded = BenchmarkCatalog.recordedCount(in: model.document.benchmarks)
        let history = model.document.benchmarks.history.count
        return HStack(spacing: 10) {
            benchmarkStat("\(reached)", "/ \(BenchmarkCatalog.metrics.count)", "Targets reached", SetlinePalette.lime)
            benchmarkStat("\(recorded)", "/ \(BenchmarkCatalog.metrics.count)", "Starting points", SetlinePalette.blue)
            benchmarkStat("\(history)", nil, "Saved check-ins", SetlinePalette.paper)
        }
    }

    private func benchmarkStat(_ value: String, _ suffix: String?, _ label: String, _ bg: Color) -> some View {
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

    private var focusStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "scope")
                .font(.title3)
                .foregroundStyle(SetlinePalette.ink.opacity(0.7))
            Text("A checkpoint list, not 15 daily workouts. Test consistently, roughly every 8\u{2013}12 weeks; do not chase every target at once.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.75))
        }
        .padding(14)
        .background(SetlinePalette.blue.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var checkInBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Your benchmarks")
                Spacer()
                ShareLink(
                    item: BenchmarkScorecard.text(for: model.document.benchmarks),
                    preview: SharePreview("Setline baseline scorecard")
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                }
                .frame(minHeight: 36)
                DatePicker("", selection: $checkInDate, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                    .frame(minHeight: 36)
                Button {
                    Task { await model.saveBenchmarkCheckIn(date: checkInDate) }
                } label: {
                    Label("Save check-in", systemImage: "plus")
                        .font(.caption.weight(.bold))
                }
                .frame(minHeight: 36)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(BenchmarkCatalog.groups, id: \.id) { group in
                    let count = group.id == "all"
                        ? BenchmarkCatalog.metrics.count
                        : BenchmarkCatalog.metrics.filter { $0.group.rawValue == group.id }.count
                    Button {
                        activeGroup = group.id
                    } label: {
                        Text("\(group.name) \(count)")
                            .font(.caption.weight(activeGroup == group.id ? .black : .semibold))
                            .foregroundStyle(activeGroup == group.id ? SetlinePalette.chalk : SetlinePalette.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(activeGroup == group.id ? SetlinePalette.ink : SetlinePalette.steel.opacity(0.5))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var metricCards: some View {
        VStack(spacing: 14) {
            ForEach(BenchmarkCatalog.metrics, id: \.id) { metric in
                if activeGroup == "all" || metric.group.rawValue == activeGroup {
                    BenchmarkMetricCard(metric: metric)
                }
            }
        }
    }

    private var bottomNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            Text("Ambitious goals, not certified percentiles. An easy attempt is a lower bound, a blank is unknown, and an estimated lift is not a tested maximum.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.72))
        }
        .padding(.top, 8)
    }

    // MARK: - Check-ins

    @ViewBuilder
    private var checkInsContent: some View {
        let history = model.document.benchmarks.history
        if history.isEmpty {
            ContentUnavailableView(
                "Your first chapter is unwritten.",
                systemImage: "calendar.badge.plus",
                description: Text("Enter your results on the overview, then save a check-in. Your current inputs autosave; check-ins preserve the history.")
            )
            .frame(minHeight: 260)
            Button {
                activeView = .overview
            } label: {
                Label("Back to overview", systemImage: "arrow.left")
            }
            .buttonStyle(ActionSlabStyle())
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(history) { checkIn in
                    BenchmarkCheckInRow(checkIn: checkIn)
                }
            }
            Text("Check-in dates are logging dates, not proof that every test was performed on that day. A snapshot carries forward unchanged results.")
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.72))
                .padding(.top, 8)
        }
    }

    // MARK: - Guide

    private var guideContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Measure the capability. Not your worth.")
                .font(.system(.title, design: .rounded, weight: .black))
                .tracking(-0.8)
            Text("A small set of checkpoints for broad fitness\u{2014}not an athlete ranking, a diagnosis, or a training prescription.")
                .font(.body)
                .foregroundStyle(.secondary)
            guideCard("One target per capability", body: "Use the 15 cards as periodic checkpoints. Overlapping push-up, dip, dead-hang, plank, and VO\u{2082}max targets are deliberately left out. A 10 km run does not reveal an exact VO\u{2082}max, and bench strength does not prove a specific push-up count.")
            guideCard("What the numbers mean", body: "Targets are editable coaching goals, not validated top-10% cutoffs. Waist-to-height below 0.50 is a health-oriented guardrail, not an elite score. The mobility checks sample specific movements, not every joint. \u{201C}Targets reached\u{201D} only counts checklist items\u{2014}it is not a composite fitness percentage.")
            guideCard("Bodyweight and bench estimates", body: "Weight-based targets use your current entered bodyweight: bench 1.25\u{00D7}, split squat 0.50\u{00D7} total external load, and farmer carry 0.50\u{00D7} per hand. Do not add bodyweight to the dumbbell load. For bench sets of 2\u{2013}10 repetitions, the app shows the planning estimate load \u{00D7} (1 + reps / 30). It is not a measured maximum.")
            guideCard("Compare like with like", body: "Run: record the actual distance and elapsed time; no projected 10 km times. Pull-ups: no kipping. Split squats: same depth and setup, repetitions for the weaker leg. Carries: same handles, no straps, no put-downs. Jumps: a practised best of three with a stable landing. Balance uses the weaker side under eyes-closed conditions.")
            guideCard("Test safely", body: "Do not rush into maximal lifts, jumps, or shuttle sprints from your present baseline. Build familiarity and use a spotter or appropriate safeties for bench testing. Stop for pain, dizziness, or other concerning symptoms. Use gentle, pain-free mobility ranges and a nearby support for eyes-closed balance. Swim with appropriate supervision.")
            guideCard("Your data stays with you", body: "No account, analytics, or network requests in the benchmark path. Changes save on this device. Check-ins provide local snapshots, not a remote backup. Use Export to keep a copy.")
            HStack(spacing: 12) {
                Button {
                    showClearConfirmation = true
                } label: {
                    Label("Clear measurements", systemImage: "trash")
                        .font(.caption.weight(.bold))
                }
                .frame(minHeight: 40)
            }
            .padding(.top, 8)
        }
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
