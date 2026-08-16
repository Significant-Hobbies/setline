import SetlineCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isImporterPresented = false
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader("You", subtitle: "Device-first. Nothing leaves this iPhone unless you choose it.")
                storageSection
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
        .task { await model.refreshSyncAvailability() }
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

    /// States plainly where the training lives. There is no account to sign into
    /// and no server holding a copy, so the screen says so rather than implying one.
    private var storageSection: some View {
        settingsSection("Storage") {
            HStack {
                Image(systemName: "iphone.gen3")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(SetlinePalette.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(storageTitle).font(.headline)
                    Text("Workouts run and record with no signal and no sign-in.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            LabeledContent("Recorded workouts", value: "\(model.document.history.count)")
            LabeledContent("Templates", value: "\(model.document.templates.count)")
            LabeledContent("Targets", value: "\(model.document.goals.count)")
            if let synced = model.document.lastSyncedAt {
                LabeledContent(
                    "Last iCloud sync",
                    value: synced.formatted(date: .abbreviated, time: .shortened)
                )
            }
            iCloudRow
        }
    }

    /// Says what iCloud is doing, and when it is doing nothing, why.
    ///
    /// "Sync is off" with no reason is what makes people stop trusting a sync
    /// feature, so every unavailable state explains itself and only the genuinely
    /// actionable ones offer a button.
    @ViewBuilder private var iCloudRow: some View {
        if let availability = model.syncAvailability, !availability.isAvailable {
            Text(SyncError.unavailable(availability).errorDescription ?? "iCloud is unavailable.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Button {
                Task { await model.syncWithiCloud(announcing: true) }
            } label: {
                Label(
                    model.isSyncing ? "Syncing with iCloud…" : "Sync with iCloud now",
                    systemImage: model.isSyncing ? "arrow.triangle.2.circlepath" : "icloud"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(model.isSyncing || model.document.activeSession != nil)
            .frame(minHeight: 48)
            if model.document.activeSession != nil {
                Text("Finish the active workout first. Setline never syncs a session you are still doing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        Text("Use Export to keep a copy of everything, including on devices where iCloud is off.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var storageTitle: String {
        switch model.document.syncState {
        case .deviceOnly: "On this iPhone"
        case .pending: "Saving to iCloud"
        case .synced: "Synced with iCloud"
        case .conflict: "Decision needed"
        case .failed: "iCloud retry needed"
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

func pageHeader(_ title: String, subtitle: String) -> some View {
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

extension SetSegment {
    /// How one segment reads in a receipt. Every recorded dimension is shown, so a
    /// two-segment set is never flattened into a single pair of numbers.
    var recordedDescription: String {
        var parts: [String] = []
        if let side, side != .both { parts.append(side.title) }
        if let repetitions, let weight {
            parts.append("\(repetitions) × \(weight.trimmedString) kg")
        } else if let repetitions {
            parts.append("\(repetitions) reps")
        } else if let weight {
            parts.append("\(weight.trimmedString) kg")
        }
        if let assistanceKilograms { parts.append("assisted −\(assistanceKilograms.trimmedString) kg") }
        if let durationSeconds { parts.append(durationSeconds.durationLabel) }
        if let distanceKilometres { parts.append("\(distanceKilometres.trimmedString) km") }
        if let rangeOfMotionValue { parts.append("\(rangeOfMotionValue.trimmedString) range") }
        if let rpe { parts.append("RPE \(rpe.trimmedString)") }
        if let repsInReserve { parts.append("\(repsInReserve) RIR") }
        if reachedFailure { parts.append("to failure") }
        if hadPain { parts.append("pain flagged") }
        return parts.isEmpty ? "Recorded" : parts.joined(separator: " · ")
    }
}
