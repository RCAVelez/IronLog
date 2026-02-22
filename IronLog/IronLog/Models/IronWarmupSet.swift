import Foundation
import SwiftData

@Model
final class IronWarmupSet {
    var exercise: SessionExercise? = nil
    var setNumber: Int = 0
    var weightLbs: Double = 45.0
    var reps: Int = 10
    var completed: Bool = false
    var restAfterSeconds: Int = 60

    init(setNumber: Int, weightLbs: Double, reps: Int, restAfterSeconds: Int) {
        self.setNumber = setNumber
        self.weightLbs = weightLbs
        self.reps = reps
        self.restAfterSeconds = restAfterSeconds
    }
}
