import Foundation
import SwiftData

@Model
final class IronWorkingSet {
    var exercise: SessionExercise? = nil
    var setNumber: Int = 0
    var targetReps: Int = 8
    var actualReps: Int = 0
    var weightLbs: Double = 0.0
    var completed: Bool = false
    var completionRating: String = ""   // strong | barely | failed | ""
    var restTakenSeconds: Int = 0

    // Computed convenience
    var estimatedOneRM: Double {
        guard actualReps > 0 else { return weightLbs }
        return weightLbs * (1 + Double(actualReps) / 30.0)
    }

    init(setNumber: Int, targetReps: Int, weightLbs: Double) {
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.weightLbs = weightLbs
    }
}
