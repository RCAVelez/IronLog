import Foundation

enum ProgressionEngine {
    // MARK: - Wave loading multipliers (relative to Week-1 @ 70% e1RM)
    private static let weekMultipliers: [Double] = [1.0, 1.071, 1.171, 0.829]

    // MARK: - Sets × Reps per wave week
    static func setsReps(weekInBlock: Int, isPrimary: Bool) -> (sets: Int, reps: Int) {
        let week = max(1, min(4, weekInBlock))
        if isPrimary {
            switch week {
            case 1: return (3, 8)
            case 2: return (4, 6)
            case 3: return (3, 5)
            case 4: return (2, 8)  // deload
            default: return (3, 8)
            }
        } else {
            switch week {
            case 1: return (3, 10)
            case 2: return (3, 10)
            case 3: return (3, 8)
            case 4: return (2, 10) // deload
            default: return (3, 10)
            }
        }
    }

    // MARK: - Target weight calculation
    static func targetWeight(
        exercise: String,
        exerciseType: String,
        blockNumber: Int,
        weekInBlock: Int,
        userProfile: UserProfile,
        completedSessions: [WorkoutSession]
    ) -> Double {
        if exerciseType == "bodyweight" || exerciseType == "cardio" { return 0 }

        let multiplier = weekMultipliers[max(0, min(3, weekInBlock - 1))]
        let isUpper    = isUpperBody(exercise)
        let increment  = isUpper ? 2.5 : 5.0

        let cap = weightCap(for: exercise, userProfile: userProfile)

        // If we have prior data, build from last known weight
        if let lastWeight = lastUsedWeight(for: exercise, in: completedSessions), blockNumber > 1 {
            // Back-calc to week-1 reference, then project what week-3 peak was.
            // New block's week-1 starts just above the previous block's week-3 peak,
            // so the user always returns stronger than their last heavy session.
            let prevWeek = weekOfLastSession(for: exercise, in: completedSessions)
            let prevMultiplier = weekMultipliers[max(0, min(3, prevWeek - 1))]
            let prevWeek1Base  = lastWeight / prevMultiplier
            let prevWeek3Peak  = prevWeek1Base * weekMultipliers[2]  // week-3 multiplier = 1.171
            let newWeek1Base   = prevWeek3Peak + increment
            let computed = roundToPlate(newWeek1Base * multiplier, type: exerciseType)
            return min(computed, cap)
        }

        // First block: derive from onboarding 5RM
        let start5RM = startingWeight(for: exercise, userProfile: userProfile)
        let e1RM     = start5RM * (1 + 5.0 / 30.0)   // Epley
        let week1    = e1RM * 0.70
        let adjusted = week1 + Double(blockNumber - 1) * increment
        let computed = roundToPlate(adjusted * multiplier, type: exerciseType)
        return min(computed, cap)
    }

    // MARK: - Per-exercise weight cap
    static func weightCap(for exercise: String, userProfile: UserProfile) -> Double {
        let raw: Double
        switch exercise {
        case "Squat":             raw = userProfile.squatMaxWeightLbs
        case "Bench Press":       raw = userProfile.benchMaxWeightLbs
        case "Deadlift":          raw = userProfile.deadliftMaxWeightLbs
        case "Military Press":    raw = userProfile.ohpMaxWeightLbs
        case "Lat Pulldown":      raw = userProfile.latPulldownMaxWeightLbs
        case "Cable Row":         raw = userProfile.cableRowMaxWeightLbs
        case "Romanian Deadlift": raw = userProfile.romanianDeadliftMaxWeightLbs
        case "Hip Thrust":        raw = userProfile.hipThrustMaxWeightLbs
        default:                  raw = 0
        }
        return raw > 0 ? raw : Double.infinity  // 0 means no cap
    }

    // MARK: - Adaptive adjustment (failed set → reduce remaining sets)
    static func adjustedWeight(current: Double, failed: Bool, exerciseType: String) -> Double {
        guard failed else { return current }
        return roundToPlate(current * 0.90, type: exerciseType)
    }

    // MARK: - e1RM
    static func estimatedOneRM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    // MARK: - Helpers
    private static func lastUsedWeight(for exercise: String, in sessions: [WorkoutSession]) -> Double? {
        sessions
            .filter { $0.status == "completed" }
            .sorted { $0.sessionOrderIndex > $1.sessionOrderIndex }
            .lazy
            .compactMap { session -> Double? in
                guard let ex = session.exercises.first(where: { $0.exerciseName == exercise }) else { return nil }
                return ex.workingSets.filter { $0.completed }.max(by: { $0.setNumber < $1.setNumber })?.weightLbs
            }
            .first
    }

    private static func weekOfLastSession(for exercise: String, in sessions: [WorkoutSession]) -> Int {
        sessions
            .filter { $0.status == "completed" }
            .sorted { $0.sessionOrderIndex > $1.sessionOrderIndex }
            .first(where: { $0.exercises.contains(where: { $0.exerciseName == exercise }) })?
            .weekInBlock ?? 1
    }

    private static func startingWeight(for exercise: String, userProfile: UserProfile) -> Double {
        switch exercise {
        case "Squat":             return userProfile.squatStartWeightLbs
        case "Bench Press":       return userProfile.benchStartWeightLbs
        case "Deadlift":          return userProfile.deadliftStartWeightLbs
        case "Military Press":    return userProfile.ohpStartWeightLbs
        case "Lat Pulldown":      return userProfile.latPulldownStartWeightLbs
        case "Cable Row":         return userProfile.cableRowStartWeightLbs
        case "Romanian Deadlift": return max(65, userProfile.deadliftStartWeightLbs * 0.65)
        case "Hip Thrust":        return max(45, userProfile.squatStartWeightLbs * 0.75)
        default:                  return 95
        }
    }

    private static func isUpperBody(_ exercise: String) -> Bool {
        ["Bench Press", "Military Press", "Lat Pulldown", "Cable Row"].contains(exercise)
    }

    private static func roundToPlate(_ weight: Double, type: String) -> Double {
        let increment: Double = 5.0
        return max(increment, (weight / increment).rounded() * increment)
    }
}
