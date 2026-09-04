import Foundation

/// What the Dashboard's Growth section is allowed to say for free.
///
/// It is a pure function so the rule that matters can be tested without a
/// simulator: **weight gain is the only signal that reaches this line**
/// (DECISIONS 2026-08-25). `FeedingAdequacy.Assessment` also carries feeding
/// and wet-nappy signals; neither is read here, and neither may ever be —
/// a below-reference feeding count beside a gain inside the reference must
/// still produce the calm word, because the reference tables exist precisely
/// so the app can stay quiet when it should.
enum DashboardGrowthSummary {

    /// The gain half of the free line. Three states, not two: "we cannot say"
    /// is not the same statement as "not enough data yet", and neither is a
    /// verdict.
    enum Gain: Equatable {
        /// The calm word — never a number. `StatusWord`, not
        /// `FeedingAdequacy.Signal`: the signal collapses an above-reference
        /// gain into `.within` for the breakdown gate, which is right for the
        /// gate and wrong for the sentence a parent reads.
        case word(StatusWord)
        /// Inside the age the reference covers, but only one weighing so far.
        /// An invitation to weigh again, not a finding.
        case needsAnotherWeighing
        /// Past the age the gain reference covers. The section says nothing
        /// about gain at all — the Growth screen's own rule.
        case unavailable
    }

    enum Free: Equatable {
        /// Never weighed. An invitation, not an empty state and never a dash.
        case invitation
        case summary(weightKg: Double, gain: Gain)
    }

    /// - Parameters:
    ///   - latestWeightKg: newest recorded weight, nil when none exists.
    ///   - assessment: `FeedingAdequacy`'s verdict, nil when it cannot be made.
    ///   - band: `WeightVelocity.latest(...)?.band` over the same two
    ///     weighings the assessment covers. It only ever splits the WORD;
    ///     nothing about the breakdown gate is decided here.
    ///   - withinReferenceAge: `correctedAgeDays <= FeedingAdequacy.maxAgeDays`.
    static func free(latestWeightKg: Double?,
                     assessment: FeedingAdequacy.Assessment?,
                     band: WeightVelocity.Band?,
                     withinReferenceAge: Bool) -> Free {
        guard let weightKg = latestWeightKg else { return .invitation }

        let gain: Gain
        if !withinReferenceAge {
            gain = .unavailable
        } else if let assessment {
            // `.gain` and nothing else — see this type's doc comment. The band
            // is not a fourth signal: it re-reads the same weight gain.
            gain = .word(StatusWord.of(assessment.gain, band: band))
        } else {
            gain = .needsAnotherWeighing
        }
        return .summary(weightKg: weightKg, gain: gain)
    }
}
