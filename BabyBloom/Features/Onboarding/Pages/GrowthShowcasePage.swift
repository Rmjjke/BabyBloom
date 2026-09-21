import SwiftUI

// MARK: - Growth showcase (page 7 of 11)

/// The app's strongest card, shown rather than described.
///
/// One number on this page is real: the birth weight the parent typed two pages
/// ago, scored against the WHO tables by
/// `WHOGrowthStandard.percentileReading(of:correctedBirthDate:isMale:)` — the
/// same function the Growth screen calls — and rendered by `PercentileCard`,
/// the same view the Growth screen renders. Nothing here is a mock-up of the
/// product; it is the product, with the data the flow already has. The precedent
/// is `WidgetShowcasePage`, which shows the real widget view for the same reason.
///
/// Everything the app cannot know yet is drawn as a sketch and labelled as one.
/// A curve of invented weighings would be the one thing this page must not do:
/// the parent would recognise it later as a promise the app never made.
struct GrowthShowcasePage: View {
    let babyName: String
    let birthDate: Date
    let gender: Baby.Gender
    /// nil when the parent answered «не помню точно» on the measurements page.
    let birthWeightKg: Double?
    /// nil unless the parent said the baby was born early.
    let gestationalWeeks: Int?
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    private let bullets: [(icon: String, key: String, takesName: Bool)] = [
        ("chart.bar.xaxis", "onboarding.showcase.bullet1", true),
        ("scalemass.fill", "onboarding.showcase.bullet2", false),
        ("heart.text.square.fill", "onboarding.showcase.bullet3", false),
    ]

    private var name: String {
        let trimmed = babyName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "baby.default_name".l : trimmed
    }

    private var preview: OnboardingGrowthPreview.State {
        OnboardingGrowthPreview.state(
            birthWeightKg: birthWeightKg,
            birthDate: birthDate,
            gestationalWeeks: gestationalWeeks,
            isMale: gender == .male
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pinned footer, scrolling pitch — the arrangement NotificationsPage
            // and PremiumPage already use. At the app's AX2 ceiling a card, a
            // drawing and three bullets outgrow an SE-class screen, and an
            // overflowing VStack centres its children, which would push the only
            // way forward off a page that has no back button.
            ScrollView(showsIndicators: false) {
                VStack(spacing: BBTheme.Spacing.lg) {
                    BBTheme.Typography.title3(String(format: "onboarding.showcase.title".l, name))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(appear ? 1 : 0)

                    liveCard
                        .scaleEffect(appear ? 1 : 0.96)
                        .opacity(appear ? 1 : 0)

                    sketch
                        .offset(y: appear ? 0 : 20)
                        .opacity(appear ? 1 : 0)

                    bulletList
                        .offset(y: appear ? 0 : 30)
                        .opacity(appear ? 1 : 0)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.vertical, BBTheme.Spacing.xl)
                .frame(maxWidth: .infinity)
            }

            BBPrimaryButton("button.next".l, icon: "arrow.right", action: onContinue)
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 36)
                .opacity(appear ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { appear = true; return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appear = true }
        }
    }

    // MARK: - The one real card

    @ViewBuilder
    private var liveCard: some View {
        switch preview {
        case let .reading(reading, birthWeightKg):
            // `tone: .neutralOnly` — see `PercentileCard.Tone`. The band label
            // still names the tail in full; only the alarm colour is withheld.
            PercentileCard(
                percentile: reading.percentile,
                badge: reading.badge,
                captionLines: [
                    String(format: "onboarding.showcase.caption_fmt".l, name,
                           String(format: "%.2f %@", birthWeightKg, "unit.kg".l)),
                ],
                tone: .neutralOnly
            )
        case .invitation:
            invitationCard
        }
    }

