import SetlineCore
import SwiftUI

// MARK: - Target editor

struct BenchmarkTargetEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let metric: BenchmarkDefinition

    @State private var values: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(metric.targetNote ?? "Set an ambitious, practical goal. This changes your personal checklist\u{2014}not a scientific percentile or a training prescription.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    ForEach(Array(metric.targets.enumerated()), id: \.offset) { _, field in
                        if case .number(let key, let label, _, _, _, _) = field {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(label)
                                    .font(.subheadline.weight(.bold))
                                TextField("", text: Binding(
                                    get: { values[key] ?? "" },
                                    set: { values[key] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .font(.headline.monospacedDigit())
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(SetlinePalette.chalk)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    Button {
                        restoreDefaults()
                    } label: {
                        Label("Restore default", systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.bold))
                    }
                }
                .padding(20)
            }
            .setlineBackground()
            .navigationTitle(metric.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .onAppear { syncFromModel() }
    }

    private func syncFromModel() {
        let current = model.document.benchmarks.targets[metric.id] ?? .init()
        for field in metric.targets {
            if case .number(let key, _, _, _, _, _) = field {
                values[key] = current.value(key).map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? ""
            }
        }
    }

    private func restoreDefaults() {
        let defaults = BenchmarkCatalog.defaultTargets[metric.id] ?? .init()
        for field in metric.targets {
            if case .number(let key, _, _, _, _, _) = field {
                values[key] = defaults.value(key).map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? ""
            }
        }
    }

    private func save() {
        var parsed: [String: Double] = [:]
        for (key, text) in values {
            if let value = Double(text.trimmingCharacters(in: .whitespaces)) {
                parsed[key] = value
            }
        }
        Task {
            await model.updateBenchmarkTarget(metric.id, values: parsed)
            dismiss()
        }
    }
}

// MARK: - Notification bridge

extension Notification.Name {
    static let benchmarkEditTarget = Notification.Name("benchmarkEditTarget")
}
