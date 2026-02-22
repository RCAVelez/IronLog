import SwiftUI

struct PlateBreakdownView: View {
    let weightLbs: Double
    let exerciseType: String  // "barbell" | "cable" | "bodyweight" | "cardio"

    private var plates: [PlateCount] {
        PlateCalculator.breakdown(for: weightLbs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if exerciseType == "barbell" {
                barbellView
            } else if exerciseType == "cable" {
                cableView
            } else if exerciseType == "bodyweight" {
                bodweightView
            }
        }
    }

    // MARK: - Barbell
    private var barbellView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Bar chip
            HStack(spacing: 6) {
                plateChip(label: "Bar", color: .plateBar)
                Text("45 lbs")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
            }

            // Plate rows
            ForEach(plates) { p in
                HStack(spacing: 6) {
                    plateChip(label: p.label, color: p.color)
                    Text("× \(p.count)  each side")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.ironSecondary)
                }
            }

            // Total
            Divider().background(Color.ironElevated)
            HStack {
                Text("Total")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.ironSecondary)
                Spacer()
                Text(Formatters.weight(weightLbs))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(Color.ironSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Cable
    private var cableView: some View {
        HStack {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(Color.ironBlue)
            Text("Cable pin weight")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
            Spacer()
            Text(Formatters.weight(weightLbs))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(Color.ironSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Bodyweight
    private var bodweightView: some View {
        HStack {
            Image(systemName: "figure.strengthtraining.functional")
                .foregroundStyle(Color.ironBlue)
            Text("Bodyweight")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.ironSecondary)
        }
        .padding(14)
        .background(Color.ironSurface2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Plate chip
    private func plateChip(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
