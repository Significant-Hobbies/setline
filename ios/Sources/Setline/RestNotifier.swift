import SetlineCore
import UserNotifications

/// Fires a local notification when an authored rest period ends.
///
/// Without this the rest timer only exists while Setline is on screen, which is
/// precisely when it is least useful — you put the phone down between sets. The
/// notification is scheduled against the rest's wall-clock end, so it stays
/// correct whether the app is backgrounded, locked or terminated.
@MainActor
final class RestNotifier {
    private static let identifier = "setline.rest.complete"

    private let centre: UNUserNotificationCenter
    private var hasRequestedAuthorisation = false

    init(centre: UNUserNotificationCenter = .current()) {
        self.centre = centre
    }

    /// Schedules, reschedules or clears the alert to match the session's rest.
    ///
    /// Called after every rest change, so an adjusted or ended rest never leaves a
    /// stale alert queued.
    func update(for rest: RestState?, nextStep: WorkoutStep?) async {
        cancel()
        guard let rest else { return }
        let remaining = rest.remaining()
        guard remaining > 0 else { return }
        guard await ensureAuthorisation() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        if let nextStep {
            content.body = "\(nextStep.exerciseName) · \(nextStep.target.displayString)"
        } else {
            content.body = "Return to Setline for the next set."
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remaining),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: trigger
        )
        try? await centre.add(request)
    }

    func cancel() {
        centre.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        centre.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }

    /// Asks once. A refusal is respected silently — resting still works on screen.
    private func ensureAuthorisation() async -> Bool {
        switch await authorisationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            guard !hasRequestedAuthorisation else { return false }
            hasRequestedAuthorisation = true
            return (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    /// Reads just the authorisation status, never the settings object that carries it.
    ///
    /// `UNNotificationSettings` is not Sendable on every SDK Setline builds against,
    /// so `await centre.notificationSettings()` compiles on some and fails on others.
    /// Taking the status inside the callback keeps the non-Sendable value from ever
    /// crossing an isolation boundary, which compiles everywhere.
    private func authorisationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            centre.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
}
