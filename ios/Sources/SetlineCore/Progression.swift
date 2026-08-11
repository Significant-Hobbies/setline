import Foundation

public struct ProgressionRecommendation: Equatable, Sendable {
    public var exerciseName: String
    public var previousWeight: Double
    public var recommendedWeight: Double
    public var rationale: String

    public init(exerciseName: String, previousWeight: Double, recommendedWeight: Double, rationale: String) {
        self.exerciseName = exerciseName
        self.previousWeight = previousWeight
        self.recommendedWeight = recommendedWeight
        self.rationale = rationale
    }
}

public enum ProgressionEngine {
    public static func recommendation(for exercise: String, history: [WorkoutSession]) -> ProgressionRecommendation? {
        let completed = history
            .flatMap(\.steps)
            .filter { $0.exerciseName == exercise && $0.status == .complete && $0.kind == .strength }
        guard completed.count >= 2 else { return nil }
        let recent = completed.prefix(3)
        let weights = recent.compactMap { $0.segments.first?.weight }
        guard weights.count == recent.count, let latest = weights.first, Set(weights).count == 1 else { return nil }
        return ProgressionRecommendation(
            exerciseName: exercise,
            previousWeight: latest,
            recommendedWeight: latest + 2.5,
            rationale: "The last \(weights.count) comparable working sets were completed at \(latest.formatted()) kg. This suggestion applies to this session only."
        )
    }
}
