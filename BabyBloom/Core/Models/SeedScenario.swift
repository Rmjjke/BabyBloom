import Foundation
import OSLog
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
/// # Only run this on a simulator that is NOT signed into iCloud
///
/// Read this before you pass `-BBSeedScenario` for the first time. The
/// simulator gate keeps the wipe out of every shipped binary; it does NOT make
/// the wipe local. The model container is configured with
/// `cloudKitDatabase: .automatic` (`BabyBloomApp.swift`), so on a simulator
/// signed into a real iCloud account this deletes every `Baby` and every entry
/// from **that Apple Account's private database** — the same records the
/// person's own phone is syncing — and then pushes the fixture baby outward to
/// replace them. It is not a sandbox and there is no undo.
///
/// Sign the simulator out of iCloud (Settings ▸ [your name] ▸ Sign Out), or use
/// a simulator that was never signed in. A simulator with no account does not
/// sync at all, which is the normal state for a test run.
///
/// Permanent scaffolding per `.desk/project.md` (`scaffolding: keep`): it lets
/// every later growth feature be verified in the real app instead of only in
/// unit tests.
enum SeedScenario: String, CaseIterable {
    /// Gain below reference, feeds and nappies below theirs — the breakdown case.
    case lowGain
    /// Everything within reference — the calm case the parent usually sees.
    case healthy
    /// Gain below reference, nothing else logged — proves "not enough data"
    /// renders instead of zero.
    case sparseLogs

    #if targetEnvironment(simulator)
    /// The launch argument's UserDefaults key. Deliberately declared INSIDE the
    /// simulator block: it is the one string that can unlock the wipe, and
    /// keeping it here is what keeps it out of a device binary entirely.
    private static let launchArgumentKey = "BBSeedScenario"

    /// Everything here is written with `privacy: .public`. The values are
    /// fixture names, never a real person's data, and the whole point of the
    /// line is that a flow's log capture can read it —
    /// `log stream --predicate 'subsystem CONTAINS "nenita"'` would otherwise
    /// show `<private>`, since os.Logger redacts interpolated strings by
    /// default.
    private static let log = Logger(subsystem: "com.nenita.app", category: "SeedScenario")

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
    ///
    /// **A missing key and an unrecognised one are not the same thing.** Absent,
    /// this is simply a launch that is not seeding — the overwhelmingly common
    /// case, and a clean no-op. Present but unparsable is a typo in a flow, and
    /// falling quietly through would leave the app running on whatever the
    /// PREVIOUS flow left in the store: observably identical to a launch that
    /// deliberately did not seed, and the assertions would go green against
    /// stale data. For scaffolding whose entire job is to make e2e assertions
    /// mean something, that is the wrong default, so it logs a fault naming the
    /// bad value and the valid ones and then traps — in every build
    /// configuration, which is why it is `fatalError` and not `assertionFailure`.
    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard !hasSeeded else { return }
        guard let raw = UserDefaults.standard.string(forKey: launchArgumentKey) else { return }
        guard let scenario = SeedScenario(rawValue: raw) else {
            let valid = allCases.map(\.rawValue).joined(separator: ", ")
            log.fault("""
                -\(launchArgumentKey, privacy: .public) was \"\(raw, privacy: .public)\", \
                which is not a scenario. Valid: \(valid, privacy: .public). Nothing was seeded.
                """)
            // `fatalError`, not `assertionFailure`: assertions are stripped in a
            // Release configuration, and a Release simulator build would then
            // fall through to run the flow against whatever the PREVIOUS run
            // left in the store — the exact failure this guard exists to
            // prevent, and it would show up as green assertions on stale data.
            // The `log.fault` above runs first because a flow's log capture is
            // what reads the reason out.
            fatalError("-\(launchArgumentKey) was \"\(raw)\", which is not a scenario. Valid: \(valid)")
        }
        hasSeeded = true
        wipe(context)
        scenario.seed(into: context)
        do {
            try context.save()
            // Named in the log so a flow's capture can confirm WHICH fixture its
            // assertions actually ran against.
            log.notice("Seeded scenario \(scenario.rawValue, privacy: .public).")
        } catch {
            // `hasSeeded` is already true and nothing reached disk, so without
            // this the screen is merely empty and there is no way to tell why.
            log.fault("""
                Seeding \(scenario.rawValue, privacy: .public) failed to save: \
                \(String(describing: error), privacy: .public)
                """)
            assertionFailure("Seeding \(scenario.rawValue) failed to save: \(error)")
        }
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
        //
        // `healthy` takes 8 feeds — MID-BAND, not the band's upper bound. 9
        // would also read as "within" today, but only because the comparison is
        // `perDay < lowerBound` and never looks at the upper edge; a fixture
        // that passes on a technicality is a trap for whoever tightens that
        // comparison next, and it leaves no headroom for the hour a DST
        // boundary inside the window would move the rates by.
        //
        // The nappy figure deliberately stays at 7, and this is NOT an
        // oversight of the same rule. `wetNappyMinimum` returns a single floor,
        // not a range — there is no upper edge to sit on, so the only way to
        // fail is to drop under 6, and 7 clears that by a whole nappy (~14%,
        // against a DST wobble of ~0.4%). 7 is also squarely what the NHS and
        // AAP describe as typical, so the fixture still reads as plausible data.
        let feedsPerDay = (self == .healthy) ? 8 : 5
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
