import SwiftUI

// MARK: - BabyBloom Design System
// Soft lavender iOS — lavender/peach palette, soft shadows, rounded cards.
// ALL colors resolve through Asset Catalog colorsets (light + dark variants):
// re-theming the app = editing the colorsets, no code changes.

enum BBTheme {

    // MARK: Colors
    enum Colors {
        /// Deep violet — brand primary
        static let primary = Color("BBPrimary")
        /// Soft peach — warm accent
        static let accent = Color("BBAccent")
        /// Lavender-white app background
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

        // Premium hero gradient (violet → lavender)
        static let premiumGradient = LinearGradient(
            colors: [Color("BBGradientStart"), Color("BBGradientEnd")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Typography
    // Scale D1: straight SF Pro (semibold, not bold) for headers; rounded for body;
    // rounded + monospacedDigit for metrics/timers so digits don't jump.
    enum Typography {
        /// The app's Dynamic Type ceiling, in the ONE place that decides it.
        /// AX2 is a deliberate MVP compromise: full AX5 would demand per-screen
        /// relayout across the app. `BabyBloomApp` reads `maxDynamicTypeSize`
        /// from this same constant, so the SwiftUI cap and the font cap below
        /// cannot drift apart again — which is exactly how they drifted before.
        static let maxContentSizeCategory: UIContentSizeCategory = .accessibilityLarge

        /// The SwiftUI face of `maxContentSizeCategory`. Views may branch on
        /// `dynamicTypeSize` for LAYOUT, so the environment must agree with the
        /// point sizes the fonts actually get.
        static let maxDynamicTypeSize: DynamicTypeSize =
            DynamicTypeSize(maxContentSizeCategory) ?? .accessibility2

        // `UITraitCollection(mutations:)` would read better, but its closure is
        // main-actor-isolated and these helpers are called from nonisolated code
        // too. This initializer is not deprecated — only `traitsFrom:` is.
        private static let capTraits =
            UITraitCollection(preferredContentSizeCategory: maxContentSizeCategory)

        /// Point size for the D1 scale value `size`, scaled for Dynamic Type and
        /// clamped to `maxContentSizeCategory`.
        ///
        /// The `min` IS the cap. `UIFontMetrics.scaledValue(for:)` — the form
        /// with no trait collection — reads the DEVICE content size and ignores
        /// the SwiftUI environment, so `.dynamicTypeSize(...)` never constrained
        /// these fonts: at AX5 a card measured 774pt against 442pt at AX2.
        /// Scaling is monotonic in the category, so the smaller of "what the
        /// device asks for" and "what AX2 gives" caps growth while leaving
        /// everything at or below AX2 pixel-identical.
        ///
        /// `category` is the test seam — the device size cannot be moved from
        /// inside a test process. Production passes nil and reads the device.
        static func scaledPointSize(_ size: CGFloat,
                                    relativeTo style: UIFont.TextStyle,
                                    for category: UIContentSizeCategory? = nil) -> CGFloat {
            let metrics = UIFontMetrics(forTextStyle: style)
            let requested: CGFloat
            if let category {
                requested = metrics.scaledValue(
                    for: size,
                    compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
                )
            } else {
                requested = metrics.scaledValue(for: size)
            }
            return min(requested, metrics.scaledValue(for: size, compatibleWith: capTraits))
        }

        /// Dynamic-Type-aware system font. `size`/`weight`/`design` are the D1 scale
        /// values (unchanged); the point size is scaled for the user's Content Size
        /// setting and capped at `maxContentSizeCategory`. At the standard "Large"
        /// setting the scale factor is 1.0, so rendering is pixel-identical to the
        /// fixed-size D1 scale.
        static func scaled(_ size: CGFloat,
                           relativeTo style: UIFont.TextStyle,
                           weight: Font.Weight,
                           design: Font.Design = .rounded) -> Font {
            .system(size: scaledPointSize(size, relativeTo: style),
                    weight: weight, design: design)
        }

        static func largeTitle(_ text: String) -> Text {
            Text(text)
                .font(scaled(30, relativeTo: .title1, weight: .semibold, design: .default))
                .tracking(-0.4)
        }
        static func title1(_ text: String) -> Text {
            Text(text)
                .font(scaled(26, relativeTo: .title2, weight: .semibold, design: .default))
                .tracking(-0.3)
        }
        static func title2(_ text: String) -> Text {
            Text(text)
                .font(scaled(21, relativeTo: .title3, weight: .semibold, design: .default))
                .tracking(-0.2)
        }
        static func title3(_ text: String) -> Text {
            Text(text).font(scaled(18, relativeTo: .headline, weight: .semibold, design: .default))
        }
        static func body(_ text: String) -> Text {
            Text(text).font(scaled(17, relativeTo: .body, weight: .regular, design: .rounded))
        }
        static func bodyEmphasized(_ text: String) -> Text {
            Text(text).font(scaled(17, relativeTo: .body, weight: .medium, design: .rounded))
        }
        static func callout(_ text: String) -> Text {
            Text(text).font(scaled(16, relativeTo: .callout, weight: .regular, design: .rounded))
        }
        static func caption(_ text: String) -> Text {
            Text(text)
                .font(scaled(12, relativeTo: .caption1, weight: .medium, design: .rounded))
                .tracking(0.3)
        }
        /// Large KPI digits — rounded, monospaced so values don't shift width.
        static func metric(_ text: String) -> Text {
            Text(text)
                .font(scaled(28, relativeTo: .title2, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        /// Small metric digits (inline totals, secondary stats).
        static func metricSmall(_ text: String) -> Text {
            Text(text)
                .font(scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
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
    // Depth system (D2): tinted, diffuse shadows in the brand hue instead of flat
    // black — reads softer and more premium. Button shadow toned right down so it
    // no longer glows like a lantern (especially in dark mode).
    enum Shadow {
        static let soft = ShadowConfig(color: Colors.primary.opacity(0.14), radius: 28, x: 0, y: 12)
        static let card = ShadowConfig(color: Colors.primary.opacity(0.10), radius: 20, x: 0, y: 8)
        static let button = ShadowConfig(color: Colors.primary.opacity(0.18), radius: 10, x: 0, y: 4)
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

/// Elevated surface (level 1): white/dark card with a tinted diffuse shadow and a
/// 1px inner highlight along the top edge so it catches light like a real object.
/// The highlight is bright in light mode (white@0.5) and whisper-soft in dark
/// (white@0.08) so it hints at an edge without glowing.
struct BBCardModifier: ViewModifier {
    var padding: CGFloat = BBTheme.Spacing.md
    @Environment(\.colorScheme) private var colorScheme

    private var highlightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.5)
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                    .strokeBorder(highlightColor, lineWidth: 1)
                    .blendMode(.overlay)
            )
            .shadow(
                color: BBTheme.Shadow.card.color,
                radius: BBTheme.Shadow.card.radius,
                x: BBTheme.Shadow.card.x,
                y: BBTheme.Shadow.card.y
            )
    }
}

/// Tonal surface (level 0): a flat wash of the category tint with no shadow and no
/// border. Reads as a grouped/secondary surface that sits *into* the page rather
/// than floating above it — used for at-a-glance stat tiles and quick-add tiles.
struct BBCardTonalModifier: ViewModifier {
    let tint: Color
    var padding: CGFloat = BBTheme.Spacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(tint.opacity(0.08))
            .cornerRadius(BBTheme.Radius.lg)
    }
}

/// Bare row: vertical padding only, no fill/shadow — designed to sit inside a
/// grouped container with Dividers between rows.
struct BBBareRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, BBTheme.Spacing.sm)
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

    /// Tonal (flat, tinted, shadowless) surface — see `BBCardTonalModifier`.
    func bbCardTonal(_ tint: Color, padding: CGFloat = BBTheme.Spacing.md) -> some View {
        modifier(BBCardTonalModifier(tint: tint, padding: padding))
    }

    /// Bare row (vertical padding only) — see `BBBareRowModifier`.
    func bbBareRow() -> some View {
        modifier(BBBareRowModifier())
    }

    func bbGlass() -> some View {
        modifier(BBGlassModifier())
    }

    func bbShadow(_ config: BBTheme.ShadowConfig) -> some View {
        shadow(color: config.color, radius: config.radius, x: config.x, y: config.y)
    }
}
