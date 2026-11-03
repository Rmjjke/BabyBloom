import Foundation

/// The report's counting rules, applied to the plain `Input`. Each
/// section is bucketed by its OWN `PeriodSummary`, so "days with entries"
/// means days with a feed for feeding, days with a sleep for sleep,
/// never the any-entry count the weekly card divides by.
extension DoctorReportSummary {

    static func make(input: Input, periodStart: Date, now: Date, startsAtVisit: Bool,
                     calendar: Calendar) -> DoctorReportSummary {
        let frame = Frame(start: periodStart, now: now, calendar: calendar,
                          periodDays: DoctorPeriod.periodDays(from: periodStart, to: now,
                                                              calendar: calendar))
        // A running timer has no end, so it is not a feed or a sleep yet.
        let feeds = input.feeds.filter { $0.end != nil && frame.contains($0.start) }
        let sleeps = input.sleeps.compactMap { frame.clipped($0) }
        let diapers = input.diapers.filter { frame.contains($0.time) }

        let growth = growthSection(input: input, frame: frame)
        let feeding = feedingSection(feeds, frame: frame)
        let sleep = sleepSection(sleeps, frame: frame)
        let diaperSection = diapersSection(diapers, frame: frame)
        let medications = medicationsSection(input.doses.filter { frame.contains($0.time) },
                                             locale: calendar.locale ?? Locale(identifier: "en_US_POSIX"))

        return DoctorReportSummary(
            periodStart: periodStart,
            now: now,
            periodDays: frame.periodDays,
            growth: growth,
            feeding: feeding,
            sleep: sleep,
            diapers: diaperSection,
            showsNewPeriodCard: startsAtVisit && frame.periodDays == 0 && feeding == nil
                && sleep == nil && diaperSection == nil && growth.weighings.isEmpty,
            medications: medications)
    }

    // MARK: Medications

