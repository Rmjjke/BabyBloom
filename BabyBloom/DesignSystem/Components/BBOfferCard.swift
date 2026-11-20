import SwiftUI

/// The calm Premium card on Home: the parent's own first days as bars, the
/// baby's point on the WHO band, or a few of their own numbers, one line on
/// what Premium adds, and a close control.
///
/// The whole card except × is one tap target. × sits outside the card's
/// button, so a tap on it can never open the paywall. No entrance of its own:
/// whether it shows is decided when Home appears, and its exits belong to the
/// caller, which knows why it leaves.
struct BBOfferCard: View {
    let model: OfferCardModel
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) { content }
                .buttonStyle(BBScaleButtonStyle())
                // Two elements in place of one button, in reading order: what
                // the card shows as plain text, then the action.
                .accessibilityRepresentation {
                    VStack(alignment: .leading) {
                        Text(model.accessibilityLabel)
                            .accessibilitySortPriority(3)
                        Button("offer.cta".l, action: onOpen)
                            .accessibilityHint("premium.opens_a11y_hint".l)
                            .accessibilityIdentifier("offer.card.action")
                            .accessibilitySortPriority(2)
                    }
                }
            closeButton
                .padding(.top, BBTheme.Spacing.md - 8)
                .padding(.trailing, BBTheme.Spacing.md - 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("offer.card")
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            // The title's room leaves × its 44 pt and a gap.
            BBSteppedText(model.title)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 44 + BBTheme.Spacing.sm)

            visualAndStats

            Text(model.body)
                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            actionRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard(radius: BBTheme.Radius.lg)
        .contentShape(RoundedRectangle(cornerRadius: BBTheme.Radius.lg))
    }

    /// The stats sit `sm` under a visual, tighter than the card's own rhythm.
    @ViewBuilder
    private var visualAndStats: some View {
        let hasVisual = model.visual != .none
        if hasVisual || !model.stats.isEmpty {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                visual
                if !model.stats.isEmpty { stats }
            }
        }
    }

    @ViewBuilder
    private var visual: some View {
        switch model.visual {
        case .none:
            EmptyView()
        case .bars(let values):
            OfferDaysBars(values: values)
                .frame(height: 56)
                .accessibilityHidden(true)
        case .curve(let curve):
            OfferMiniCurve(curve: curve)
                .frame(height: 72)
                .accessibilityHidden(true)
        case .thin:
            Text("offer.thin_data".l)
                .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One line joined by " · " while it fits, else one stat per line. The
    /// month report is always one per line: its two averages read as a list.
    @ViewBuilder
    private var stats: some View {
        if model.content == .monthReport {
            statsStacked
        } else {
            ViewThatFits(in: .horizontal) {
                statText(model.stats.joined(separator: " · "))
                    .lineLimit(1)
                statsStacked
            }
        }
    }

    private var statsStacked: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
            ForEach(model.stats, id: \.self) { stat in
                statText(stat).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statText(_ text: String) -> Text {
        Text(text)
            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium))
            .foregroundStyle(BBTheme.Colors.textPrimary)
    }

    /// No lock glyph and no price: the line names what opens, not its cost.
    private var actionRow: some View {
        (Text("offer.cta".l)
            + Text("\u{2004}")
            + Text(Image(systemName: "chevron.right"))
                .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .semibold)))
            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold))
            .foregroundStyle(BBTheme.Colors.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44, alignment: .leading)
    }

    // MARK: Close

    /// Present from the first frame. It floats over the card's corner, 8 pt
    /// into the padding, so the title, not the 44 pt box, sets the row's
    /// height.
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(BBTheme.Colors.background))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("offer.close_a11y".l)
        .accessibilityIdentifier("offer.card.close")
        .accessibilitySortPriority(1)
    }
}

// MARK: - Days bars

/// One bar per calendar day, oldest first, scaled to the busiest day. No
/// axis, labels, grid or grow-in: the bars are a picture of the parent's
/// days, not a reading.
private struct OfferDaysBars: View {
    let values: [Int]

    var body: some View {
        Canvas { context, size in
            let count = values.count
            guard count > 0 else { return }
            let gap: CGFloat = 6
            let width = min(24, (size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            let top = CGFloat(max(values.max() ?? 0, 1))
            for (day, value) in values.enumerated() {
                // A day without records keeps a 2 pt stub, so the gap reads
                // as a day, not as a missing bar.
                let height = value > 0 ? max(2, size.height * CGFloat(value) / top) : 2
                let rect = CGRect(x: CGFloat(day) * (width + gap), y: size.height - height,
                                  width: width, height: height)
                let radius = min(4, width / 2, height / 2)
                context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(BBTheme.Colors.primary))
            }
        }
    }
}

// MARK: - Mini WHO curve

/// The WHO weight band (3rd–97th) with its median and the baby's weighings,
/// birth to two weeks past the newest. No axis, percentile or alert colour:
/// the dots carry the point, the band is context.
private struct OfferMiniCurve: View {
    let curve: OfferCardModel.Curve

    var body: some View {
        Canvas { context, size in
            let band = curve.band
            guard band.count >= 2 else { return }
            // The newest dot with its ring is 12 pt: inset so it is never cut.
            let inset: CGFloat = 6
            let plot = CGRect(x: inset, y: inset, width: size.width - 2 * inset, height: size.height - 2 * inset)
            let weights = band.flatMap { [$0.low, $0.high] } + curve.points.map(\.kg)
            let low = weights.min() ?? 0
            let high = max(weights.max() ?? 1, low + 0.1)
            let domain = curve.ageDomain
            let span = max(domain.upperBound - domain.lowerBound, 1)
            let point = { (age: Double, kg: Double) -> CGPoint in
                CGPoint(x: plot.minX + plot.width * (age - domain.lowerBound) / span,
                        y: plot.maxY - plot.height * (kg - low) / (high - low))
            }

            var area = Path()
            area.move(to: point(Double(band[0].ageDays), band[0].high))
            for sample in band.dropFirst() { area.addLine(to: point(Double(sample.ageDays), sample.high)) }
            for sample in band.reversed() { area.addLine(to: point(Double(sample.ageDays), sample.low)) }
            area.closeSubpath()
            context.fill(area, with: .color(BBTheme.Colors.primary.opacity(0.08)))

            var median = Path()
            median.move(to: point(Double(band[0].ageDays), band[0].mid))
            for sample in band.dropFirst() { median.addLine(to: point(Double(sample.ageDays), sample.mid)) }
            context.stroke(median, with: .color(BBTheme.Colors.primary.opacity(0.5)), lineWidth: 1.5)

            for (index, weighing) in curve.points.enumerated() {
                let center = point(weighing.ageDays, weighing.kg)
                if index == curve.points.count - 1 {
                    context.fill(circle(center, 12), with: .color(BBTheme.Colors.surface))
                    context.fill(circle(center, 8), with: .color(BBTheme.Colors.primary))
                } else {
                    context.fill(circle(center, 6), with: .color(BBTheme.Colors.primary))
                }
            }
        }
    }

    private func circle(_ center: CGPoint, _ diameter: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2,
                               width: diameter, height: diameter))
    }
}
