import Foundation
import SwiftData

@Model
final class BodyWeightEntry {
    var date: Date = Date()
    var weightLbs: Double = 160.0

    init(date: Date = Date(), weightLbs: Double) {
        self.date = date
        self.weightLbs = weightLbs
    }
}
