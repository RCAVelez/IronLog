import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var sessionOrderIndex: Int = 0
    var sessionType: String = "lowerA"   // lowerA | upperA | lowerB | upperB | cardio
    var weekInBlock: Int = 1             // 1–4
    var blockNumber: Int = 1

    var startDate: Date? = nil
    var completedDate: Date? = nil
    var status: String = "planned"       // planned | active | completed | skipped
    var durationSeconds: Int = 0

    // Resume state (written on every advance so crash-safe)
    var resumeExerciseIndex: Int = 0
    var resumeSetIndex: Int = 0
    var resumeIsWarmup: Bool = true

    @Relationship(deleteRule: .cascade) var exercises: [SessionExercise] = []

    init(sessionOrderIndex: Int, sessionType: String, weekInBlock: Int, blockNumber: Int) {
        self.sessionOrderIndex = sessionOrderIndex
        self.sessionType = sessionType
        self.weekInBlock = weekInBlock
        self.blockNumber = blockNumber
    }
}
