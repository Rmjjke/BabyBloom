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
        InsightCard(title: "breakdown.title".l) {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                if let line = gainLine {
                    Text(line)
                }
                if let line = feedsLine {
                    Text(line)
                }
                if let line = nappiesLine {
                    Text(line)
                }
                if feedsLine == nil && nappiesLine == nil {
                    Text("breakdown.no_data".l)
                }
                Text("breakdown.disclaimer".l)
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .padding(.top, 2)
            }
            .font(BBTheme.Typography.scaled(14, relativeTo: .body,
                                            weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
        }
    }

    private var gainLine: String? {
        guard let reading, let expected = reading.expectedPerWeek else { return nil }
        return String(format: "breakdown.gain_fmt".l,
                      Int(reading.gramsPerWeek.rounded()),
                      assessment.windowDays,
                      assessment.windowDays.dayWord,
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
        // Measured value as a string, bounds as whole numbers — the same
        // split velocity.per_week_fmt / velocity.expected_fmt already use.
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
