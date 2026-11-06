import Foundation

/// The lines a medication shows, as the screens draw them.
struct MedicationLines: Equatable {
    /// Line A: where the medication stands. nil for an ended course, which has
    /// no status.
    let primary: String?
    /// Line B: the last dose and its age, the interval, or the end of the course.
    let secondary: String
    /// Line C: the last 24 hours against the maximum, on a running course
    /// that has one.
    let count: String?
}

/// The words of the medication screens, put together from the copy keys.
///
/// Every slot that takes a time takes a when-string as well, so a time on
/// another day carries its day word in every language without a preposition
/// in front of it. Typed text (the name, the dose) is never a key and is never
/// glued or reformatted.
enum MedicationFormat {
    /// A no-break space before the dot, so a wrapped line never opens with it.
    static let separator = "\u{00A0}· "

    /// "6 h", "1 h 30 min", "45 min".
    static func duration(minutes: Int) -> String { DurationText.minutes(minutes) }

    /// The time since a dose, or nil under a minute. From two days it counts
    /// days: "73 h ago" would leave the arithmetic to the parent.
    static func age(_ seconds: TimeInterval) -> String? {
        let minutes = Int(seconds / 60)
        guard minutes >= 1 else { return nil }
        if minutes < 48 * 60 { return duration(minutes: minutes) }
        let days = minutes / (24 * 60)
        return "\(days)\u{00A0}\(days.dayWord)"
    }

    /// A clock time, with "yesterday", "tomorrow" or the date when it is not
    /// on `now`'s day, on the device's 12/24-hour clock in the app's language.
    static func when(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = date.appTimeOfDay
        switch dayOffset(of: date, from: now, calendar: calendar) {
        case 0: return time
        case -1: return String(format: "medication.when_yesterday_fmt".l, time)
        case 1: return String(format: "medication.when_tomorrow_fmt".l, time)
        default: return String(format: "medication.when_date_fmt".l, date.appDayMonth, time)
        }
    }

    /// The day a dose row puts after its time: Today, Yesterday or the date.
    /// Glued, so a large text size moves it to the next line whole.
    static func doseDay(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        switch dayOffset(of: date, from: now, calendar: calendar) {
        case 0: return "medication.day_today".l
        case -1: return "medication.day_yesterday".l
        default: return date.appDayMonth.replacingOccurrences(of: " ", with: "\u{00A0}")
        }
    }

    /// "1 dose", "3 doses"; the plural forms of the app's language.
    static func doseCount(_ count: Int) -> String {
        String(format: count.plural(one: "medication.dose_count.one",
                                    few: "medication.dose_count.few",
                                    many: "medication.dose_count.many"), count)
    }

    /// A dose text in the report as written, or the words for the doses
    /// logged without one when they stand beside doses that have one.
    static func reportDoseText(_ text: String?) -> String {
        text ?? "medication.report_dose_not_written".l
    }

    /// One dose text of a line whose dose changed: "2.5 ml · 10 doses ·
    /// Oct 31 – Nov 2".
    static func reportDoseLine(_ dose: DoctorReportSummary.Medication.DoseText, now: Date) -> String {
        [reportDoseText(dose.text), doseCount(dose.count), ReportFormat.dayRange(dose.first, dose.last, now: now)]
            .joined(separator: separator)
    }

    /// The list row's third line: the dose text and the interval, or the
    /// interval alone.
    static func meta(doseText: String?, intervalMinutes: Int) -> String {
        let interval = duration(minutes: intervalMinutes)
        guard let dose = doseText?.trimmingCharacters(in: .whitespacesAndNewlines), !dose.isEmpty else {
            return String(format: "medication.interval_fmt".l, interval)
        }
        return dose + separator + String(format: "medication.interval_short_fmt".l, interval)
    }

