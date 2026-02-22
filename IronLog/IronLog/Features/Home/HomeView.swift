import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.sessionOrderIndex) private var sessions: [WorkoutSession]

    private var profile: UserProfile? { profiles.first }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == "completed" || $0.status == "skipped" }
    }

    private var nextSessionIndex: Int {
        (completedSessions.map(\.sessionOrderIndex).max() ?? -1) + 1
    }

    private var nextSessionInfo: SessionInfo? {
        guard let p = profile else { return nil }
        return ProgramEngine.sessionInfo(for: nextSessionIndex,
                                         userProfile: p,
                                         completedSessions: completedSessions)
    }

    // Upcoming 4 sessions after the next one
    private var upcomingInfos: [SessionInfo] {
        guard let p = profile else { return [] }
        return (1...4).map {
            ProgramEngine.sessionInfo(for: nextSessionIndex + $0,
                                      userProfile: p,
                                      completedSessions: completedSessions)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date())
    }

    private var blockLabel: String {
        guard let info = nextSessionInfo else { return "" }
        return info.isDeload ? "Deload Week" : "Block \(info.blockNumber) · Week \(info.weekInBlock)"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greeting + (profile?.name.isEmpty == false ? ", \(profile!.name)" : ""))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.ironSecondary)
                            Text("IronLog")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text(dateString)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.ironSecondary)
                    }

                    // Next session card
                    if let info = nextSessionInfo {
                        nextSessionCard(info: info)
                    }

                    // Stats row
                    statsRow

                    // Program status
                    programStatusCard

                    // Upcoming sessions
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Upcoming")
                        ForEach(upcomingInfos, id: \.sessionOrderIndex) { info in
                            upcomingRow(info: info)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Next session card
    private func nextSessionCard(info: SessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT UP")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Color.ironBlue)
                    Text(ProgramEngine.title(for: info.sessionType))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(ProgramEngine.subtitle(for: info.sessionType))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: sessionIcon(info.sessionType))
                        .font(.title2)
                        .foregroundStyle(Color.ironBlue)
                    Text("~\(ProgramEngine.estimatedMinutes(for: info.sessionType)) min")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                }
            }

            // Exercise previews
            VStack(alignment: .leading, spacing: 6) {
                ForEach(info.exercises) { ex in
                    HStack {
                        Circle()
                            .fill(Color.ironBlue)
                            .frame(width: 5, height: 5)
                        Text(ex.name)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        if ex.type == "barbell" || ex.type == "cable" {
                            Text(Formatters.weight(ex.targetWeightLbs))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.ironSecondary)
                        } else if ex.type == "cardio" {
                            Text(Formatters.distance(ex.targetWeightLbs))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.ironSecondary)
                        } else {
                            Text("\(Int(ex.targetWeightLbs)) reps")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color.ironSecondary)
                        }
                    }
                }
            }
            .padding(.top, 4)

            if info.isDeload {
                Label("Deload week — lighter loads, full recovery", systemImage: "arrow.down.heart")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.ironAmber)
            }
        }
        .padding(20)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.ironBlue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Stats row
    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(value: "\(completedSessions.count)", label: "Sessions")
            statCard(value: blockLabel, label: "Program")
            if let p = profile {
                statCard(value: Formatters.weightCompact(p.bodyWeightLbs), label: "lbs")
            }
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Program status card
    private var programStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Program Status")

            if let info = nextSessionInfo {
                let daysLeft = ProgramEngine.daysToBenchmark(completedCount: nextSessionIndex)
                HStack {
                    Label("Next benchmark in \(daysLeft) days", systemImage: "flag.fill")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                    Spacer()
                    Text(info.isDeload ? "DELOAD" : "LOADING")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(info.isDeload ? Color.ironAmber : Color.ironBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((info.isDeload ? Color.ironAmber : Color.ironBlue).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Upcoming row
    private func upcomingRow(info: SessionInfo) -> some View {
        HStack {
            Image(systemName: sessionIcon(info.sessionType))
                .foregroundStyle(Color.ironBlue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(ProgramEngine.title(for: info.sessionType))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(ProgramEngine.subtitle(for: info.sessionType))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
            }
            Spacer()
            Text("Session \(info.sessionOrderIndex + 1)")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.ironTertiary)
        }
        .padding(14)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers
    private func sessionIcon(_ type: String) -> String {
        switch type {
        case "lowerA", "lowerB": return "figure.strengthtraining.traditional"
        case "upperA", "upperB": return "dumbbell.fill"
        case "cardio":           return "figure.run"
        default:                 return "bolt.fill"
        }
    }
}
