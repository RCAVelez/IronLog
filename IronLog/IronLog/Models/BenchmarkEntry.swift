import Foundation
import SwiftData

@Model
final class BenchmarkEntry {
    var date: Date = Date()
    var exerciseName: String = ""
    var weightLbs: Double = 0.0
    var reps: Int = 1
    var estimatedOneRM: Double = 0.0
    var deltaVsPrevious: Double = 0.0   // positive = improvement

    init(date: Date = Date(), exerciseName: String, weightLbs: Double,
         reps: Int, estimatedOneRM: Double, deltaVsPrevious: Double = 0) {
        self.date = date
        self.exerciseName = exerciseName
        self.weightLbs = weightLbs
        self.reps = reps
        self.estimatedOneRM = estimatedOneRM
        self.deltaVsPrevious = deltaVsPrevious
    }
}
