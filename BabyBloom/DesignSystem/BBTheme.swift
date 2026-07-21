import SwiftUI

// MARK: - BabyBloom Design System
// Soft botanical iOS — sage/mint palette, soft shadows, rounded cards.
// ALL colors resolve through Asset Catalog colorsets (light + dark variants):
// re-theming the app = editing the colorsets, no code changes.

enum BBTheme {

    // MARK: Colors
    enum Colors {
        /// Deep sage teal — brand primary
        static let primary = Color("BBPrimary")
        /// Soft peach — warm accent
        static let accent = Color("BBAccent")
        /// Mint-white app background
        static let background = Color("BBBackground")
        /// Mint green — success
        static let success = Color("BBSuccess")
        /// White / dark surface
        static let surface = Color("BBSurface")
        static let textPrimary = Color("BBTextPrimary")
        static let textSecondary = Color("BBTextSecondary")

        // Semantic category tints
        static let feeding = Color("BBFeeding")
        static let sleep = Color("BBSleep")
        static let diaper = Color("BBDiaper")
        static let growth = Color("BBGrowth")
        static let events = Color("BBEvents")

        // Premium hero gradient (sage → mint)
        static let premiumGradient = LinearGradient(
            colors: [Color("BBGradientStart"), Color("BBGradientEnd")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Typography
    // Scale D1: straight SF Pro (semibold, not bold) for headers; rounded for body;
    // rounded + monospacedDigit for metrics/timers so digits don't jump.
    enum Typography {
        static func largeTitle(_ text: String) -> Text {
            Text(text)
                .font(.system(size: 30, weight: .semibold, design: .default))
                .tracking(-0.4)
        }
        static func title1(_ text: String) -> Text {
            Text(text)
                .font(.system(size: 26, weight: .semibold, design: .default))
                .tracking(-0.3)
        }
        static func title2(_ text: String) -> Text {
            Text(text)
                .font(.system(size: 21, weight: .semibold, design: .default))
                .tracking(-0.2)
        }
        static func title3(_ text: String) -> Text {
            Text(text).font(.system(size: 18, weight: .semibold, design: .default))
        }
        static func body(_ text: String) -> Text {
            Text(text).font(.system(size: 17, weight: .regular, design: .rounded))
        }
        static func bodyEmphasized(_ text: String) -> Text {
            Text(text).font(.system(size: 17, weight: .medium, design: .rounded))
        }
        static func callout(_ text: String) -> Text {
            Text(text).font(.system(size: 16, weight: .regular, design: .rounded))
        }
        static func caption(_ text: String) -> Text {
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .tracking(0.3)
        }
        /// Large KPI digits — rounded, monospaced so values don't shift width.
        static func metric(_ text: String) -> Text {
            Text(text)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        /// Small metric digits (inline totals, secondary stats).
        static func metricSmall(_ text: String) -> Text {
            Text(text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
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
