import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Phase
enum WorkoutPhase: Equatable {
    case preview
    case warmup
    case workingSet
    case feedback
    case resting
    case exerciseComplete
    case cardioActive
    case sessionComplete
}

// MARK: - ViewModel
@Observable
final class WorkoutViewModel {
    // Phase
    var phase: WorkoutPhase = .preview
    var currentExerciseIndex: Int = 0
    var currentSetIndex: Int = 0      // index into warmupSets or workingSets
    var isInWarmup: Bool = true

    // Rest timer
    var restStartTime: Date? = nil
    var restTotalDuration: Int = 60
    var restRemaining: Int = 60
    private var restTimer: Timer? = nil

    // Feedback
    var feedbackRating: String = ""   // strong | barely | failed
    var feedbackActualReps: Int = 0
    var showFeedbackSheet: Bool = false

    // Active session
    var session: WorkoutSession? = nil
    var sessionInfo: SessionInfo? = nil

    // Cardio timer
    var cardioElapsed: Int = 0
    var cardioRunning: Bool = false
    private var cardioTimer: Timer? = nil

    // Session timing
    var sessionStartTime: Date? = nil

    // Body weight prompt on complete
    var showBodyWeightPrompt: Bool = false
    var completionBodyWeight: Double = 160

    private let modelContext: ModelContext
    private var userProfile: UserProfile? = nil

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Start session
    func startSession(info: SessionInfo, profile: UserProfile) {
        let s = WorkoutSession(
            sessionOrderIndex: info.sessionOrderIndex,
            sessionType: info.sessionType,
            weekInBlock: info.weekInBlock,
            blockNumber: info.blockNumber
        )
        s.startDate = Date()
        s.status = "active"
        modelContext.insert(s)

        // Build SessionExercise + warmup + working sets
        for (i, spec) in info.exercises.enumerated() {
            let ex = SessionExercise(
                exerciseName: spec.name,
                exerciseType: spec.type,
                order: i,
                isPrimary: spec.isPrimary,
                targetSets: spec.targetSets,
                targetReps: spec.targetReps,
                targetWeightLbs: spec.targetWeightLbs,
                restDurationSeconds: spec.restDurationSeconds
            )
            ex.session = s

            // Warmup sets
            let warmupSpecs = WarmupCalculator.specs(targetWeight: spec.targetWeightLbs,
                                                     exerciseType: spec.type)
            for ws in warmupSpecs {
                let w = IronWarmupSet(setNumber: ws.setNumber,
                                      weightLbs: ws.weightLbs,
                                      reps: ws.reps,
                                      restAfterSeconds: ws.restAfterSeconds)
                w.exercise = ex
                ex.warmupSets.append(w)
                modelContext.insert(w)
            }

            // Working sets
            for setNum in 1...spec.targetSets {
                let ws = IronWorkingSet(setNumber: setNum,
                                        targetReps: spec.targetReps,
                                        weightLbs: spec.targetWeightLbs)
                ws.exercise = ex
                ex.workingSets.append(ws)
                modelContext.insert(ws)
            }

            s.exercises.append(ex)
            modelContext.insert(ex)
        }

        try? modelContext.save()

        self.session = s
        self.sessionInfo = info
        self.sessionStartTime = Date()
        self.currentExerciseIndex = 0
        self.currentSetIndex = 0
        self.completionBodyWeight = profile.bodyWeightLbs
        self.userProfile = profile

        // Determine starting phase
        let firstEx = s.exercises.sorted(by: { $0.order < $1.order }).first
        if info.sessionType == "cardio" {
            self.phase = .cardioActive
        } else if firstEx?.warmupSets.isEmpty == false {
            self.isInWarmup = true
            self.currentSetIndex = 0
            self.phase = .warmup
        } else {
            self.isInWarmup = false
            self.currentSetIndex = 0
            self.phase = .workingSet
        }
    }

    // MARK: - Current exercise / set accessors
    var currentExercise: SessionExercise? {
        guard let s = session else { return nil }
        let sorted = s.exercises.sorted(by: { $0.order < $1.order })
        guard currentExerciseIndex < sorted.count else { return nil }
        return sorted[currentExerciseIndex]
    }

    var currentWarmupSet: IronWarmupSet? {
        let ws = currentExercise?.warmupSets.sorted(by: { $0.setNumber < $1.setNumber }) ?? []
        guard currentSetIndex < ws.count else { return nil }
        return ws[currentSetIndex]
    }

