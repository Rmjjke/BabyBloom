import Foundation
import SwiftData

/// The bridge from the store to the pure `DoctorReportSummary.Input`, as
/// `WeeklySummary+Store` is for the weekly card.
///
/// It maps and nothing else: running timers, the period edges and the
/// future-date horizon are rules of `make`, so the screen and the PDF can
/// never filter one way here and another there.
extension DoctorReportSummary.Input {
    init(baby: Baby, feeds: [FeedingEntry], sleeps: [SleepEntry], diapers: [DiaperEntry],
         growth: [GrowthEntry]) {
        self.init(
            feeds: feeds.map { Feed(start: $0.startTime, end: $0.endTime, type: $0.type, volumeML: $0.volumeML) },
            sleeps: sleeps.map { Sleep(start: $0.startTime, end: $0.endTime) },
            diapers: diapers.map { Diaper(time: $0.time, type: $0.type, color: $0.color) },
            growth: growth.map {
                Growth(date: $0.date, weightKg: $0.weightKg, heightCm: $0.heightCm,
                       headCm: $0.headCircumferenceCm)
            },
            birthDate: baby.birthDate,
            correctedBirthDate: baby.correctedBirthDate,
            birthWeightKg: baby.birthWeightKg,
            isMale: baby.gender == .male)
    }

    /// For the share button, which has no view of its own to hold @Query: the
    /// same period window `ReportDataSection` queries (feeds and diapers from
    /// the start, sleeps from 36 h before it), growth whole.
    @MainActor
    static func load(baby: Baby, periodStart: Date, in context: ModelContext) -> DoctorReportSummary.Input {
        let start = periodStart
        let sleepsFrom = periodStart.addingTimeInterval(-36 * 3600)
        let feeds = (try? context.fetch(FetchDescriptor<FeedingEntry>(
            predicate: #Predicate { $0.startTime >= start }))) ?? []
        let sleeps = (try? context.fetch(FetchDescriptor<SleepEntry>(
            predicate: #Predicate { $0.startTime >= sleepsFrom }))) ?? []
        let diapers = (try? context.fetch(FetchDescriptor<DiaperEntry>(
            predicate: #Predicate { $0.time >= start }))) ?? []
        let growth = (try? context.fetch(FetchDescriptor<GrowthEntry>())) ?? []
        return DoctorReportSummary.Input(baby: baby, feeds: feeds, sleeps: sleeps,
                                         diapers: diapers, growth: growth)
    }
}
