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

    private var plannedTemplate: WorkoutTemplate? {
        let weekday = Calendar.current.component(.weekday, from: .now)
        guard let id = model.document.programme?.days.first(where: { $0.weekday == weekday })?.templateID else {
            return model.document.templates.first
        }
        return model.document.templates.first(where: { $0.id == id }) ?? model.document.templates.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if let active = model.document.activeSession {
                    activeReceipt(active)
                } else if let plannedTemplate {
                    workoutHero(plannedTemplate)
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

    private func workoutHero(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: "Today · authored plan")
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
            }
            .padding(.bottom, 14)
            Text(template.name)
                .font(.system(.title, design: .rounded, weight: .black))
                .tracking(-0.8)
            Text(template.detail)
                .font(.title3.weight(.medium))
                .foregroundStyle(SetlinePalette.ink.opacity(0.66))
                .padding(.top, 3)
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        metric("EXERCISES", "\(template.exercises.count)")
                        metric("SETS", "\(template.exercises.flatMap(\.sets).count)")
                        metric("MODE", "OFFLINE")
                    }
                } else {
                    HStack(spacing: 0) {
                        metric("EXERCISES", "\(template.exercises.count)")
                        metric("SETS", "\(template.exercises.flatMap(\.sets).count)")
                        metric("MODE", "OFFLINE")
                    }
                }
            }
            .padding(.vertical, 22)
            Button {
                Task { await model.startWorkout(template) }
            } label: {
                Label("Start workout", systemImage: "arrow.right")
            }
            .buttonStyle(ActionSlabStyle())
            .accessibilityHint("Starts an offline workout using the authored order")
        }
        .padding(20)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SetlinePalette.ink.opacity(0.12), lineWidth: 1)
        }
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
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(text: "This week")
            HStack(spacing: 7) {
                ForEach(1...7, id: \.self) { index in
                    let hasPlan = model.document.programme?.days.first(where: { $0.weekday == index })?.templateID != nil
                    VStack(spacing: 8) {
                        Text(Calendar.current.veryShortWeekdaySymbols[index - 1])
                            .font(.caption2.weight(.bold))
                        Circle()
                            .fill(hasPlan ? SetlinePalette.ink : SetlinePalette.steel)
                            .frame(width: 9, height: 9)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(hasPlan ? SetlinePalette.blue.opacity(0.65) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
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
                    Text("\(latest.completedCount)")
                        .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
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
