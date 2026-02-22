import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var bodyEntries: [BodyWeightEntry]
    @Query(sort: \WorkoutSession.sessionOrderIndex) private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext

    @State private var showWeightEntry = false
    @State private var newWeight: Double = 160
    @State private var showResetAlert = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    private var profile: UserProfile? { profiles.first }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == "completed" }
    }

    private var nextSessionIndex: Int {
        (completedSessions.map(\.sessionOrderIndex).max() ?? -1) + 1
    }

    private var blockInfo: (block: Int, week: Int, isDeload: Bool)? {
        guard profiles.first != nil else { return nil }
        let (block, week) = ProgramEngine.blockInfo(for: nextSessionIndex)
        let isDeload = week == 4
        return (block, week, isDeload)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile?.name.isEmpty == false ? profile!.name : "Athlete")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            if let p = profile {
                                Text("\(p.bodyWeightLbs, specifier: "%.0f") lbs · \(p.heightInches / 12)'\(p.heightInches % 12)\"")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Color.ironSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.ironBlue)
                    }

                    // Program status
                    if let info = blockInfo {
                        programStatusSection(info: info)
                    }

                    // Body weight log
                    bodyWeightSection

                    // Starting weights reference
                    if let p = profile {
                        startingWeightsSection(profile: p)
                    }

                    // Settings
                    settingsSection

                    // Danger zone
                    dangerSection
                }
                .padding(20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showWeightEntry) {
            weightEntrySheet
        }
        .alert("Reset Program?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetProgram() }
        } message: {
            Text("This will erase all workout history and start from scratch. This cannot be undone.")
        }
    }

    // MARK: - Program status
    private func programStatusSection(info: (block: Int, week: Int, isDeload: Bool)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Program Status")
            VStack(spacing: 8) {
                statusRow("Block", value: "\(info.block)")
                statusRow("Week in block", value: "\(info.week) of 4")
                statusRow("Phase", value: info.isDeload ? "Deload" : "Loading",
                          highlight: info.isDeload ? .ironAmber : .ironBlue)
                statusRow("Total sessions", value: "\(completedSessions.count)")
                let days = ProgramEngine.daysToBenchmark(completedCount: nextSessionIndex)
                statusRow("Next benchmark", value: "~\(days) days")
            }
        }
        .padding(16)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statusRow(_ label: String, value: String, highlight: Color = .white) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(highlight)
        }
    }

    // MARK: - Body weight
    private var bodyWeightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Body Weight")
                Spacer()
                Button {
                    newWeight = profile?.bodyWeightLbs ?? 160
                    showWeightEntry = true
                } label: {
                    Label("Log", systemImage: "plus")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.ironBlue)
                }
            }

            if bodyEntries.isEmpty {
                Text("No weight entries yet.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(bodyEntries.prefix(8)) { entry in
                        HStack {
                            Text(Formatters.date(entry.date, style: .medium))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.ironSecondary)
                            Spacer()
                            Text(Formatters.weight(entry.weightLbs))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.vertical, 10)
                        if entry.id != bodyEntries.prefix(8).last?.id {
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

    // MARK: - Starting weights reference
    private func startingWeightsSection(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Program Starting Weights")
            VStack(spacing: 8) {
                weightRef("Squat",          lbs: profile.squatStartWeightLbs)
                weightRef("Bench Press",    lbs: profile.benchStartWeightLbs)
                weightRef("Deadlift",       lbs: profile.deadliftStartWeightLbs)
                weightRef("Military Press", lbs: profile.ohpStartWeightLbs)
                weightRef("Lat Pulldown",   lbs: profile.latPulldownStartWeightLbs)
                weightRef("Cable Row",      lbs: profile.cableRowStartWeightLbs)
            }
        }
        .padding(16)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func weightRef(_ name: String, lbs: Double) -> some View {
        HStack {
            Text(name)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
            Spacer()
            Text(Formatters.weight(lbs))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Settings
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Settings")
            VStack(spacing: 0) {
                settingToggle("Rest timer sounds", isOn: .constant(true))
                Divider().background(Color.ironElevated)
                settingToggle("Haptic feedback", isOn: .constant(true))
                Divider().background(Color.ironElevated)
                settingToggle("Rest auto-timer", isOn: .constant(true))
            }
        }
        .padding(16)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func settingToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(label, isOn: isOn)
            .font(.system(.subheadline, design: .rounded))
            .tint(Color.ironBlue)
            .padding(.vertical, 8)
    }

    // MARK: - Danger zone
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Danger Zone")
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.ironRed)
                    Text("Reset Program")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.ironRed)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Weight entry sheet
    private var weightEntrySheet: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.ironElevated)
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Text("Log Body Weight")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            HStack {
                Button { newWeight = max(90, newWeight - 0.5) } label: {
                    Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(Color.ironSecondary)
                }
                Text(Formatters.weight(newWeight))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 120)
                Button { newWeight += 0.5 } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Color.ironBlue)
                }
            }

            Slider(value: $newWeight, in: 100...250, step: 0.5)
                .tint(Color.ironBlue)
                .padding(.horizontal, 24)

            IronButton(title: "Save") {
                let entry = BodyWeightEntry(weightLbs: newWeight)
                modelContext.insert(entry)
                profile?.bodyWeightLbs = newWeight
                try? modelContext.save()
                showWeightEntry = false
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.ironSurface)
        .presentationDetents([.medium])
    }

    // MARK: - Reset
    private func resetProgram() {
        for session in sessions { modelContext.delete(session) }
        for entry in bodyEntries { modelContext.delete(entry) }
        for p in profiles { modelContext.delete(p) }
        try? modelContext.save()
        hasCompletedOnboarding = false
    }
}
