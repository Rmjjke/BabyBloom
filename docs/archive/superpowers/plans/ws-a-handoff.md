# Workstream A — Handoff Notes

## Task A1: CloudKit-compatible models (commit 4af4a8b)

### API change: Baby relationship arrays are now OPTIONAL
CloudKit requires SwiftData relationships to be optional. The following
properties on `Baby` changed type from `[T]` to `[T]?` (default `[]`):

- `feedingEntries: [FeedingEntry]?`
- `sleepEntries: [SleepEntry]?`
- `diaperEntries: [DiaperEntry]?`
- `growthEntries: [GrowthEntry]?`
- `customEvents: [CustomEvent]?`

**Impact on other workstreams:** any code that reads these arrays
(e.g. `baby.feedingEntries.count`) must now unwrap, typically with
`?? []`, e.g. `(baby.feedingEntries ?? []).count`.

**Call sites needing fixes:** NONE at time of A1. A repo-wide grep for
`.feedingEntries` / `.sleepEntries` / `.diaperEntries` /
`.growthEntries` / `.customEvents` across `Features/`, `Services/`,
`DesignSystem/`, and tests found no usages. The app currently queries
entries via `@Query` rather than through the `Baby` relationship, so no
in-place fixes were required. Downstream tasks that introduce access via
these relationships must add `?? []`.

### Other notes
- Each entry model gained `var baby: Baby?` (the inverse). Existing
  `init(...)` signatures are unchanged.
- Enum-typed defaults are fully qualified (e.g. `Gender.female`, not
  `.female`) because the `@Model` macro rejects leading-dot shorthand in
  default values.
