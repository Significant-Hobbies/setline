import SetlineCore
import SwiftUI
import UniformTypeIdentifiers

struct PlanView: View {
    @Environment(AppModel.self) private var model
    @State private var editingTemplate: WorkoutTemplate?
    @State private var isCreatingTemplate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader("Plan", subtitle: "Templates stay authored. Sessions record deviations.")
                if let programme = model.document.programme {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionLabel(text: "Active programme")
                                Text(programme.name).font(.title2.weight(.black))
                                Text("\(programme.weekCount) weeks · Monday-based")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Enabled", isOn: Binding(
                                get: { programme.enabled },
                                set: { _ in Task { await model.toggleProgramme() } }
                            ))
                            .labelsHidden()
                        }
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                            spacing: 6
                        ) {
                            ForEach(programme.days) { day in
                                Menu {
                                    Button("Rest day") {
                                        Task { await model.assignTemplate(nil, to: day.weekday) }
                                    }
                                    ForEach(model.document.templates) { template in
                                        Button(template.name) {
                                            Task { await model.assignTemplate(template.id, to: day.weekday) }
                                        }
                                    }
                                } label: {
                                    VStack(spacing: 7) {
                                        Text(Calendar.current.shortWeekdaySymbols[day.weekday - 1].prefix(2))
                                            .font(.caption2.weight(.bold))
                                        Image(systemName: day.templateID == nil ? "minus" : "checkmark")
                                            .font(.caption.weight(.black))
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(day.templateID == nil ? SetlinePalette.steel.opacity(0.55) : SetlinePalette.lime)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .accessibilityLabel("\(Calendar.current.weekdaySymbols[day.weekday - 1]), \(templateName(for: day.templateID))")
                            }
                        }
                        Stepper(
                            "Block length: \(programme.weekCount) weeks",
                            value: Binding(
                                get: { programme.weekCount },
                                set: { weeks in Task { await model.setProgrammeWeeks(weeks) } }
                            ),
                            in: 1...16
                        )
                    }
                    .padding(18)
                    .background(SetlinePalette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionLabel(text: "Workout templates")
                        Spacer()
                        Button { isCreatingTemplate = true } label: {
                            Label("New template", systemImage: "plus")
                        }
                        .font(.subheadline.weight(.bold))
                        .frame(minHeight: 44)
                    }
                    ForEach(model.document.templates) { template in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name).font(.title3.weight(.black))
                                    Text(template.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(template.isBundled ? "BUNDLED" : "CUSTOM")
                                    .font(.caption2.weight(.black))
                                    .padding(6)
                                    .background(template.isBundled ? SetlinePalette.blue : SetlinePalette.lime)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            HStack {
                                Text("\(template.exercises.count) exercises")
                                Text("·")
                                Text("\(template.exercises.flatMap(\.sets).count) sets")
                                Spacer()
                                Button("Duplicate") { Task { await model.duplicateTemplate(template) } }
                                    .font(.subheadline.weight(.bold))
                                if !template.isBundled {
                                    Button("Edit") { editingTemplate = template }
                                        .font(.subheadline.weight(.bold))
                                }
                            }
                            .font(.subheadline.monospacedDigit())
                            InkRule()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(20)
        }
        .setlineBackground()
        .navigationBarHidden(true)
        .sheet(isPresented: $isCreatingTemplate) {
            TemplateEditorView()
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(template: template)
        }
    }

    private func templateName(for id: UUID?) -> String {
        guard let id else { return "rest day" }
        return model.document.templates.first(where: { $0.id == id })?.name ?? "unavailable template"
    }
}

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                pageHeader("History", subtitle: "Recorded, calculated, and unavailable stay distinct.")
                HStack(spacing: 10) {
                    historyMetric("SESSIONS", "\(model.document.history.count)", SetlinePalette.blue)
                    historyMetric("SETS", "\(model.document.history.reduce(0) { $0 + $1.completedCount })", SetlinePalette.lime)
                }
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
                                    Text("\(session.completedCount) completed · \(session.steps.count - session.completedCount) skipped")
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
            .padding(20)
        }
        .setlineBackground()
        .navigationBarHidden(true)
    }

    private var progressionSection: some View {
        let exerciseNames = Array(Set(model.document.history.flatMap(\.steps).map(\.exerciseName))).sorted()
        let recommendations = exerciseNames.compactMap {
            ProgressionEngine.recommendation(for: $0, history: model.document.history)
        }
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Next-session suggestions")
            if recommendations.isEmpty {
                Text("Unavailable until at least two comparable completed strength sets establish evidence.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recommendations, id: \.exerciseName) { recommendation in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(recommendation.exerciseName).font(.headline)
                        Text("\(recommendation.previousWeight.formatted()) → \(recommendation.recommendedWeight.formatted()) kg")
                            .font(.title3.monospacedDigit().weight(.black))
                        Text(recommendation.rationale).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(SetlinePalette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func historyMetric(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.system(size: 36, weight: .black, design: .rounded).monospacedDigit())
            SectionLabel(text: label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct TemplateEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutTemplate

    init(template: WorkoutTemplate? = nil) {
        _draft = State(initialValue: template ?? WorkoutTemplate(
            name: "",
            detail: "",
            isBundled: false,
            exercises: [
                Exercise(
                    name: "",
                    cue: "",
                    sets: [PlannedSet(label: "Working 1", kind: .strength, target: "", restSeconds: 90)]
                ),
            ]
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Name", text: $draft.name)
                    TextField("Short description", text: $draft.detail, axis: .vertical)
                }
                ForEach($draft.exercises) { $exercise in
                    Section {
                        TextField("Exercise name", text: $exercise.name)
                        TextField("Coaching cue", text: $exercise.cue, axis: .vertical)
                        ForEach($exercise.sets) { $set in
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Set label", text: $set.label)
                                Picker("Activity", selection: $set.kind) {
                                    ForEach(ActivityKind.allCases, id: \.self) { kind in
                                        Text(kind.rawValue.capitalized).tag(kind)
                                    }
                                }
                                TextField("Target", text: $set.target)
                                Stepper("Rest: \(set.restSeconds) seconds", value: $set.restSeconds, in: 0...600, step: 15)
                                Button("Remove set", role: .destructive) {
                                    exercise.sets.removeAll { $0.id == set.id }
                                }
                            }
                        }
                        Button {
                            exercise.sets.append(PlannedSet(
                                label: "Working \(exercise.sets.count + 1)",
                                kind: .strength,
                                target: "",
                                restSeconds: 90
                            ))
                        } label: {
                            Label("Add set", systemImage: "plus")
                        }
                        Button("Remove exercise", role: .destructive) {
                            draft.exercises.removeAll { $0.id == exercise.id }
                        }
                    } header: {
                        Text(exercise.name.isEmpty ? "Exercise" : exercise.name)
                    }
                }
                Section {
                    Button {
                        draft.exercises.append(Exercise(
                            name: "",
                            cue: "",
                            sets: [PlannedSet(label: "Working 1", kind: .strength, target: "", restSeconds: 90)]
                        ))
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "New template" : "Edit template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await model.saveTemplate(draft)
                            dismiss()
                        }
                    }
                    .disabled(
                        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        draft.exercises.isEmpty ||
                        draft.exercises.contains { exercise in
                            exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exercise.sets.isEmpty
                        }
                    )
                }
            }
        }
    }
}

private struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section("Session receipt") {
                LabeledContent("Workout", value: session.templateName)
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let completedAt = session.completedAt {
                    LabeledContent("Completed", value: completedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            Section("Execution ledger") {
                ForEach(Array(session.steps.enumerated()), id: \.element.id) { performed, step in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(step.exerciseName).font(.headline)
                            Spacer()
                            Text(step.status.rawValue.uppercased()).font(.caption.weight(.black))
                        }
                        Text("Planned #\(step.authoredPosition + 1) · performed \(step.performedPosition.map { "#\($0 + 1)" } ?? "—")")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text("Target: \(step.target)").font(.subheadline)
                        if !step.segments.isEmpty {
                            Text("Recorded: " + step.segments.map(\.recordedDescription).joined(separator: " + "))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Recorded workout")
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isImporterPresented = false
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader("You", subtitle: "Device-first. Nothing leaves this iPhone unless you choose it.")
                settingsSection("Account & sync") {
                    HStack {
                        Image(systemName: "iphone.gen3")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(SetlinePalette.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Device-only mode").font(.headline)
                            Text("Workout actions work offline.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(model.document.syncState.rawValue.uppercased())
                            .font(.caption2.weight(.black))
                    }
                    Link(destination: URL(string: "https://setline.significanthobbies.com")!) {
                        Label("Open Setline account", systemImage: "safari")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                }
                settingsSection("Your data") {
                    ShareLink(
                        item: SetlineExportPayload(document: model.document),
                        preview: SharePreview("Setline data")
                    ) {
                        Label("Export complete Setline data", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 48)
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Preview an import", systemImage: "doc.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 48)
                    Button(role: .destructive) { showResetConfirmation = true } label: {
                        Label("Reset local data", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 48)
                }
                settingsSection("About") {
                    LabeledContent("Version", value: "1.0.0 (1)")
                    Link("Privacy", destination: URL(string: "https://setline.significanthobbies.com/privacy")!)
                        .frame(minHeight: 44)
                    Link("Support", destination: URL(string: "https://setline.significanthobbies.com")!)
                        .frame(minHeight: 44)
                }
            }
            .padding(20)
        }
        .setlineBackground()
        .navigationBarHidden(true)
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.json]) { result in
            guard case let .success(url) = result else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                Task { await model.prepareImport(data) }
            }
        }
        .alert("Replace all Setline data?", isPresented: $model.isImportConfirmationPresented) {
            Button("Replace", role: .destructive) { Task { await model.confirmImport() } }
            Button("Cancel", role: .cancel) { model.importPreview = nil }
        } message: {
            Text("The import contains \(model.importPreview?.templates.count ?? 0) templates and \(model.importPreview?.history.count ?? 0) completed workouts. Your current device state will be replaced.")
        }
        .confirmationDialog("Reset local Setline data?", isPresented: $showResetConfirmation) {
            Button("Reset local data", role: .destructive) { Task { await model.resetLocalData() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(16)
                .background(SetlinePalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private func pageHeader(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("SETLINE").font(.caption.weight(.black)).tracking(2.2)
        InkRule()
        Text(title).font(.system(.largeTitle, design: .rounded, weight: .black))
        Text(subtitle).font(.body).foregroundStyle(.secondary)
    }
    .padding(.top, 18)
}

private struct SetlineExportPayload: Transferable {
    let document: SetlineDocument

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { payload in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(payload.document)
        }
    }
}

private extension SetSegment {
    var recordedDescription: String {
        if let weight, let repetitions { return "\(weight.formatted()) kg × \(repetitions)" }
        if let repetitions { return "\(repetitions) reps" }
        if let durationSeconds { return "\(durationSeconds)s" }
        if let distanceKilometres { return "\(distanceKilometres.formatted()) km" }
        return "Recorded"
    }
}
