import Foundation

/// Everything the pediatrician report's data cards show, for one period
/// `[periodStart, now)`. Pure: plain values in (see `Input`), numbers and dates
/// out; the views format them. Every rule of the report's counting lives here
/// and is pinned by `DoctorReportSummaryTests`.
///
/// It builds on `PeriodSummary`, but feeds it the REPORT's input: running
/// timers are left out and a sleep that began before the period counts by its
/// part inside — the weekly card decides both the other way.
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
        /// A medication event: a medicine's dose, or an older or free-text one.
        struct Dose: Equatable {
            var time: Date
            /// The name and dose text copied when it was logged, or as typed.
            var name: String?
            var doseText: String?
            /// The medicine it is a dose of; nil for an event without one.
            var medicineID: UUID?
            var medicineName: String?
        }

        var feeds: [Feed] = []
        var sleeps: [Sleep] = []
        var diapers: [Diaper] = []
        var growth: [Growth] = []
        var doses: [Dose] = []
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
        /// The latest weighing at or before now, of ANY date.
        let latestWeight: Measure?
        let weightPercentile: PercentileRow
        let latestHeight: Measure?
        let heightPercentile: PercentileRow
        let latestHead: Measure?
        /// «Since <baseDate>: ±grams»; nil when hidden.
        let change: (baseDate: Date, grams: Int)?
        /// The period's weighings, newest first. The view shows 6, then «Show all N».
        let weighings: [Weighing]
        let atBirthWeightKg: Double?
        let atBirthHeightCm: Double?
        /// The PDF's weight-for-age chart; nil when the weight percentile shows
        /// no figure or fewer than two weighings are known.
        var weightChart: WeightForAgeChart? = nil

        static func == (a: Growth, b: Growth) -> Bool {
            a.latestWeight == b.latestWeight && a.weightPercentile == b.weightPercentile
                && a.latestHeight == b.latestHeight && a.heightPercentile == b.heightPercentile
                && a.latestHead == b.latestHead && a.change?.baseDate == b.change?.baseDate
                && a.change?.grams == b.change?.grams && a.weighings == b.weighings
                && a.atBirthWeightKg == b.atBirthWeightKg && a.atBirthHeightCm == b.atBirthHeightCm
                && a.weightChart == b.weightChart
        }

        /// No weighing ever: the card shows `report.empty_growth` + «Add a weighing».
        var isEmpty: Bool { latestWeight == nil && latestHeight == nil && latestHead == nil }

        /// The height row would print the same note the weight row already
        /// prints (before the due date, past the table): say it once.
        var repeatsWeightNote: Bool {
            guard latestWeight != nil, heightPercentile == weightPercentile else { return false }
            switch heightPercentile {
            case .beforeDueDate, .outOfRange: return true
            default: return false
            }
        }
    }

    /// «Days with entries: N of M» — shown only when `withEntries < counted`.
    struct Days: Equatable {
        let withEntries: Int
        /// Full days since the period start, plus today only if today has an entry of this kind.
        let counted: Int
        var showsLine: Bool { withEntries < counted }
    }

    struct Feeding: Equatable {
        let totalFeeds: Int
        /// nil in a short period — the view prints `report.feeds_count_fmt` then.
        let feedsPerDay: Double?
        /// Only when more than one type was logged; most frequent first.
        let byType: [TypeCount]
        /// Formula + expressed ml a day, over days with a bottle that has a volume.
        let bottleMLPerDay: Double?
        /// Median length of finished breastfeeds: one
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
        /// `both` counts in wet AND dirty.
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
    /// Fewer than 3 days: raw counts, no averages, no days lines.
    var isShort: Bool { periodDays < 3 }

    var growth: Growth
    /// nil = no finished entry of that kind in the period → «No … logged since».
    let feeding: Feeding?
    let sleep: Sleep?
    let diapers: Diapers?
    /// A visit starts the period and nothing was logged since: ONE «new period»
    /// card replaces the three empty ones. Never for «since birth».
    let showsNewPeriodCard: Bool

    /// One line of the medications section: a medicine, an older event's
    /// typed name, or the events with no name together.
    struct Medication: Equatable {
        /// nil: the events with no name.
        let name: String?
        /// The dose texts the line's doses carry, in order of first use, each
        /// with its own count and days. One entry: every dose shares it (nil:
        /// none has one). More: the dose changed, and each text is stated
        /// with what it counts, nil being the doses logged without one. The
        /// latest text alone would turn 10 × 2.5 ml and 3 × 5 ml into 13 × 5 ml.
        let texts: [DoseText]
        let count: Int
        let first: Date
        let last: Date

        struct DoseText: Equatable {
            /// As written on the group's latest dose; nil: no text written.
            let text: String?
            let count: Int
            let first: Date
            let last: Date
        }

        /// The text every dose shares; nil when none has one or they differ.
        var doseText: String? { texts.count == 1 ? texts[0].text : nil }
    }

    /// Medications given in the period, by name, the line without a name
    /// last. Empty: no section. Never an interval, a maximum or a mark on an
    /// early dose: in a document for the doctor that would be a verdict.
    var medications: [Medication] = []

    // MARK: Building — implemented in DoctorReportSummary+Make.swift

    // static func make(input: Input, periodStart: Date, now: Date,
    //                  startsAtVisit: Bool, calendar: Calendar) -> DoctorReportSummary
}
