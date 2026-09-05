import SetlineCore
import SwiftUI

// MARK: - Profile card

struct BenchmarkProfileCard: View {
    @Environment(AppModel.self) private var model
    @State private var weightText = ""
    @State private var heightText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Your starting point")
                Spacer()
                Text("All units metric")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.5))
            }
            HStack(spacing: 24) {
                profileField("Bodyweight", text: $weightText, unit: "kg", key: \.weight)
                profileField("Height", text: $heightText, unit: "cm", key: \.height)
            }
            Text("Enter your bodyweight and height. Weight-based targets update automatically.")
                .font(.system(size: 11))
                .foregroundStyle(SetlinePalette.ink.opacity(0.55))
        }
        .padding(16)
        .background(SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear { syncFromModel() }
        .onChange(of: model.document.benchmarks.profile) { _, _ in syncFromModel() }
        .onChange(of: weightText) { _, newValue in
            let value = Double(newValue.trimmingCharacters(in: .whitespaces))
            // Only push when the text diverges from the model's formatted value,
            // avoiding a sync loop without a fragile isSyncing flag.
            let modelValue = model.document.benchmarks.profile.weight
            if value != modelValue {
                Task { await model.updateBenchmarkProfile(weight: value, height: nil) }
            }
        }
        .onChange(of: heightText) { _, newValue in
            let value = Double(newValue.trimmingCharacters(in: .whitespaces))
            let modelValue = model.document.benchmarks.profile.height
            if value != modelValue {
                Task { await model.updateBenchmarkProfile(weight: nil, height: value) }
            }
        }
    }

    private func profileField(_ label: String, text: Binding<String>, unit: String, key: KeyPath<BenchmarkProfile, Double?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            HStack(spacing: 6) {
                TextField("", text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(.title2, design: .rounded).monospacedDigit().weight(.black))
                    .frame(minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(SetlinePalette.chalk)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(unit)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func syncFromModel() {
        let profile = model.document.benchmarks.profile
        let formattedWeight = profile.weight.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? ""
        let formattedHeight = profile.height.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? ""
        // Only overwrite the text field if the model's value differs from what
        // the user is currently typing. This avoids clobbering in-progress edits
        // without needing a fragile isSyncing flag.
        if weightText.trimmingCharacters(in: .whitespaces) != formattedWeight
            && Double(weightText.trimmingCharacters(in: .whitespaces)) != profile.weight {
            weightText = formattedWeight
        }
        if heightText.trimmingCharacters(in: .whitespaces) != formattedHeight
            && Double(heightText.trimmingCharacters(in: .whitespaces)) != profile.height {
            heightText = formattedHeight
        }
    }
}

// MARK: - Metric card

struct BenchmarkMetricCard: View {
    @Environment(AppModel.self) private var model
    let metric: BenchmarkDefinition

    private var assessment: BenchmarkAssessment {
        BenchmarkEngine.assess(metric.id, state: model.document.benchmarks)
    }

    private var isCustomTarget: Bool {
        BenchmarkCatalog.targetIsCustom(metric.id, targets: model.document.benchmarks.targets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader
            Text(metric.name)
                .font(.system(.title2, design: .rounded, weight: .black))
            Text(metric.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            comparisonRow
            messageRow
            inputFields
            if !metric.extra.isEmpty {
                extraFields
            }
            DisclosureGroup("Test protocol & notes") {
                Text(metric.protocolText)
                    .font(.footnote)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.72))
            }
            .tint(SetlinePalette.ink.opacity(0.6))
            sourceNote
        }
        .padding(20)
        .background(assessment.reached ? SetlinePalette.lime.opacity(0.3) : SetlinePalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(SetlinePalette.ink.opacity(0.1), lineWidth: 1)
        }
    }

    private var cardHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: metric.systemImage)
                    .font(.subheadline)
                Text(metric.group.title)
                    .font(.system(size: 10, weight: .black))
            }
            .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            Spacer()
            badge
        }
    }

    private var badge: some View {
        let bg: Color = switch assessment.tone {
        case .good: SetlinePalette.lime
        case .caution: Color(red: 0.96, green: 0.85, blue: 0.55)
        case .neutral: SetlinePalette.steel
        }
        return Text(assessment.status)
            .font(.system(size: 10, weight: .black))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(bg)
            .clipShape(Capsule())
    }

    private var comparisonRow: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENT")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(SetlinePalette.ink.opacity(0.5))
                Text(assessment.current)
                    .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                Text(assessment.currentSub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(isCustomTarget ? "YOUR TARGET" : "TARGET")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(SetlinePalette.ink.opacity(0.5))
                    if !metric.targets.isEmpty {
                        Button {
                            // Navigate via the environment — handled by parent sheet
                            NotificationCenter.default.post(
                                name: .benchmarkEditTarget,
                                object: nil,
                                userInfo: ["metricID": metric.id]
                            )
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundStyle(SetlinePalette.ink.opacity(0.5))
                        }
                    }
                }
                Text(assessment.target)
                    .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                Text(assessment.targetSub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var messageRow: some View {
        Text(assessment.message)
            .font(.footnote)
            .foregroundStyle(assessment.reached ? SetlinePalette.ink : SetlinePalette.ink.opacity(0.72))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(assessment.reached ? SetlinePalette.lime.opacity(0.4) : SetlinePalette.chalk)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var inputFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(metric.fields.enumerated()), id: \.offset) { _, field in
                BenchmarkFieldInput(metricID: metric.id, field: field)
            }
        }
    }

    private var extraFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(metric.extra.enumerated()), id: \.offset) { _, field in
                BenchmarkFieldInput(metricID: metric.id, field: field)
            }
        }
    }

    private var sourceNote: some View {
        let updated = model.document.benchmarks.updated[metric.id]
        let text: String = if let updated {
            "Updated \(updated.formatted(date: .abbreviated, time: .omitted))"
        } else if assessment.recorded {
            "Recorded result"
        } else {
            "No result entered yet"
        }
        return Text(text)
            .font(.system(size: 11))
            .foregroundStyle(SetlinePalette.ink.opacity(0.5))
    }
}

