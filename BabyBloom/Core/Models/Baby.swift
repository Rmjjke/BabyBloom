import Foundation
import SwiftData

// MARK: - Baby Profile
@Model
final class Baby {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date = Date()
    var gender: Gender = Gender.female
    var feedingType: FeedingType = FeedingType.breast
    var photoData: Data?
    var createdAt: Date = Date()

    /// Weight at birth. The anchor for everything the first two weeks are about:
    /// a newborn physiologically loses 5–10% of it and should be back to it by
    /// day 10–14. `nil` is a permanently valid state — a parent may simply not
    /// know it, and no feature may hard-require it.
    var birthWeightKg: Double?

    /// Completed weeks of gestation at birth. `nil` means "not stated" and is
    /// treated as term. Only used to derive `correctedAgeDays`.
    var gestationalWeeks: Int?

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \FeedingEntry.baby) var feedingEntries: [FeedingEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \SleepEntry.baby) var sleepEntries: [SleepEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \DiaperEntry.baby) var diaperEntries: [DiaperEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \GrowthEntry.baby) var growthEntries: [GrowthEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \CustomEvent.baby) var customEvents: [CustomEvent]? = []

    init(name: String, birthDate: Date, gender: Gender, feedingType: FeedingType) {
        self.id = UUID()
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.feedingType = feedingType
        self.createdAt = Date()
    }

    // MARK: Computed
    var ageInDays: Int { Self.days(from: birthDate) }

    var ageInWeeks: Int { ageInDays / 7 }

    var ageInMonths: Int { Self.months(from: birthDate) }

    var ageDescription: String { Self.describeAge(from: birthDate) }

    // MARK: Corrected age (prematurity)

    /// Born before 37 completed weeks — the threshold at which growth references
    /// expect a corrected age.
    var isPreterm: Bool { (gestationalWeeks ?? Self.termWeeks) < Self.pretermThresholdWeeks }

    /// The date this baby would have been born on had the pregnancy reached term.
    ///
    /// Correcting the age *is* shifting this reference date forward, and deriving
    /// everything from it keeps days, weeks and months on one calendar code path
    /// instead of three hand-rolled ones that can disagree.
    ///
    /// Correction stops once the baby is two years old, the usual clinical
    /// convention, so beyond that this is just `birthDate`.
    var correctedBirthDate: Date {
        guard isPreterm, let weeks = gestationalWeeks, ageInDays <= Self.correctionCutoffDays else {
            return birthDate
        }
        // Guard against nonsense stored ages producing an absurd correction.
        let clamped = min(max(weeks, Self.minGestationalWeeks), Self.termWeeks)
        let offsetDays = (Self.termWeeks - clamped) * 7
        return Calendar.current.date(byAdding: .day, value: offsetDays, to: birthDate) ?? birthDate
    }

    /// Age corrected for prematurity, in days, never negative.
    ///
    /// A baby born at 32 weeks is, on its 100th day of life, developmentally
    /// closer to a 44-day-old term baby; measuring its weight against a 100-day
    /// reference would invent a problem that is not there. In the first weeks a
    /// very preterm baby corrects to 0 — that is correct, not a bug.
    ///
    /// This is the age every growth reference in `Core/Growth` expects. The one
    /// deliberate exception is newborn weight loss, which is measured from the
    /// actual birth: the physiological drop follows delivery, not term.
    var correctedAgeDays: Int { max(0, Self.days(from: correctedBirthDate)) }

    /// Corrected age in whole months, for copy that talks in months.
    var correctedAgeMonths: Int { max(0, Self.months(from: correctedBirthDate)) }

    /// Corrected age for display, or `nil` for a baby born at term — the UI
    /// should only ever show a second age when it genuinely differs from the first.
    var correctedAgeDescription: String? {
        guard isPreterm else { return nil }
        return Self.describeAge(from: correctedBirthDate)
    }

    // MARK: Age helpers

    private static let termWeeks = 40
    private static let pretermThresholdWeeks = 37
    private static let minGestationalWeeks = 22
    /// Two years, after which prematurity is no longer corrected for.
    private static let correctionCutoffDays = 730

    private static func days(from date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }

    static func months(from date: Date) -> Int {
        Calendar.current.dateComponents([.month], from: date, to: Date()).month ?? 0
    }

    static func describeAge(from date: Date) -> String {
        let days = max(0, self.days(from: date))
        if days < 7 {
            return "\(days) \(days.dayWord)"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks) \(weeks.weekWord)"
        } else {
            let months = max(0, self.months(from: date))
            return "\(months) \(months.monthWord)"
        }
    }

    enum Gender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .male: return "baby.gender.male"
            case .female: return "baby.gender.female"
            }
        }

        var icon: String {
            switch self {
            case .male: return "person.fill"
            case .female: return "person.fill"
            }
        }
    }

    enum FeedingType: String, Codable, CaseIterable {
        case breast = "breast"
        case formula = "formula"
        case mixed = "mixed"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .breast: return "baby.feeding.breast"
            case .formula: return "baby.feeding.formula"
            case .mixed: return "baby.feeding.mixed"
            }
        }

        var icon: String {
            switch self {
            case .breast: return "heart.fill"
            case .formula: return "drop.fill"
            case .mixed: return "heart.circle.fill"
            }
        }
    }
}

// MARK: - Int word forms (language-aware)
extension Int {
    var dayWord: String   { ageWord(one: "age.day.one",   few: "age.day.few",   many: "age.day.many") }
    var weekWord: String  { ageWord(one: "age.week.one",  few: "age.week.few",  many: "age.week.many") }
    var monthWord: String { ageWord(one: "age.month.one", few: "age.month.few", many: "age.month.many") }

    private func ageWord(one: String, few: String, many: String) -> String {
        switch LocalizationManager.shared.language.pluralRule {
        case .singularPlural:
            // English/Spanish: "1 day" / "21 days", "1 día" / "21 días".
            return self == 1 ? one.l : few.l
        case .slavic:
            return pluralize(one: one.l, few: few.l, many: many.l)
        }
    }

    private func pluralize(one: String, few: String, many: String) -> String {
        let n = abs(self) % 100
        let n1 = n % 10
        if n >= 11 && n <= 19 { return many }
        if n1 == 1 { return one }
        if n1 >= 2 && n1 <= 4 { return few }
        return many
    }
}
