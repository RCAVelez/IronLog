import SwiftUI

extension Color {
    // MARK: - Backgrounds
    static let ironSurface    = Color(hex: "111111")
    static let ironSurface2   = Color(hex: "1C1C1E")
    static let ironElevated   = Color(hex: "2C2C2E")

    // MARK: - Text
    static let ironSecondary  = Color(hex: "8E8E93")
    static let ironTertiary   = Color(hex: "48484A")

    // MARK: - Accent
    static let ironBlue       = Color(hex: "5AC8FA")

    // MARK: - Feedback
    static let ironGreen      = Color(hex: "30D158")
    static let ironAmber      = Color(hex: "FF9F0A")
    static let ironRed        = Color(hex: "FF453A")

    // MARK: - Plates
    static let plate45        = Color(hex: "D62828")
    static let plate35        = Color(hex: "2B6CB0")
    static let plate25        = Color(hex: "D97706")
    static let plate10        = Color(hex: "2D6A4F")
    static let plate5         = Color(hex: "9CA3AF")
    static let plate2_5       = Color(hex: "6B7280")
    static let plateBar       = Color(hex: "4B5563")

    static func plateColor(for weight: Double) -> Color {
        switch weight {
        case 45:   return .plate45
        case 35:   return .plate35
        case 25:   return .plate25
        case 10:   return .plate10
        case 5:    return .plate5
        default:   return .plate2_5
        }
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