    /// A medicine's doses together; older and free-text events by their typed
    /// name, trimmed and case-insensitive, beside the medicines and never
    /// merged into one by guesswork; the events with no name in one line.
    static func medicationsSection(_ doses: [Input.Dose], locale: Locale) -> [Medication] {
        enum Key: Hashable { case medicine(UUID), named(String), nameless }
        func text(_ raw: String?) -> String? {
            let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
        let groups = Dictionary(grouping: doses) { dose -> Key in
            if let id = dose.medicineID { return .medicine(id) }
            guard let name = text(dose.name) else { return .nameless }
            return .named(name.lowercased())
        }
        let lines = groups.map { key, doses -> Medication in
            let sorted = doses.sorted { $0.time < $1.time }
            let latest = sorted[sorted.count - 1]
            let name: String? = switch key {
            case .medicine: text(latest.medicineName) ?? text(latest.name)
            case .named: text(latest.name)
            case .nameless: nil
            }
            return Medication(name: name, doseText: key == .nameless ? nil : text(latest.doseText),
                              count: sorted.count, first: sorted[0].time, last: latest.time)
        }
        return lines.sorted { a, b in
            guard let x = a.name else { return false }
            guard let y = b.name else { return true }
            let order = x.compare(y, options: [.caseInsensitive], range: nil, locale: locale)
            return order == .orderedSame ? a.first < b.first : order == .orderedAscending
        }
    }

    // MARK: The period

    /// `[start, now)` with the calendar it is cut by, shared by every section.
    private struct Frame {
        let start: Date
        let now: Date
        let calendar: Calendar
        /// Full calendar days elapsed before today: today's index in a bucket.
        let periodDays: Int

        var isShort: Bool { periodDays < 3 }

        func contains(_ date: Date) -> Bool { date >= start && date < now }

        /// Midnight today: the end of the finished days.
        var todayStart: Date { calendar.startOfDay(for: now) }

        func isFinishedDay(_ date: Date) -> Bool { date < todayStart }

        /// The FINISHED days only, `[start, todayStart)`. Every per-day figure
        /// and the days line come from here: the report is opened at the
        /// visit, mid-morning, and a half-lived today divided like a whole day
        /// pulled «feeds a day» from 8 to 6.5 — and «wet a day» down with it,
        /// the one number a doctor reads for hydration.
        /// Today stays in every count; it just does not average.
        func bucketFinished(_ input: PeriodSummary.Input) -> PeriodSummary {
            PeriodSummary.make(start: start, end: todayStart, input: input, calendar: calendar)
        }

        /// «N of M» over the finished days: M is `periodDays`, whatever today holds.
        func days(_ finished: PeriodSummary) -> Days {
            Days(withEntries: finished.daysWithEntries, counted: periodDays)
        }

        /// The whole period, today included: totals and the longest sleep.
        func bucket(_ input: PeriodSummary.Input) -> PeriodSummary {
            PeriodSummary.make(start: start, end: now, input: input, calendar: calendar)
        }

        /// A finished sleep counted by its part inside the period. The
        /// clipped start lands on day 0, which is where the night belongs. The
        /// end is held at `now` too, so a `-BBNow` behind the real clock cannot
        /// count sleep that has not happened in its world.
        func clipped(_ sleep: Input.Sleep) -> (start: Date, end: Date)? {
            let from = max(sleep.start, start)
            guard let end = sleep.end, from < now, sleep.start >= start || end > start
            else { return nil }
            return (start: from, end: max(from, min(end, now)))
        }
    }

    // MARK: Feeding, sleep, diapers

    private static func feedingSection(_ feeds: [Input.Feed], frame: Frame) -> Feeding? {
        guard !feeds.isEmpty else { return nil }
        let summary = frame.bucket(.init(feeds: feeds.map(\.start)))
        let finished = frame.bucketFinished(.init(feeds: feeds.map(\.start)))

        let types = mostFrequentFirst(feeds.map(\.type))
        // A volume of 0 is an unfilled field, not a bottle the baby refused.
        let bottles = feeds.filter { $0.type != .breast && ($0.volumeML ?? 0) > 0 && frame.isFinishedDay($0.start) }
        let bottleDays = frame.bucketFinished(.init(otherEntries: bottles.map(\.start))).daysWithEntries
        let bottleML = bottles.reduce(0) { $0 + ($1.volumeML ?? 0) }
        let breastLengths = feeds.filter { $0.type == .breast }
            .compactMap { feed in feed.end.map { max(0, $0.timeIntervalSince(feed.start)) } }

        return Feeding(
            totalFeeds: summary.totalFeeds,
            feedsPerDay: frame.isShort || finished.daysWithEntries == 0
                ? nil : Double(finished.totalFeeds) / Double(finished.daysWithEntries),
            byType: types.count > 1 ? types.map { Feeding.TypeCount(type: $0.value, count: $0.count) } : [],
            bottleMLPerDay: frame.isShort || bottleDays == 0 ? nil : bottleML / Double(bottleDays),
            breastfeedMedian: median(breastLengths),
            days: frame.days(finished))
    }

    static func median(_ values: [TimeInterval]) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func sleepSection(_ sleeps: [(start: Date, end: Date)], frame: Frame) -> Sleep? {
        guard !sleeps.isEmpty else { return nil }
        let summary = frame.bucket(.init(sleeps: sleeps))
        // A night that began yesterday is yesterday's, whole, as the Sleep tab files it.
        let finished = frame.bucketFinished(.init(sleeps: sleeps))
        return Sleep(
            total: summary.totalSleep,
            perDay: frame.isShort || finished.daysWithEntries == 0
                ? nil : finished.totalSleep / Double(finished.daysWithEntries),
            longest: summary.longestSleep,
            longestStart: summary.longestSleepStart,
            days: frame.days(finished))
    }

    private static func diapersSection(_ diapers: [Input.Diaper], frame: Frame) -> Diapers? {
        guard !diapers.isEmpty else { return nil }
        let finishedDiapers = diapers.filter { frame.isFinishedDay($0.time) }
        let finished = frame.bucketFinished(.init(otherEntries: finishedDiapers.map(\.time)))
        // `both` is one diaper that is wet AND dirty, so it counts in each.
        let wet = diapers.filter { $0.type != .dirty }.count
        let dirty = diapers.filter { $0.type != .wet }.count
        let finishedWet = finishedDiapers.filter { $0.type != .dirty }.count
        let finishedDirty = finishedDiapers.filter { $0.type != .wet }.count
        // Only a diaper with stool has a stool colour; one left on a diaper
        // switched to wet afterwards is a stale field.
        let colors = mostFrequentFirst(diapers.filter { $0.type != .wet }.compactMap(\.color))
        let days = Double(finished.daysWithEntries)
        let averages = !frame.isShort && days > 0

        return Diapers(
            wetCount: wet,
            dirtyCount: dirty,
            wetPerDay: averages ? Double(finishedWet) / days : nil,
            dirtyPerDay: averages ? Double(finishedDirty) / days : nil,
            colors: colors.map { Diapers.ColorCount(color: $0.value, count: $0.count) },
            days: frame.days(finished))
    }

    /// Ties keep the declaration order of the enum: two renders, or the screen
    /// and the PDF, must never list the same counts in a different order.
    private static func mostFrequentFirst<T: CaseIterable & Hashable>(_ values: [T]) -> [(value: T, count: Int)] {
        let counts = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
        let ranked: [(rank: Int, value: T, count: Int)] = T.allCases.enumerated().compactMap { item in
            counts[item.element].map { (rank: item.offset, value: item.element, count: $0) }
        }
        return ranked
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.rank < $1.rank }
            .map { (value: $0.value, count: $0.count) }
    }

