import SwiftUI
import SwiftData
import Charts

struct IronProgressView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.sessionOrderIndex) private var sessions: [WorkoutSession]
    @Query(sort: \BodyWeightEntry.date) private var bodyWeightEntries: [BodyWeightEntry]
    @Query(sort: \CardioRecord.date) private var cardioRecords: [CardioRecord]

    @State private var selectedLift: String = "Squat"
    @State private var calendarMonth: Date = Calendar.current.startOfMonth(for: Date())

    private let lifts = ["Squat", "Bench Press", "Deadlift", "Military Press",
                         "Lat Pulldown", "Cable Row", "Romanian Deadlift", "Hip Thrust"]

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == "completed" }
    }

    // Wave loading multipliers (mirrors ProgressionEngine)
    private let projWaveMultipliers: [Double] = [1.0, 1.071, 1.171, 0.829]

    // MARK: - Historical weight points
    struct WeightPoint: Identifiable {
        let id = UUID()
        let date: Date
        let workingWeight: Double
    }

    private func weightPoints(for exercise: String) -> [WeightPoint] {
        var pts: [WeightPoint] = []
        for session in completedSessions {
            guard let date = session.completedDate else { continue }
            let sets = session.exercises
                .filter { $0.exerciseName == exercise }
                .flatMap { $0.workingSets }
                .filter { $0.completed }
            guard let heaviest = sets.max(by: { $0.weightLbs < $1.weightLbs }) else { continue }
            pts.append(WeightPoint(date: date, workingWeight: heaviest.weightLbs))
        }
        return pts.sorted { $0.date < $1.date }
    }

    // MARK: - Future projected weight points
    struct FutureWeightPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
        let sessionIndex: Int
    }

    private func sessionTypeForExercise(_ exercise: String) -> String? {
        ProgramEngine.exerciseDefs.first(where: { $0.value.contains(where: { $0.0 == exercise }) })?.key
    }

    private func lastExerciseDate(for exercise: String) -> Date? {
        completedSessions
            .sorted { $0.sessionOrderIndex > $1.sessionOrderIndex }
            .first(where: { $0.exercises.contains(where: { $0.exerciseName == exercise }) })?
            .completedDate
    }

    private func averageDaysBetweenOccurrences(for sessionType: String) -> Double {
        let dates = completedSessions
            .filter { $0.sessionType == sessionType }
            .sorted { $0.sessionOrderIndex < $1.sessionOrderIndex }
            .compactMap { $0.completedDate }
        guard dates.count >= 2 else { return 7.0 }
        var total = 0.0
        for i in 1..<dates.count {
            total += dates[i].timeIntervalSince(dates[i - 1]) / 86400
        }
        return total / Double(dates.count - 1)
    }

    private func lastSessionHadFailures(for exercise: String) -> Bool {
        guard let lastSession = completedSessions
            .sorted(by: { $0.sessionOrderIndex > $1.sessionOrderIndex })
            .first(where: { $0.exercises.contains(where: { $0.exerciseName == exercise }) })
        else { return false }
        let sets = lastSession.exercises
            .filter { $0.exerciseName == exercise }
            .flatMap { $0.workingSets }
            .filter { $0.completed }
        guard !sets.isEmpty else { return false }
        return Double(sets.filter { $0.completionRating == "failed" }.count) / Double(sets.count) > 0.5
    }

    private func lastUsedWeightForExercise(_ exercise: String) -> Double? {
        completedSessions
            .sorted { $0.sessionOrderIndex > $1.sessionOrderIndex }
            .lazy
            .compactMap { s -> Double? in
                guard let ex = s.exercises.first(where: { $0.exerciseName == exercise }) else { return nil }
                return ex.workingSets.filter { $0.completed }.max(by: { $0.weightLbs < $1.weightLbs })?.weightLbs
            }
            .first
    }

    private func futureWeightPoints(for exercise: String, count: Int = 52) -> [FutureWeightPoint] {
        guard let profile = profiles.first else { return [] }
        guard let targetSessionType = sessionTypeForExercise(exercise) else { return [] }
        guard let anchorDate = lastExerciseDate(for: exercise) else { return [] }
        guard let lastWeight = lastUsedWeightForExercise(exercise) else { return [] }
        let cap = ProgressionEngine.weightCap(for: exercise, userProfile: profile)

        let nextIdx = (completedSessions.map(\.sessionOrderIndex).max() ?? -1) + 1
        let hadFailures = lastSessionHadFailures(for: exercise)
        let avgDays = averageDaysBetweenOccurrences(for: targetSessionType)

        // Determine if exercise is upper body (smaller increment 2.5 vs 5 lbs)
        let isUpper = ["Bench Press", "Military Press", "Lat Pulldown", "Cable Row"].contains(exercise)
        let increment = isUpper ? 2.5 : 5.0

        // Back-calculate the week-1 base from the last actual completed weight
        let lastSessionForExercise = completedSessions
            .sorted { $0.sessionOrderIndex > $1.sessionOrderIndex }
            .first(where: { $0.exercises.contains(where: { $0.exerciseName == exercise }) })
        let lastWeekInBlock = lastSessionForExercise?.weekInBlock ?? 1
        let lastBlock = lastSessionForExercise?.blockNumber ?? 1
        let lastMultiplier = projWaveMultipliers[max(0, min(3, lastWeekInBlock - 1))]
        var projectedWeek1Base = lastWeight / lastMultiplier
        var trackedBlock = lastBlock

        var result: [FutureWeightPoint] = []
        var occurrenceCount = 0
        var i = nextIdx
        var projectedDate = anchorDate

        while occurrenceCount < count && i < nextIdx + count * 6 {
            if ProgramEngine.sessionType(for: i) == targetSessionType {
                projectedDate = projectedDate.addingTimeInterval(avgDays * 86400)
                let (blockNumber, weekInBlock) = ProgramEngine.blockInfo(for: i)

                // Each new block: new week-1 base = previous block's week-3 peak + increment.
                // This ensures coming back after deload is always above the last heavy session.
                if blockNumber > trackedBlock {
                    let prevWeek3Peak = projectedWeek1Base * projWaveMultipliers[2]  // 1.171
                    projectedWeek1Base = prevWeek3Peak + increment
                    trackedBlock = blockNumber
                }

                let multiplier = projWaveMultipliers[weekInBlock - 1]
                var weight = (projectedWeek1Base * multiplier / 5.0).rounded() * 5.0
                weight = max(5, min(weight, cap))

                // Failure: first projected session stays flat, not regressed
                if occurrenceCount == 0 && hadFailures {
                    weight = min((lastWeight / 5.0).rounded() * 5.0, cap)
                }

                result.append(FutureWeightPoint(date: projectedDate, weight: weight, sessionIndex: i))
                occurrenceCount += 1
            }
            i += 1
        }
        return result
    }

    // MARK: - Ab wheel data points
    struct AbPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxReps: Int
    }

    private var abWheelPoints: [AbPoint] {
        var pts: [AbPoint] = []
        for session in completedSessions {
            guard let date = session.completedDate else { continue }
            let sets = session.exercises
                .filter { $0.exerciseName == "Ab Wheel" }
                .flatMap { $0.workingSets }
                .filter { $0.completed }
            guard let best = sets.max(by: { $0.actualReps < $1.actualReps }) else { continue }
            let reps = best.actualReps > 0 ? best.actualReps : best.targetReps
            pts.append(AbPoint(date: date, maxReps: reps))
        }
        return pts.sorted { $0.date < $1.date }
    }

    // MARK: - Best set PRs
    struct SetPR {
        let weight: Double
        let reps: Int
        let date: Date
        var e1RM: Double { ProgressionEngine.estimatedOneRM(weight: weight, reps: reps) }
    }

    private func bestSet(for exercise: String) -> SetPR? {
        var bestE1RM: Double = 0
        var result: SetPR? = nil
        for session in completedSessions {
            guard let date = session.completedDate else { continue }
            for ex in session.exercises where ex.exerciseName == exercise {
                for ws in ex.workingSets where ws.completed && ws.actualReps > 0 {
                    let e = ProgressionEngine.estimatedOneRM(weight: ws.weightLbs, reps: ws.actualReps)
                    if e > bestE1RM {
                        bestE1RM = e
                        result = SetPR(weight: ws.weightLbs, reps: ws.actualReps, date: date)
                    }
                }
            }
        }
        return result
    }

    // MARK: - Weekly volume
    struct VolumeBar: Identifiable {
        let id = UUID()
        let weekStart: Date
        let totalLbs: Double
    }

    private var weeklyVolume: [VolumeBar] {
        var grouped: [Date: Double] = [:]
        for session in completedSessions {
            guard let date = session.completedDate else { continue }
            let weekStart = Calendar.current.startOfWeek(for: date)
            var vol: Double = 0
            for ex in session.exercises {
                for ws in ex.workingSets where ws.completed {
                    let reps = ws.actualReps > 0 ? ws.actualReps : ws.targetReps
                    vol += ws.weightLbs * Double(reps)
                }
            }
            grouped[weekStart, default: 0] += vol
        }
        return grouped.map { VolumeBar(weekStart: $0.key, totalLbs: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    // MARK: - Workout dates (for calendar)
    private var workoutDates: Set<String> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var dates = Set<String>()
        for s in completedSessions {
            if let d = s.completedDate { dates.insert(fmt.string(from: d)) }
        }
        return dates
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Progress")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    exerciseProgressSection

                    if bodyWeightEntries.count >= 1 { bodyWeightSection }

                    if weeklyVolume.count > 1 { weeklyVolumeSection }

                    if !cardioRecords.isEmpty { cardioSection }

                    if !abWheelPoints.isEmpty { abWheelSection }

                    calendarSection

                    prSection
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Exercise progress section
    private var exerciseProgressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Weight Progression")

            // Lift selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lifts, id: \.self) { lift in
                        Button { selectedLift = lift } label: {
                            Text(lift.components(separatedBy: " ").first ?? lift)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(selectedLift == lift ? .black : Color.ironSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedLift == lift ? Color.ironBlue : Color.ironSurface2)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            let pts = weightPoints(for: selectedLift)
            let futurePts = futureWeightPoints(for: selectedLift, count: 52)

            if pts.isEmpty {
                emptyPlaceholder("Complete \(selectedLift) sessions to see progression")
            } else {
                exerciseChart(pts: pts, futurePts: futurePts)
            }
        }
    }

    private func exerciseChart(pts: [WeightPoint], futurePts: [FutureWeightPoint]) -> some View {
        // Build the bridge: last historical point → all future points (for the dashed amber line)
        var bridged = [FutureWeightPoint]()
        if let last = pts.last {
            bridged.append(FutureWeightPoint(date: last.date, weight: last.workingWeight, sessionIndex: -1))
        }
        bridged.append(contentsOf: futurePts)

        let actualLabel = pts.last.map { Formatters.weight($0.workingWeight) } ?? "—"
        let projectedLabel = futurePts.first.map { Formatters.weight($0.weight) } ?? "—"

        // Y domain: historical + first 5 projected points (the initially-visible window).
        // Using all 52 future points would include far-future capped weights and compress
        // the visible wave into a flat line.
        let windowWeights = pts.map(\.workingWeight) + futurePts.prefix(5).map(\.weight)
        let dataMin = windowWeights.min() ?? 45
        let dataMax = windowWeights.max() ?? 135
        let dataRange = max(dataMax - dataMin, 20)   // at least 20 lb span
        let pad = dataRange * 0.40                   // 40% headroom above/below
        let yMin = max(0, dataMin - pad)
        let yMax = dataMax + pad

        return VStack(alignment: .leading, spacing: 0) {
            chartCard {
                Chart {
                    // Historical: solid blue line + white dots
                    ForEach(pts) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("lbs", p.workingWeight),
                            series: .value("s", "actual")
                        )
                        .foregroundStyle(Color.ironBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("lbs", p.workingWeight)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(50)
                    }

                    // Projected: dashed amber line bridging from last historical dot
                    ForEach(bridged) { p in
                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("lbs", p.weight),
                            series: .value("s", "projected")
                        )
                        .foregroundStyle(Color.ironAmber)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .interpolationMethod(.linear)
                    }

                    // Amber dots for future points only (not the bridge anchor)
                    ForEach(futurePts) { p in
                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("lbs", p.weight)
                        )
                        .foregroundStyle(Color.ironAmber)
                        .symbolSize(50)
                    }
                }
                .chartYScale(domain: yMin...yMax)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 35 * 24 * 3600)  // 5 weeks visible; scroll right for 12 months
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 4)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.ironSecondary)
                        AxisGridLine().foregroundStyle(Color.ironElevated)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel().foregroundStyle(Color.ironSecondary)
                        AxisGridLine().foregroundStyle(Color.ironElevated)
                    }
                }
                .frame(height: 200)
            }

            HStack(spacing: 20) {
                legendItem(color: Color.ironBlue, label: "Actual", value: actualLabel)
                legendItem(color: Color.ironAmber, label: "Projected", value: projectedLabel, dashed: true)
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)

            Text("Scroll to see 12 months ahead  →")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.ironTertiary)
                .padding(.top, 4)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Body weight
    private var bodyWeightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Body Weight")
            chartCard {
                Chart(bodyWeightEntries) { e in
                    AreaMark(x: .value("Date", e.date), y: .value("lbs", e.weightLbs))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.ironBlue.opacity(0.25), .clear],
                            startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", e.date), y: .value("lbs", e.weightLbs))
                        .foregroundStyle(Color.ironBlue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", e.date), y: .value("lbs", e.weightLbs))
                        .foregroundStyle(.white).symbolSize(50)
                }
                .chartYScale(domain: {
                    let weights = bodyWeightEntries.map(\.weightLbs)
                    let lo = (weights.min() ?? 150) - 5
                    let hi = (weights.max() ?? 180) + 5
                    return lo...hi
                }())
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(Color.ironSecondary)
                            }
                        }
                        AxisGridLine().foregroundStyle(Color.ironElevated)
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisValueLabel().foregroundStyle(Color.ironSecondary)
                        AxisGridLine().foregroundStyle(Color.ironElevated)
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Weekly volume
    private var weeklyVolumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Weekly Volume")
            chartCard {
                Chart(weeklyVolume) { bar in
                    BarMark(x: .value("Week", bar.weekStart, unit: .weekOfYear),
                            y: .value("Volume", bar.totalLbs))
                        .foregroundStyle(Color.ironBlue.opacity(0.8))
                        .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Color.ironSecondary)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 130)
            }
        }
    }

    // MARK: - Cardio
    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cardio Progression")
            chartCard {
                Chart {
                    ForEach(cardioRecords) { r in
                        AreaMark(x: .value("Date", r.date), y: .value("Miles", r.distanceMiles))
                            .foregroundStyle(LinearGradient(
                                colors: [Color.ironGreen.opacity(0.25), .clear],
                                startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Date", r.date), y: .value("Miles", r.distanceMiles))
                            .foregroundStyle(Color.ironGreen)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", r.date), y: .value("Miles", r.distanceMiles))
                            .foregroundStyle(.white).symbolSize(40)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Color.ironSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks {
                        AxisValueLabel().foregroundStyle(Color.ironSecondary)
                        AxisGridLine().foregroundStyle(Color.ironElevated)
                    }
                }
                .frame(height: 150)
            }

            HStack(spacing: 12) {
                if let best = cardioRecords.max(by: { $0.distanceMiles < $1.distanceMiles }) {
                    miniStat(label: "Best Run", value: Formatters.distance(best.distanceMiles))
                }
                if let fastest = cardioRecords.filter({ $0.distanceMiles > 0 && $0.durationSeconds > 0 })
                                              .min(by: { $0.paceSecondsPerMile < $1.paceSecondsPerMile }) {
                    miniStat(label: "Best Pace", value: Formatters.pace(distanceMiles: fastest.distanceMiles,
                                                                         durationSeconds: fastest.durationSeconds))
                }
                miniStat(label: "Total Runs", value: "\(cardioRecords.count)")
            }
        }
    }

    // MARK: - Ab wheel
    private var abWheelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Ab Wheel Progression")
            chartCard {
                Chart(abWheelPoints) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("Reps", p.maxReps))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.ironAmber.opacity(0.25), .clear],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Date", p.date), y: .value("Reps", p.maxReps))
                        .foregroundStyle(Color.ironAmber)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", p.date), y: .value("Reps", p.maxReps))
                        .foregroundStyle(.white).symbolSize(40)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Color.ironSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel().foregroundStyle(Color.ironSecondary)
                        AxisGridLine().foregroundStyle(Color.ironElevated)
                    }
                }
                .frame(height: 130)
            }
            if let best = abWheelPoints.max(by: { $0.maxReps < $1.maxReps }) {
                Text("Best: \(best.maxReps) reps · \(Formatters.shortDate(best.date))")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Workout calendar
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Workout Calendar")
            WorkoutCalendarView(workoutDates: workoutDates,
                                displayedMonth: $calendarMonth)
                .padding(16)
                .background(Color.ironSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - PRs
    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Personal Records")
            VStack(spacing: 0) {
                let trackedLifts = lifts.filter { lift in
                    completedSessions.contains { $0.exercises.contains { $0.exerciseName == lift } }
                }
                ForEach(trackedLifts, id: \.self) { lift in
                    if let pr = bestSet(for: lift) {
                        prRow(lift: lift, pr: pr)
                        if lift != trackedLifts.last {
                            Divider().background(Color.ironElevated)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func prRow(lift: String, pr: SetPR) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lift)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(Formatters.weight(pr.weight)) × \(pr.reps) reps")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.weight(pr.e1RM))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.ironBlue)
                Text("e1RM · " + Formatters.shortDate(pr.date))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.ironTertiary)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Helpers
    private func chartCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.ironSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func emptyPlaceholder(_ message: String) -> some View {
        Text(message)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Color.ironSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .multilineTextAlignment(.center)
            .padding()
            .background(Color.ironSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func legendItem(color: Color, label: String, value: String, dashed: Bool = false) -> some View {
        HStack(spacing: 6) {
            if dashed {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color)
                            .frame(width: 6, height: 2)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 18, height: 2)
            }
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Workout calendar view
struct WorkoutCalendarView: View {
    let workoutDates: Set<String>
    @Binding var displayedMonth: Date

    private let cal = Calendar.current
    private let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private let keyFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let monthFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var daysInMonth: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        let firstWeekday = cal.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func isWorkoutDay(_ date: Date) -> Bool {
        workoutDates.contains(keyFmt.string(from: date))
    }

    private func isToday(_ date: Date) -> Bool {
        cal.isDateInToday(date)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.ironSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.ironElevated)
                        .clipShape(Circle())
                }

                Spacer()

                Text(monthFmt.string(from: displayedMonth))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    let next = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    if next <= Date() { displayedMonth = next }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.ironSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.ironElevated)
                        .clipShape(Circle())
                }
            }

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.ironTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let d = date {
                        let isWorkout = isWorkoutDay(d)
                        let today = isToday(d)
                        ZStack {
                            Circle()
                                .fill(isWorkout ? Color.ironBlue : Color.clear)
                                .frame(width: 34, height: 34)

                            if today && !isWorkout {
                                Circle()
                                    .stroke(Color.ironSecondary.opacity(0.5), lineWidth: 1)
                                    .frame(width: 34, height: 34)
                            }

                            Text(dayFmt.string(from: d))
                                .font(.system(.caption, design: .rounded,
                                              weight: isWorkout ? .bold : .regular))
                                .foregroundStyle(isWorkout ? .black : (today ? .white : Color.ironSecondary))
                        }
                        .frame(height: 34)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(Color.ironBlue).frame(width: 10, height: 10)
                    Text("Workout")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                }
                HStack(spacing: 6) {
                    Circle().stroke(Color.ironSecondary.opacity(0.5), lineWidth: 1)
                        .frame(width: 10, height: 10)
                    Text("Today")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                }
            }
        }
    }
}

// MARK: - Calendar helpers
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? date
    }
}
