import SwiftUI

// MARK: - BabyBloom Design System
// Femtech Wellness iOS — lavender purple palette, soft shadows, rounded cards

enum BBTheme {

    // MARK: Colors
    enum Colors {
        /// #6B5EA8 — lavender purple
        static let primary = Color("BBPrimary")
        /// #E8A0BF — powder pink
        static let accent = Color("BBAccent")
        /// #F7F3FF — milk white
        static let background = Color("BBBackground")
        /// #A8D5C2 — mint green
        static let success = Color("BBSuccess")
        /// White / dark surface
        static let surface = Color("BBSurface")
        static let textPrimary = Color("BBTextPrimary")
        static let textSecondary = Color("BBTextSecondary")

        // Semantic
        static let feeding = Color(hex: "#E8A0BF")
        static let sleep = Color(hex: "#B0C4F5")
        static let diaper = Color(hex: "#F5D6A0")
        static let growth = Color(hex: "#A8D5C2")
        static let events = Color(hex: "#D4A8D5")
    }

    // MARK: Typography
    enum Typography {
        static func largeTitle(_ text: String) -> Text {
            Text(text).font(.system(size: 34, weight: .bold, design: .rounded))
        }
        static func title1(_ text: String) -> Text {
            Text(text).font(.system(size: 28, weight: .bold, design: .rounded))
        }
        static func title2(_ text: String) -> Text {
            Text(text).font(.system(size: 22, weight: .semibold, design: .rounded))
        }
        static func title3(_ text: String) -> Text {
            Text(text).font(.system(size: 20, weight: .semibold, design: .rounded))
        }
        static func body(_ text: String) -> Text {
            Text(text).font(.system(size: 17, weight: .regular, design: .rounded))
        }
        static func callout(_ text: String) -> Text {
            Text(text).font(.system(size: 16, weight: .regular, design: .rounded))
        }
        static func caption(_ text: String) -> Text {
            Text(text).font(.system(size: 12, weight: .medium, design: .rounded))
        }
    }

    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Radius
    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let pill: CGFloat = 999
    }

    // MARK: Shadow
    enum Shadow {
        static let soft = ShadowConfig(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 4)
        static let card = ShadowConfig(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)
        static let button = ShadowConfig(color: Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    struct ShadowConfig {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers
struct BBCardModifier: ViewModifier {
    var padding: CGFloat = BBTheme.Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.md)
            .shadow(
                color: BBTheme.Shadow.card.color,
                radius: BBTheme.Shadow.card.radius,
                x: BBTheme.Shadow.card.x,
                y: BBTheme.Shadow.card.y
            )
    }
}

struct BBGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(BBTheme.Radius.md)
            .shadow(
                color: BBTheme.Shadow.soft.color,
                radius: BBTheme.Shadow.soft.radius,
                x: BBTheme.Shadow.soft.x,
                y: BBTheme.Shadow.soft.y
            )
    }
}

extension View {
    func bbCard(padding: CGFloat = BBTheme.Spacing.md) -> some View {
        modifier(BBCardModifier(padding: padding))
    }

    func bbGlass() -> some View {
        modifier(BBGlassModifier())
    }

    func bbShadow(_ config: BBTheme.ShadowConfig) -> some View {
        shadow(color: config.color, radius: config.radius, x: config.x, y: config.y)
    }
}