    /// Lines A, B and C for a status. The look never changes with the state;
    /// only these words do.
    static func lines(status: MedicineStatus,
                      intervalMinutes: Int,
                      maxPer24h: Int?,
                      dosesInLast24Hours: Int,
                      doseCount total: Int,
                      now: Date,
                      calendar: Calendar = .current) -> MedicationLines {
        let interval = duration(minutes: intervalMinutes)
        let count = maxPer24h.map {
            String(format: "medication.count_24h_fmt".l, doseCount(dosesInLast24Hours), $0)
        }
        func lastAt(_ dose: Date) -> String {
            String(format: "medication.status_last_at_fmt".l, when(dose, now: now, calendar: calendar))
        }
        switch status {
        case .ended(let endedAt):
            return MedicationLines(
                primary: nil,
                secondary: String(format: "medication.ended_on_fmt".l, endedAt.appDayMonth, doseCount(total)),
                count: nil)
        case .noDose:
            // No count line before the first dose: «0 of the 4 you set» says
            // nothing the empty list does not.
            return MedicationLines(primary: "medication.status_no_doses".l,
                                   secondary: String(format: "medication.interval_fmt".l, interval),
                                   count: nil)
        case .waiting(let last, let until):
            let age = Self.age(now.timeIntervalSince(last))
                .map { String(format: "medication.ago_fmt".l, $0) } ?? "medication.just_now".l
            return MedicationLines(
                primary: String(format: "medication.status_next_fmt".l, when(until, now: now, calendar: calendar)),
                secondary: lastAt(last) + separator + age,
                count: count)
        case .allowed(let last):
            // An interval of at least 15 minutes has passed, so the age is
            // never under a minute; the fallback only guards a bad stored value.
            let age = Self.age(now.timeIntervalSince(last)) ?? duration(minutes: 0)
            return MedicationLines(
                primary: lastAt(last) + separator
                    + String(format: "medication.status_passed_short_fmt".l, interval),
                secondary: String(format: "medication.status_ago_fmt".l, age),
                count: count)
        }
    }

    /// Running courses by name, as the parent typed them: an order by time or
    /// urgency would move rows on every dose and rank which one to give first.
    static func byName(_ medicines: [Medicine]) -> [Medicine] {
        let locale = LocalizationManager.shared.language.locale
        return medicines.sorted {
            let order = $0.name.compare($1.name, options: [.caseInsensitive], range: nil, locale: locale)
            return order == .orderedSame ? $0.createdAt < $1.createdAt : order == .orderedAscending
        }
    }

    /// Ended courses, the latest end first.
    static func byEnd(_ medicines: [Medicine]) -> [Medicine] {
        medicines.sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }

    /// The reminder's title and body. The title is the name as typed. The body
    /// is the time since the dose it counts from, with that dose's time, so a
    /// phone that has not synced a later dose yet still states a fact. The day
    /// word is counted against the moment it fires: a 22:00 dose read at 04:00
    /// is yesterday's.
    static func reminder(name: String, lastDose: Date, fireDate: Date,
                         calendar: Calendar = .current) -> (title: String, body: String) {
        let minutes = Int((fireDate.timeIntervalSince(lastDose) / 60).rounded())
        return (String(format: "notification.medication_title_fmt".l, name),
                String(format: "notification.medication_body_fmt".l,
                       duration(minutes: minutes), when(lastDose, now: fireDate, calendar: calendar)))
    }

    /// A VoiceOver label: the visible lines read in order.
    static func spoken(_ parts: [String?]) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ". ")
    }

    /// A medication event's row on Events. A dose takes its medicine's name,
    /// as copied when it was logged, for the title, then dose · note. An older
    /// or free-text event keeps the type word, then name · dose · note; one
    /// with neither reads as before. Text as typed, never translated.
    static func eventRow(typeWord: String, isDose: Bool,
                         name: String?, dose: String?, note: String?) -> (title: String, subtitle: String) {
        let name = name.flatMap(MedicationFormInput.optional)
        let dose = dose.flatMap(MedicationFormInput.optional)
        let note = note.flatMap(MedicationFormInput.optional)
        func joined(_ parts: [String?]) -> String { parts.compactMap { $0 }.joined(separator: separator) }
        if isDose, let name { return (name, joined([dose, note])) }
        return (typeWord, joined([name, dose, note]))
    }

    private static func dayOffset(of date: Date, from now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                to: calendar.startOfDay(for: date)).day ?? 0
    }
}

extension Medicine {
    /// Linked medication events, newest first: the dose list, and the count
    /// on an ended course. A deleted one is left out before the save
    /// removes it from the relationship.
    var doseEvents: [CustomEvent] {
        (doses ?? [])
            .filter { $0.type == .medication && !$0.isDeleted }
            .sorted { $0.time > $1.time }
    }

    /// The lines as of `now`; `excluding` leaves out the dose being edited.
    func lines(now: Date, excluding: CustomEvent? = nil) -> MedicationLines {
        let schedule = schedule(now: now, excluding: excluding)
        return MedicationFormat.lines(status: status(now: now, excluding: excluding),
                                      intervalMinutes: intervalMinutes,
                                      maxPer24h: schedule.maxPer24h,
                                      dosesInLast24Hours: schedule.dosesInLast24Hours,
                                      doseCount: doseEvents.count,
                                      now: now)
    }

    var metaLine: String { MedicationFormat.meta(doseText: doseText, intervalMinutes: intervalMinutes) }
}
