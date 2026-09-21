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
/// The bands are not decoration: `WHOGrowthStandard.weight(atZ:ageDays:isMale:)`
/// reads the published LMS coefficients, so the 3rd, 50th and 97th centiles are
/// where the standard puts them and the parent's own point lands at its true
/// height between them. The DASHED line is the illustration — it follows the
/// baby's own centile forward, which is what a healthy course looks like and is
/// exactly what the app cannot yet know. The label beside the drawing says so.
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
    private static let sampleDays = Array(stride(from: 0, through: spanDays, by: 7))
    /// z for the 97th centile; the 3rd is its mirror.
    private static let tailZ = 1.8807936

    private var lower: [CGPoint] { curve(z: -Self.tailZ) }
    private var upper: [CGPoint] { curve(z: Self.tailZ) }
    private var median: [CGPoint] { curve(z: 0) }

    /// The baby's own z, held constant across the window — "tracking its
    /// centile", the shape the dashed line illustrates.
    private var ownZ: Double? {
        birthWeightKg.flatMap { WHOGrowthStandard.zScore(weightKg: $0, ageDays: 0, isMale: isMale) }
    }

    /// Day/weight pairs in DATA space; `place` maps them onto the canvas.
    private func curve(z: Double) -> [CGPoint] {
        Self.sampleDays.compactMap { day in
            WHOGrowthStandard.weight(atZ: z, ageDays: day, isMale: isMale)
                .map { CGPoint(x: CGFloat(day), y: $0) }
        }
    }

    /// The weight window the drawing spans: the whole corridor, plus a little
    /// air so the 3rd centile is not welded to the bottom edge. Clamped to
    /// include the baby's own point, which can sit outside the corridor.
    private var weightRange: ClosedRange<CGFloat> {
        let lows = lower.map(\.y), highs = upper.map(\.y)
        var minKg = lows.min() ?? 2, maxKg = highs.max() ?? 10
        if let z = ownZ, let own = WHOGrowthStandard.weight(atZ: z, ageDays: 0, isMale: isMale) {
            minKg = Swift.min(minKg, own)
            maxKg = Swift.max(maxKg, own)
        }
        let pad = (maxKg - minKg) * 0.08
        return (minKg - pad)...(maxKg + pad)
    }

    /// Horizontal breathing room. The one real point sits at day 0, and without
    /// this its marker is half outside the canvas — the run-and-look shots on
    /// both iPhone 17 and SE showed a clipped dot at the left edge.
    private static let inset: CGFloat = 6

    private func place(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let range = weightRange
        let spanKg = Swift.max(range.upperBound - range.lowerBound, 0.01)
        let usableWidth = Swift.max(size.width - Self.inset * 2, 1)
        return CGPoint(
            x: Self.inset + point.x / CGFloat(Self.spanDays) * usableWidth,
            // Heavier babies sit higher, so the weight axis is inverted.
            y: size.height - (point.y - range.lowerBound) / spanKg * size.height
        )
    }

    private func path(_ points: [CGPoint], in size: CGSize) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let placed = place(point, in: size)
            if index == 0 { path.move(to: placed) } else { path.addLine(to: placed) }
        }
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // The 3rd–97th band: one closed shape, the upper curve out and
                // the lower curve back.
                corridor(in: size)
                    .fill(BBTheme.Colors.growth.opacity(0.16))

                path(median, in: size)
                    .stroke(BBTheme.Colors.growth.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

                if let z = ownZ {
                    path(curve(z: z), in: size)
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(BBTheme.Colors.growth,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round,
                                                   dash: [5, 5]))

                    // The one real thing on the drawing.
                    if let own = WHOGrowthStandard.weight(atZ: z, ageDays: 0, isMale: isMale) {
                        let dot = place(CGPoint(x: 0, y: own), in: size)
                        Circle()
                            .fill(BBTheme.Colors.growth)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(BBTheme.Colors.surface, lineWidth: 2.5))
                            .position(x: dot.x, y: dot.y)
                            .opacity(drawn ? 1 : 0)
                    }
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

    private func corridor(in size: CGSize) -> Path {
        var path = path(upper, in: size)
        for point in lower.reversed() { path.addLine(to: place(point, in: size)) }
        path.closeSubpath()
        return path
    }
}
