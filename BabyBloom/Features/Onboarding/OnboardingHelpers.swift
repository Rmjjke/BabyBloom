import SwiftUI

// MARK: - Typed step

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case name
    case birth
    case feeding
    case growth
    case fact
    case generating
    case notifications
    case premium

    /// Quiz pages show the progress bar and bottom nav. The two pages added
    /// after Generating are not quiz pages, so neither the bar nor
    /// `quizProgress`'s denominator moves when the flow grows.
    var isQuiz: Bool {
        switch self {
        case .name, .birth, .feeding, .growth: return true
        default: return false
        }
    }

    /// Goal Gradient Effect: front-loaded progress across the quiz pages.
    var quizProgress: Double {
        switch self {
        case .name:    return 0.22
        case .birth:   return 0.50
        case .feeding: return 0.78
        case .growth:  return 1.0
        default:       return 0
        }
    }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}

// MARK: - Helpers

/// Onboarding page hero: a themed SF Symbol inside a soft category-colored
/// circle. Replaces the previous emoji heroes, which rendered as tofu "?"
/// squares on the simulator.
func onboardingHeroIcon(_ systemName: String, color: Color) -> some View {
    Image(systemName: systemName)
        .font(.system(size: 56, weight: .medium))
        .foregroundStyle(color)
        .frame(width: 120, height: 120)
        .background(color.opacity(0.22), in: Circle())
}

func backButton(action: @escaping () -> Void) -> some View {
    HStack {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("button.back".l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
            }
            .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        .padding(.leading, BBTheme.Spacing.lg)
        .padding(.top, 12)
        Spacer()
    }
}
