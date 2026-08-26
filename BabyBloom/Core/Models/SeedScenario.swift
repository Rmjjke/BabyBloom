import Foundation
import OSLog
import SwiftData
import WidgetKit

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
    /// A plausible, well-populated two-month-old for App Store captures.
    ///
    /// Unlike the three above it is not tuned to a threshold — it is tuned to
    /// look like a real parent's week, because every number it produces is
    /// going in front of App Store review and then in front of buyers. Its one
    /// hard constraint comes from the app's Medical category: nothing on the
    /// Growth screen may render red, because a red "below normal" verdict in a
    /// storefront screenshot reads as a diagnosis rather than as tracking.
    /// `ShowcaseGrowthTests` is what keeps that true.
    case showcase

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
            // The widget is a separate process reading the App Group store. It
            // has no idea the fixture just replaced everything under it, and its
            // cached timeline would keep showing the PREVIOUS run's baby — and
            // the previous run's language — until iOS got round to a refresh.
            WidgetCenter.shared.reloadAllTimelines()
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
        guard self != .showcase else { return Self.seedShowcase(into: context) }

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

    // MARK: - Showcase fixture

    /// The fixture baby's age on the day of the capture.
    ///
    /// Two months is what the capture brief asks for, and it is also safely past
    /// `NewbornWeightLoss.observationWindowDays` — so `NewbornProgressCard`, the
    /// one place the Growth screen draws red flag rows, does not render at all.
    static let showcaseAgeDays = 62

    /// How many days of feeds, sleep, nappies and events the fixture logs,
    /// counting back from today.
    ///
    /// Three weeks, for two independent reasons — the longer of the two wins.
    ///
    /// `BBWeeklyBarChart` opens on the current CALENDAR week, so a capture taken
    /// on a Wednesday would show three bars and four empty slots — the exact
    /// emptiness the capture brief exists to fix. Any span over a fortnight
    /// guarantees a complete previous week whatever day the captures are taken,
    /// and the chart's back arrow reaches it in one tap.
    ///
    /// The binding reason is the Nutrition card. It counts feeds and nappies
    /// across `FeedingAdequacy.window(for:)` — the gap between the last two
    /// weighings, which here is the 18 days from day 42 to day 60. A history
    /// shorter than that gap is averaged over days that hold no entries, and the
    /// card reported "5 a day" from a fixture logging eight. Three weeks covers
    /// the whole window with room at both edges.
    static let showcaseHistoryDays = 21

    /// A girl: the three names the capture brief picks per locale are all
    /// feminine, and the WHO reference used for every figure below is the girls'
    /// table.
    static let showcaseIsMale = false

    /// One weighing in the showcase curve: age in days and what was measured.
    ///
    /// The shape is the ordinary newborn one — a physiological dip by day 4,
    /// back past birth weight by day 10, then a steady climb. A flat line would
    /// not be worth putting on a chart.
    ///
    /// The 6-week weight is **4.70 kg where the capture brief proposed 4.80**,
    /// because the brief's own pair fails the brief's own hard requirement:
    /// 4.80 → 5.20 over those 18 days is 22.2 g/day, and `WeightVelocity`'s
    /// 15th-centile edge for a girl at the interval's midpoint (day 51) is
    /// 22.33 g/day. `WeightGainCard` would have rendered `.below`. 4.70 gives
    /// 27.8 g/day — mid-band — and leaves the 5.20 kg headline untouched.
    ///
    /// The last row carries all three measurements because the Growth screen's
    /// stat cards read the LATEST entry: a missing height or head circumference
    /// there shows as an em dash in the captures.
    static let showcaseWeighings: [(ageDays: Int, weightKg: Double, heightCm: Double?, headCm: Double?)] = [
        (0,  3.40, 50.0, 33.9),
        (4,  3.18, nil,  nil),
        (10, 3.45, nil,  nil),
        (30, 4.40, 54.0, 36.5),
        (42, 4.70, nil,  nil),
        (60, 5.20, 58.0, 38.3),
    ]

    /// Minutes since the most recent feed, anchored to launch rather than to a
    /// wall-clock slot. The Dashboard leads with time-since-last-feed, and a
    /// morning capture run would otherwise open on "9 h ago".
    static let showcaseLastFeedMinutesAgo = 16.0

    /// A day's feeds. Eight matches the Dashboard's own target for a two-month
    /// old, so the progress card reads as a day nearly met rather than a rebuke,
    /// and the mix of types is what the Feeding list has to show off.
    private static let showcaseFeeds: [(hour: Int, minute: Int,
                                        type: FeedingEntry.FeedingType,
                                        side: FeedingEntry.BreastSide?,
                                        ml: Double?, minutes: Int)] = [
        (2,  45, .breast,  .left,  nil, 18),
        (6,  10, .breast,  .right, nil, 22),
        (9,   5, .formula, nil,     90, 15),
        (11, 50, .breast,  .left,  nil, 20),
        (14, 20, .pumped,  nil,     80, 16),
        (16, 45, .breast,  .right, nil, 24),
        (19, 35, .breast,  .both,  nil, 19),
        (22, 15, .formula, nil,    100, 15),
    ]

    /// A day's sleep, totalling ~14.6 h before the per-day spread below — the
    /// middle of the range a two-month-old sleeps.
    ///
    /// The night arrives as two entries because that is how it is actually
    /// logged: the baby wakes for the 02:45 feed and goes back down. It also
    /// matters mechanically — the Dashboard buckets sleep by `startTime`, so a
    /// single 22:40 → 07:30 block would leave "today" with naps only.
    private static let showcaseSleeps: [(hour: Int, minute: Int, minutes: Int,
                                         type: SleepEntry.SleepType)] = [
        (3,  15, 255, .night),
        (9,  20, 100, .nap),
        (12, 20,  80, .nap),
        (15, 10,  90, .nap),
        (17, 50,  60, .nap),
        (20, 10,  30, .nap),
        (22, 40, 260, .night),
    ]

    /// Minutes added to every nap on each day back from today, so the weekly
    /// chart has a profile instead of seven identical bars. Deterministic on
    /// purpose: a fixture that shifts between two capture runs cannot be re-shot
    /// to match the first.
    private static let showcaseNapSpread = [0, 12, -14, 7, -9, 16, -6]

    /// Which of the day's feeds to leave out, indexed by days back from today.
    /// `nil` keeps all eight.
    ///
    /// Eight feeds every single day is the same tell as seven identical sleep
    /// bars — the brief's own figure is "7–8 a day", and a chart of seven equal
    /// columns reads as generated rather than logged. Today keeps its full
    /// schedule so the Dashboard's progress card is not short for no reason.
    private static let showcaseFeedOmission: [Int?] = [nil, 2, nil, nil, 5, nil, 3]

    /// A day's nappies: eight, over the Dashboard's target of six, and using
    /// enough of the stool-colour scale to show that the scale exists.
    ///
    /// Seven of the eight count as wet (`.wet` and `.both` both do), against a
    /// `wetNappyMinimum` of six at this age. Six would also read as "within",
    /// but only by landing exactly on the floor — no headroom for the hour a DST
    /// boundary inside the window moves the rate by.
    private static let showcaseNappies: [(hour: Int, minute: Int,
                                          type: DiaperEntry.DiaperType,
                                          color: DiaperEntry.StoolColor?)] = [
        (3,   0, .wet,   nil),
        (6,  20, .both,  .yellow),
        (9,  15, .wet,   nil),
        (12,  0, .dirty, .yellow),
        (14, 35, .wet,   nil),
        (17,  0, .both,  .green),
        (19, 45, .wet,   nil),
        (22, 30, .both,  .yellow),
    ]

    /// A day's events. `notes`, `medicationName` and `weatherNote` stay nil
    /// throughout: they are free text, they would be written in one language,
    /// and a Russian note sitting in the Spanish capture is exactly the seam a
    /// storefront set cannot have.
    private static let showcaseEvents: [(hour: Int, minute: Int,
                                         type: CustomEvent.EventType,
                                         minutes: Int?)] = [
        (11,  0, .walk, 45),
        (16,  5, .mood, nil),
        (18, 20, .bath, 15),
    ]

    /// The mood logged on each day back from today. Not every day is a calm one,
    /// and a week of identical entries reads as generated data.
    private static let showcaseMoods: [CustomEvent.MoodLevel] = [
        .calm, .calm, .fussy, .calm, .calm, .fussy, .calm,
    ]

    /// The fixture baby's name follows the UI language. A Cyrillic name in the
    /// English capture is the kind of detail that makes a storefront set look
    /// assembled rather than shot.
    private static var showcaseBabyName: String {
        switch LocalizationManager.shared.language {
        case .ru: return "Лея"
        case .es: return "Lucía"
        case .en: return "Mia"
        }
    }

    /// Seeds a plausible week for App Store captures.
    ///
    /// Everything is placed at wall-clock times on real calendar days rather
    /// than at offsets in seconds, so a DST boundary inside the week moves the
    /// day and not the hour. Nothing is ever logged into the future: today's
    /// schedule is truncated at launch, which is what keeps the "Today" cards
    /// honest at whatever hour the captures happen to be taken.
    private static func seedShowcase(into context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        func time(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        let birthDay = calendar.date(byAdding: .day, value: -showcaseAgeDays, to: today) ?? today
        let baby = Baby(name: showcaseBabyName,
                        birthDate: calendar.date(bySettingHour: 9, minute: 20, second: 0, of: birthDay) ?? birthDay,
                        gender: showcaseIsMale ? .male : .female,
                        feedingType: .mixed)
        baby.birthWeightKg = showcaseWeighings[0].weightKg
        context.insert(baby)

        for weighing in showcaseWeighings {
            let entry = GrowthEntry(date: time(showcaseAgeDays - weighing.ageDays, 11, 0),
                                    weightKg: weighing.weightKg,
                                    heightCm: weighing.heightCm,
                                    headCircumferenceCm: weighing.headCm)
            entry.baby = baby
            context.insert(entry)
        }

        // Today's scheduled feeds stop an hour short of now so the anchored
        // "16 minutes ago" one below is not stacked on top of a 19:35 slot.
        let scheduledFeedCutoff = now.addingTimeInterval(-3600)

        for daysAgo in 0...showcaseHistoryDays {
            let omitted = showcaseFeedOmission[daysAgo % showcaseFeedOmission.count]
            for (index, slot) in showcaseFeeds.enumerated() {
                guard index != omitted else { continue }
                let start = time(daysAgo, slot.hour, slot.minute)
                guard start < scheduledFeedCutoff else { continue }
                let feed = FeedingEntry(startTime: start, type: slot.type,
                                        side: slot.side, volumeML: slot.ml)
                feed.endTime = start.addingTimeInterval(Double(slot.minutes) * 60)
                feed.baby = baby
                context.insert(feed)
            }

            let napSpread = showcaseNapSpread[daysAgo % showcaseNapSpread.count]
            for slot in showcaseSleeps {
                let start = time(daysAgo, slot.hour, slot.minute)
                let minutes = slot.type == .nap ? slot.minutes + napSpread : slot.minutes
                let end = start.addingTimeInterval(Double(minutes) * 60)
                // By END, not by start: an entry still in progress would be
                // `isActive`, which the Dashboard excludes from today's total —
                // a stretch of sleep that is on screen but not in the number.
                guard end <= now else { continue }
                let sleep = SleepEntry(startTime: start, type: slot.type,
                                       location: slot.type == .night ? .crib : .stroller)
                sleep.endTime = end
                sleep.baby = baby
                context.insert(sleep)
            }

            for slot in showcaseNappies {
                let at = time(daysAgo, slot.hour, slot.minute)
                guard at < now else { continue }
                let nappy = DiaperEntry(time: at, type: slot.type, color: slot.color)
                nappy.baby = baby
                context.insert(nappy)
            }

            for slot in showcaseEvents {
                let at = time(daysAgo, slot.hour, slot.minute)
                guard at < now else { continue }
                let event = CustomEvent(time: at, type: slot.type)
                event.durationMinutes = slot.minutes
                if slot.type == .mood {
                    event.mood = showcaseMoods[daysAgo % showcaseMoods.count]
                }
                event.baby = baby
                context.insert(event)
            }
        }

        let recentStart = now.addingTimeInterval(-showcaseLastFeedMinutesAgo * 60)
        let recentFeed = FeedingEntry(startTime: recentStart, type: .breast, side: .left)
        // Ends two minutes ago rather than at the anchor: an `endTime` in the
        // future is a feed that has not happened yet.
        recentFeed.endTime = recentStart.addingTimeInterval(14 * 60)
        recentFeed.baby = baby
        context.insert(recentFeed)
    }

    #else
    /// Device builds carry no seeding path at all. The gate is the simulator,
    /// not the configuration: a release-optimized QA build still runs on a
    /// simulator and still needs to seed.
    @MainActor
    static func seedIfRequested(in context: ModelContext) {}
    #endif
}