    // MARK: Growth

    private static func growthSection(input: Input, frame: Frame) -> Growth {
        // The same horizon as `weightMeasurements(asOf:)`: a row a few hours
        // ahead (the sheet's stamp, a fast clock on the other phone) counts, a
        // row dated next week is not evidence about today.
        let horizon = frame.now.addingTimeInterval(Array<GrowthEntry>.futureDateTolerance)
        let known = input.growth.filter { $0.date <= horizon }
        let weighings = known
            .compactMap { entry in
                entry.weightKg.flatMap { $0 > 0 ? WeightMeasurement(date: entry.date, weightKg: $0) : nil }
            }
            .sorted(by: chronological)
        let latestWeight = weighings.last
        let latestHeight = latest(in: known, \.heightCm)
        let latestHead = latest(in: known, \.headCm)

        return Growth(
            latestWeight: latestWeight.map { Measure(value: $0.weightKg, date: $0.date) },
            weightPercentile: percentileRow(at: latestWeight?.date, input: input) { _ in
                latestWeight.flatMap {
                    WHOGrowthStandard.percentileReading(of: $0, correctedBirthDate: input.correctedBirthDate,
                                                        isMale: input.isMale)
                }
            },
            latestHeight: latestHeight,
            heightPercentile: percentileRow(at: latestHeight?.date, input: input) { date in
                latestHeight.flatMap {
                    WHOGrowthStandard.lengthPercentileReading(lengthCm: $0.value, measuredOn: date,
                                                              correctedBirthDate: input.correctedBirthDate,
                                                              isMale: input.isMale)
                }
            },
            latestHead: latestHead,
            change: change(weighings: weighings, input: input, frame: frame),
            weighings: periodWeighings(known, frame: frame),
            atBirthWeightKg: input.birthWeightKg.flatMap { $0 > 0 ? $0 : nil },
            atBirthHeightCm: known
                .filter { frame.calendar.isDate($0.date, inSameDayAs: input.birthDate) }
                .sorted { $0.date < $1.date }
                .compactMap { $0.heightCm.flatMap { $0 > 0 ? $0 : nil } }.first)
    }

