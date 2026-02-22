import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String = ""
    var bodyWeightLbs: Double = 160.0
    var heightInches: Int = 69
    var programStartDate: Date = Date()

    // Onboarding: e5RM (5-rep working weight) per exercise
    var squatStartWeightLbs: Double = 135.0
    var benchStartWeightLbs: Double = 115.0
    var deadliftStartWeightLbs: Double = 155.0
    var ohpStartWeightLbs: Double = 75.0
    var latPulldownStartWeightLbs: Double = 100.0
    var cableRowStartWeightLbs: Double = 100.0

    // Per-exercise weight ceilings, derived from user's stated maxes:
    //   Squat 315, Bench 225, OHP 135 (given)
    //   Deadlift  = Squat × 1.25       → 395
    //   RDL       = Deadlift × 0.70    → 275
    //   Hip Thrust= Squat × 1.00       → 315
    //   Lat PD    = Bench × 0.65       → 145
    //   Cable Row = Bench × 0.70       → 160
    var squatMaxWeightLbs: Double = 315.0
    var benchMaxWeightLbs: Double = 225.0
    var deadliftMaxWeightLbs: Double = 395.0
    var ohpMaxWeightLbs: Double = 135.0
    var latPulldownMaxWeightLbs: Double = 145.0
    var cableRowMaxWeightLbs: Double = 160.0
    var romanianDeadliftMaxWeightLbs: Double = 275.0
    var hipThrustMaxWeightLbs: Double = 315.0

    // Cardio / bodyweight progression
    var runMaxDistanceMiles: Double = 6.0
    var runCurrentDistanceMiles: Double = 1.0
    var abWheelCurrentReps: Int = 5
    var abWheelCurrentSets: Int = 3

    // Tracks total sessions completed (used to derive next session index)
    var totalSessionsCompleted: Int = 0

    init() {}
}
