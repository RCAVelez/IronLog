import Foundation
import SwiftData

@Model
final class CardioRecord {
    var date: Date = Date()
    var sessionOrderIndex: Int = 0
    var distanceMiles: Double = 0.0
    var durationSeconds: Int = 0
    var rpeRating: Int = 5              // 1–10

    var paceSecondsPerMile: Double {
        guard distanceMiles > 0 else { return 0 }
        return Double(durationSeconds) / distanceMiles
    }

    init(date: Date = Date(), sessionOrderIndex: Int,
         distanceMiles: Double, durationSeconds: Int, rpeRating: Int) {
        self.date = date
        self.sessionOrderIndex = sessionOrderIndex
        self.distanceMiles = distanceMiles
        self.durationSeconds = durationSeconds
        self.rpeRating = rpeRating
    }
}
