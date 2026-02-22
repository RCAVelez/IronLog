import SwiftUI

struct IronButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var fullWidth: Bool = true
    let action: () -> Void

    enum ButtonStyle { case primary, secondary, danger }

    var body: some View {
        Button(action: {
            HapticManager.impact(.medium)
            action()
        }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 54)
            .padding(.horizontal, fullWidth ? 0 : 24)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var background: Color {
        switch style {
        case .primary:   return .ironBlue
        case .secondary: return .ironElevated
        case .danger:    return Color.ironRed.opacity(0.2)
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:   return .black
        case .secondary: return .white
        case .danger:    return .ironRed
        }
    }
}

// MARK: - Scale press style
struct ScaleButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Section header
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(Color.ironSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