    var currentWorkingSet: IronWorkingSet? {
        let ws = currentExercise?.workingSets.sorted(by: { $0.setNumber < $1.setNumber }) ?? []
        guard currentSetIndex < ws.count else { return nil }
        return ws[currentSetIndex]
    }

    var totalExercises: Int { session?.exercises.count ?? 0 }

    var warmupSetCount: Int {
        currentExercise?.warmupSets.count ?? 0
    }
    var workingSetCount: Int {
        currentExercise?.workingSets.count ?? 0
    }

    // MARK: - Complete warmup set
    func completeWarmupSet() {
        guard let ws = currentWarmupSet else { return }
        ws.completed = true
        saveContext()
        HapticManager.impact(.light)

        let rest = ws.restAfterSeconds
        let nextIndex = currentSetIndex + 1
        let total = warmupSetCount

        if nextIndex >= total {
            // Move to working sets
            startRest(duration: rest) {
                self.isInWarmup = false
                self.currentSetIndex = 0
                self.phase = .workingSet
            }
        } else {
            startRest(duration: rest) {
                self.currentSetIndex = nextIndex
                self.phase = .warmup
            }
        }
    }

    // MARK: - Complete working set (opens feedback sheet)
    func beginSetFeedback() {
        guard let ws = currentWorkingSet else { return }
        feedbackRating = ""
        feedbackActualReps = ws.targetReps
        phase = .feedback
        HapticManager.impact(.medium)
    }

    func submitFeedback(rating: String, actualReps: Int) {
        guard let ws = currentWorkingSet, let ex = currentExercise else { return }
        ws.completed = true
        ws.completionRating = rating
        ws.actualReps = actualReps
        HapticManager.notification(rating == "failed" ? .warning : .success)

        // Adaptive adjustment: if failed, reduce weight on remaining working sets
        if rating == "failed" {
            let adjusted = ProgressionEngine.adjustedWeight(
                current: ws.weightLbs, failed: true, exerciseType: ex.exerciseType)
            let remaining = ex.workingSets.filter { !$0.completed && $0.setNumber > ws.setNumber }
            for r in remaining { r.weightLbs = adjusted }
        }
        saveContext()

        let rest = ex.restDurationSeconds
        let nextIndex = currentSetIndex + 1
        let total = workingSetCount

        phase = .workingSet // reset before rest so feedback sheet dismisses
        if nextIndex >= total {
            // Exercise done
            startRest(duration: rest) {
                self.advanceExercise()
            }
        } else {
            startRest(duration: rest) {
                self.currentSetIndex = nextIndex
                self.phase = .workingSet
            }
        }
    }

