import Foundation
import SwiftData

/// One-time repair for entries created before they were linked to their Baby.
///
/// Until this shipped, no insert site set `entry.baby`. Every entry on disk
/// therefore has a nil owner, which makes `Baby`'s `.cascade` delete rules
/// inert: deleting the profile would leave every feeding, sleep, diaper,
/// growth and event record behind. New entries are linked at creation now;
/// this adopts the ones already stored.
///
/// The app is single-baby (one `Baby` is created in onboarding and every screen
/// reads `babies.first`), so the owner is unambiguous. With no Baby yet — a
/// fresh install still in onboarding — there is nothing to adopt and the pass
/// does not mark itself done, so it runs again once a profile exists.
enum OrphanedEntryAdoption {

    private static let completionKey = "bb.migration.entryOwnership.v1"

    /// Runs once per install. Safe to call on every launch.
    @MainActor
    static func runIfNeeded(in context: ModelContext,
                            defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completionKey) else { return }
        guard adopt(in: context) else { return }
        defaults.set(true, forKey: completionKey)
    }

    /// Links every ownerless entry to the baby. Returns false when there is no
    /// profile to adopt into, or when the save failed — either way the caller
    /// must not record the migration as done.
    ///
    /// Exposed for tests; `runIfNeeded` is the production entry point.
    @MainActor
    @discardableResult
    static func adopt(in context: ModelContext) -> Bool {
        guard let baby = (try? context.fetch(
            FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)])
        ))?.first else { return false }

        // Filtered in memory rather than by predicate: SwiftData's handling of
        // `nil` on a to-one relationship inside #Predicate is not dependable
        // across releases, and this runs at most once per install.
        var adopted = 0
        adopted += link(FetchDescriptor<FeedingEntry>(), in: context) { $0.baby == nil } assign: { $0.baby = baby }
        adopted += link(FetchDescriptor<SleepEntry>(),   in: context) { $0.baby == nil } assign: { $0.baby = baby }
        adopted += link(FetchDescriptor<DiaperEntry>(),  in: context) { $0.baby == nil } assign: { $0.baby = baby }
        adopted += link(FetchDescriptor<GrowthEntry>(),  in: context) { $0.baby == nil } assign: { $0.baby = baby }
        adopted += link(FetchDescriptor<CustomEvent>(),  in: context) { $0.baby == nil } assign: { $0.baby = baby }

        guard adopted > 0 else { return true }   // nothing orphaned: already correct
        do {
            try context.save()
            return true
        } catch {
            // Leave the flag unset so the next launch tries again.
            return false
        }
    }

    private static func link<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        in context: ModelContext,
        where isOrphaned: (T) -> Bool,
        assign: (T) -> Void
    ) -> Int {
        guard let all = try? context.fetch(descriptor) else { return 0 }
        let orphans = all.filter(isOrphaned)
        orphans.forEach(assign)
        return orphans.count
    }
}
