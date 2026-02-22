import Foundation

// MARK: - Data structures
struct ExerciseSpec: Identifiable {
    let id = UUID()
    let name: String
    let type: String          // barbell | cable | bodyweight | cardio
    let isPrimary: Bool
    let targetSets: Int
    let targetReps: Int
    let targetWeightLbs: Double
    let restDurationSeconds: Int
}

struct SessionInfo {
    let sessionOrderIndex: Int
    let sessionType: String
    let weekInBlock: Int
    let blockNumber: Int
    let exercises: [ExerciseSpec]

    var isDeload: Bool { weekInBlock == 4 }
    var isBenchmark: Bool {
        // Benchmark replaces deload at end of every 2nd block (session index 39, 79, 119…)
        let pos = sessionOrderIndex % 40
        return pos >= 35 && pos <= 39 && weekInBlock == 4
    }
}

// MARK: - ProgramEngine
enum ProgramEngine {
    // 5-session cycle
    static let sessionTypes = ["lowerA", "upperA", "lowerB", "upperB", "cardio"]

    // Exercise definitions per session type (name, type, isPrimary)
    static let exerciseDefs: [String: [(String, String, Bool)]] = [
        "lowerA": [("Squat", "barbell", true),  ("Romanian Deadlift", "barbell", false)],
        "upperA": [("Bench Press", "barbell", true), ("Cable Row", "cable", false)],
        "lowerB": [("Deadlift", "barbell", true), ("Hip Thrust", "barbell", false)],
        "upperB": [("Military Press", "barbell", true), ("Lat Pulldown", "cable", false)],
        "cardio": [("Run", "cardio", true), ("Ab Wheel", "bodyweight", false)]
    ]

    // MARK: - Derived info from index
    static func sessionType(for index: Int) -> String {
        sessionTypes[index % 5]
    }

    static func blockInfo(for index: Int) -> (blockNumber: Int, weekInBlock: Int) {
        let block = (index / 20) + 1       // 20 sessions = 5 sessions × 4 weeks
        let posInBlock = index % 20
        let week  = (posInBlock / 5) + 1
        return (block, week)
    }

    static func title(for type: String) -> String {
        switch type {
        case "lowerA": return "Lower A"
        case "upperA": return "Upper A"
        case "lowerB": return "Lower B"
        case "upperB": return "Upper B"
        case "cardio": return "Cardio"
        default:       return "Session"
        }
    }

    static func subtitle(for type: String) -> String {
        switch type {
        case "lowerA": return "Squat · Romanian Deadlift"
        case "upperA": return "Bench Press · Cable Row"
        case "lowerB": return "Deadlift · Hip Thrust"
        case "upperB": return "Military Press · Lat Pulldown"
        case "cardio": return "Run · Ab Wheel"
        default:       return ""
        }
    }

    static func estimatedMinutes(for type: String) -> Int {
        switch type {
        case "lowerA": return 55
        case "upperA": return 50
        case "lowerB": return 55
        case "upperB": return 45
        case "cardio": return 35
        default:       return 50
        }
    }

    static func restDuration(for exercise: String) -> Int {
        switch exercise {
        case "Squat":              return 210
        case "Deadlift":           return 270
        case "Bench Press":        return 180
        case "Romanian Deadlift":  return 120
        case "Hip Thrust":         return 120
        case "Military Press":     return 150
        case "Lat Pulldown":       return 120
        case "Cable Row":          return 120
        case "Ab Wheel":           return 90
        default:                   return 120
        }
    }

    // MARK: - Build full session info
    static func sessionInfo(
        for index: Int,
        userProfile: UserProfile,
        completedSessions: [WorkoutSession]
    ) -> SessionInfo {
        let type = sessionType(for: index)
        let (block, week) = blockInfo(for: index)
        let defs = exerciseDefs[type] ?? []

        let specs = defs.map { (name, exType, isPrimary) -> ExerciseSpec in
            let (sets, reps) = ProgressionEngine.setsReps(weekInBlock: week, isPrimary: isPrimary)
            let weight: Double

            if exType == "cardio" {
                weight = userProfile.runCurrentDistanceMiles
            } else if exType == "bodyweight" {
                weight = Double(userProfile.abWheelCurrentReps)
            } else {
                weight = ProgressionEngine.targetWeight(
                    exercise: name,
                    exerciseType: exType,
                    blockNumber: block,
                    weekInBlock: week,
                    userProfile: userProfile,
                    completedSessions: completedSessions
                )
            }

            return ExerciseSpec(
                name: name, type: exType, isPrimary: isPrimary,
                targetSets: sets, targetReps: reps,
                targetWeightLbs: weight,
                restDurationSeconds: restDuration(for: name)
            )
        }

        return SessionInfo(
            sessionOrderIndex: index,
            sessionType: type,
            weekInBlock: week,
            blockNumber: block,
            exercises: specs
        )
    }

    // MARK: - Benchmark scheduling
    static func nextBenchmarkIndex(after completedCount: Int) -> Int {
        // Benchmark every 40 sessions (end of 2nd block). First at index 39.
        let benchmarks = stride(from: 39, through: 10000, by: 40)
        return benchmarks.first(where: { $0 >= completedCount }) ?? completedCount + 40
    }

    static func daysToBenchmark(completedCount: Int) -> Int {
        let nextBench = nextBenchmarkIndex(after: completedCount)
        let remaining = nextBench - completedCount
        // Approximate: 5 sessions/week
        return max(0, remaining * 7 / 5)
    }
}
