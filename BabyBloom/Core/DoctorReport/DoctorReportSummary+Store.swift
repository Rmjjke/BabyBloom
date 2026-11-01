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
}
