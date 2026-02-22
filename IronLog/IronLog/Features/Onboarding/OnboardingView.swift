import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step = 0
    @State private var name = ""
    @State private var bodyWeight: Double = 160
    @State private var heightFt: Int = 5
    @State private var heightIn: Int = 9

    // Starting weights (e5RM)
    @State private var squat: Double = 135
    @State private var bench: Double = 115
    @State private var deadlift: Double = 155
    @State private var ohp: Double = 75
    @State private var latPulldown: Double = 100
    @State private var cableRow: Double = 100

    private let totalSteps = 4

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Color.ironBlue : Color.ironElevated)
                            .frame(width: i == step ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 32)

                // Content
                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: profileStep
                    case 2: weightsStep
                    case 3: readyStep
                    default: welcomeStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: step)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Step 0: Welcome
    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Text("IronLog")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Train smarter.\nProgress forever.")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureLine(icon: "chart.line.uptrend.xyaxis", text: "Evidence-based programming")
                featureLine(icon: "scalemass", text: "Exact plate breakdowns every set")
                featureLine(icon: "timer", text: "Smart rest timers & progression")
                featureLine(icon: "lock.shield", text: "100% on-device, no accounts")
            }
            .padding(.vertical, 8)

            Spacer()
            IronButton(title: "Get Started", icon: "arrow.right") { advance() }
        }
    }

    // MARK: - Step 1: Profile
    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            headerText("Your Profile", subtitle: "We'll use this to personalise your program.")

            VStack(spacing: 14) {
                inputCard(label: "NAME (OPTIONAL)") {
                    TextField("Ray", text: $name)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.white)
                }

                inputCard(label: "BODY WEIGHT") {
                    HStack {
                        Slider(value: $bodyWeight, in: 100...250, step: 0.5)
                            .tint(Color.ironBlue)
                        Text("\(bodyWeight, specifier: "%.1f") lbs")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 70, alignment: .trailing)
                    }
                }

                inputCard(label: "HEIGHT") {
                    HStack {
                        Picker("ft", selection: $heightFt) {
                            ForEach(4...7, id: \.self) { Text("\($0) ft") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .clipped()

                        Picker("in", selection: $heightIn) {
                            ForEach(0...11, id: \.self) { Text("\($0) in") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .clipped()
                    }
                    .tint(Color.ironBlue)
                }
            }

            IronButton(title: "Continue") { advance() }
        }
    }

    // MARK: - Step 2: Starting weights
    private var weightsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerText("Starting Weights",
                           subtitle: "Enter the weight you can lift for 5 solid reps. We'll build from here.")

                VStack(spacing: 16) {
                    weightInput("Squat",          value: $squat,       type: "barbell")
                    weightInput("Bench Press",     value: $bench,       type: "barbell")
                    weightInput("Deadlift",        value: $deadlift,    type: "barbell")
                    weightInput("Military Press",  value: $ohp,         type: "barbell")
                    weightInput("Lat Pulldown",    value: $latPulldown, type: "cable")
                    weightInput("Cable Row",       value: $cableRow,    type: "cable")
                }

                Button(action: loadDefaults) {
                    Text("Use conservative defaults")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                IronButton(title: "Continue") { advance() }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 3: Ready
    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            headerText("You're all set.", subtitle: "Here's your program, built for you.")

            VStack(spacing: 12) {
                sessionPreview(day: "Session 1", name: "Lower A",   exercises: "Squat · Romanian Deadlift")
                sessionPreview(day: "Session 2", name: "Upper A",   exercises: "Bench Press · Cable Row")
                sessionPreview(day: "Session 3", name: "Lower B",   exercises: "Deadlift · Hip Thrust")
                sessionPreview(day: "Session 4", name: "Upper B",   exercises: "Military Press · Lat Pulldown")
                sessionPreview(day: "Session 5", name: "Cardio",    exercises: "Run · Ab Wheel")
            }

            Text("Your first benchmark test is in 8 weeks.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.ironSecondary)

            IronButton(title: "Start Program", icon: "bolt.fill") { finishOnboarding() }
        }
    }

    // MARK: - Helpers
    private func weightInput(_ label: String, value: Binding<Double>, type: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ironSecondary)

            HStack(spacing: 12) {
                // Stepper
                HStack(spacing: 0) {
                    Button(action: {
                        value.wrappedValue = max(45, value.wrappedValue - 5)
                    }) {
                        Image(systemName: "minus")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Color.ironBlue)
                    }
                    Text(Formatters.weightCompact(value.wrappedValue))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, alignment: .center)
                    Button(action: {
                        value.wrappedValue += 5
                    }) {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                            .foregroundStyle(Color.ironBlue)
                    }
                }
                .background(Color.ironSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if type == "barbell" && value.wrappedValue > 45 {
                PlateBreakdownView(weightLbs: value.wrappedValue, exerciseType: type)
            }
        }
    }

    private func inputCard<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color.ironSecondary)
            content()
        }
        .padding(16)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func featureLine(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.ironBlue)
                .frame(width: 24)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
        }
    }

    private func headerText(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
        }
    }

    private func sessionPreview(day: String, name: String, exercises: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(exercises)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
            }
            Spacer()
            Text(day)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.ironBlue)
        }
        .padding(14)
        .background(Color.ironSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadDefaults() {
        squat = 135; bench = 115; deadlift = 155; ohp = 75; latPulldown = 100; cableRow = 100
    }

    private func advance() {
        withAnimation { step = min(step + 1, totalSteps - 1) }
    }

    private func finishOnboarding() {
        let profile = UserProfile()
        profile.name = name
        profile.bodyWeightLbs = bodyWeight
        profile.heightInches = heightFt * 12 + heightIn
        profile.programStartDate = Date()
        profile.squatStartWeightLbs = squat
        profile.benchStartWeightLbs = bench
        profile.deadliftStartWeightLbs = deadlift
        profile.ohpStartWeightLbs = ohp
        profile.latPulldownStartWeightLbs = latPulldown
        profile.cableRowStartWeightLbs = cableRow
        profile.runCurrentDistanceMiles = 1.0
        profile.abWheelCurrentReps = 5
        profile.abWheelCurrentSets = 3

        modelContext.insert(profile)

        // Log initial body weight
        let bwEntry = BodyWeightEntry(weightLbs: bodyWeight)
        modelContext.insert(bwEntry)

        try? modelContext.save()
        hasCompletedOnboarding = true
    }
}
