import SwiftUI

struct RestTimerRing: View {
    let totalSeconds: Int
    let remainingSeconds: Int
    var onSkip: () -> Void
    var onAddTime: (Int) -> Void

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    var body: some View {
        VStack(spacing: 32) {
            Text("REST")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Color.ironSecondary)

            ZStack {
                // Track
                Circle()
                    .stroke(Color.ironElevated, lineWidth: 10)
                    .frame(width: 200, height: 200)

                // Progress ring (depletes clockwise)
                Circle()
                    .trim(from: 0, to: max(0, 1.0 - progress))
                    .stroke(Color.ironBlue,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.ironBlue.opacity(0.35), radius: 8)
                    .animation(.linear(duration: 1), value: remainingSeconds)

                // Countdown
                Text(Formatters.timerDisplay(remainingSeconds))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.linear(duration: 0.3), value: remainingSeconds)
            }

            // Add time buttons
            HStack(spacing: 12) {
                addTimeButton("+30s", seconds: 30)
                addTimeButton("+60s", seconds: 60)
                addTimeButton("+90s", seconds: 90)
            }

            // End rest early — bordered button
            Button(action: onSkip) {
                Text("End Rest Early")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.ironSecondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.ironSecondary.opacity(0.5), lineWidth: 1)
                    )
            }
        }
    }

    private func addTimeButton(_ label: String, seconds: Int) -> some View {
        Button {
            HapticManager.impact(.light)
            onAddTime(seconds)
        } label: {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.ironBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.ironBlue.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.ironBlue.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
