import SwiftUI

// MARK: - Feeding type (page 4 of 11)

struct FeedingPage: View {
    @Binding var feedingType: Baby.FeedingType
    let babyName: String
    let onBack: () -> Void

    private var displayName: String {
        babyName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "baby.default_name".l
            : babyName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(spacing: 0) {
            backButton(action: onBack)

            onboardingCenteredScroll {
            VStack(spacing: BBTheme.Spacing.xl) {
                onboardingHeroIcon("heart.fill", color: BBTheme.Colors.feeding)

                VStack(spacing: BBTheme.Spacing.sm) {
                    BBTheme.Typography.title1("onboarding.feeding_title".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    FeedingHint(text: "onboarding.feeding_hint".l)
                }

                // One shape for the three rows: the name beside its icon while
                // every name fits there, else each name under its icon, so
                // «Смешанное» on a 320-pt screen at the accessibility sizes is
                // never broken.
                ViewThatFits(in: .horizontal) {
                    typeRows(stacked: false)
                    typeRows(stacked: true)
                }
            }
            .padding(.horizontal, BBTheme.Spacing.lg)
            .padding(.vertical, BBTheme.Spacing.md)
            }
        }
    }

    private func typeRows(stacked: Bool) -> some View {
        VStack(spacing: BBTheme.Spacing.md) {
            ForEach(Baby.FeedingType.allCases, id: \.self) { type in
                let selected = feedingType == type
                Button {
                    withAnimation(.spring(response: 0.3)) { feedingType = type }
                } label: {
                    typeRow(type, selected: selected, stacked: stacked)
                        .padding(BBTheme.Spacing.md)
                        .background(selected ? BBTheme.Colors.primary.opacity(0.12) : Color.clear).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md)
                        .bbShadow(BBTheme.Shadow.card)
                        .bbSelectedBorder(selected)
                }
                .buttonStyle(BBScaleButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func typeRow(_ type: Baby.FeedingType, selected: Bool, stacked: Bool) -> some View {
        let icon = Image(systemName: type.icon)
            .font(.system(size: 22))
            .foregroundStyle(BBTheme.Colors.primary)
            .frame(width: 46, height: 46)
            .background(selected ? BBTheme.Colors.primary.opacity(0.22) : BBTheme.Colors.primary.opacity(0.1))
            .cornerRadius(12)
        // Hidden on the other rows rather than left out: every name has the
        // same room, so picking a row never changes the shape or breaks a name.
        let check = Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(BBTheme.Colors.primary)
            .font(.system(size: 20))
            .opacity(selected ? 1 : 0)
            .accessibilityHidden(!selected)
        if stacked {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                HStack {
                    icon
                    Spacer()
                    check
                }
                typeName(Text(type.displayName.l), selected: selected)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            // The name's ideal width is its widest word's: the width the
            // ViewThatFits compares.
            HStack(spacing: BBTheme.Spacing.md) {
                icon
                typeName(WordWrappingText(text: type.displayName.l), selected: selected)
                    .frame(maxWidth: .infinity, alignment: .leading)
                check
            }
        }
    }

    private func typeName(_ text: some View, selected: Bool) -> some View {
        text
            .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
            .foregroundStyle(selected ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The subtitle under the feeding title. It wraps between words at the
/// reader's size; only a word wider than the whole column
/// («персонализированного» on a 320-pt screen at the largest sizes) sets it
/// at the AX1 size, then at xxxLarge's, as a button's title does.
struct FeedingHint: View {
    let text: String
    /// The text size the hint is set for; nil follows the device.
    var category: UIContentSizeCategory? = nil

    var body: some View {
        // Each try's ideal width is its widest word's: a size is passed over
        // only when a word misses the column.
        ViewThatFits(in: .horizontal) {
            hint(size: naturalSize)
            hint(size: steppedSize(.accessibilityMedium))
            hint(size: steppedSize(.extraExtraExtraLarge))
        }
    }

    private var naturalSize: CGFloat {
        BBTheme.Typography.scaledPointSize(14, relativeTo: .body, for: category)
    }

    private func steppedSize(_ step: UIContentSizeCategory) -> CGFloat {
        min(naturalSize, BBTheme.Typography.scaledPointSize(14, relativeTo: .body, for: step))
    }

    private func hint(size: CGFloat) -> some View {
        WordWrappingText(text: text)
            .font(.system(size: size, weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
