import Foundation

/// The word a parent reads for one signal against its reference — four states,
/// where `FeedingAdequacy.Signal` has three. The fourth exists for weight gain
/// alone; feeding and nappy counts pass a nil band and keep their three.
///
/// `Signal` has no `.above`: `FeedingAdequacy.assess` maps a gain above the
/// reference onto `.within`, and that collapse is deliberate and must stay —
/// it is the breakdown GATE (DECISIONS 2026-08-25), which may never fire on a
/// baby gaining fast. It is the wrong vocabulary, though, and the build-11
/// review caught it: a `+10267 g/week` gain was rendered as "within the
/// reference" on the Dashboard while the Growth screen's own gain card, two
/// hundred points below, read "above the reference".
///
/// So the WORD is split from the GATE. The gate still reads `Signal` and is
/// untouched; every surface that speaks to a parent reads this instead, with
/// `WeightVelocity.Band` supplying the distinction `Signal` throws away.
enum StatusWord: Equatable {
    case below
    case within
    /// Faster than the reference. Not a concern, never styled as one — it is
    /// simply not the same statement as "within the reference".
    case above
    case notEnoughData

    /// `band` comes from `WeightVelocity.latest` over the same pair of
    /// weighings the assessment covers — `FeedingAdequacy.assess` pairs them
    /// through that exact call — and is nil when no interval is measurable.
    static func of(_ signal: FeedingAdequacy.Signal, band: WeightVelocity.Band?) -> StatusWord {
        switch signal {
        case .below:         return .below
        case .notEnoughData: return .notEnoughData
        // Only this case splits: `.within` stands for "not below", which the
        // band resolves into the two things it actually covers.
        case .within:        return band == .above ? .above : .within
        }
    }

    /// Localization key for the status word. The three original keys are
    /// unchanged, so no existing surface moves.
    var localizationKey: String {
        switch self {
        case .below:         return "nutrition.status_below"
        case .within:        return "nutrition.status_within"
        case .above:         return "nutrition.status_above"
        case .notEnoughData: return "nutrition.status_unknown"
        }
    }
}
