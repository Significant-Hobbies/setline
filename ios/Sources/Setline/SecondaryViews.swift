import AuthenticationServices
import SetlineCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @State private var isImporterPresented = false
    @State private var showResetConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var appleNonce = AppleNonce.make()

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
                            Text(model.account?.name ?? "Device-only mode").font(.headline)
                            Text(model.account?.email ?? "Workout actions work offline.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(syncLabel(model.document.syncState).uppercased())
                            .font(.caption2.weight(.black))
                    }
                    if model.isAccountBusy {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Contacting Setline…")
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                    } else if model.account == nil {
                        Button { Task { await model.connectAccount() } } label: {
                            Label("Connect Google account", systemImage: "person.crop.circle.badge.plus")
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SetlinePalette.ink)
                        appleAccountButton
                    } else {
                        if let lastSync = model.document.lastSyncedAt {
                            LabeledContent("Last synced") {
                                Text(lastSync, style: .relative).foregroundStyle(.secondary)
                            }
                        }
                        Button { Task { await model.syncNow() } } label: {
                            Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SetlinePalette.ink)
                        if model.account?.hasApple == false {
                            Text("Add Apple to this account so future Apple sign-ins open the same private workout copy.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            appleAccountButton
                        }
                        Button { Task { await model.signOut() } } label: {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 48)
                        Button(role: .destructive) { showDeleteAccountConfirmation = true } label: {
                            Label("Delete Setline account", systemImage: "person.crop.circle.badge.minus")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 48)
                    }
                    if let accountMessage = model.accountMessage {
                        Text(accountMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Account status: \(accountMessage)")
                    }
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
        .confirmationDialog(
            "Delete your Setline account and private cloud copy?",
            isPresented: $showDeleteAccountConfirmation
        ) {
            Button("Delete account", role: .destructive) { Task { await model.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workouts already saved on this iPhone remain local. This account action cannot be undone.")
        }
        .sheet(item: $model.cloudConflict) { conflict in
            NavigationStack {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(SetlinePalette.blue)
                    Text("Choose the workout copy to keep")
                        .font(.title2.bold())
                    Text("This iPhone and your private account changed separately. Review the totals, then choose. Nothing is replaced until you decide.")
                        .foregroundStyle(.secondary)
                    LabeledContent("This iPhone") {
                        Text(workoutCount(model.document.history.count))
                    }
                    LabeledContent("Account copy") {
                        Text(workoutCount(conflict.document.history.count))
                    }
                    Button { Task { await model.keepDeviceCopy() } } label: {
                        Text("Keep this iPhone’s copy").foregroundStyle(.white)
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(SetlinePalette.ink)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    Button("Use the account copy") { Task { await model.useAccountCopy() } }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    Button("Decide later") { model.decideConflictLater() }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Spacer()
                }
                .padding(24)
                .navigationTitle("Sync conflict")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
    }

    private var appleAccountButton: some View {
        SignInWithAppleButton(.continue) { request in
            appleNonce = AppleNonce.make()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleNonce.digest(appleNonce)
        } onCompletion: { result in
            guard
                case let .success(authorization) = result,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                if case let .failure(error) = result,
                   (error as? ASAuthorizationError)?.code != .canceled {
                    model.accountMessage = error.localizedDescription
                }
                return
            }
            let payload = AppleIdentityPayload(
                identityToken: token,
                nonce: appleNonce,
                email: credential.email,
                firstName: credential.fullName?.givenName,
                lastName: credential.fullName?.familyName
            )
            Task { await model.completeAppleSignIn(payload) }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(maxWidth: .infinity, minHeight: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("apple-account-button")
        .disabled(model.isAccountBusy)
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

    private func syncLabel(_ state: SyncState) -> String {
        switch state {
        case .deviceOnly: "On device"
        case .pending: "Syncing"
        case .synced: "Synced"
        case .conflict: "Decision needed"
        case .failed: "Retry needed"
        }
    }

    private func workoutCount(_ count: Int) -> String {
        "\(count) workout\(count == 1 ? "" : "s")"
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
