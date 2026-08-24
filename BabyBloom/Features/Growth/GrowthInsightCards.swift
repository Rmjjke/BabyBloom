import SwiftUI

// MARK: - Shared chrome

/// The card shell every insight block sits in, so they read as one family.
private struct InsightCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBTheme.Typography.title3(title)
                .foregroundStyle(BBTheme.Colors.textPrimary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }
}

/// Neutral note for "not enough data yet" states. These are not failures and
/// must not look like them — a parent who has weighed once is doing fine.
private struct HintText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A thing worth raising with a doctor. Never a diagnosis, always an invitation
/// to ask someone qualified.
private struct FlagRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "#E05A5A"))
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BBTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#E05A5A").opacity(0.10))
        .cornerRadius(BBTheme.Radius.md)
    }
}

// MARK: - First weeks

/// Birth-weight recovery, shown only while it is the question that matters.
///
/// Free for everyone, including the flags. Putting a "your baby may be losing
/// too much weight" warning behind a paywall would be indefensible.
struct NewbornProgressCard: View {
    let status: NewbornWeightLoss.Status

    var body: some View {
        InsightCard(title: "section.first_weeks".l) {
            Text(String(format: "newborn.day_fmt".l, status.dayOfLife))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)

            if let percent = status.percentOfBirthWeight {
                HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                    BBTheme.Typography.metric(String(format: "newborn.percent_fmt".l, Int(percent.rounded())))
                        .foregroundStyle(status.hasRegained ? Color(hex: "#6BBF6B") : BBTheme.Colors.textPrimary)
                    Spacer()
                    if status.hasRegained {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "#6BBF6B"))
                    }
                }

                Text(status.hasRegained ? "newborn.regained".l : "newborn.not_regained".l)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            } else {
                HintText(text: "newborn.needs_weighing".l)
            }

            ForEach(status.flags, id: \.self) { flag in
                FlagRow(text: flag == .lossExceeds10Percent
                        ? "newborn.flag_loss".l
                        : "newborn.flag_not_regained".l)
            }
        }
    }
}

extension NewbornWeightLoss.Flag: Hashable {}

// MARK: - Weight gain

struct WeightGainCard: View {
    let reading: WeightVelocity.Reading?

    var body: some View {
        InsightCard(title: "section.weight_gain".l) {
            guardedContent
        }
    }

    @ViewBuilder
    private var guardedContent: some View {
        if let reading {
            HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                BBTheme.Typography.metric(
                    String(format: "velocity.per_week_fmt".l, formatted(reading.gramsPerWeek))
                )
                .foregroundStyle(color(for: reading.band))
                Spacer()
                Text(String(format: "velocity.interval_fmt".l, reading.intervalDays))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }

            if let band = reading.band, let expected = reading.expectedPerWeek {
                Text(label(for: band))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(color(for: band))
                Text(String(format: "velocity.expected_fmt".l,
                            Int(expected.lowerBound.rounded()), Int(expected.upperBound.rounded())))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            } else {
                HintText(text: "velocity.no_reference".l)
            }
        } else {
            HintText(text: "velocity.needs_two".l)
        }
    }

    /// Signed, so a week of loss reads unmistakably as loss.
    private func formatted(_ gramsPerWeek: Double) -> String {
        let rounded = Int(gramsPerWeek.rounded())
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func label(for band: WeightVelocity.Band?) -> String {
        switch band {
        case .below:  return "velocity.below".l
        case .within: return "velocity.within".l
        case .above:  return "velocity.above".l
        case nil:     return ""
        }
    }

    /// Only "below" is tinted as something to look at. A baby gaining fast is
    /// not a problem to flag in an app.
    private func color(for band: WeightVelocity.Band?) -> Color {
        switch band {
        case .below:  return Color(hex: "#F5A45F")
        case .within: return Color(hex: "#6BBF6B")
        case .above:  return BBTheme.Colors.textPrimary
        case nil:     return BBTheme.Colors.textPrimary
        }
    }
}

// MARK: - Centile trend

struct CentileTrendCard: View {
    let assessment: GrowthTrend.Assessment

    var body: some View {
        InsightCard(title: "section.trend".l) {
            switch assessment {
            case .insufficientData:
                HintText(text: "trend.insufficient".l)
            case .stable:
                HStack(spacing: BBTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "#6BBF6B"))
                    Text("trend.stable".l)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
            case let .sustainedDrop(spaces):
                FlagRow(text: String(format: "trend.drop_fmt".l, String(format: "%.1f", spaces)))
            }
        }
    }
}

// MARK: - Percentile out of range

/// Past 24 months the WHO weight-for-age tables run out. Saying so is the honest
/// alternative to the old behaviour, which read an older child off the 24-month
/// row and presented the result as fact.
struct PercentileOutOfRangeCard: View {
    var body: some View {
        InsightCard(title: "section.who_percentiles".l) {
            HintText(text: "percentile.out_of_range".l)
        }
    }
}

// MARK: - Premium gate

/// Stands in for a Premium-only card. Says what the block would tell them
/// without showing the number itself.
struct LockedInsightCard: View {
    let title: String
    let teaser: String
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            InsightCard(title: title) {
                HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(BBTheme.Colors.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(teaser)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        Text("premium.locked_hint".l)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.primary)
                    }
                }
            }
        }
        .buttonStyle(BBScaleButtonStyle())
    }
}

// MARK: - Corrected age

/// Shown only for a baby born preterm, next to anything compared against a
/// reference — otherwise the numbers look wrong to a parent who knows their
/// child's actual age.
struct CorrectedAgeChip: View {
    let description: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
            Text(String(format: "growth.corrected_age_fmt".l, description))
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(BBTheme.Colors.primary)
        .padding(.horizontal, BBTheme.Spacing.sm)
        .padding(.vertical, 6)
        .background(BBTheme.Colors.primary.opacity(0.12))
        .cornerRadius(BBTheme.Radius.sm)
    }
}

/// The line that keeps every number on this screen in its place.
struct WHOFootnote: View {
    var body: some View {
        Text("growth.who_footnote".l)
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
