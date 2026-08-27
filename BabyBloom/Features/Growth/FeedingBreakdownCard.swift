import SwiftUI

/// The Premium half: what the same window's feeds and nappies looked like when
/// gain came in below the reference.
///
/// It STATES and COMPARES. It never instructs — "feeds: 5 a day, reference
/// 8–12" is information a parent can take to a clinician; "feed more often" is
/// a medical instruction and is out of bounds for this app.
struct FeedingBreakdownCard: View {
    let assessment: FeedingAdequacy.Assessment
    let reading: WeightVelocity.Reading?

    var body: some View {
        // Bound once, not re-read per branch: each line runs `String(format:)`
        // and `.appRate` builds a fresh NumberFormatter, and `feedsLine` and
        // `nappiesLine` are each consulted twice — once to render, once for the
        // no-data fallback.
        let gain = gainLine
        let feeds = feedsLine
        let nappies = nappiesLine

        InsightCard(title: "breakdown.title".l) {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                if let gain {
                    line(gain)
                }
                if let feeds {
                    line(feeds)
                }
                if let nappies {
                    line(nappies)
                }
                if feeds == nil && nappies == nil {
                    line("breakdown.no_data".l)
                }
                line("breakdown.disclaimer".l)
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .padding(.top, 2)
            }
            .font(BBTheme.Typography.scaled(14, relativeTo: .body,
                                            weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
        }
    }

    /// Every line here is a full sentence that wraps, so each one needs its
    /// ideal height — the same `fixedSize` every sibling card on this screen
    /// carries. `breakdown.disclaimer` is the longest string on the screen, and
    /// longer still in ru and es.
    private func line(_ text: String) -> some View {
        Text(text)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The interval comes from `reading`, NOT from `assessment.windowDays`.
    /// Both describe the same two weighings and both are now the same whole-day
    /// `Calendar.current.dateComponents([.day], from:to:)` count, so the two
    /// agree by construction — including across a DST transition, which is what
    /// they used to disagree over. `reading` is still the right source here:
    /// the rate in this sentence is divided by `reading.intervalDays`, and
    /// `WeightGainCard` sits directly above printing that same value, so the
    /// number and its divisor stay one thing rather than two that happen to
    /// match.
    private var gainLine: String? {
        guard let reading, let expected = reading.expectedPerWeek else { return nil }
        return String(format: "breakdown.gain_fmt".l,
                      Int(reading.gramsPerWeek.rounded()),
                      reading.intervalDays,
                      reading.intervalDays.dayWord,
                      Int(expected.lowerBound.rounded()),
                      Int(expected.upperBound.rounded()))
    }

    private var feedsLine: String? {
        // BOTH guards, though `feedingsPerDay` alone is currently sufficient:
        // with nothing logged the reference is the widest `.mixed` union and
        // narrows the moment one feed is logged, so it must never be shown
        // beside a `notEnoughData` signal.
        guard let perDay = assessment.feedingsPerDay,
              let reference = assessment.feedingReference else { return nil }
        // A measured value goes in as a formatted string and its bounds as
        // whole numbers. `velocity.expected_fmt` takes its bounds the same way;
        // `velocity.per_week_fmt` also takes `%@`, but the string it gets is a
        // SIGNED integer from `WeightGainCard.formatted(_:)`, not an `.appRate`
        // decimal — analogous in shape, a different mechanism.
        return String(format: "breakdown.feeds_fmt".l,
                      perDay.appRate,
                      Int(reference.lowerBound.rounded()),
                      Int(reference.upperBound.rounded()))
    }

    private var nappiesLine: String? {
        guard let perDay = assessment.wetNappiesPerDay,
              let minimum = assessment.wetNappyMinimum else { return nil }
        return String(format: "breakdown.nappies_fmt".l,
                      perDay.appRate, Int(minimum.rounded()))
    }
}