    /// Same chrome as the card it stands in for, and deliberately not an empty
    /// state: a parent who answered «не помню точно» two pages ago did nothing
    /// wrong, and the sketch below still shows what the screen is for.
    private var invitationCard: some View {
        InsightCard(title: "section.who_percentiles".l) {
            HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(BBTheme.Colors.growth)
                Text(String(format: "onboarding.showcase.invite".l, name))
                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - The sketch

    private var sketch: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            GrowthCorridorSketch(
                isMale: gender == .male,
                birthWeightKg: {
                    if case let .reading(_, kg) = preview { return kg }
                    return nil
                }()
            )
            .frame(height: 150)

            // The same legend, in the same words, as the real chart's — so the
            // band the parent meets here is recognisably the band they will
            // find on the Growth screen.
            WHOCorridorLegend()

            // The label is not a caption, it is the honesty: the corridor is
            // real WHO data, the baby's forward line is not, and the parent has
            // to be told which is which before they read anything into it.
            Text("onboarding.showcase.sketch_label".l)
                .font(BBTheme.Typography.scaled(12, relativeTo: .caption1, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    // MARK: - What the screen does

    /// Three capabilities that exist TODAY — percentiles, the gain verdict, the
    /// newborn window — and no fourth one the app would have to grow into.
    private var bulletList: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            ForEach(bullets, id: \.key) { bullet in
                HStack(alignment: .top, spacing: BBTheme.Spacing.md) {
                    Image(systemName: bullet.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.growth)
                        .frame(width: 32, height: 32)
                        .background(BBTheme.Colors.growth.opacity(0.18), in: Circle())
                    Text(bullet.takesName ? String(format: bullet.key.l, name) : bullet.key.l)
                        .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(BBTheme.Spacing.lg)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }
}

// MARK: - Corridor drawing

/// The WHO weight-for-age corridor over the first six months, the baby's real
/// birth point on it, and a dashed line forward.
///
/// The band is not decoration and it is not this view's invention: it comes
/// from `WHOCorridor`, the sampler the Growth screen's own weight chart draws,
/// with the same fill, the same median stroke and the same legend underneath.
/// That parity is the point — this page promises the parent a chart, and the
/// chart it promises now exists (DECISIONS 2026-09-21).
///
/// What remains illustrative is the DASHED line, which follows the baby's own
/// centile forward: a plausible healthy course, and exactly the thing the app
/// cannot yet know. The label beside the drawing says so.
///
/// Plain `Path`s rather than Charts: three curves and a dot do not need a chart
/// engine, and this must stay legible at 150pt with no axes to read.
private struct GrowthCorridorSketch: View {
    let isMale: Bool
    /// The real birth weight, placed at day 0. Absent for «не помню точно» and
    /// for a preterm baby with no honest percentile — the corridor then stands
    /// on its own, which is the point of still drawing it.
    let birthWeightKg: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    /// Half a year. Long enough for the corridor to open up visibly, short
    /// enough that the first weeks — the part a newborn's parent is living in —
    /// are not squeezed into the left margin.
    private static let spanDays = 182
    /// Horizontal breathing room. The one real point sits at day 0, and without
    /// this its marker is half outside the canvas — the run-and-look shots on
    /// both iPhone 17 and SE showed a clipped dot at the left edge.
    private static let inset: CGFloat = 6

    /// Everything the drawing needs, resolved ONCE. These were computed
    /// properties read from inside `place`, which made the whole drawing
    /// quadratic in the sample count.
    private struct Geometry {
        let samples: [WHOCorridor.Sample]
        let weightRange: ClosedRange<Double>
        /// The baby's own centile, held constant across the window — "tracking
        /// its centile", the shape the dashed line illustrates. nil when there
        /// is no birth weight to track.
        let ownCurve: [(ageDays: Int, kg: Double)]?
    }

    private var geometry: Geometry {
        let samples = WHOCorridor.samples(fromAgeDays: 0, toAgeDays: Self.spanDays,
                                          isMale: isMale, maxSamples: 27)
        var minKg = samples.map(\.low).min() ?? 2
        var maxKg = samples.map(\.high).max() ?? 10

        var ownCurve: [(ageDays: Int, kg: Double)]?
        if let birthWeightKg {
            // The dot's own weight is used as given — it is already on this
            // axis, and pushing it through z and back would only add rounding.
            minKg = Swift.min(minKg, birthWeightKg)
            maxKg = Swift.max(maxKg, birthWeightKg)
            if let z = WHOGrowthStandard.zScore(weightKg: birthWeightKg, ageDays: 0, isMale: isMale) {
                ownCurve = samples.compactMap { sample in
                    WHOGrowthStandard.weight(atZ: z, ageDays: sample.ageDays, isMale: isMale)
                        .map { (sample.ageDays, $0) }
                }
            }
        }

        let pad = (maxKg - minKg) * 0.08
        return Geometry(samples: samples,
                        weightRange: (minKg - pad)...(maxKg + pad),
                        ownCurve: ownCurve)
    }

    private func place(ageDays: Int, kg: Double, in geometry: Geometry, size: CGSize) -> CGPoint {
        let spanKg = Swift.max(geometry.weightRange.upperBound - geometry.weightRange.lowerBound, 0.01)
        let usableWidth = Swift.max(size.width - Self.inset * 2, 1)
        return CGPoint(
            x: Self.inset + CGFloat(ageDays) / CGFloat(Self.spanDays) * usableWidth,
            // Heavier babies sit higher, so the weight axis is inverted.
            y: size.height - CGFloat((kg - geometry.weightRange.lowerBound) / spanKg) * size.height
        )
    }

    private func path(_ values: [(ageDays: Int, kg: Double)],
                      in geometry: Geometry, size: CGSize) -> Path {
        var path = Path()
        for (index, value) in values.enumerated() {
            let point = place(ageDays: value.ageDays, kg: value.kg, in: geometry, size: size)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let geometry = geometry
            ZStack {
                // The 3rd–97th band: one closed shape, the upper curve out and
                // the lower curve back.
                corridor(geometry, size: size)
                    .fill(BBTheme.Colors.growth.opacity(0.16))

                path(geometry.samples.map { ($0.ageDays, $0.mid) }, in: geometry, size: size)
                    .stroke(BBTheme.Colors.growth.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                if let ownCurve = geometry.ownCurve, let birthWeightKg {
                    path(ownCurve, in: geometry, size: size)
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(BBTheme.Colors.growth,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round,
                                                   dash: [5, 5]))

                    // The one real thing on the drawing, at the weight the
                    // parent actually typed.
                    let dot = place(ageDays: 0, kg: birthWeightKg, in: geometry, size: size)
                    Circle()
                        .fill(BBTheme.Colors.growth)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(BBTheme.Colors.surface, lineWidth: 2.5))
                        .position(x: dot.x, y: dot.y)
                        .opacity(drawn ? 1 : 0)
                }
            }
        }
        // Decoration: the sentence beside it carries the meaning, and a
        // VoiceOver reader has nothing to gain from a path description.
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { drawn = true; return }
            withAnimation(.easeOut(duration: 1.1).delay(0.35)) { drawn = true }
        }
    }

    private func corridor(_ geometry: Geometry, size: CGSize) -> Path {
        var path = path(geometry.samples.map { ($0.ageDays, $0.high) }, in: geometry, size: size)
        for sample in geometry.samples.reversed() {
            path.addLine(to: place(ageDays: sample.ageDays, kg: sample.low,
                                   in: geometry, size: size))
        }
        path.closeSubpath()
        return path
    }
}
