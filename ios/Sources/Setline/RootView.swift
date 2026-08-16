import SetlineCore
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.selectedTab) {
            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "scope") }
                .tag(0)
            NavigationStack { PlanView() }
                .tabItem { Label("Plan", systemImage: "list.bullet.rectangle") }
                .tag(1)
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("You", systemImage: "person.crop.circle") }
                .tag(3)
            NavigationStack { ExercisesView() }
                .tabItem { Label("Exercises", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(4)
        }
        .setlineBackground()
        .fullScreenCover(isPresented: $model.isWorkoutPresented) {
            WorkoutPlayerView()
        }
        .alert("Setline", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
    }
}

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var resolved: ResolvedSession? { model.document.session() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if let active = model.document.activeSession {
                    activeReceipt(active)
                } else if let resolved {
                    workoutHero(resolved)
                } else {
                    ContentUnavailableView(
                        "No programme selected",
                        systemImage: "calendar.badge.plus",
                        description: Text("Choose the authored block or build your own in Plan.")
                    )
                }
                weekStrip
                recentEvidence
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(SetlinePalette.chalk)
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        brandLabel
                        dateLabel
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        brandLabel
                        Spacer()
                        dateLabel
                    }
                }
            }
            .padding(.top, 18)
            InkRule()
            Text("Follow the plan.\nRecord the truth.")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
                .tracking(-1)
                .padding(.top, 10)
        }
    }

    private var brandLabel: some View {
        Text("SETLINE")
            .font(.caption.weight(.black))
            .tracking(2.2)
    }

    private var dateLabel: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            .font(.subheadline.monospacedDigit().weight(.semibold))
    }

    private func workoutHero(_ resolved: ResolvedSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: resolved.isRestDay ? "Today · scheduled rest" : "Today · authored plan")
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
            }
            .padding(.bottom, 14)
            Text(resolved.template.name)
                .font(.system(.title, design: .rounded, weight: .black))
                .tracking(-0.8)
            Text(resolved.subtitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(SetlinePalette.ink.opacity(0.66))
                .padding(.top, 3)
            if let notice = resolved.outOfBlockNotice {
                Text(notice)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.7))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SetlinePalette.blue.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 12)
            }
            if !resolved.isRestDay {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 12) { metrics(resolved.template) }
                    } else {
                        HStack(spacing: 0) { metrics(resolved.template) }
                    }
                }
                .padding(.vertical, 22)
                pillarChips(resolved.template.pillars)
                    .padding(.bottom, 18)
                Button {
                    Task { await model.startWorkout(resolved) }
                } label: {
                    Label("Start workout", systemImage: "arrow.right")
                }
                .buttonStyle(ActionSlabStyle())
                .accessibilityHint("Starts an offline workout using the authored order")
                NavigationLink {
                    SessionPreviewView(resolved: resolved)
                } label: {
                    Label("Review the session first", systemImage: "list.bullet")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            if !resolved.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    InkRule()
                    SectionLabel(text: "Authored rules")
                    ForEach(Array(resolved.notes.enumerated()), id: \.offset) { _, note in
                        Text("· \(note)")
                            .font(.footnote)
                            .foregroundStyle(SetlinePalette.ink.opacity(0.72))
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(20)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SetlinePalette.ink.opacity(0.12), lineWidth: 1)
        }
    }

    /// Scrolls rather than wraps: four pillars cannot share one phone-width row
    /// without hyphenating, and a broken word reads as a rendering fault.
    private func pillarChips(_ pillars: Set<Pillar>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Pillar.allCases.filter { pillars.contains($0) }, id: \.self) { pillar in
                    Text(pillar.title.uppercased())
                        .font(.caption2.weight(.black))
                        .tracking(0.6)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(SetlinePalette.blue.opacity(0.7))
                        .clipShape(Capsule())
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func activeReceipt(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Workout in progress")
            Text(session.templateName)
                .font(.system(.title, design: .rounded, weight: .black))
            ProgressView(value: Double(session.completedCount), total: Double(max(1, session.steps.count)))
                .tint(SetlinePalette.lime)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            Text("\(session.completedCount) of \(session.steps.count) steps recorded")
                .font(.subheadline.monospacedDigit())
            Button("Resume workout") { model.isWorkoutPresented = true }
                .buttonStyle(ActionSlabStyle())
        }
        .padding(20)
        .background(SetlinePalette.ink)
        .foregroundStyle(SetlinePalette.chalk)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Cardio and mobility days author no working sets, so counting them would
    /// read as zero effort. Those sessions report their step count instead.
    @ViewBuilder
    private func metrics(_ template: WorkoutTemplate) -> some View {
        metric("EXERCISES", "\(template.exercises.count)")
        if template.workingSetCount > 0 {
            metric("WORKING", "\(template.workingSetCount)")
        } else {
            metric("STEPS", "\(template.plannedSetCount)")
        }
        metric("MINUTES", template.expectedMinutes.map(String.init) ?? "—")
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.headline.monospacedDigit().weight(.black))
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(SetlinePalette.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekStrip: some View {
        let week = model.document.week()
        let todayIndex = todayStripIndex
        return VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "This week")
            HStack(spacing: 7) {
                ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                    let hasPlan = day != nil && !(day?.isRestDay ?? true)
                    VStack(spacing: 6) {
                        Text(stripDayLabel(index))
                            .font(.caption2.weight(.bold))
                        Circle()
                            .fill(hasPlan ? SetlinePalette.ink : SetlinePalette.steel)
                            .frame(width: 9, height: 9)
                        Text(stripSessionLabel(day))
                            .font(.system(size: 9, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(SetlinePalette.ink.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(index == todayIndex ? SetlinePalette.lime : (hasPlan ? SetlinePalette.blue.opacity(0.65) : .clear))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .accessibilityLabel("\(stripDayLabel(index)): \(day.map { $0.isRestDay ? "rest day" : $0.template.name } ?? "nothing scheduled")")
                }
            }
        }
    }

    /// The bundled block runs Monday-first; custom programmes follow the locale week.
    private var todayStripIndex: Int {
        switch model.document.programme {
        case .bundled:
            TwelveWeekProgramme.position(for: .now).dayIndex
        case .custom, .none:
            Calendar.current.component(.weekday, from: .now) - 1
        }
    }

    private func stripDayLabel(_ index: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        switch model.document.programme {
        case .bundled:
            return symbols[(index + 1) % 7]
        case .custom, .none:
            return symbols[index % 7]
        }
    }

    private func stripSessionLabel(_ day: ResolvedSession?) -> String {
        guard let day else { return "—" }
        if day.isRestDay { return "Rest" }
        return day.template.name
    }

    private var recentEvidence: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "Recorded evidence")
            if let latest = model.document.history.first {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(latest.templateName).font(.headline)
                        Text(latest.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "In progress")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(latest.completedWorkingSetCount)")
                            .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                        Text("WORKING SETS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(SetlinePalette.ink.opacity(0.55))
                    }
                }
                .padding(.vertical, 12)
                InkRule()
            } else {
                Text("Your first completed workout will establish the record—not an estimate.")
                    .font(.body)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.66))
            }
        }
    }
}

/// The full authored session, readable before you start it — so the PDF is never
/// needed in the gym.
struct SessionPreviewView: View {
    let resolved: ResolvedSession

    var body: some View {
        List {
            if !resolved.notes.isEmpty {
                Section("Authored rules") {
                    ForEach(Array(resolved.notes.enumerated()), id: \.offset) { _, note in
                        Text(note).font(.footnote)
                    }
                }
            }
            ForEach(resolved.template.exercises) { exercise in
                Section {
                    ForEach(exercise.sets) { plannedSet in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(plannedSet.label)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(plannedSet.stepType.title.uppercased())
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(SetlinePalette.ink.opacity(0.5))
                            }
                            Text(plannedSet.target.displayString)
                                .font(.headline.monospacedDigit())
                            let qualifiers = plannedSet.target.qualifiers
                                + (plannedSet.rest.isEmpty ? [] : ["Rest \(plannedSet.rest.displayString)"])
                                + (plannedSet.isOptional ? ["Optional"] : [])
                            if !qualifiers.isEmpty {
                                Text(qualifiers.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let cue = plannedSet.cue, !cue.isEmpty {
                                Text(cue).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text(exercise.name)
                }
            }
        }
        .navigationTitle(resolved.template.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
