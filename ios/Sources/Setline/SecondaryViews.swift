import AuthenticationServices
import PersonalSyncKit
import SetlineCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var recoveryOnly = false
    @Environment(AppModel.self) private var model
    @State private var isImporterPresented = false
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader(
                    recoveryOnly ? "Restore your programme" : "You",
                    subtitle: recoveryOnly
                        ? "Your saved file could not be opened and has not been changed. Try again or restore a JSON backup."
                        : "Device-first. Choose how your data follows you."
                )
                if recoveryOnly {
                    Button("Try opening again") { Task { await model.load() } }
                } else {
                    capabilitySection
                    benchmarksSection
                    mobilitySection
                    storageSection
                    iCloudSection
                    significantHobbiesHubSection
                }
                settingsSection("Your data") {
                    if !recoveryOnly {
                        ShareLink(
                            item: SetlineExportPayload(document: model.document),
                            preview: SharePreview("Setline data")
                        ) {
                            Label("Export complete Setline data", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 48)
                    }
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
                    LabeledContent("Version", value: appVersion)
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
        .task {
            guard !recoveryOnly else { return }
            await model.restoreAccountIfIdle()
            await model.refreshSyncAvailability()
            await model.refreshHubSyncStatus()
        }
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

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var significantHobbiesHubSection: some View {
        settingsSection("Significant Hobbies Hub") {
            Text(SyncDisclosure.hubPurpose)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(SyncDisclosure.hubScope)
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledContent("Status", value: hubStatusTitle)
            LabeledContent("Queued summaries", value: "\(model.hubPendingCount)")
            if let synced = model.hubSyncSnapshot.lastSuccessfulAt {
                LabeledContent(
                    "Last successful sync",
                    value: synced.formatted(date: .abbreviated, time: .shortened)
                )
            }
            if let failed = model.hubSyncSnapshot.lastFailedAt {
                Text("The last attempt failed \(failed.formatted(date: .abbreviated, time: .shortened)). Pending summaries stay on this iPhone until a retry succeeds.")
                    .font(.footnote)
                    .foregroundStyle(SetlinePalette.coral)
            }
            if let account = model.account {
                if account.isSignedIn {
                    Label(account.session?.email ?? "Connected", systemImage: "checkmark.icloud")
                    if let notice = model.hubAccountNotice {
                        Text(notice).font(.footnote).foregroundStyle(SetlinePalette.coral)
                    }
                    if (model.document.hubAccountID == nil || model.hubAccountMatches) && (model.needsHubApproval || model.hubAccountNotice != nil) {
                        Text("Connect unapproved workout history and waiting sync changes to the account above? Workouts already owned by another account stay separate.")
                            .font(.footnote)
                        Button("Approve history for this account") {
                            Task { await model.approveHubAccount() }
                        }
                        .disabled(model.isPlatformSyncing || model.document.activeSession != nil)
                    }
                    Button {
                        Task { await model.syncWithPlatform(announcing: true) }
                    } label: {
                        Label(hubSyncButtonTitle, systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(model.isPlatformSyncing || model.document.activeSession != nil || !model.hubAccountMatches)
                    Button("Recover missing Hub summaries") {
                        Task { await model.syncWithPlatform(announcing: true, recoverMissingRecords: true) }
                    }
                    .disabled(model.isPlatformSyncing || model.document.activeSession != nil || !model.hubAccountMatches)
                    Text("Checks this account’s history for summaries an older app may have missed. Existing local workouts are kept. Unavailable set details cannot be recovered from a summary.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Sign out", role: .destructive) { Task { await account.signOut() } }
                } else {
                    Text("Connect your private Significant Hobbies account to make these summaries visible in Hub. iCloud device continuity works separately.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    SignInWithAppleButton(.continue) { request in
                        account.prepareApple(request)
                    } onCompletion: { result in
                        Task {
                            await account.completeApple(result)
                            if account.isSignedIn { await model.syncWithPlatform() }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(minHeight: 46)
                    .disabled(account.isConnecting)
                    Button("Continue with Google") {
                        Task {
                            await account.connect()
                            await model.syncWithPlatform()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(account.isConnecting)
                }
                if account.isConnecting { ProgressView() }
                if let error = account.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            }
            if model.document.activeSession != nil {
                Text("Finish the active workout first. Setline never shares a workout you are still doing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// One iconed navigation row — the You tab's recurring "assessment
    /// surface" entry shape.
    private func settingsLinkRow<Destination: View>(
        icon: String, color: Color, title: String, subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 48)
        }
    }

    /// The four-axis capability profile: scores, priorities, and the
    /// coordinated programme. Lives inside "You" with the other assessment
    /// surfaces rather than competing with the daily workout flow.
    private var capabilitySection: some View {
        let plan = CapabilityEngine.plan(in: model.document)
        let priorities = plan.priorities.map(\.title).joined(separator: " + ")
        return settingsSection("Capability") {
            settingsLinkRow(
                icon: "diamond", color: SetlinePalette.coral, title: "Capability profile",
                subtitle: priorities.isEmpty ? "Four axes, one programme" : "Priorities: \(priorities)"
            ) { CapabilityView() }
        }
    }

    /// A periodic capability scorecard — 15 checkpoints with editable targets,
    /// test protocols, and check-in snapshots. Lives inside "You" because it is
    /// an occasional assessment, not a daily training surface.
    private var benchmarksSection: some View {
        let reached = BenchmarkCatalog.reachedCount(in: model.document.benchmarks)
        let recorded = BenchmarkCatalog.recordedCount(in: model.document.benchmarks)
        return settingsSection("Benchmarks") {
            settingsLinkRow(
                icon: "checkmark.seal", color: SetlinePalette.lime, title: "Capability scorecard",
                subtitle: "\(reached) of \(BenchmarkCatalog.metrics.count) targets reached · \(recorded) starting points · \(model.document.benchmarks.history.count) check-ins"
            ) { BenchmarksView() }
        }
    }

    /// A head-to-toe movement baseline — 15 assessment cards plus two optional
    /// functional benchmarks. Lives inside "You" for the same reason as
    /// Benchmarks: an occasional assessment, not a daily training surface.
    private var mobilitySection: some View {
        let coverage = MobilityEngine.coverage(in: model.document.mobility)
        return settingsSection("Mobility") {
            settingsLinkRow(
                icon: "figure.cooldown", color: SetlinePalette.blue, title: "Movement baseline",
                subtitle: "\(coverage.cardsStarted) of 15 cards started · \(model.document.mobility.practising.count) in practice · \(model.document.mobility.history.count) snapshots"
            ) { MobilityView() }
        }
    }

    /// States plainly where the immediate training copy lives.
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
        }
    }

    private var iCloudSection: some View {
        settingsSection("iCloud device continuity") {
            Text(SyncDisclosure.iCloudPurpose)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(SyncDisclosure.iCloudScope)
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledContent("Status", value: iCloudStatusTitle)
            if let synced = model.document.lastSyncedAt {
                LabeledContent(
                    "Last successful sync",
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
        "On this iPhone"
    }

    private var iCloudStatusTitle: String {
        if model.isSyncing { return "Syncing now" }
        if let availability = model.syncAvailability, !availability.isAvailable {
            return "Unavailable"
        }
        return switch model.document.syncState {
        case .deviceOnly: "On this iPhone"
        case .pending: "Pending"
        case .synced: "Up to date"
        case .conflict: "Decision needed"
        case .failed: "Retry needed"
        }
    }

    private var hubStatusTitle: String {
        HubSyncPresentation.statusTitle(
            snapshot: model.hubSyncSnapshot,
            pendingCount: model.hubPendingCount,
            isSyncing: model.isPlatformSyncing,
            isSignedIn: model.account?.isSignedIn == true
        )
    }

    private var hubSyncButtonTitle: String {
        if model.isPlatformSyncing { return "Syncing with Hub…" }
        if model.hubSyncSnapshot.lastFailedAt != nil { return "Retry Hub sync" }
        return "Sync Hub now"
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