    /// `WeightVelocity`'s order (private there): oldest first, and of two
    /// weighings stamped the same instant the LIGHTER lands last, so the
    /// latest weight and the change never overstate a gain.
    private static func chronological(_ a: WeightMeasurement, _ b: WeightMeasurement) -> Bool {
        a.date == b.date ? a.weightKg > b.weightKg : a.date < b.date
    }

    private static func latest(in growth: [Input.Growth], _ value: KeyPath<Input.Growth, Double?>) -> Measure? {
        growth
            .compactMap { entry in entry[keyPath: value].flatMap { $0 > 0 ? Measure(value: $0, date: entry.date) : nil } }
            .max { $0.date < $1.date }
    }

    /// Why a row has no number matters to the parent, so the two
    /// nil cases of a reading are told apart here, by the measurement's own
    /// date and the corrected age the WHO functions use.
    private static func percentileRow(at date: Date?, input: Input,
                                      reading: (Date) -> WHOGrowthStandard.PercentileReading?) -> PercentileRow {
        guard let date else { return .none }
        guard let age = WHOGrowthStandard.correctedAgeDaysIfBorn(on: date,
                                                                 correctedBirthDate: input.correctedBirthDate)
        else { return .beforeDueDate }
        guard age <= WHOGrowthStandard.maxAgeDays else { return .outOfRange }
        if let found = reading(date) { return .reading(found) }
        return .none
    }

    /// The newborn gate is `gainDeferral` itself, never a copy:
    /// a change measured across the physiological dip reads as a loss.
    private static func change(weighings: [WeightMeasurement], input: Input,
                               frame: Frame) -> (baseDate: Date, grams: Int)? {
        guard weighings.count >= 2,
              NewbornWeightLoss.gainDeferral(birthWeightKg: input.birthWeightKg, birthDate: input.birthDate,
                                             measurements: weighings, now: frame.now) == nil,
              // The base may be the visit's OWN weighing: it is stamped with
              // the time of day, after the period's 00:00 start, so "on or
              // before the start" means before the start DAY ends.
              let startDayEnd = frame.calendar.date(byAdding: .day, value: 1,
                                                    to: frame.calendar.startOfDay(for: frame.start)),
              let baseIndex = weighings.lastIndex(where: { $0.date < startDayEnd })
                ?? weighings.firstIndex(where: { $0.date >= frame.start }),
              baseIndex < weighings.count - 1
        else { return nil }
        let base = weighings[baseIndex]
        let kg = weighings[weighings.count - 1].weightKg - base.weightKg
        // To 10 g, as the weekly card's gain: scales differ by more.
        return (baseDate: base.date, grams: Int((kg * 1000 / 10).rounded()) * 10)
    }

    /// Newest first, each with a height and a head logged the same day —
    /// on the weighing's own row, else on another row of that day (the parent
    /// may enter them one at a time).
    private static func periodWeighings(_ known: [Input.Growth], frame: Frame) -> [Weighing] {
        let newestFirst = known.sorted { $0.date > $1.date }
        func sameDay(_ entry: Input.Growth, _ value: KeyPath<Input.Growth, Double?>) -> Double? {
            if let own = entry[keyPath: value], own > 0 { return own }
            return newestFirst.first {
                ($0[keyPath: value] ?? 0) > 0 && frame.calendar.isDate($0.date, inSameDayAs: entry.date)
            }?[keyPath: value]
        }
        return known
            .compactMap { entry -> Weighing? in
                guard let kg = entry.weightKg, kg > 0, entry.date >= frame.start else { return nil }
                return Weighing(date: entry.date, weightKg: kg, heightCm: sameDay(entry, \.heightCm),
                                headCm: sameDay(entry, \.headCm))
            }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.weightKg < $1.weightKg }
    }
}
