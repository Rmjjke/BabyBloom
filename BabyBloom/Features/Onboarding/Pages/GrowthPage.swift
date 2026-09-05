import SwiftUI

// MARK: - Page 4: Measurements at birth

/// Asks for the BIRTH weight and height — the numbers on the discharge record.
/// They fill `Baby.birthWeightKg` and the first `GrowthEntry`, dated at the
/// birth, in one answer; `OnboardingBabyBuilder` explains why that is one
/// question rather than two.
///
/// **The sliders are birth-ranged, and that is a correctness matter rather than
/// polish.** They inherited a 1–20 kg / 0.1 range from the "weight today" page
/// this replaced, which cannot express 3.45 kg at all — and the newborn card's
/// one clinical threshold is a 10% loss from birth weight, so a birth weight
/// rounded by 50 g moves the flag by roughly a third of a percentage point of
/// loss. 0.5–6.0 by 0.05 matches `BabyProfileEditSheet`'s birth-weight field
/// exactly, which is the same number in the same units and must not be
/// enterable at two precisions.
///
/// Height is 30–60 by 0.5. There is no birth-height field in the profile to
/// match, so the range is this page's own call: WHO length-for-age at birth
/// runs about 44–55 cm, and 30–60 covers extreme preterm through the largest
/// term newborn with room at both ends. The old 30–130 ceiling was a
/// four-year-old's height on a page about a newborn, which makes every drag
/// coarser for no reachable value.
struct GrowthPage: View {
    @Binding var weightKg: Double
    @Binding var heightCm: Double
    @Binding var headCm: Double
    @Binding var includeHead: Bool
    /// False when the parent tapped "I don't remember". Everything the page
    /// collects is then discarded — see `OnboardingBabyBuilder`.
    @Binding var knowsMeasurements: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            backButton(action: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: BBTheme.Spacing.lg) {
                    onboardingHeroIcon("ruler.fill", color: BBTheme.Colors.growth)
                        .padding(.top, BBTheme.Spacing.md)

                    VStack(spacing: BBTheme.Spacing.sm) {
                        BBTheme.Typography.title1("onboarding.growth_title".l)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                        Text("onboarding.growth_hint".l)
                            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if knowsMeasurements {
                        BBMeasureSlider(
                            title: "form.birth_weight_kg".l,
                            value: $weightKg,
                            range: 0.5...6.0, step: 0.05,
                            display: String(format: "%.2f \("unit.kg".l)", weightKg),
                            color: BBTheme.Colors.growth,
                            minLabel: "0.5 \("unit.kg".l)",
                            maxLabel: "6 \("unit.kg".l)"
                        )

                        BBMeasureSlider(
                            title: "form.birth_height_cm".l,
                            value: $heightCm,
                            range: 30.0...60.0, step: 0.5,
                            display: String(format: "%.1f \("unit.cm".l)", heightCm),
                            color: BBTheme.Colors.primary,
                            minLabel: "30 \("unit.cm".l)",
                            maxLabel: "60 \("unit.cm".l)"
                        )

                        BBOptionalMeasureToggle(
                            title: "form.head_cm".l,
                            hint: "onboarding.growth_head_optional".l,
                            isOn: $includeHead,
                            value: $headCm,
                            range: 25.0...55.0, step: 0.5,
                            display: String(format: "%.1f \("unit.cm".l)", headCm),
                            minLabel: "25 \("unit.cm".l)",
                            maxLabel: "55 \("unit.cm".l)",
                            color: BBTheme.Colors.accent
                        )
                    } else {
                        unknownNote
                    }

                    unknownToggle

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 20)
            }
        }
    }

    /// The opt-out, and it is not a nicety.
    ///
    /// A slider cannot express "I don't know": it always holds a number, and
    /// the default is 3.5 kg, so without this every parent who cannot find the
    /// discharge record silently stores an invented birth weight — as the
    /// profile baseline the 10%-loss flag is measured against AND as the first
    /// point on the chart. The old birth-page toggle protected against exactly
    /// that; asking the question properly on this page does not remove the need
    /// for an answer of "unknown", it only makes the question worth asking.
    ///
    /// A toggle rather than a second way forward: "Next" stays the only
    /// advance on every onboarding page, which is what the walk flows and the
    /// progress bar both assume.
    private var unknownToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { knowsMeasurements.toggle() }
        } label: {
            Text(knowsMeasurements ? "onboarding.growth_unknown".l
                                   : "onboarding.growth_known".l)
                .font(BBTheme.Typography.scaled(15, relativeTo: .body,
                                                weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BBTheme.Spacing.sm)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// What the app does instead, stated plainly. A parent who chooses this
    /// should not discover later that a card they were expecting never appeared.
    private var unknownNote: some View {
        HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(BBTheme.Colors.primary)
            Text("onboarding.growth_unknown_note".l)
                .font(BBTheme.Typography.scaled(14, relativeTo: .body,
                                                weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }
}