// MARK: - Field input

struct BenchmarkFieldInput: View {
    @Environment(AppModel.self) private var model
    let metricID: String
    let field: BenchmarkField

    var body: some View {
        switch field {
        case .number(let key, let label, let min, let max, _, let placeholder):
            BenchmarkNumberField(metricID: metricID, key: key, label: label, min: min, max: max, placeholder: placeholder)
        case .time(let key, let label, let placeholder):
            BenchmarkTimeField(metricID: metricID, key: key, label: label, placeholder: placeholder)
        case .select(let key, let label, let options):
            BenchmarkSelectField(metricID: metricID, key: key, label: label, options: options)
        case .check(let key, let label):
            BenchmarkCheckField(metricID: metricID, key: key, label: label)
        }
    }
}

struct BenchmarkNumberField: View {
    @Environment(AppModel.self) private var model
    let metricID: String
    let key: String
    let label: String
    let min: Double
    let max: Double
    let placeholder: String
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .font(.headline.monospacedDigit())
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(SetlinePalette.chalk)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: text) { _, newValue in
                    let value = Double(newValue.trimmingCharacters(in: .whitespaces))
                    let modelValue = model.document.benchmarks.metrics[metricID]?.number(key)
                    if value != modelValue {
                        let clamped = value.map { Swift.min(Swift.max($0, min), max) }
                        Task { await model.updateBenchmarkNumber(metricID, field: key, value: clamped) }
                    }
                }
        }
        .onAppear { syncFromModel() }
        .onChange(of: model.document.benchmarks.metrics[metricID]?.numbers[key]) { _, _ in syncFromModel() }
    }

    private func syncFromModel() {
        let state = model.document.benchmarks.metrics[metricID] ?? .init()
        let formatted = state.number(key).map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? ""
        // Only overwrite if the field doesn't already match the model value.
        if Double(text.trimmingCharacters(in: .whitespaces)) != state.number(key) {
            text = formatted
        }
    }
}

struct BenchmarkTimeField: View {
    @Environment(AppModel.self) private var model
    let metricID: String
    let key: String
    let label: String
    let placeholder: String
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            TextField(placeholder, text: $text)
                .keyboardType(.numbersAndPunctuation)
                .font(.headline.monospacedDigit())
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(SetlinePalette.chalk)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: text) { _, newValue in
                    let modelValue = model.document.benchmarks.metrics[metricID]?.text(key)
                    if newValue != modelValue {
                        Task { await model.updateBenchmarkText(metricID, field: key, value: newValue) }
                    }
                }
        }
        .onAppear { syncFromModel() }
        .onChange(of: model.document.benchmarks.metrics[metricID]?.texts[key]) { _, _ in syncFromModel() }
    }

    private func syncFromModel() {
        let state = model.document.benchmarks.metrics[metricID] ?? .init()
        let modelText = state.text(key) ?? ""
        if text != modelText {
            text = modelText
        }
    }
}

struct BenchmarkSelectField: View {
    @Environment(AppModel.self) private var model
    let metricID: String
    let key: String
    let label: String
    let options: [String]
    @State private var selection = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            Picker(label, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .padding(.horizontal, 10)
            .background(SetlinePalette.chalk)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: selection) { _, newValue in
                let modelValue = model.document.benchmarks.metrics[metricID]?.text(key)
                if newValue != modelValue {
                    Task { await model.updateBenchmarkText(metricID, field: key, value: newValue) }
                }
            }
        }
        .onAppear { syncFromModel() }
        .onChange(of: model.document.benchmarks.metrics[metricID]?.texts[key]) { _, _ in syncFromModel() }
    }

    private func syncFromModel() {
        let state = model.document.benchmarks.metrics[metricID] ?? .init()
        let modelSelection = state.text(key) ?? options.first ?? ""
        if selection != modelSelection {
            selection = modelSelection
        }
    }
}

struct BenchmarkCheckField: View {
    @Environment(AppModel.self) private var model
    let metricID: String
    let key: String
    let label: String
    @State private var checked = false

    var body: some View {
        Toggle(isOn: $checked) {
            Text(label)
                .font(.subheadline)
        }
        .onChange(of: checked) { _, newValue in
            let modelValue = model.document.benchmarks.metrics[metricID]?.flag(key) ?? false
            if newValue != modelValue {
                Task { await model.updateBenchmarkFlag(metricID, field: key, value: newValue) }
            }
        }
        .onAppear { syncFromModel() }
        .onChange(of: model.document.benchmarks.metrics[metricID]?.flags[key]) { _, _ in syncFromModel() }
    }

    private func syncFromModel() {
        let state = model.document.benchmarks.metrics[metricID] ?? .init()
        let modelChecked = state.flag(key)
        if checked != modelChecked {
            checked = modelChecked
        }
    }
}
