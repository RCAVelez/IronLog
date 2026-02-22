import Foundation

enum Formatters {
    static func weight(_ lbs: Double) -> String {
        if lbs == lbs.rounded() {
            return "\(Int(lbs)) lbs"
        }
        return String(format: "%.1f lbs", lbs)
    }

    static func weightCompact(_ lbs: Double) -> String {
        if lbs == lbs.rounded() { return "\(Int(lbs))" }
        return String(format: "%.1f", lbs)
    }

    static func duration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m == 0 { return "\(s)s" }
        if s == 0 { return "\(m)m" }
        return "\(m)m \(s)s"
    }

    static func timerDisplay(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    static func pace(distanceMiles: Double, durationSeconds: Int) -> String {
        guard distanceMiles > 0 else { return "--:--" }
        let secsPerMile = Double(durationSeconds) / distanceMiles
        let m = Int(secsPerMile) / 60
        let s = Int(secsPerMile) % 60
        return String(format: "%d:%02d /mi", m, s)
    }

    static func date(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let f = DateFormatter()
        f.dateStyle = style
        f.timeStyle = .none
        return f.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    static func distance(_ miles: Double) -> String {
        String(format: "%.1f mi", miles)
    }

    static func volume(_ lbs: Double) -> String {
        if lbs >= 1000 {
            return String(format: "%.1fk lbs", lbs / 1000)
        }
        return "\(Int(lbs)) lbs"
    }
}