    // MARK: - Advance to next exercise
    private func advanceExercise() {
        let nextIndex = currentExerciseIndex + 1
        guard let s = session else { return }
        let sorted = s.exercises.sorted(by: { $0.order < $1.order })

        if nextIndex >= sorted.count {
            finishSession()
            return
        }

        currentExerciseIndex = nextIndex
        currentSetIndex = 0
        phase = .exerciseComplete

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let nextEx = sorted[nextIndex]
            if nextEx.warmupSets.isEmpty {
                self.isInWarmup = false
                self.phase = .workingSet
            } else {
                self.isInWarmup = true
                self.phase = .warmup
            }
        }
    }

    // MARK: - Rest timer
    private var afterRest: (() -> Void)? = nil

    private func startRest(duration: Int, then: @escaping () -> Void) {
        restTotalDuration = duration
        restRemaining = duration
        restStartTime = Date()
        afterRest = then
        phase = .resting
        scheduleRestNotification(in: duration)

        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let start = self.restStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            self.restRemaining = max(0, self.restTotalDuration - elapsed)
            if self.restRemaining == 60 || self.restRemaining == 30 || self.restRemaining == 10 {
                HapticManager.impact(.light)
            }
            if self.restRemaining <= 0 {
                self.endRest()
            }
        }
    }

    func skipRest() {
        endRest()
    }

    func addRestTime(_ seconds: Int) {
        restTotalDuration += seconds
        restRemaining += seconds
        // Reschedule notification for new remaining time
        cancelRestNotification()
        scheduleRestNotification(in: restRemaining)
    }

    private func endRest() {
        restTimer?.invalidate()
        restTimer = nil
        cancelRestNotification()
        afterRest?()
        afterRest = nil
    }

    // MARK: - Cardio session
    func startCardioTimer() {
        cardioElapsed = 0
        cardioRunning = true
        cardioTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.cardioElapsed += 1
        }
    }

    func stopCardioTimer() {
        cardioTimer?.invalidate()
        cardioTimer = nil
        cardioRunning = false
    }

    func completeCardio(distanceMiles: Double, rpe: Int) {
        let cappedDistance: Double
        if let p = userProfile, p.runMaxDistanceMiles > 0 {
            cappedDistance = min(distanceMiles, p.runMaxDistanceMiles)
        } else {
            cappedDistance = distanceMiles
        }

        let record = CardioRecord(
            date: Date(),
            sessionOrderIndex: session?.sessionOrderIndex ?? 0,
            distanceMiles: cappedDistance,
            durationSeconds: cardioElapsed,
            rpeRating: rpe
        )
        modelContext.insert(record)

        // Progress cardio distance for next session if user met or exceeded current target
        if let p = userProfile, cappedDistance >= p.runCurrentDistanceMiles {
            let next = ((cappedDistance + 0.25) * 10).rounded() / 10
            let maxDist = p.runMaxDistanceMiles > 0 ? p.runMaxDistanceMiles : 6.0
            p.runCurrentDistanceMiles = min(next, maxDist)
        }

        stopCardioTimer()

        // Move to ab wheel
        currentExerciseIndex = 1
        currentSetIndex = 0
        isInWarmup = false
        phase = .workingSet
    }

    // MARK: - Finish session
    private func finishSession() {
        guard let s = session else { return }
        s.status = "completed"
        s.completedDate = Date()
        if let start = sessionStartTime {
            s.durationSeconds = Int(Date().timeIntervalSince(start))
        }
        saveContext()
        HapticManager.notification(.success)
        phase = .sessionComplete
    }

    func saveBodyWeightAndFinish(weightLbs: Double, context: ModelContext) {
        let entry = BodyWeightEntry(weightLbs: weightLbs)
        context.insert(entry)
        try? context.save()
    }

    // MARK: - Computed stats for complete screen
    var sessionDurationFormatted: String {
        guard let start = sessionStartTime else { return "--" }
        let secs = Int(Date().timeIntervalSince(start))
        return Formatters.duration(secs)
    }

    var totalVolumeLifted: Double {
        guard let exercises = session?.exercises else { return 0 }
        var total: Double = 0
        for ex in exercises {
            for ws in ex.workingSets where ws.completed {
                let reps = ws.actualReps > 0 ? ws.actualReps : ws.targetReps
                total += ws.weightLbs * Double(reps)
            }
        }
        return total
    }

    var completedSetsCount: Int {
        guard let exercises = session?.exercises else { return 0 }
        var count = 0
        for ex in exercises { count += ex.workingSets.filter(\.completed).count }
        return count
    }

    var totalSetsCount: Int {
        guard let exercises = session?.exercises else { return 0 }
        var count = 0
        for ex in exercises { count += ex.workingSets.count }
        return count
    }

    // MARK: - Notifications
    private let restNotificationID = "rest-timer"

    private func scheduleRestNotification(in seconds: Int) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = "Rest Over"
        content.body  = "Next set is ready."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: restNotificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restNotificationID])
    }

    private func saveContext() { try? modelContext.save() }
}

