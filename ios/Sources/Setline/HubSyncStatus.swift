import Foundation

struct HubSyncSnapshot: Codable, Equatable {
    var lastSuccessfulAt: Date?
    var lastFailedAt: Date?

    static let empty = HubSyncSnapshot(lastSuccessfulAt: nil, lastFailedAt: nil)
}

@MainActor
final class HubSyncStatusStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "setline.hub-sync-status.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> HubSyncSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(HubSyncSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    @discardableResult
    func recordSuccess(at date: Date = .now) -> HubSyncSnapshot {
        let snapshot = HubSyncSnapshot(lastSuccessfulAt: date, lastFailedAt: nil)
        save(snapshot)
        return snapshot
    }

    @discardableResult
    func recordFailure(at date: Date = .now) -> HubSyncSnapshot {
        var snapshot = load()
        snapshot.lastFailedAt = date
        save(snapshot)
        return snapshot
    }

    private func save(_ snapshot: HubSyncSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}

enum HubSyncPresentation {
    static func statusTitle(
        snapshot: HubSyncSnapshot,
        pendingCount: Int,
        isSyncing: Bool,
        isSignedIn: Bool
    ) -> String {
        if isSyncing { return "Syncing now" }
        if snapshot.lastFailedAt != nil { return "Retry needed" }
        if pendingCount > 0 { return pendingSummary(pendingCount) }
        if snapshot.lastSuccessfulAt != nil { return "Up to date" }
        return isSignedIn ? "Ready to sync" : "Not connected"
    }

    static func pendingSummary(_ count: Int) -> String {
        "\(count) workout \(count == 1 ? "summary" : "summaries") pending"
    }
}

enum SyncDisclosure {
    static let iCloudPurpose =
        "Keeps your Setline data consistent on your Apple devices using your private iCloud account."
    static let iCloudScope =
        "Syncs custom plans and templates, targets, and completed workouts. It does not sync an active workout or the bundled programme content that already ships with Setline."
    static let hubPurpose =
        "Private visibility across your Significant Hobbies apps. Setline shares completed-workout summaries only."
    static let hubScope =
        "Each summary includes the workout name, start time, duration, and completed-step count. It does not include set-by-set details, targets, templates, plans, or an active workout."
}
