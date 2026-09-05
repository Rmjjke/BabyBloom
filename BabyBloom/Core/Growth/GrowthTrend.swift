import Foundation

/// Whether the baby is sliding down the chart, as opposed to sitting low on it.
///
/// A single percentile is a snapshot and a poor alarm: a baby can sit at the 9th
/// centile for a year in perfect health, while a baby falling from the 75th to
/// the 25th over two months is the one worth a look. What matters clinically is
/// sustained movement *across* centile spaces.
///
/// The CLINICAL question is downward-only, and stays that way: a fast climb is
/// not a faltering-growth concern and raises no flag. It is still reported,
/// because the alternative was to call it stability — see `crossingUp`.
///
/// Thresholds follow NICE faltering-growth guidance, which scales the trigger by
/// where the baby started: a fall of one centile space matters for a baby born
/// below the 9th centile, two for a baby born between the 9th and 91st, three
/// for a baby born above the 91st.
///
/// Ages take the **corrected** age for a baby born preterm.
enum GrowthTrend {

    /// One centile space on the standard chart lines (0.4th, 2nd, 9th, 25th,
    /// 50th, 75th, 91st, 98th, 99.6th) is two thirds of a standard deviation.
    /// Working in z rather than in percentile points keeps the spacing uniform —
    /// percentile points are compressed in the tails and would understate a fall
    /// exactly where it matters most.
    static let zPerCentileSpace = 2.0 / 3.0

    /// Enough history to tell a trend from a wobble.
    static let minimumMeasurements = 3
    static let minimumSpanDays = 28

    /// How far back the comparison's REFERENCES may reach, in days. It bounds
    /// the peak and the starting point — never the evidence gates, which read
    /// the whole history.
    ///
    /// Unbounded, the peak is the all-time maximum, and an ordinary regression
    /// to the mean becomes a PERMANENT flag: a baby that touched the 91st
    /// centile at two months and settled on the 50th by eighteen is measured
    /// against a peak a year in the past, and nothing it does afterwards can
    /// lower that peak or clear the drop. Six months is long enough to contain
    /// the fall NICE describes — weeks to months — and short enough that the
    /// comparison is still about where this baby is heading now.
    ///
    /// **Nothing reaches past this bound to find a reference.** That is what
    /// makes the paragraph above true: every reference sits inside the window
    /// or among the two newest readings, so the next weighing always displaces
    /// it, where an all-time peak never could be. The one deliberate exception
    /// is `referenceWindowStart`'s two-most-recent floor, whose pair is only
    /// reached when everything else is already outside the bound.
    ///
    /// Two costs, both deliberate, both narrower than "a fall beyond 180 days
    /// is invisible":
    ///
    /// - A fall spread over three or more weighings, each step small enough
    ///   that no eligible peak sits a full `thresholdSpaces` above the latest
    ///   reading, is never reported however far it travels in total. A fall
    ///   between two readings 200 days apart IS reported, because the floor
    ///   keeps that pair.
    /// - A parent whose only recent weighings are days apart gets
    ///   `insufficientData` until they span four weeks, rather than a verdict
    ///   measured against something older than the bound.
    ///
    /// Both shapes are outside NICE's scope, whose thresholds describe a fall
    /// over weeks to months, and catching either would mean reinstating the
    /// permanent flag this bound exists to remove. The number is a judgement
    /// rather than a published threshold; the owner may retune it.
    static let peakLookbackDays = 180

    /// A rise past this many centile spaces is named as a crossing rather than
    /// reported as stability.
    ///
    /// A flat two, deliberately not `thresholdSpaces`: the NICE scaling exists
    /// because a baby born small has less room to fall before it matters, and
    /// that argument has no upward counterpart. Two spaces is the middle rule,
    /// and the same distance a fall needs for a baby born mid-chart.
    static let upwardCrossingSpaces: Double = 2

    enum Assessment: Equatable {
        /// Fewer than three weighings, or less than four weeks of history.
        case insufficientData
        /// Neither a fall nor a rise past the threshold — the excursion is
        /// bounded in both directions, which is what makes the card's green
        /// tick a statement rather than a default.
        case stable
        /// Sustained fall, in centile spaces, past the threshold for this baby.
        case sustainedDrop(spaces: Double)
        /// Sustained rise past `upwardCrossingSpaces`. Not a concern and never
        /// styled as one; it exists because "holding its channel" is untrue of
        /// a baby climbing from the 50th to the 99th centile.
        case crossingUp(spaces: Double)
    }

    /// How many centile spaces of fall are meaningful for a baby that started at
    /// this birth percentile. Unknown birth weight — and any preterm baby, whose
    /// birth percentile cannot be read off a term chart — takes the middle rule.
    static func thresholdSpaces(birthPercentile: Double?) -> Double {
        guard let p = birthPercentile else { return 2 }
        if p < 9 { return 1 }
        if p > 91 { return 3 }
        return 2
    }