// MARK: - WorkoutView (root)
struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.sessionOrderIndex) private var sessions: [WorkoutSession]

    @State private var vm: WorkoutViewModel? = nil
    // WorkoutViewModel is @Observable — @State holds it so SwiftUI tracks changes

    private var profile: UserProfile? { profiles.first }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == "completed" || $0.status == "skipped" }
    }

    private var nextSessionIndex: Int {
        (completedSessions.map(\.sessionOrderIndex).max() ?? -1) + 1
    }

    private var nextInfo: SessionInfo? {
        guard let p = profile else { return nil }
        return ProgramEngine.sessionInfo(for: nextSessionIndex, userProfile: p, completedSessions: completedSessions)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let vm = vm, vm.phase != .preview {
                activeWorkoutView(vm: vm)
            } else {
                previewView
            }
        }
    }

    // MARK: - Session preview
    private var previewView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Workout")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let info = nextInfo {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ProgramEngine.title(for: info.sessionType).uppercased())
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Color.ironBlue)
                            Text(ProgramEngine.subtitle(for: info.sessionType))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Block \(info.blockNumber) · Week \(info.weekInBlock)\(info.isDeload ? " · Deload" : "")")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.ironSecondary)
                        }

                        Divider().background(Color.ironElevated)

                        // Exercise details
                        ForEach(info.exercises) { ex in
                            exercisePreviewRow(spec: ex, isDeload: info.isDeload)
                        }

                        if info.isDeload {
                            Label("Deload week — reduced sets, same weight", systemImage: "leaf.fill")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.ironAmber)
                        }
                    }
                    .padding(20)
                    .background(Color.ironSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    IronButton(title: "Begin Session", icon: "bolt.fill") {
                        guard let p = profile else { return }
                        let newVM = WorkoutViewModel(modelContext: modelContext)
                        newVM.startSession(info: info, profile: p)
                        vm = newVM
                    }
                } else {
                    Text("No profile found. Complete onboarding first.")
                        .foregroundStyle(Color.ironSecondary)
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
    }

    private func exercisePreviewRow(spec: ExerciseSpec, isDeload: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(spec.name)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(spec.targetSets) × \(spec.targetReps)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.ironBlue)
            }

            if spec.type == "barbell" || spec.type == "cable" {
                PlateBreakdownView(weightLbs: spec.targetWeightLbs, exerciseType: spec.type)
            } else if spec.type == "cardio" {
                Text(Formatters.distance(spec.targetWeightLbs) + " easy pace")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
            } else {
                Text("\(Int(spec.targetWeightLbs)) reps · bodyweight")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
            }
        }
    }

    // MARK: - Active workout view
    @ViewBuilder
    private func activeWorkoutView(vm: WorkoutViewModel) -> some View {
        switch vm.phase {
        case .preview:
            EmptyView()
        case .warmup:
            WarmupSetScreen(vm: vm)
        case .workingSet:
            WorkingSetScreen(vm: vm)
        case .feedback:
            WorkingSetScreen(vm: vm)
                .sheet(isPresented: .constant(true)) {
                    SetFeedbackSheet(vm: vm)
                        .presentationDetents([.medium])
                        .presentationBackground(Color.ironSurface)
                }
        case .resting:
            RestScreen(vm: vm)
        case .exerciseComplete:
            ExerciseCompleteScreen(vm: vm)
        case .cardioActive:
            CardioScreen(vm: vm)
        case .sessionComplete:
            SessionCompleteScreen(vm: vm) {
                self.vm = nil
            }
        }
    }
}

// MARK: - Warmup set screen
struct WarmupSetScreen: View {
    var vm: WorkoutViewModel
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar(vm: vm)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        exerciseHeader(vm: vm, tag: "WARMUP")

                        if let ws = vm.currentWarmupSet {
                            // Set indicator
                            Text("Set \(vm.currentSetIndex + 1) of \(vm.warmupSetCount)")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.ironSecondary)

                            // Weight
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Formatters.weight(ws.weightLbs))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(ws.reps) reps")
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundStyle(Color.ironSecondary)
                            }

                            // Plate breakdown
                            if let ex = vm.currentExercise {
                                PlateBreakdownView(weightLbs: ws.weightLbs, exerciseType: ex.exerciseType)
                            }

                            // Rest note
                            Label("Rest \(Formatters.duration(ws.restAfterSeconds)) after", systemImage: "timer")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.ironSecondary)
                        }
                    }
                    .padding(20)
                }

                VStack(spacing: 12) {
                    IronButton(title: "Done", icon: "checkmark") {
                        vm.completeWarmupSet()
                    }
                }
                .padding(20)
                .background(Color.black)
            }
        }
    }
}

// MARK: - Working set screen
struct WorkingSetScreen: View {
    var vm: WorkoutViewModel
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar(vm: vm)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        exerciseHeader(vm: vm, tag: "WORKING SET")

                        if let ws = vm.currentWorkingSet, let ex = vm.currentExercise {
                            // Set indicator
                            HStack {
                                Text("Set \(vm.currentSetIndex + 1) of \(vm.workingSetCount)")
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color.ironSecondary)
                                Spacer()
                                Text("RPE target: 8")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Color.ironTertiary)
                            }

                            // Big weight
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Formatters.weight(ws.weightLbs))
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                                Text("\(ws.targetReps) reps")
                                    .font(.system(.title2, design: .rounded))
                                    .foregroundStyle(Color.ironSecondary)
                            }

                            // Plate breakdown
                            PlateBreakdownView(weightLbs: ws.weightLbs, exerciseType: ex.exerciseType)

                            // Rest note
                            Label("Rest \(Formatters.duration(ex.restDurationSeconds)) after", systemImage: "timer")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.ironSecondary)
                        }
                    }
                    .padding(20)
                }

                VStack(spacing: 12) {
                    IronButton(title: "Complete Set", icon: "checkmark.circle.fill") {
                        vm.beginSetFeedback()
                    }
                }
                .padding(20)
                .background(Color.black)
            }
        }
    }
}

