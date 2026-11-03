import Foundation

/// The dose rules every medicine surface shares: the last dose, when the next
/// one is allowed, and whether a dose at a given time sits too close to
/// another. Pure: times in, facts out. It states time since a dose; it never
/// says whether to give one.
///
/// All arithmetic is elapsed time (`Date` plus seconds), never calendar
/// components: «6 h» after 01:00 on the night the clocks go back is 06:00 of
/// real time, which is what the leaflet means.
struct MedicineSchedule: Equatable {
    /// The doses the rules read, oldest first.
    let doses: [Date]
    let interval: TimeInterval
    /// nil when the medicine has no 24-hour maximum.
    let maxPer24h: Int?
    /// The moment the schedule was read at. Everything it answers is as of
    /// this time, so no caller can pass a second, different "now".
    let now: Date

    static let day: TimeInterval = 24 * 3600

    /// `doseTimes` may hold anything a store holds. A dose later than `now`
    /// (a clock skewed on another device) is left out: it has not happened,
    /// and counting it would hold every later dose back from a time that
    /// never came.
    init(intervalMinutes: Int, maxDosesPer24h: Int?, doseTimes: [Date], now: Date) {
        doses = doseTimes.filter { $0 <= now }.sorted()
        interval = TimeInterval(max(0, intervalMinutes)) * 60
        maxPer24h = maxDosesPer24h.flatMap { $0 > 0 ? $0 : nil }
        self.now = now
    }

    var lastDose: Date? { doses.last }

    /// Doses in the 24 hours up to `now`, for the line that shows the count
    /// against the maximum. A dose exactly 24 hours old has left the window,
    /// as in `check`.
    var dosesInLast24Hours: Int {
        let start = now.addingTimeInterval(-Self.day)
        return doses.filter { $0 > start }.count
    }

    /// When the 24-hour count falls under the maximum for a dose after the
    /// last one: the oldest of the last `max` doses plus a day. nil while
    /// fewer than `max` doses exist, or with no maximum.
    private var maximumEnds: Date? {
        guard let max = maxPer24h, doses.count >= max else { return nil }
        return doses[doses.count - max].addingTimeInterval(Self.day)
    }

    /// The earliest time a dose would neither sit closer than the interval to
    /// the last one nor take any 24 hours over the maximum: the later of the
    /// interval's end and `maximumEnds`. nil with no dose. Without the second
    /// part, the screen could show a time at which logging a dose still
    /// raises the 24-hour confirmation.
    var nextAllowed: Date? {
        guard let last = doses.last else { return nil }
        let intervalEnds = last.addingTimeInterval(interval)
        guard let maximumEnds else { return intervalEnds }
        return Swift.max(intervalEnds, maximumEnds)
    }

    /// Whether a dose at `time` needs the calm confirmation, and the facts it
    /// names. The dose being edited must already be left out of `doses`.
    ///
    /// Too close means within the interval of ANY considered dose, before or
    /// after: a dose back-dated to 14:00 when 16:00 is logged sits inside the
    /// 16:00 dose's interval just as much. Exactly the interval apart is on
    /// time.
    ///
    /// A close LATER dose is named first, the nearest of them. Only when none
    /// exists is the latest close earlier dose named, with the end of its
    /// interval. That end is then a true «not before»: a dose put between two
    /// logged ones has no free time between them, and naming the earlier
    /// dose's end would give a time inside the later dose's interval.
    func check(_ time: Date) -> DoseCheck {
        var result = DoseCheck()
        let close = doses.filter { abs($0.timeIntervalSince(time)) < interval }
        if let later = close.first(where: { $0 > time }) {
            result.neighbour = .later(dose: later)
        } else if let earlier = close.last {
            result.neighbour = .earlier(dose: earlier, intervalEnds: earlier.addingTimeInterval(interval))
        }
        if let max = maxPer24h {
            // A window is [start, start + 24 h). The windows that hold `time`
            // start in (time − 24 h, time], and the fullest of them starts at
            // a dose, so those starts are the only ones to try.
            let all = (doses + [time]).sorted()
            let earliest = time.addingTimeInterval(-Self.day)
            for start in all where start > earliest && start <= time {
                let end = start.addingTimeInterval(Self.day)
                let count = all.filter { $0 >= start && $0 < end }.count
                if count > max, count > (result.daily?.count ?? 0) {
                    result.daily = DoseCheck.Daily(count: count, max: max, windowStart: start)
                }
            }
        }
        // One confirmation per save, so it names the limit that sets the
        // screen's «not before»: the maximum only when it holds the next dose
        // back past the interval's end. On a tie, and for a dose put before a
        // logged one, the interval.
        if result.daily != nil {
            switch result.neighbour {
            case nil:
                result.showsDaily = true
            case .earlier(_, let intervalEnds):
                result.showsDaily = (maximumEnds ?? .distantPast) > intervalEnds
            case .later:
                result.showsDaily = false
            }
        }
        return result
    }
}

/// What a dose at a given time would mean, for the confirmation to name.
/// Empty means on time: no confirmation.
struct DoseCheck: Equatable {
    enum Neighbour: Equatable {
        /// A logged dose less than the interval before this one, with the end
        /// of its interval: the time this dose would have been on time.
        case earlier(dose: Date, intervalEnds: Date)
        /// A logged dose less than the interval after this one.
        case later(dose: Date)
    }

    /// The fullest 24 hours holding this dose, when it is over the maximum.
    struct Daily: Equatable {
        let count: Int
        let max: Int
        let windowStart: Date
    }

    var neighbour: Neighbour?
    var daily: Daily?
    /// Which fact the one confirmation states when both hold: true for the
    /// 24-hour count, false for the interval.
    var showsDaily = false

    var needsConfirmation: Bool { neighbour != nil || daily != nil }
}

/// Where a medicine stands now, for the line under it.
enum MedicineStatus: Equatable {
    case ended(Date)
    case noDose
    case waiting(lastDose: Date, until: Date)
    case allowed(lastDose: Date)
}

extension Medicine {
    /// The times of this medicine's doses, without `excluding` (the dose being
    /// edited). Only linked `.medication` events count: a free-text event with
    /// the same name is not matched to a medicine, and a linked event of
    /// another type is not a dose.
    func doseTimes(excluding: CustomEvent? = nil) -> [Date] {
        (doses ?? [])
            .filter { $0.type == .medication && $0 !== excluding }
            .map(\.time)
    }

    func schedule(now: Date, excluding: CustomEvent? = nil) -> MedicineSchedule {
        MedicineSchedule(intervalMinutes: intervalMinutes, maxDosesPer24h: maxDosesPer24h,
                         doseTimes: doseTimes(excluding: excluding), now: now)
    }

    /// An ended course has no next time; its doses stay where they were.
    func status(now: Date) -> MedicineStatus {
        if let endedAt { return .ended(endedAt) }
        let schedule = schedule(now: now)
        guard let last = schedule.lastDose, let next = schedule.nextAllowed else { return .noDose }
        return now < next ? .waiting(lastDose: last, until: next) : .allowed(lastDose: last)
    }

    /// The check for a dose at `time`, new or (with `editing`) moved.
    func check(_ time: Date, now: Date, editing: CustomEvent? = nil) -> DoseCheck {
        schedule(now: now, excluding: editing).check(time)
    }
}
