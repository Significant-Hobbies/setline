import Foundation

public enum SetlineHubOwnershipError: LocalizedError, Equatable {
    case approvalRequired
    case differentAccount
    case workoutActive

    public var errorDescription: String? {
        switch self {
        case .approvalRequired: "Approve this history for the displayed Hub account before syncing."
        case .differentAccount: "This training belongs to another Hub account. Sign in to that account to sync."
        case .workoutActive: "Finish the active workout before changing its Hub connection."
        }
    }
}

public extension SetlineDocument {
    mutating func approveHubHistory(for userID: String) throws {
        guard activeSession == nil else { throw SetlineHubOwnershipError.workoutActive }
        guard !userID.isEmpty else { throw SetlineHubOwnershipError.approvalRequired }
        guard hubAccountID == nil || hubAccountID == userID else { throw SetlineHubOwnershipError.differentAccount }
        hubAccountID = userID
        for index in history.indices where history[index].hubAccountID == nil {
            history[index].hubAccountID = userID
        }
    }

    func approvedHubHistory(for userID: String) throws -> [WorkoutSession] {
        guard hubAccountID != nil else { throw SetlineHubOwnershipError.approvalRequired }
        guard hubAccountID == userID else { throw SetlineHubOwnershipError.differentAccount }
        return history.filter { $0.hubAccountID == userID && $0.hubRecordID == nil }
    }
}