    /// Assesses the weight history. `birthPercentile` may be nil.
    static func assess(
        measurements: [WeightMeasurement],
        correctedBirthDate: Date,
        isMale: Bool,
        birthPercentile: Double?
    ) -> Assessment {
        // Every weighing the WHO tables can actually score, each keeping its own
        // date. The gates below are then evaluated on THIS array rather than on
        // the raw input: they ask whether there is enough evidence, and a
        // weighing the tables cannot score is not evidence. The old order gave
        // the right answer by accident, because the tables happen to cover the
        // whole age range the rest of the screen admits.
        let scored: [(date: Date, z: Double)] = measurements
            .sorted { $0.date < $1.date }
            .compactMap { m in
                let age = WHOGrowthStandard.correctedAgeDays(on: m.date,
                                                             correctedBirthDate: correctedBirthDate)
                guard let z = WHOGrowthStandard.zScore(weightKg: m.weightKg,
                                                       ageDays: age, isMale: isMale) else { return nil }
                return (m.date, z)
            }

        // EVIDENCE gates, on the whole scorable history. Whether this parent has
        // weighed enough to be told anything is a question about their whole
        // record, and it does not expire: a toddler weighed at 12, 15, 18 and 24
        // months has years of evidence and never two points inside six months.
        // Gating on the recent window instead left that child's card reading
        // "not enough data" permanently.
        guard scored.count >= minimumMeasurements,
              let oldest = scored.first,
              let newest = scored.last,
              days(from: oldest.date, to: newest.date) >= minimumSpanDays
        else { return .insufficientData }

        // REFERENCES, bounded to the recent window — see `peakLookbackDays`.
        // The gates decide whether to speak; this decides what the comparison is
        // measured against, and only the recent past can say where a baby is
        // heading now.
        let windowStart = referenceWindowStart(scored, newest: newest)

        // The comparison itself has to describe four weeks, and NOTHING widens
        // the window past the lookback to reach that. If the readings inside
        // the lookback cannot span it — a parent whose only recent weighings
        // are three days apart — the honest answer is that nothing can be said
        // yet, the same answer the evidence gates give. Reaching further back
        // for a span instead would resurrect the ancient peak: a tight cluster
        // today could pull in a reading a year old, flag a drop against it, and
        // keep flagging until the cluster itself grew four weeks wide.
        guard days(from: scored[windowStart].date, to: newest.date) >= minimumSpanDays else {
            return .insufficientData
        }

        // Non-optional by construction: `referenceWindowStart` always leaves at
        // least two readings. `peak` seeds its search with `start` because
        // `start` IS the first of the readings it searches — a seed, not a
        // fallback for a case that cannot happen.
        let scores = scored[windowStart...].map(\.z)
        let latest = newest.z
        let start = scores[0]
        let peak = scores.dropLast().reduce(start) { Swift.max($0, $1) }

        // FALL first, and unguarded. Both directions are now pure arithmetic
        // against the window's own extremes, with no "the latest reading must
        // be the extreme" test on either side.
        //
        // The guard that used to sit here (`latest <= scores.min()`) was the
        // last way one wobbly weighing bought back the green tick: a baby that
        // fell from the median to three SD below and then came back thirty
        // grams was no longer the lowest of its series, so the card said it was
        // holding its channel while it sat four centile spaces under its own
        // peak. It was never load-bearing for the case it was written for — a
        // fully recovered dip computes `peak - latest ≈ 0` on its own — and a
        // half-recovered one is a fall that deserves saying so.
        //
        // The property that makes dropping it sound: `peak` is the maximum of
        // the readings BEFORE the latest, so a baby at a new high always has a
        // non-positive drop and can never be flagged.
        let drop = (peak - latest) / zPerCentileSpace
        if drop >= thresholdSpaces(birthPercentile: birthPercentile) {
            return .sustainedDrop(spaces: drop)
        }

        // The rise, and the reason `.stable` can be trusted at all: this
        // detector used to return `.stable` for ANY non-fall, so a climb from
        // the 50th centile to the 99th was reported as "holding its channel"
        // with a green tick (build-11 review).
        //
        // Measured from where the baby STARTED in this window, not from its
        // lowest reading: a dip that has climbed back to its opening centile
        // has crossed nothing, and measuring from the trough would announce a
        // recovery as a rocket. The fall's peak-based rule is NICE's, about
        // position lost from the best the baby ever held, and does not transfer
        // to a direction nobody is worried about.
        //
        // Checked second, so a series that is both a fall from its peak and a
        // rise from its start reports the fall. That is the clinical signal;
        // the crossing is context.
        let rise = (latest - start) / zPerCentileSpace
        if rise >= upwardCrossingSpaces {
            return .crossingUp(spaces: rise)
        }
        return .stable
    }

    /// Where the window a verdict may be measured against begins.
    ///
    /// Two rules, and deliberately no third:
    ///
    /// 1. **Everything inside the lookback** — the bound itself, which is what
    ///    keeps an ancient peak out of the comparison.
    /// 2. **Never fewer than the two most recent weighings**, however far apart.
    ///    A comparison needs two, and a plain cutoff drops one of them the
    ///    moment a parent weighs twice more than six months apart — a toddler
    ///    seen at 18 and 24 months is 182 days, two over the bound, and the card
    ///    went dead. This cannot bring back the flag the bound exists to remove:
    ///    the reference then sits among the two newest readings and the next
    ///    weighing displaces it, where an all-time peak never could be.
    ///
    /// The rule that is NOT here: widening backwards to reach
    /// `minimumSpanDays`. It looked like the obvious way to stop a verdict being
    /// computed over a two-day pair, and it reopened exactly the hole the
    /// lookback closes — three weighings around the 97th centile at two to three
    /// months, then two at the median at thirteen, and the window walked back
    /// 312 days for a peak and flagged a drop that no weighing could clear for
    /// another four weeks. The span floor lives at the call site instead, where
    /// failing it means `insufficientData` rather than a longer reach.
    private static func referenceWindowStart(
        _ scored: [(date: Date, z: Double)],
        newest: (date: Date, z: Double)
    ) -> Int {
        let cutoff = newest.date.addingTimeInterval(-Double(peakLookbackDays) * 86_400)
        var first = scored.count - 1
        while first > 0, scored[first - 1].date >= cutoff {
            first -= 1
        }
        // Rule 2. `scored` holds at least three readings by the time this runs,
        // so this index is always a valid start with a reading after it.
        return Swift.min(first, scored.count - 2)
    }

    private static func days(from: Date, to: Date) -> Int {
        Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
