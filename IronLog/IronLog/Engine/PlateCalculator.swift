import SwiftUI

struct PlateCount: Identifiable {
    let id = UUID()
    let weightLbs: Double
    let count: Int
    var color: Color { Color.plateColor(for: weightLbs) }

    var label: String {
        weightLbs == 2.5 ? "2.5" : "\(Int(weightLbs))"
    }
}

enum PlateCalculator {
    static let barWeightLbs: Double = 45.0
    private static let plates: [Double] = [45, 35, 25, 10, 5, 2.5]

    /// Breaks a total barbell weight into a plate-per-side list.
    static func breakdown(for totalWeight: Double) -> [PlateCount] {
        guard totalWeight > barWeightLbs else { return [] }
        var remaining = (totalWeight - barWeightLbs) / 2.0
        var result: [PlateCount] = []
        for plate in plates {
            let count = Int(remaining / plate)
            if count > 0 {
                result.append(PlateCount(weightLbs: plate, count: count))
                remaining -= Double(count) * plate
                remaining = (remaining * 10).rounded() / 10 // float safety
            }
        }
        return result
    }

    /// Rounds a weight to nearest barbell-loadable increment (5 lbs = 2.5 per side).
    static func roundToBarbell(_ weight: Double) -> Double {
        (weight / 5.0).rounded() * 5.0
    }

    /// Rounds a cable/pin-stack weight to nearest 5 lbs.
    static func roundToCable(_ weight: Double) -> Double {
        (weight / 5.0).rounded() * 5.0
    }

    static func isBarbell(_ exerciseType: String) -> Bool {
        exerciseType == "barbell"
    }
}
