import Foundation
import SwiftData

@Model
final class SessionExercise {
    var session: WorkoutSession? = nil
    var exerciseName: String = ""
    var exerciseType: String = "barbell"  // barbell | cable | bodyweight | cardio
    var order: Int = 0
    var isPrimary: Bool = true
    var targetSets: Int = 3
    var targetReps: Int = 8
    var targetWeightLbs: Double = 0.0
    var restDurationSeconds: Int = 180

    @Relationship(deleteRule: .cascade) var warmupSets: [IronWarmupSet] = []
    @Relationship(deleteRule: .cascade) var workingSets: [IronWorkingSet] = []

    init(exerciseName: String, exerciseType: String, order: Int, isPrimary: Bool,
         targetSets: Int, targetReps: Int, targetWeightLbs: Double, restDurationSeconds: Int) {
        self.exerciseName = exerciseName
        self.exerciseType = exerciseType
        self.order = order
        self.isPrimary = isPrimary
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeightLbs = targetWeightLbs
        self.restDurationSeconds = restDurationSeconds
    }
}
