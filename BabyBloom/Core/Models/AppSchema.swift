import SwiftData

/// The one list of persisted models, for every container that opens the store:
/// the app (`SharedStore`), the widget (`WidgetDataStore`) and the tests.
///
/// The widget opens the SAME App Group store as the app. Were its list to lack
/// a model, it would open the store as a different model version, and a
/// lightweight migration may then drop the tables it does not know — the
/// widget would delete the user's data. One constant makes that impossible to
/// write; `AppSchemaTests` pins the list so a change to it is deliberate.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Baby.self,
        FeedingEntry.self,
        SleepEntry.self,
        DiaperEntry.self,
        GrowthEntry.self,
        CustomEvent.self,
        DoctorVisit.self,
        DoctorQuestion.self
    ]

    static var schema: Schema { Schema(models) }
}
