import SetlineCore
import SwiftUI
import SaaSMakerUI

struct PlanView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editingTemplate: WorkoutTemplate?
    @State private var isCreatingTemplate = false
    @State private var showProgrammeSwitch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader("Plan", subtitle: "Templates stay authored. Sessions record deviations.")
                programmeSection
                templatesSection
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
        .confirmationDialog("Which programme drives Today?", isPresented: $showProgrammeSwitch) {
            Button(TwelveWeekProgramme.shortName) {
                Task { await model.selectProgramme(.bundled(.twelveWeekStrengthCardioMobility)) }
            }
            if let custom = model.document.programme.customProgramme {
                Button(custom.name) { Task { await model.selectProgramme(.custom(custom)) } }
            } else {
                Button("Create a weekly programme") {
                    Task { await model.selectProgramme(.custom(CustomProgramme(
                        name: "My programme",
                        weekCount: 12,
                        enabled: true,
                        days: (1...7).map { ProgrammeDay(weekday: $0, templateID: nil) }
                    ))) }
                }
                .textCase(.lowercase)
                .accessibilityLabel("Create a weekly programme")
            }
            Button("No programme") { Task { await model.selectProgramme(.none) } }
                .textCase(.lowercase)
                .accessibilityLabel("No programme")
            Button("Cancel", role: .cancel) {}
                .textCase(.lowercase)
                .accessibilityLabel("Cancel")
        }
    }

    // MARK: - Programme

    @ViewBuilder
    private var programmeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "Active programme")
                    Text(programmeTitle).font(SetlineType.title2.weight(.black))
                    Text(programmeSubtitle)
                        .font(SetlineType.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showProgrammeSwitch = true
                } label: {
                    Label("change", systemImage: "arrow.triangle.2.circlepath").accessibilityLabel("Change")
                        .font(SetlineType.caption.weight(.bold))
                }
                .frame(minHeight: 36)
            }
            switch model.document.programme {
            case .bundled(.twelveWeekStrengthCardioMobility):
                bundledProgrammeDetail
            case let .custom(programme):
                customProgrammeEditor(programme)
            case .none:
                Text("Today will offer your first template until a programme is chosen.")
                    .font(SetlineType.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var programmeTitle: String {
        switch model.document.programme {
        case let .bundled(id): id.title
        case let .custom(programme): programme.name
        case .none: "No programme"
        }
    }

    private var programmeSubtitle: String {
        switch model.document.programme {
        case .bundled(.twelveWeekStrengthCardioMobility):
            let position = TwelveWeekProgramme.position(for: .now)
            return "Week \(position.weekNumber) of 12 · authored, Monday-based"
        case let .custom(programme):
            return "\(programme.weekCount) weeks · \(programme.enabled ? "running" : "paused")"
        case .none:
            return "Choose a programme to schedule Today"
        }
    }

    private var bundledProgrammeDetail: some View {
        let position = TwelveWeekProgramme.position(for: .now)
        return VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: dynamicTypeSize.isAccessibilitySize ? 2 : 7), spacing: 6) {
                ForEach(TwelveWeekProgramme.schedule) { entry in
                    VStack(spacing: 5) {
                        Text(entry.dayLabel)
                            .font(SetlineType.caption2.weight(.bold))
                        Text(entry.title)
                            .font(.custom(SetlinePalette.theme.sansFont, size: 9, relativeTo: .caption2).weight(.bold))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(4)
                    .background(entry.dayIndex == position.dayIndex ? SetlinePalette.lime : SetlinePalette.blue.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("\(entry.dayLabel): \(entry.title)")
                }
            }
            InkRule()
            SectionLabel(text: "Sessions in this block")
            ForEach(ProgrammeSessionKind.allCases, id: \.self) { kind in
                let template = TwelveWeekProgramme.template(for: kind, week: position.weekNumber)
                NavigationLink {
                    SessionPreviewView(resolved: ResolvedSession(
                        template: template,
                        programmeWeek: position.weekNumber,
                        subtitle: "Week \(position.weekNumber)",
                        notes: template.notes
                    ))
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name).font(SetlineType.subheadline.weight(.bold))
                            Text("\(template.exercises.count) exercises · \(template.workingSetCount) working sets")
                                .font(SetlineType.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(SetlineType.caption)
                    }
                    .foregroundStyle(SetlinePalette.ink)
                    .padding(.vertical, 6)
                }
            }
            InkRule()
            SectionLabel(text: "Checkpoints")
            ForEach(TwelveWeekProgramme.checkpoints) { checkpoint in
                HStack {
                    Text(checkpoint.name).font(SetlineType.caption.weight(.bold))
                    Spacer()
                    Text(TwelveWeekProgramme.checkpointDate(checkpoint)
                        .formatted(date: .abbreviated, time: .omitted))
                        .font(SetlineType.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text("Record \(TwelveWeekProgramme.checkpointMeasures.count) measures at each checkpoint, including knee-to-wall distance and squat support.")
                .font(SetlineType.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func customProgrammeEditor(_ programme: CustomProgramme) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Running", isOn: Binding(
                get: { programme.enabled },
                set: { _ in Task { await model.toggleProgramme() } }
            ))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: dynamicTypeSize.isAccessibilitySize ? 2 : 7), spacing: 6) {
                ForEach(programme.days) { day in
                    Menu {
                        Button("Rest day") {
                            Task { await model.assignTemplate(nil, to: day.weekday) }
                        }
                        .textCase(.lowercase)
                        .accessibilityLabel("Rest day")
                        ForEach(model.document.templates) { template in
                            Button(template.name) {
                                Task { await model.assignTemplate(template.id, to: day.weekday) }
                            }
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Text(Calendar.current.shortWeekdaySymbols[day.weekday - 1].prefix(2))
                                .font(SetlineType.caption2.weight(.bold))
                            Image(systemName: day.templateID == nil ? "minus" : "checkmark")
                                .font(SetlineType.caption.weight(.black))
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
    }

    // MARK: - Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Workout templates")
                Spacer()
                Button { isCreatingTemplate = true } label: {
                    Label("new template", systemImage: "plus").accessibilityLabel("New template")
                }
                .font(SetlineType.subheadline.weight(.bold))
                .frame(minHeight: 44)
            }
            if model.document.templates.isEmpty {
                Text("The authored block resolves its own sessions. Add a template for anything outside it.")
                    .font(SetlineType.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.document.templates) { template in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name).font(SetlineType.title3.weight(.black))
                            Text(template.detail).font(SetlineType.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(template.isBundled ? "BUNDLED" : "CUSTOM")
                            .font(SetlineType.caption2.weight(.black))
                            .padding(6)
                            .background(template.isBundled ? SetlinePalette.blue : SetlinePalette.lime)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    HStack {
                        Text("\(template.exercises.count) exercises")
                        Text("·")
                        Text("\(template.workingSetCount) working")
                        Spacer()
                        Button("Duplicate") { Task { await model.duplicateTemplate(template) } }
                            .textCase(.lowercase)
                            .accessibilityLabel("Duplicate")
                            .font(SetlineType.subheadline.weight(.bold))
                        if !template.isBundled {
                            Button("Edit") { editingTemplate = template }
                                .textCase(.lowercase)
                                .accessibilityLabel("Edit")
                                .font(SetlineType.subheadline.weight(.bold))
                        }
                    }
                    .font(SetlineType.subheadline.monospacedDigit())
                    InkRule()
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func templateName(for id: UUID?) -> String {
        guard let id else { return "rest day" }
        return model.document.templates.first(where: { $0.id == id })?.name ?? "unavailable template"
    }
}

/// Authors a template with structured targets rather than free text, so
/// everything entered here can drive progression and measurement.
struct TemplateEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutTemplate

    init(template: WorkoutTemplate? = nil) {
        _draft = State(initialValue: template ?? WorkoutTemplate(
            name: "",
            detail: "",
            isBundled: false,
            exercises: [Self.blankExercise()]
        ))
    }

    static func blankExercise() -> Exercise {
        Exercise(
            name: "",
            cue: "",
            sets: [PlannedSet(
                label: "Working 1",
                kind: .strength,
                target: SetTarget(
                    repTarget: .init(repsLow: 8),
                    load: .chooseLoad
                ),
                rest: RestRange(90)
            )]
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if let message = model.message {
                    Section { Label(message, systemImage: "exclamationmark.triangle") }
                }
                Section("Template") {
                    TextField("Name", text: $draft.name)
                    TextField("Short description", text: $draft.detail, axis: .vertical)
                }
                ForEach($draft.exercises) { $exercise in
                    Section {
                        exerciseFields($exercise)
                        ForEach($exercise.sets) { $plannedSet in
                            setFields($plannedSet, in: $exercise)
                        }
                        Button {
                            exercise.sets.append(PlannedSet(
                                label: "Working \(exercise.sets.count + 1)",
                                kind: exercise.sets.last?.kind ?? .strength,
                                target: exercise.sets.last?.target ?? SetTarget(
                                    repTarget: .init(repsLow: 8),
                                    load: .chooseLoad
                                ),
                                rest: exercise.sets.last?.rest ?? RestRange(90),
                                config: .init(stepType: .working)
                            ))
                        } label: {
                            Label("add set", systemImage: "plus").accessibilityLabel("Add set")
                        }
                        Button("Remove exercise", role: .destructive) {
                            draft.exercises.removeAll { $0.id == exercise.id }
                        }
                        .textCase(.lowercase)
                        .accessibilityLabel("Remove exercise")
                    } header: {
                        Text(exercise.name.isEmpty ? "Exercise" : exercise.name)
                    }
                }
                Section {
                    Button {
                        draft.exercises.append(Self.blankExercise())
                    } label: {
                        Label("add exercise", systemImage: "plus").accessibilityLabel("Add exercise")
                    }
                }
            }
            .disabled(model.isSaving)
            .interactiveDismissDisabled(model.isSaving)
            .navigationTitle(draft.name.isEmpty ? "New template" : "Edit template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .textCase(.lowercase)
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await model.saveTemplate(linked(draft)) { dismiss() }
                        }
                    }
                    .textCase(.lowercase)
                    .accessibilityLabel("Save")
                    .disabled(!isValid || model.isSaving)
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseFields(_ exercise: Binding<Exercise>) -> some View {
        TextField("Exercise name", text: exercise.name)
            .onChange(of: exercise.wrappedValue.name) { _, newValue in
                // Resolving to the catalogue as you type keeps measurements unified.
                guard let definition = ExerciseCatalogue.match(name: newValue) else { return }
                exercise.wrappedValue.definitionSlug = definition.slug
                exercise.wrappedValue.pillars = definition.pillars
                if exercise.wrappedValue.cue.isEmpty {
                    exercise.wrappedValue.cue = definition.cue
                }
            }
        if let definition = ExerciseCatalogue.match(name: exercise.wrappedValue.name) {
            Label("Matched \(definition.name) in the library", systemImage: "checkmark.seal")
                .font(SetlineType.caption)
                .foregroundStyle(.secondary)
        } else if !exercise.wrappedValue.name.isEmpty {
            Label("not in the library — measurements still record under this name", systemImage: "info.circle").accessibilityLabel("Not in the library — measurements still record under this name")
                .font(SetlineType.caption)
                .foregroundStyle(.secondary)
        }
        TextField("Coaching cue", text: exercise.cue, axis: .vertical)
    }

    @ViewBuilder
    private func setFields(_ plannedSet: Binding<PlannedSet>, in exercise: Binding<Exercise>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Set label", text: plannedSet.label)
            Picker("Counts as", selection: plannedSet.stepType) {
                ForEach(StepType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            Picker("Activity", selection: plannedSet.kind) {
                ForEach(ActivityKind.allCases, id: \.self) { kind in
                    Text(kind.rawValue.capitalized).tag(kind)
                }
            }
            targetFields(plannedSet)
            Stepper(
                "Rest: \(plannedSet.wrappedValue.rest.displayString)",
                value: Binding(
                    get: { plannedSet.wrappedValue.rest.lowSeconds },
                    set: { plannedSet.wrappedValue.rest = RestRange($0) }
                ),
                in: 0...600,
                step: 15
            )
            Toggle("Optional", isOn: plannedSet.isOptional)
            Button("Remove set", role: .destructive) {
                exercise.wrappedValue.sets.removeAll { $0.id == plannedSet.wrappedValue.id }
            }
            .textCase(.lowercase)
            .accessibilityLabel("Remove set")
        }
    }

    @ViewBuilder
    private func targetFields(_ plannedSet: Binding<PlannedSet>) -> some View {
        let kind = plannedSet.wrappedValue.kind
        if kind == .strength || kind == .repetitions || kind == .mobility {
            HStack {
                Text("Reps")
                Spacer()
                TextField("low", text: intBinding(plannedSet.target.repsLow))
                    .frame(width: 48)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                Text("–")
                TextField("high", text: intBinding(plannedSet.target.repsHigh))
                    .frame(width: 48)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
        }
        if kind == .strength || kind == .timed {
            HStack {
                Text("Load")
                Spacer()
                TextField("kg, blank to choose", text: loadBinding(plannedSet.target.load))
                    .frame(width: 140)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            }
        }
        if kind == .timed {
            HStack {
                Text("Hold")
                Spacer()
                TextField("seconds", text: intBinding(plannedSet.target.holdSeconds))
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
        }
        if kind == .cardio {
            HStack {
                Text("Duration")
                Spacer()
                TextField("seconds", text: intBinding(plannedSet.target.timeSeconds))
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
        }
        HStack {
            Text("Reps in reserve")
            Spacer()
            TextField("optional", text: intBinding(plannedSet.target.repsInReserve))
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
        }
        Toggle("Per side", isOn: plannedSet.target.perSide)
        LabeledContent("Reads as", value: plannedSet.wrappedValue.target.displayString)
            .font(SetlineType.caption)
    }

    private func intBinding(_ source: Binding<Int?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue.map(String.init) ?? "" },
            set: { source.wrappedValue = Int($0) }
        )
    }

    private func loadBinding(_ source: Binding<LoadTarget?>) -> Binding<String> {
        Binding(
            get: {
                guard case let .absolute(kilograms) = source.wrappedValue else { return "" }
                return kilograms.trimmedString
            },
            set: { text in
                guard let value = Double(text) else {
                    source.wrappedValue = .chooseLoad
                    return
                }
                source.wrappedValue = .absolute(kilograms: value)
            }
        )
    }

    private func linked(_ template: WorkoutTemplate) -> WorkoutTemplate {
        var result = template
        result.exercises = result.exercises.map { exercise in
            guard let definition = ExerciseCatalogue.match(name: exercise.name) else { return exercise }
            var linked = exercise
            linked.definitionSlug = definition.slug
            linked.pillars = definition.pillars
            return linked
        }
        return result
    }

    private var isValid: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.exercises.isEmpty
            && !draft.exercises.contains { exercise in
                exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || exercise.sets.isEmpty
            }
    }
}
