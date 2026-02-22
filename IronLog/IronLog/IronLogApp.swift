import SwiftUI
import SwiftData

@main
struct IronLogApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                UserProfile.self,
                WorkoutSession.self,
                SessionExercise.self,
                IronWarmupSet.self,
                IronWorkingSet.self,
                BodyWeightEntry.self,
                BenchmarkEntry.self,
                CardioRecord.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