// MARK: - Set feedback sheet
struct SetFeedbackSheet: View {
    var vm: WorkoutViewModel
    @State private var rating: String = ""
    @State private var actualReps: Int = 0

    var body: some View {
        VStack(spacing: 24) {
            // Handle
            Capsule()
                .fill(Color.ironElevated)
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            if let ws = vm.currentWorkingSet {
                Text("Set \(vm.currentSetIndex + 1) · \(Int(ws.weightLbs)) lbs × \(ws.targetReps)")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("How was that set?")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.ironSecondary)

            VStack(spacing: 10) {
                feedbackButton("Felt Strong", icon: "bolt.fill", color: .ironGreen,
                               ratingKey: "strong")
                feedbackButton("Barely Made It", icon: "checkmark", color: .ironAmber,
                               ratingKey: "barely")
                feedbackButton("Missed Reps", icon: "xmark", color: .ironRed,
                               ratingKey: "failed")
            }

            if rating == "failed" {
                VStack(spacing: 8) {
                    Text("How many reps did you complete?")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                    HStack(spacing: 24) {
                        Button {
                            actualReps = max(0, actualReps - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.ironSecondary)
                        }
                        Text("\(actualReps)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(minWidth: 50)
                        Button {
                            if let ws = vm.currentWorkingSet {
                                actualReps = min(ws.targetReps - 1, actualReps + 1)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.ironBlue)
                        }
                    }

                    IronButton(title: "Confirm", style: .secondary) {
                        vm.submitFeedback(rating: rating, actualReps: actualReps)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(Color.ironSurface)
        .onAppear {
            if let ws = vm.currentWorkingSet {
                actualReps = ws.targetReps
            }
        }
    }

    private func feedbackButton(_ title: String, icon: String, color: Color, ratingKey: String) -> some View {
        Button {
            rating = ratingKey
            HapticManager.impact(.medium)
            if ratingKey != "failed" {
                vm.submitFeedback(rating: ratingKey, actualReps: vm.currentWorkingSet?.targetReps ?? 0)
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                if rating == ratingKey {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.ironBlue)
                }
            }
            .padding(16)
            .background(rating == ratingKey ? color.opacity(0.12) : Color.ironElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Rest screen
struct RestScreen: View {
    var vm: WorkoutViewModel
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar(vm: vm)
                Spacer()
                RestTimerRing(
                    totalSeconds: vm.restTotalDuration,
                    remainingSeconds: vm.restRemaining,
                    onSkip: { vm.skipRest() },
                    onAddTime: { vm.addRestTime($0) }
                )

                // Next set preview
                if let ex = vm.currentExercise {
                    let nextIdx = vm.currentSetIndex + (vm.isInWarmup ? 1 : 1)
                    let working = ex.workingSets.sorted(by: { $0.setNumber < $1.setNumber })
                    if nextIdx < working.count {
                        Text("Next: Set \(nextIdx + 1) · \(Formatters.weight(working[nextIdx].weightLbs)) × \(working[nextIdx].targetReps)")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color.ironSecondary)
                            .padding(.top, 32)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Exercise complete screen
struct ExerciseCompleteScreen: View {
    var vm: WorkoutViewModel
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.ironGreen)
                if let ex = vm.currentExercise {
                    let prevIdx = vm.currentExerciseIndex - 1
                    let prev = vm.session?.exercises.sorted(by: { $0.order < $1.order })[safe: prevIdx]
                    Text((prev?.exerciseName ?? "Exercise") + " — Done")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Next: \(ex.exerciseName)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                }
            }
        }
    }
}

// MARK: - Cardio screen
struct CardioScreen: View {
    var vm: WorkoutViewModel
    @Query private var profiles: [UserProfile]
    @State private var distanceMiles: Double = 1.0
    @State private var rpe: Int = 5

    private var maxDistance: Double { profiles.first?.runMaxDistanceMiles ?? 6.0 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar(vm: vm)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RUN")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Color.ironBlue)
                            if let ex = vm.session?.exercises.sorted(by: { $0.order < $1.order }).first {
                                Text("Target: \(Formatters.distance(ex.targetWeightLbs))")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Easy pace · Zone 2")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Color.ironSecondary)
                            }
                        }

                        // Timer
                        VStack(spacing: 8) {
                            Text(Formatters.timerDisplay(vm.cardioElapsed))
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                                .animation(.linear(duration: 1), value: vm.cardioElapsed)

                            HStack(spacing: 16) {
                                if vm.cardioRunning {
                                    IronButton(title: "Pause", icon: "pause.fill", style: .secondary, fullWidth: false) {
                                        vm.stopCardioTimer()
                                    }
                                } else {
                                    IronButton(title: "Start Timer", icon: "play.fill", fullWidth: false) {
                                        vm.startCardioTimer()
                                    }
                                }
                            }
                        }

                        // Log
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Log Your Run")

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Distance")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Color.ironSecondary)
                                HStack {
                                    Button { distanceMiles = max(0.1, distanceMiles - 0.1) } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(Color.ironSecondary)
                                    }
                                    Text(String(format: "%.1f mi", distanceMiles))
                                        .font(.system(.title2, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(minWidth: 80)
                                    Button { distanceMiles = min(distanceMiles + 0.1, maxDistance) } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(Color.ironBlue)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Effort (RPE 1–10)")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Color.ironSecondary)
                                HStack(spacing: 8) {
                                    ForEach(1...10, id: \.self) { val in
                                        Button {
                                            rpe = val
                                        } label: {
                                            Text("\(val)")
                                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                                .foregroundStyle(rpe == val ? .black : Color.ironSecondary)
                                                .frame(width: 28, height: 28)
                                                .background(rpe == val ? Color.ironBlue : Color.ironElevated)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }

                VStack {
                    IronButton(title: "Log Run & Continue", icon: "checkmark") {
                        vm.completeCardio(distanceMiles: distanceMiles, rpe: rpe)
                    }
                }
                .padding(20)
                .background(Color.black)
            }
        }
        .onAppear {
            if let ex = vm.session?.exercises.sorted(by: { $0.order < $1.order }).first {
                distanceMiles = ex.targetWeightLbs
            }
        }
    }
}

// MARK: - Session complete screen
struct SessionCompleteScreen: View {
    var vm: WorkoutViewModel
    var onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var logWeight = false
    @State private var weight: Double = 160

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer(minLength: 32)

                    // Celebration
                    VStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.ironBlue)
                        Text("Session Complete")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let s = vm.session {
                            Text(ProgramEngine.title(for: s.sessionType))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.ironSecondary)
                        }
                    }

                    // Stats
                    HStack(spacing: 12) {
                        completeStat(value: vm.sessionDurationFormatted, label: "Duration")
                        completeStat(value: Formatters.volume(vm.totalVolumeLifted), label: "Volume")
                        completeStat(value: "\(vm.completedSetsCount)/\(vm.totalSetsCount)", label: "Sets")
                    }

                    // Body weight
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $logWeight) {
                            Text("Log today's weight")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .tint(Color.ironBlue)

                        if logWeight {
                            HStack {
                                Slider(value: $weight, in: 100...250, step: 0.5)
                                    .tint(Color.ironBlue)
                                Text(Formatters.weight(weight))
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 80, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.ironSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    IronButton(title: "Done") {
                        if logWeight {
                            vm.saveBodyWeightAndFinish(weightLbs: weight, context: modelContext)
                        }
                        onDismiss()
                    }
                }
                .padding(20)
            }
        }
        .onAppear { weight = vm.completionBodyWeight }
    }

    private func completeStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shared subviews
private func progressBar(vm: WorkoutViewModel) -> some View {
    GeometryReader { geo in
        let total = vm.totalExercises
        let done  = vm.currentExerciseIndex
        let pct   = total > 0 ? Double(done) / Double(total) : 0
        ZStack(alignment: .leading) {
            Rectangle().fill(Color.ironElevated)
            Rectangle()
                .fill(Color.ironBlue)
                .frame(width: geo.size.width * pct)
                .animation(.spring(response: 0.4), value: pct)
        }
    }
    .frame(height: 3)
}

private func exerciseHeader(vm: WorkoutViewModel, tag: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(tag)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(2)
            .foregroundStyle(Color.ironBlue)
        Text(vm.currentExercise?.exerciseName ?? "")
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
        if let ex = vm.currentExercise, let s = vm.session {
            let idx = s.exercises.sorted(by: { $0.order < $1.order }).firstIndex(where: { $0.exerciseName == ex.exerciseName }) ?? 0
            Text("Exercise \(idx + 1) of \(vm.totalExercises)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
        }
    }
}

// MARK: - Safe subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
