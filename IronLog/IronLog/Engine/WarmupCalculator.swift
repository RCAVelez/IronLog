import Foundation

struct WarmupSpec: Identifiable {
    let id = UUID()
    let setNumber: Int
    let weightLbs: Double
    let reps: Int
    let restAfterSeconds: Int
}

enum WarmupCalculator {
    // Standard plate-loading steps (bar + increments) matching user's warmup style
    private static let barbellSteps: [Double] = [45, 95, 135, 185, 225, 275, 315, 365, 405, 455]
    private static let stepReps:     [Int]    = [10,  5,   3,   2,   2,   1,   1,   1,   1,   1]

    static func specs(targetWeight: Double, exerciseType: String) -> [WarmupSpec] {
        switch exerciseType {
        case "barbell":  return barbellSpecs(target: targetWeight)
        case "cable":    return cableSpecs(target: targetWeight)
        default:         return []
        }
    }

    // MARK: - Barbell ramp
    private static func barbellSpecs(target: Double) -> [WarmupSpec] {
        guard target > 45 else { return [] }
        var result: [WarmupSpec] = []
        var setNum = 1

        for (i, stepWeight) in barbellSteps.enumerated() {
            if stepWeight >= target { break }
            // Skip if this step is too close to target (within 10%)
            if stepWeight >= target * 0.88 { break }

            let reps    = stepReps[i]
            let rest    = stepWeight >= 185 ? 90 : 60
            result.append(WarmupSpec(setNumber: setNum, weightLbs: stepWeight,
                                     reps: reps, restAfterSeconds: rest))
            setNum += 1
        }
        return result
    }

    // MARK: - Cable ramp (2 warmup sets)
    private static func cableSpecs(target: Double) -> [WarmupSpec] {
        guard target > 25 else { return [] }
        let w1 = PlateCalculator.roundToCable(target * 0.50)
        let w2 = PlateCalculator.roundToCable(target * 0.70)
        var result: [WarmupSpec] = []
        if w1 >= 10 { result.append(WarmupSpec(setNumber: 1, weightLbs: w1, reps: 10, restAfterSeconds: 45)) }
        if w2 >= 10 && w2 < target { result.append(WarmupSpec(setNumber: result.count + 1, weightLbs: w2, reps: 5, restAfterSeconds: 45)) }
        return result
    }
}
