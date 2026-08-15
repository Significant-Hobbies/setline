import Charts
import SetlineCore
import SwiftUI

/// Every exercise with recorded evidence, its measured current values, the ideal
/// you authored, and the distance between the two.
struct ExercisesView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var isCatalogueShown = false

    /// Movements you have actually trained, most recently trained first.
    private var trainedExercises: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for session in model.document.history {
            for step in session.steps where step.countsTowardVolume {
                if seen.insert(ExerciseMetrics.normalise(step.exerciseName)).inserted {
                    names.append(step.exerciseName)
                }
            }
        }
        return names
    }

    /// Goals whose movement has no recorded working set yet — still worth showing,
    /// clearly marked as awaiting evidence.
    private var goalsWithoutEvidence: [ExerciseGoal] {
        let trained = Set(trainedExercises.map(ExerciseMetrics.normalise))
        return model.document.goals.filter { !trained.contains(ExerciseMetrics.normalise($0.exerciseName)) }
    }

    private var filtered: [String] {
        guard !query.isEmpty else { return trainedExercises }
        let needle = ExerciseMetrics.normalise(query)
        return trainedExercises.filter { ExerciseMetrics.normalise($0).contains(needle) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader("Exercises", subtitle: "Measured current, authored ideal, and the gap between them.")
                if !model.document.goals.isEmpty {
                    goalSummary
                }
                Button {
                    isCatalogueShown = true
                } label: {
                    Label("Set a target from the catalogue", systemImage: "target")
                }
                .buttonStyle(ActionSlabStyle())
                if trainedExercises.isEmpty {
                    ContentUnavailableView(
                        "No recorded working sets",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Complete a working set and its measurements appear here. Setline will not estimate a starting point.")
                    )
                    .frame(minHeight: 260)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Trained movements")
                        ForEach(filtered, id: \.self) { name in
                            NavigationLink {
                                ExerciseDetailView(exerciseName: name)
                            } label: {
                                exerciseRow(name)
                            }
                            InkRule()
                        }
                    }
                }
                if !goalsWithoutEvidence.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Targets awaiting evidence")
                        ForEach(goalsWithoutEvidence) { goal in
                            NavigationLink {
                                ExerciseDetailView(exerciseName: goal.exerciseName)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(goal.exerciseName).font(.headline)
                                        Text("\(goal.metric.title) target \(goal.metric.format(goal.targetValue))")
                                            .font(.subheadline.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundStyle(SetlinePalette.ink)
                                .padding(.vertical, 8)
                            }
                            InkRule()
                        }
                    }
                }
            }
            .padding(20)
        }
        .searchable(text: $query, prompt: "Search trained movements")
        .setlineBackground()
        .navigationBarHidden(true)
        .sheet(isPresented: $isCatalogueShown) {
            CataloguePickerView()
        }
    }

    private var goalSummary: some View {
        let progresses = model.document.goals.map {
            ExerciseMetrics.progress(for: $0, history: model.document.history)
        }
        let achieved = progresses.count(where: \.isAchieved)
        return HStack(spacing: 10) {
            summaryTile("TARGETS", "\(progresses.count)", SetlinePalette.blue)
            summaryTile("REACHED", "\(achieved)", SetlinePalette.lime)
        }
    }

    private func summaryTile(_ label: String, _ value: String, _ colour: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
            SectionLabel(text: label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(colour)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func exerciseRow(_ name: String) -> some View {
        let metrics = ExerciseMetrics.availableMetrics(for: name, history: model.document.history)
        let headline = metrics.first.flatMap { metric in
            ExerciseMetrics.current(for: name, metric: metric, history: model.document.history)
                .map { (metric, $0) }
        }
        let goal = model.document.goals.first {
            ExerciseMetrics.normalise($0.exerciseName) == ExerciseMetrics.normalise(name)
        }
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.headline.weight(.black))
                if let headline {
                    Text("\(headline.0.title): \(headline.0.format(headline.1.value))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let goal {
                    let progress = ExerciseMetrics.progress(for: goal, history: model.document.history)
                    HStack(spacing: 6) {
                        Text("Target \(goal.metric.format(goal.targetValue))")
                            .font(.caption.monospacedDigit().weight(.bold))
                        if progress.isAchieved {
                            Text("REACHED")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(SetlinePalette.lime)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else if let fraction = progress.fraction {
                            Text("\(Int(fraction * 100))%")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .foregroundStyle(SetlinePalette.ink)
        .padding(.vertical, 8)
    }
}

/// One movement: what it measures, what you have measured, and what you want.
struct ExerciseDetailView: View {
    @Environment(AppModel.self) private var model
    let exerciseName: String

    @State private var isGoalEditorShown = false
    @State private var editingGoal: ExerciseGoal?

    private var definition: ExerciseDefinition? { ExerciseCatalogue.match(name: exerciseName) }

    private var availableMetrics: [MetricKind] {
        let measured = ExerciseMetrics.availableMetrics(for: exerciseName, history: model.document.history)
        guard measured.isEmpty else { return measured }
        return definition?.goalMetrics ?? []
    }

    private var goals: [ExerciseGoal] {
        model.document.goals.filter {
            ExerciseMetrics.normalise($0.exerciseName) == ExerciseMetrics.normalise(exerciseName)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                heading
                currentBlock
                goalsBlock
                progressionBlock
                if let definition { detailsBlock(definition) }
            }
            .padding(20)
        }
        .setlineBackground()
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isGoalEditorShown) {
            GoalEditorView(exerciseName: exerciseName, metrics: metricsForGoal, existing: nil)
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditorView(exerciseName: exerciseName, metrics: metricsForGoal, existing: goal)
        }
    }

    private var metricsForGoal: [MetricKind] {
        let candidates = definition?.goalMetrics ?? []
        let measured = ExerciseMetrics.availableMetrics(for: exerciseName, history: model.document.history)
        let combined = candidates + measured.filter { !candidates.contains($0) }
        return combined.isEmpty ? MetricKind.allCases : combined
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let definition {
                HStack(spacing: 6) {
                    ForEach(Pillar.allCases.filter { definition.pillars.contains($0) }, id: \.self) { pillar in
                        Text(pillar.title.uppercased())
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SetlinePalette.blue.opacity(0.7))
                            .clipShape(Capsule())
                    }
                }
                if !definition.cue.isEmpty {
                    Text(definition.cue)
                        .font(.subheadline)
                        .foregroundStyle(SetlinePalette.ink.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Current

    private var currentBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Current · measured")
            if availableMetrics.isEmpty {
                Text("No comparable working set recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(availableMetrics, id: \.self) { metric in
                    if let value = ExerciseMetrics.current(
                        for: exerciseName,
                        metric: metric,
                        history: model.document.history
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
                            Text(metric.format(value.value))
                                .font(.system(size: 28, weight: .black, design: .rounded).monospacedDigit())
                            Text(value.provenance)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(SetlinePalette.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
                            Text("Unavailable")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(SetlinePalette.paper.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Goals

    private var goalsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Ideal · authored")
                Spacer()
                Button {
                    isGoalEditorShown = true
                } label: {
                    Label("Set target", systemImage: "plus")
                        .font(.caption.weight(.bold))
                }
                .frame(minHeight: 32)
            }
            if goals.isEmpty {
                Text("No target set. Setting one turns recorded numbers into a trajectory.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(goals) { goal in
                    goalCard(ExerciseMetrics.progress(for: goal, history: model.document.history))
                }
            }
        }
    }

    private func goalCard(_ progress: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(progress.goal.metric.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SetlinePalette.ink.opacity(0.6))
                    Text(progress.goal.metric.format(progress.goal.targetValue))
                        .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                }
                Spacer()
                if progress.isAchieved {
                    Text("REACHED")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(SetlinePalette.lime)
                        .clipShape(Capsule())
                }
                Menu {
                    Button("Edit target") { editingGoal = progress.goal }
                    Button("Remove target", role: .destructive) {
                        Task { await model.deleteGoal(progress.goal) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 32, height: 32)
                }
            }
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
                    .tint(progress.isAchieved ? SetlinePalette.lime : SetlinePalette.ink)
            }
            HStack(spacing: 16) {
                if let current = progress.current {
                    factColumn("NOW", progress.goal.metric.format(current.value))
                }
                if let remaining = progress.remaining, remaining > 0 {
                    factColumn("TO GO", progress.goal.metric.format(remaining))
                }
                if let rate = progress.ratePerWeek, abs(rate) > 0.001 {
                    factColumn("PER WEEK", progress.goal.metric.format(abs(rate)))
                }
            }
            if let projected = progress.projectedDate {
                Text("At the recorded rate, reached around \(projected.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if progress.evidenceCount < 2 {
                Text("A trend needs at least two comparable sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            trendChart(progress)
        }
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func factColumn(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(SetlinePalette.ink.opacity(0.55))
            Text(value).font(.subheadline.monospacedDigit().weight(.bold))
        }
    }

    @ViewBuilder
    private func trendChart(_ progress: GoalProgress) -> some View {
        let points = ExerciseMetrics.series(
            for: progress.goal.exerciseName,
            metric: progress.goal.metric,
            referenceRepetitions: progress.goal.referenceRepetitions,
            history: model.document.history
        )
        // Two points is the floor for a line that means anything.
        if points.count >= 2 {
            Chart {
                ForEach(points) { point in
                    LineMark(x: .value("Date", point.achievedAt), y: .value(progress.goal.metric.title, point.value))
                        .foregroundStyle(SetlinePalette.ink)
                    PointMark(x: .value("Date", point.achievedAt), y: .value(progress.goal.metric.title, point.value))
                        .foregroundStyle(SetlinePalette.ink)
                }
                RuleMark(y: .value("Target", progress.goal.targetValue))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(SetlinePalette.coral)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Target").font(.system(size: 9, weight: .black)).foregroundStyle(SetlinePalette.coral)
                    }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 160)
            .accessibilityLabel("\(progress.goal.metric.title) trend across \(points.count) sessions")
        }
    }

    // MARK: - Progression

    @ViewBuilder
    private var progressionBlock: some View {
        if let recommendation = ProgressionEngine.recommendation(
            for: exerciseName,
            rule: nil,
            history: model.document.history
        ), recommendation.action != .insufficientEvidence {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Next session")
                Text(actionTitle(recommendation))
                    .font(.system(size: 22, weight: .black, design: .rounded).monospacedDigit())
                if let evidence = recommendation.evidenceSummary {
                    Text("Last session: \(evidence)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(recommendation.rationale)
                    .font(.footnote)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(SetlinePalette.blue.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func actionTitle(_ recommendation: ProgressionRecommendation) -> String {
        switch recommendation.action {
        case .addLoad:
            if let current = recommendation.currentLoad, let next = recommendation.recommendedLoad {
                return "\(current.trimmedString) → \(next.trimmedString) kg"
            }
            return "Add load"
        case .addRepetitions:
            return "Hold the load, add repetitions"
        case .reduceLoad:
            if let current = recommendation.currentLoad, let next = recommendation.recommendedLoad {
                return "\(current.trimmedString) → \(next.trimmedString) kg"
            }
            return "Reduce the load"
        case .insufficientEvidence:
            return "Not enough evidence"
        }
    }

    // MARK: - Reference

    private func detailsBlock(_ definition: ExerciseDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Movement")
            LabeledContent("Trains", value: definition.primaryMuscles.map(\.title).joined(separator: ", "))
            if !definition.secondaryMuscles.isEmpty {
                LabeledContent("Also", value: definition.secondaryMuscles.map(\.title).joined(separator: ", "))
            }
            LabeledContent("Equipment", value: definition.equipment.map(\.title).joined(separator: ", "))
            LabeledContent("Default rest", value: definition.defaultRest.displayString)
            if let rule = TwelveWeekProgramme.rule(forSlug: definition.slug) {
                InkRule()
                SectionLabel(text: "Authored progression")
                Text("\(rule.repsLow)–\(rule.repsHigh) reps. \(rule.specialRule)")
                    .font(.footnote)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.72))
            }
        }
        .font(.subheadline)
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Authors an ideal for one exercise and metric.
private struct GoalEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let metrics: [MetricKind]
    let existing: ExerciseGoal?

    @State private var metric: MetricKind
    @State private var value = ""
    @State private var referenceRepetitions = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Date.now.addingTimeInterval(60 * 60 * 24 * 84)
    @State private var note = ""

    init(exerciseName: String, metrics: [MetricKind], existing: ExerciseGoal?) {
        self.exerciseName = exerciseName
        self.metrics = metrics
        self.existing = existing
        _metric = State(initialValue: existing?.metric ?? metrics.first ?? .estimatedOneRepMax)
        _value = State(initialValue: existing.map { $0.targetValue.trimmedString } ?? "")
        _referenceRepetitions = State(initialValue: existing?.referenceRepetitions.map(String.init) ?? "")
        _hasTargetDate = State(initialValue: existing?.targetDate != nil)
        _targetDate = State(initialValue: existing?.targetDate ?? Date.now.addingTimeInterval(60 * 60 * 24 * 84))
        _note = State(initialValue: existing?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movement") {
                    LabeledContent("Exercise", value: exerciseName)
                    Picker("Measure", selection: $metric) {
                        ForEach(metrics, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
                Section("Ideal") {
                    HStack {
                        TextField("Target", text: $value)
                            .keyboardType(.decimalPad)
                        Text(metric.unit).foregroundStyle(.secondary)
                    }
                    if metric == .topSetLoad {
                        HStack {
                            TextField("For at least", text: $referenceRepetitions)
                                .keyboardType(.numberPad)
                            Text("reps").foregroundStyle(.secondary)
                        }
                    }
                    if metric == .bestPaceSecondsPerKilometre {
                        Text("Enter seconds per kilometre. Lower is better.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Set a target date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("By", selection: $targetDate, displayedComponents: .date)
                    }
                }
                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(existing == nil ? "New target" : "Edit target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(Double(value) == nil)
                }
            }
        }
    }

    private func save() {
        guard let targetValue = Double(value) else { return }
        let goal = ExerciseGoal(
            id: existing?.id ?? UUID(),
            exerciseName: exerciseName,
            metric: metric,
            targetValue: targetValue,
            referenceRepetitions: metric == .topSetLoad ? Int(referenceRepetitions) : nil,
            targetDate: hasTargetDate ? targetDate : nil,
            createdAt: existing?.createdAt ?? .now,
            note: note.isEmpty ? nil : note
        )
        Task {
            await model.saveGoal(goal)
            dismiss()
        }
    }
}

/// Browse the bundled movement library to set a target for something not yet trained.
private struct CataloguePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var pillar: Pillar?

    private var results: [ExerciseDefinition] {
        let base = pillar.map { ExerciseCatalogue.definitions(for: $0) } ?? ExerciseCatalogue.search(query)
        guard pillar != nil, !query.isEmpty else { return base }
        let needle = ExerciseMetrics.normalise(query)
        return base.filter { ExerciseMetrics.normalise($0.name).contains(needle) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Pillar", selection: $pillar) {
                        Text("All").tag(Pillar?.none)
                        ForEach(Pillar.allCases, id: \.self) { option in
                            Text(option.title).tag(Pillar?.some(option))
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ForEach(results) { definition in
                    NavigationLink {
                        ExerciseDetailView(exerciseName: definition.name)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(definition.name).font(.headline)
                            Text(definition.equipment.map(\.title).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search \(ExerciseCatalogue.all.count) movements")
            .navigationTitle("Movement library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
