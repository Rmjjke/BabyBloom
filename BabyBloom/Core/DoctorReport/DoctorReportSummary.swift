import Foundation

/// Everything the pediatrician report's data cards show, for one period
/// `[periodStart, now)`. Pure: plain values in (see `Input`), numbers and dates
/// out; the views format them. Every rule of requirements.md R2–R5 lives here
/// and is pinned by `DoctorReportSummaryTests`.
///
/// It builds on `PeriodSummary`, but feeds it the REPORT's input: running
/// timers are left out and a sleep that began before the period counts by its
/// part inside — the weekly card decides both the other way (plan v2
/// decision 6, DECISION m2-report-screen 1).
struct DoctorReportSummary: Equatable {

    // MARK: Input (no SwiftData)

    struct Input {
        struct Feed: Equatable {
            var start: Date
            /// nil = running: never counted.
            var end: Date?
            var type: FeedingEntry.FeedingType
            var volumeML: Double?
        }
        struct Sleep: Equatable {
            var start: Date
            /// nil = running: never counted.
            var end: Date?
        }
        struct Diaper: Equatable {
            var time: Date
            var type: DiaperEntry.DiaperType
            var color: DiaperEntry.StoolColor?
        }
        struct Growth: Equatable {
            var date: Date
            var weightKg: Double?
            var heightCm: Double?
            var headCm: Double?
        }

        var feeds: [Feed] = []
        var sleeps: [Sleep] = []
        var diapers: [Diaper] = []
        var growth: [Growth] = []
        var birthDate: Date
        var correctedBirthDate: Date
        var birthWeightKg: Double?
        var isMale: Bool
    }

    // MARK: Output

    struct Measure: Equatable {
        let value: Double
        let date: Date
    }

    /// What a percentile row shows.
    enum PercentileRow: Equatable {
        /// Number only; `PercentileReading.badge` gives «> 97» / «< 3» past the edge.
        case reading(WHOGrowthStandard.PercentileReading)
        /// Measured before the corrected birth date: `percentile.before_due_date`.
        case beforeDueDate
        /// Older than 24 months at the measurement: `percentile.out_of_range`.
        case outOfRange
        /// No measurement: no row.
        case none
    }

    struct Weighing: Equatable {
        let date: Date
        let weightKg: Double
        /// A height logged on the same day, if any.
        let heightCm: Double?
        /// A head circumference logged on the same day, if any (the PDF's column).
        var headCm: Double? = nil
    }

    struct Growth: Equatable {
        /// The latest weighing at or before now, of ANY date (R4.1).
        let latestWeight: Measure?
        let weightPercentile: PercentileRow
        let latestHeight: Measure?
        let heightPercentile: PercentileRow
        let latestHead: Measure?
        /// «Since <baseDate>: ±grams» (R4.5); nil when hidden.
        let change: (baseDate: Date, grams: Int)?
        /// The period's weighings, newest first (R4.6). The view shows 6, then «Show all N».
        let weighings: [Weighing]
        let atBirthWeightKg: Double?
        let atBirthHeightCm: Double?

        static func == (a: Growth, b: Growth) -> Bool {
            a.latestWeight == b.latestWeight && a.weightPercentile == b.weightPercentile
                && a.latestHeight == b.latestHeight && a.heightPercentile == b.heightPercentile
                && a.latestHead == b.latestHead && a.change?.baseDate == b.change?.baseDate
                && a.change?.grams == b.change?.grams && a.weighings == b.weighings
                && a.atBirthWeightKg == b.atBirthWeightKg && a.atBirthHeightCm == b.atBirthHeightCm
        }

        /// No weighing ever: the card shows `report.empty_growth` + «Add a weighing».
        var isEmpty: Bool { latestWeight == nil && latestHeight == nil && latestHead == nil }
    }

    /// «Days with entries: N of M» — shown only when `withEntries < counted` (R3.2).
    struct Days: Equatable {
        let withEntries: Int
        /// Full days since the period start, plus today only if today has an entry of this kind.
        let counted: Int
        var showsLine: Bool { withEntries < counted }
    }

    struct Feeding: Equatable {
        let totalFeeds: Int
        /// nil in a short period (R3.3) — the view prints `report.feeds_count_fmt` then.
        let feedsPerDay: Double?
        /// Only when more than one type was logged (R5.1); most frequent first.
        let byType: [TypeCount]
        /// Formula + expressed ml a day, over days with a bottle that has a volume.
        let bottleMLPerDay: Double?
        /// Median length of finished breastfeeds (design review, 2026-11-02): one
        /// forgotten 3-hour timer moved a mean by minutes; the typical feed is
        /// what the doctor asks about. An even count takes the mean of the two
        /// middle lengths.
        let breastfeedMedian: TimeInterval?
        let days: Days

        struct TypeCount: Equatable {
            let type: FeedingEntry.FeedingType
            let count: Int
        }
    }

    struct Sleep: Equatable {
        let total: TimeInterval
        /// nil in a short period — the view prints `report.sleep_total_fmt`.
        let perDay: TimeInterval?
        let longest: TimeInterval?
        let longestStart: Date?
        let days: Days
    }

    struct Diapers: Equatable {
        /// `both` counts in wet AND dirty (R5.3).
        let wetCount: Int
        let dirtyCount: Int
        /// nil in a short period — the view prints the counts.
        let wetPerDay: Double?
        let dirtyPerDay: Double?
        /// Most frequent first; empty when no colour was logged.
        let colors: [ColorCount]
        let days: Days

        struct ColorCount: Equatable {
            let color: DiaperEntry.StoolColor
            let count: Int
        }
    }

    let periodStart: Date
    let now: Date
    /// Whole calendar days from the period start's day to today's (`DoctorPeriod.periodDays`).
    let periodDays: Int
    /// Fewer than 3 days: raw counts, no averages, no days lines (R3.3).
    var isShort: Bool { periodDays < 3 }

    let growth: Growth
    /// nil = no finished entry of that kind in the period → «No … logged since» (R5.4).
    let feeding: Feeding?
    let sleep: Sleep?
    let diapers: Diapers?
    /// A visit starts the period and nothing was logged since: ONE «new period»
    /// card replaces the three empty ones (R5.5). Never for «since birth».
    let showsNewPeriodCard: Bool

    // MARK: Building — implemented in DoctorReportSummary+Make.swift

    // static func make(input: Input, periodStart: Date, now: Date,
    //                  startsAtVisit: Bool, calendar: Calendar) -> DoctorReportSummary
}
