import SetlineCore
import UserNotifications

/// Fires a local notification when an authored rest period ends.
///
/// Without this the rest timer only exists while Setline is on screen, which is
/// precisely when it is least useful — you put the phone down between sets. The
/// notification is scheduled against the rest's wall-clock end, so it stays
/// correct whether the app is backgrounded, locked or terminated.
///
/// Every call into `UNUserNotificationCenter` resolves `.current()` at the point
/// of use rather than holding it. Neither the centre nor its settings object is
/// marked Sendable on every SDK Setline builds against, so storing one and then
/// touching it from an async context compiles against some SDKs and fails as a
/// data-race error on others. Resolving it inside a synchronous or nonisolated
/// scope keeps a non-Sendable value from ever crossing an isolation boundary.
@MainActor
final class RestNotifier {
    private static let identifier = "setline.rest.complete"

    private var hasRequestedAuthorisation = false

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
        Self.schedule(
            UNNotificationRequest(
                identifier: Self.identifier,
                content: content,
                trigger: trigger
            )
        )
    }

    func cancel() {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        centre.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }

    /// Asks once. A refusal is respected silently — resting still works on screen.
    private func ensureAuthorisation() async -> Bool {
        switch await Self.authorisationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            guard !hasRequestedAuthorisation else { return false }
            hasRequestedAuthorisation = true
            return await Self.requestAuthorisation()
        @unknown default:
            return false
        }
    }

    /// Synchronous, so handing the request over never crosses an isolation boundary.
    /// A failure to queue is ignored for the same reason a refusal is: rest still
    /// runs on screen, and there is nothing useful to say mid-set.
    private nonisolated static func schedule(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Returns only the status, never the settings object that carries it.
    private nonisolated static func authorisationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private nonisolated static func requestAuthorisation() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
        }
    }
}
