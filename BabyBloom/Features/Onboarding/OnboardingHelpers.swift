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
    case premium

    /// Quiz pages show the progress bar and bottom nav.
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
