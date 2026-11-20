import Foundation
import SwiftData

extension OfferRule.Facts {

    /// The facts the offer rule reads, from the store. No baby, no facts:
    /// `onboardingEndedAt` stays nil and nothing is due.
    static func load(in context: ModelContext, onboardingEndedAt stored: Date?, now: Date) -> OfferRule.Facts {
        // `first` by creation date, the app's single-baby rule.
        let babies = (try? context.fetch(FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        guard let baby = babies.first else { return OfferRule.Facts() }
        let ended = stored ?? baby.createdAt.addingTimeInterval(OnboardingEnd.fallbackAfterBaby)

        var records: [OfferRule.Record] = []
        records += ((try? context.fetch(FetchDescriptor<FeedingEntry>())) ?? []).map { .init(date: $0.startTime, createdAt: $0.createdAt) }
        records += ((try? context.fetch(FetchDescriptor<SleepEntry>())) ?? []).map { .init(date: $0.startTime, createdAt: $0.createdAt) }
        records += ((try? context.fetch(FetchDescriptor<DiaperEntry>())) ?? []).map { .init(date: $0.time, createdAt: $0.createdAt) }
        records += ((try? context.fetch(FetchDescriptor<CustomEvent>())) ?? []).map { .init(date: $0.time, createdAt: $0.createdAt) }

        let growth = ((try? context.fetch(FetchDescriptor<GrowthEntry>())) ?? []).filter { ($0.weightKg ?? 0) > 0 }
        func blockers(asOf moment: Date, entries: [GrowthEntry]) -> Bool {
            let found = ReviewPromptPolicy.clinicalBlockers(
                birthDate: baby.birthDate,
                birthWeightKg: baby.birthWeightKg,
                correctedBirthDate: baby.correctedBirthDate,
                isMale: baby.gender == .male,
                measurements: entries.weightMeasurements(asOf: moment),
                now: moment)
            return found.belowReferenceGain || found.newbornFlag
        }
        // A weighing is flagged when the clinical blockers stood right after
        // it was added — read over the weighings that existed then. Only the
        // ones added in the app are judged: the rest never count.
        let weighings = growth.map { entry -> OfferRule.Weighing in
            let added = entry.createdAt > ended
            let flagged = added && blockers(asOf: entry.createdAt,
                                            entries: growth.filter { $0.createdAt <= entry.createdAt })
            return .init(date: entry.date, createdAt: entry.createdAt, flagged: flagged)
        }

        return OfferRule.Facts(onboardingEndedAt: ended,
                               records: records,
                               weighings: weighings,
                               clinicalBlocked: blockers(asOf: now, entries: growth))
    }
}
