import Foundation
import SwiftData

/// Deterministic data for driving the app in tests. Simulator-only.
///
/// Delivered as a LAUNCH ARGUMENT rather than a stored default, so it survives
/// Maestro's `clearState` the same way `-BBSkipSplash` and
/// `-hasCompletedOnboarding` do:
///
///     xcrun simctl launch booted com.nenita.app \
///       -BBSkipSplash true -hasCompletedOnboarding true -appLanguage en \
///       -BBSeedScenario lowGain
///
/// Gated on `targetEnvironment(simulator)`, deliberately NOT on `DEBUG`: a
/// release-optimized QA build has `DEBUG` false but is still a real build for a
/// real device, and no shipped binary may carry a path that wipes a parent's
/// data. On device the whole seeding body — including `wipe` — does not exist.
///
/// Permanent scaffolding per `.desk/project.md` (`scaffolding: keep`): it lets
/// every later growth feature be verified in the real app instead of only in
/// unit tests.
enum SeedScenario: String {
    /// Gain below reference, feeds and nappies below theirs — the breakdown case.
    case lowGain
    /// Everything within reference — the calm case the parent usually sees.
    case healthy
    /// Gain below reference, nothing else logged — proves "not enough data"
    /// renders instead of zero.
    case sparseLogs

    #if targetEnvironment(simulator)
    /// Whether this process has already seeded. The root view's `.onAppear`
    /// re-fires whenever its identity changes (it is keyed on `appLanguage`),
    /// and a second pass would wipe and re-seed against a later `now` — the
    /// data would silently shift under a flow mid-run.
    @MainActor
    private static var hasSeeded = false

    /// Wipes existing data and seeds the requested scenario. No-op without the
    /// launch argument, and no-op on every call after the first.
    ///
    /// The wipe is unreachable except through this guard: `wipe` is private and
    /// this is its only call site, below the `guard`.
    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard !hasSeeded else { return }
        guard let raw = UserDefaults.standard.string(forKey: "BBSeedScenario"),
              let scenario = SeedScenario(rawValue: raw) else { return }
        hasSeeded = true
        wipe(context)
        scenario.seed(into: context)
        try? context.save()
    }

    /// Entries first, then the babies that own them: deleting a `Baby` marks its
    /// entries for cascade deletion too, and re-deleting those in the same pass
    /// would be asking SwiftData to delete an object it has already buried.
    private static func wipe(_ context: ModelContext) {
        for entry in (try? context.fetch(FetchDescriptor<FeedingEntry>())) ?? [] { context.delete(entry) }
        for entry in (try? context.fetch(FetchDescriptor<SleepEntry>())) ?? [] { context.delete(entry) }
        for entry in (try? context.fetch(FetchDescriptor<DiaperEntry>())) ?? [] { context.delete(entry) }
        for entry in (try? context.fetch(FetchDescriptor<GrowthEntry>())) ?? [] { context.delete(entry) }
        for entry in (try? context.fetch(FetchDescriptor<CustomEvent>())) ?? [] { context.delete(entry) }
        for baby in (try? context.fetch(FetchDescriptor<Baby>())) ?? [] { context.delete(baby) }
    }

    /// Days between the two weighings — also the stretch feeds and nappies are
    /// logged over, because `FeedingAdequacy` counts them across exactly the
    /// window the two weighings define.
    ///
    /// Nine clears both floors that bear on these fixtures with room to spare:
    /// `WeightVelocity.minimumIntervalDays` (3, below which the gain signal is
    /// `.notEnoughData` rather than `.below`) and `FeedingAdequacy.window(for:)`
    /// (one full day, below which there is no window at all).
    private static let windowDays = 9

    private func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now) ?? now }

        // 40 days old: inside the 0-6 month range this feature covers, and past
        // the newborn window so `NewbornProgressCard` does not take the screen.
        let baby = Baby(name: "Mia", birthDate: daysAgo(40), gender: .female, feedingType: .breast)
        baby.birthWeightKg = 3.4
        context.insert(baby)

        // Compared at the midpoint of the interval — a corrected age of ~35 days
        // — where the WHO velocity band for a girl is 22.3–39.6 g/day. 17 sits
        // below it; 32 sits inside it.
        let gramsPerDay: Double = (self == .healthy) ? 32 : 17
        let startKg = 4.0
        for (offset, kg) in [(Self.windowDays, startKg),
                             (0, startKg + gramsPerDay * Double(Self.windowDays) / 1000)] {
            let entry = GrowthEntry(date: daysAgo(offset), weightKg: kg,
                                    heightCm: 55, headCircumferenceCm: nil)
            entry.baby = baby
            context.insert(entry)
        }

        guard self != .sparseLogs else { return }

        // Corrected age 40 days puts the breast reference at 7–9 feeds a day and
        // the wet-nappy minimum at 6.
        let feedsPerDay = (self == .healthy) ? 9 : 5
        let nappiesPerDay = (self == .healthy) ? 7 : 4
        // `1...windowDays`, not `0...windowDays`: `rate(of:in:)` divides by the
        // window's length in days, so logging BOTH endpoints would put
        // `windowDays + 1` days of entries over a `windowDays`-long window and
        // report 5.5 a day from a fixture that means 5. Starting at day 1 keeps
        // the rendered rate exactly the number written here, which is what the
        // e2e assertions read.
        for day in 1...Self.windowDays {
            // Spread across the day rather than stacked on one instant, so the
            // Feeding and Diaper screens show a plausible log too. Hourly, and
            // forwards: day `windowDays` sits exactly on the window's start, and
            // an offset backwards would fall outside it and go uncounted.
            for index in 0..<feedsPerDay {
                let start = daysAgo(day).addingTimeInterval(Double(index) * 3600)
                let feed = FeedingEntry(startTime: start, type: .breast, side: .left, volumeML: nil)
                feed.endTime = start.addingTimeInterval(15 * 60)
                feed.baby = baby
                context.insert(feed)
            }
            for index in 0..<nappiesPerDay {
                let nappy = DiaperEntry(time: daysAgo(day).addingTimeInterval(Double(index) * 3600),
                                        type: .wet)
                nappy.baby = baby
                context.insert(nappy)
            }
        }
    }
    #else
    /// Release builds carry no seeding path at all.
    @MainActor
    static func seedIfRequested(in context: ModelContext) {}
    #endif
}
