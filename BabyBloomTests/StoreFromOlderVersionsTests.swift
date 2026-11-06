import XCTest
import SwiftData
@testable import BabyBloom

// Aliases to the app's enums, declared BEFORE `Schema120`: inside it the names
// Baby, FeedingEntry and the rest mean the nested copies.
private typealias Gender120 = Baby.Gender
private typealias BabyFeedingType120 = Baby.FeedingType
private typealias FeedingType120 = FeedingEntry.FeedingType
private typealias BreastSide120 = FeedingEntry.BreastSide
private typealias SleepType120 = SleepEntry.SleepType
private typealias SleepLocation120 = SleepEntry.SleepLocation
private typealias DiaperType120 = DiaperEntry.DiaperType
private typealias StoolColor120 = DiaperEntry.StoolColor
private typealias EventType120 = CustomEvent.EventType
private typealias MoodLevel120 = CustomEvent.MoodLevel

/// The shape of the store before medicines (1.2.0): the eight models without
/// `Baby.medicines`, `CustomEvent.medicine` and `Medicine`. Stored properties
/// only; the test writes a store with it, then opens that file under the
/// current schema.
private enum Schema120: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 2, 0)
    static var models: [any PersistentModel.Type] {
        [Baby.self, FeedingEntry.self, SleepEntry.self, DiaperEntry.self,
         GrowthEntry.self, CustomEvent.self, DoctorVisit.self, DoctorQuestion.self]
    }

    @Model
    final class Baby {
        var id: UUID = UUID()
        var name: String = ""
        var birthDate: Date = Date()
        var gender: Gender120 = Gender120.female
        var feedingType: BabyFeedingType120 = BabyFeedingType120.breast
        var photoData: Data?
        var createdAt: Date = Date()
        var birthWeightKg: Double?
        var gestationalWeeks: Int?

        @Relationship(deleteRule: .cascade, inverse: \Schema120.FeedingEntry.baby) var feedingEntries: [Schema120.FeedingEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema120.SleepEntry.baby) var sleepEntries: [Schema120.SleepEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema120.DiaperEntry.baby) var diaperEntries: [Schema120.DiaperEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema120.GrowthEntry.baby) var growthEntries: [Schema120.GrowthEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema120.CustomEvent.baby) var customEvents: [Schema120.CustomEvent]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema120.DoctorVisit.baby) var doctorVisits: [Schema120.DoctorVisit]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema120.DoctorQuestion.baby) var doctorQuestions: [Schema120.DoctorQuestion]? = []

        init(name: String, birthDate: Date) {
            self.id = UUID()
            self.name = name
            self.birthDate = birthDate
        }
    }

    @Model
    final class FeedingEntry {
        var id: UUID = UUID()
        var startTime: Date = Date()
        var endTime: Date?
        var type: FeedingType120 = FeedingType120.breast
        var side: BreastSide120?
        var volumeML: Double?
        var durationSeconds: Int?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema120.Baby?

        init(startTime: Date, type: FeedingType120) {
            self.id = UUID()
            self.startTime = startTime
            self.type = type
        }
    }

    @Model
    final class SleepEntry {
        var id: UUID = UUID()
        var startTime: Date = Date()
        var endTime: Date?
        var type: SleepType120 = SleepType120.nap
        var location: SleepLocation120?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema120.Baby?

        init(startTime: Date, type: SleepType120) {
            self.id = UUID()
            self.startTime = startTime
            self.type = type
        }
    }

    @Model
    final class DiaperEntry {
        var id: UUID = UUID()
        var time: Date = Date()
        var type: DiaperType120 = DiaperType120.wet
        var color: StoolColor120?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema120.Baby?

        init(time: Date, type: DiaperType120) {
            self.id = UUID()
            self.time = time
            self.type = type
        }
    }

    @Model
    final class GrowthEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var weightKg: Double?
        var heightCm: Double?
        var headCircumferenceCm: Double?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema120.Baby?

        init(date: Date) {
            self.id = UUID()
            self.date = date
        }
    }

    @Model
    final class CustomEvent {
        var id: UUID = UUID()
        var time: Date = Date()
        var type: EventType120 = EventType120.bath
        var mood: MoodLevel120?
        var medicationName: String?
        var medicationDose: String?
        var weatherNote: String?
        var durationMinutes: Int?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema120.Baby?

        init(time: Date, type: EventType120) {
            self.id = UUID()
            self.time = time
            self.type = type
        }
    }

    @Model
    final class DoctorVisit {
        var id: UUID = UUID()
        var date: Date = Date()
        var note: String?
        var createdAt: Date = Date()
        var baby: Schema120.Baby?

        @Relationship(deleteRule: .nullify, inverse: \Schema120.DoctorQuestion.visit)
        var questions: [Schema120.DoctorQuestion]? = []

        init(date: Date) {
            self.id = UUID()
            self.date = date
        }
    }

    @Model
    final class DoctorQuestion {
        var id: UUID = UUID()
        var text: String = ""
        var createdAt: Date = Date()
        var askedAt: Date?
        var visit: Schema120.DoctorVisit?
        var baby: Schema120.Baby?

        init(text: String) {
            self.id = UUID()
            self.text = text
        }
    }
}

/// The shape of the store a 1.1.0 install holds: the 1.2.0 copy above without
/// the visits and questions. A phone that skips 1.2.0 migrates from this.
private enum Schema110: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)
    static var models: [any PersistentModel.Type] {
        [Baby.self, FeedingEntry.self, SleepEntry.self, DiaperEntry.self,
         GrowthEntry.self, CustomEvent.self]
    }

    @Model
    final class Baby {
        var id: UUID = UUID()
        var name: String = ""
        var birthDate: Date = Date()
        var gender: Gender120 = Gender120.female
        var feedingType: BabyFeedingType120 = BabyFeedingType120.breast
        var photoData: Data?
        var createdAt: Date = Date()
        var birthWeightKg: Double?
        var gestationalWeeks: Int?

        @Relationship(deleteRule: .cascade, inverse: \Schema110.FeedingEntry.baby) var feedingEntries: [Schema110.FeedingEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema110.SleepEntry.baby) var sleepEntries: [Schema110.SleepEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema110.DiaperEntry.baby) var diaperEntries: [Schema110.DiaperEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema110.GrowthEntry.baby) var growthEntries: [Schema110.GrowthEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Schema110.CustomEvent.baby) var customEvents: [Schema110.CustomEvent]? = []

        init(name: String, birthDate: Date) {
            self.id = UUID()
            self.name = name
            self.birthDate = birthDate
        }
    }

    @Model
    final class FeedingEntry {
        var id: UUID = UUID()
        var startTime: Date = Date()
        var endTime: Date?
        var type: FeedingType120 = FeedingType120.breast
        var side: BreastSide120?
        var volumeML: Double?
        var durationSeconds: Int?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema110.Baby?

        init(startTime: Date, type: FeedingType120) {
            self.id = UUID()
            self.startTime = startTime
            self.type = type
        }
    }

    @Model
    final class SleepEntry {
        var id: UUID = UUID()
        var startTime: Date = Date()
        var endTime: Date?
        var type: SleepType120 = SleepType120.nap
        var location: SleepLocation120?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema110.Baby?

        init(startTime: Date, type: SleepType120) {
            self.id = UUID()
            self.startTime = startTime
            self.type = type
        }
    }

    @Model
    final class DiaperEntry {
        var id: UUID = UUID()
        var time: Date = Date()
        var type: DiaperType120 = DiaperType120.wet
        var color: StoolColor120?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema110.Baby?

        init(time: Date, type: DiaperType120) {
            self.id = UUID()
            self.time = time
            self.type = type
        }
    }

    @Model
    final class GrowthEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var weightKg: Double?
        var heightCm: Double?
        var headCircumferenceCm: Double?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema110.Baby?

        init(date: Date) {
            self.id = UUID()
            self.date = date
        }
    }

    @Model
    final class CustomEvent {
        var id: UUID = UUID()
        var time: Date = Date()
        var type: EventType120 = EventType120.bath
        var mood: MoodLevel120?
        var medicationName: String?
        var medicationDose: String?
        var weatherNote: String?
        var durationMinutes: Int?
        var notes: String?
        var createdAt: Date = Date()
        var baby: Schema110.Baby?

        init(time: Date, type: EventType120) {
            self.id = UUID()
            self.time = time
            self.type = type
        }
    }
}

/// A store written by an older version, 1.2.0 or 1.1.0, opens under the
/// current schema with every row intact, and a medication event written back
/// then can be linked to a medicine afterwards. A plain SQLite store, as the
/// widget opens it: the CloudKit mirroring adds its own tables beside these.
@MainActor
final class StoreFromOlderVersionsTests: XCTestCase {

    private var directory: URL!
    private var url: URL { directory.appendingPathComponent("old.store") }
    private let doseTime = Date(timeIntervalSince1970: 1_780_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreFrom120-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    /// Its own function so the old container is released before the reopen.
    private func writeOldStore() throws {
        let schema = Schema(Schema120.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)

        let baby = Schema120.Baby(name: "Mia", birthDate: doseTime.addingTimeInterval(-90 * 86400))
        context.insert(baby)

        let feed = Schema120.FeedingEntry(startTime: doseTime.addingTimeInterval(-7200), type: .breast)
        feed.endTime = doseTime.addingTimeInterval(-6000)
        feed.baby = baby
        context.insert(feed)

        let sleep = Schema120.SleepEntry(startTime: doseTime.addingTimeInterval(-5000), type: .nap)
        sleep.baby = baby
        context.insert(sleep)

        let diaper = Schema120.DiaperEntry(time: doseTime.addingTimeInterval(-4000), type: .dirty)
        diaper.color = .green
        diaper.baby = baby
        context.insert(diaper)

        let growth = Schema120.GrowthEntry(date: doseTime.addingTimeInterval(-3000))
        growth.weightKg = 5.2
        growth.baby = baby
        context.insert(growth)

        let medication = Schema120.CustomEvent(time: doseTime, type: .medication)
        medication.medicationName = "Paracetamol"
        medication.medicationDose = "2.5 ml"
        medication.baby = baby
        context.insert(medication)

        let bath = Schema120.CustomEvent(time: doseTime.addingTimeInterval(-2000), type: .bath)
        bath.baby = baby
        context.insert(bath)

        let visit = Schema120.DoctorVisit(date: doseTime.addingTimeInterval(-86400))
        visit.baby = baby
        context.insert(visit)
        let question = Schema120.DoctorQuestion(text: "Tummy sleep?")
        question.baby = baby
        question.visit = visit
        context.insert(question)

        try context.save()
    }

    func testAStoreFromBeforeMedicinesOpensWithEveryRowAndTakesAMedicine() throws {
        try writeOldStore()

        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(schema: AppSchema.schema, url: url, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Baby>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FeedingEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SleepEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DiaperEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GrowthEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CustomEvent>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DoctorVisit>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DoctorQuestion>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Medicine>()), 0)

        let event = try XCTUnwrap(context.fetch(FetchDescriptor<CustomEvent>())
            .first { $0.type == .medication })
        XCTAssertEqual(event.medicationName, "Paracetamol")
        XCTAssertEqual(event.medicationDose, "2.5 ml")
        XCTAssertEqual(event.time, doseTime)
        XCTAssertNil(event.medicine)

        let visit = try XCTUnwrap(context.fetch(FetchDescriptor<DoctorVisit>()).first)
        XCTAssertEqual(visit.questions?.count, 1)
        XCTAssertEqual(visit.questions?.first?.text, "Tummy sleep?")

        let baby = try XCTUnwrap(context.fetch(FetchDescriptor<Baby>()).first)
        XCTAssertEqual(baby.feedingEntries?.count, 1)
        XCTAssertEqual(baby.sleepEntries?.count, 1)
        XCTAssertEqual(baby.diaperEntries?.count, 1)
        XCTAssertEqual(baby.diaperEntries?.first?.color, .green)
        XCTAssertEqual(baby.growthEntries?.count, 1)
        XCTAssertEqual(baby.customEvents?.count, 2)
        XCTAssertEqual(baby.doctorVisits?.count, 1)
        XCTAssertEqual(baby.doctorQuestions?.count, 1)
        XCTAssertEqual(baby.medicines?.count, 0)

        // The old medication event becomes a dose by linking it.
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
        medicine.baby = baby
        context.insert(medicine)
        event.medicine = medicine
        try context.save()
        XCTAssertEqual(medicine.doses?.count, 1)
        XCTAssertEqual(baby.medicines?.count, 1)
    }

    /// Its own function so the old container is released before the reopen.
    private func writeStore110() throws {
        let schema = Schema(Schema110.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        let baby = Schema110.Baby(name: "Mia", birthDate: doseTime.addingTimeInterval(-90 * 86400))
        context.insert(baby)
        let feed = Schema110.FeedingEntry(startTime: doseTime.addingTimeInterval(-7200), type: .formula)
        feed.volumeML = 120
        feed.baby = baby
        context.insert(feed)
        let medication = Schema110.CustomEvent(time: doseTime, type: .medication)
        medication.medicationName = "Paracetamol"
        medication.baby = baby
        context.insert(medication)
        try context.save()
    }

    /// A phone still on 1.1.0 that updates straight to this version.
    func testAStoreFrom110OpensWithEveryRowAndTakesAMedicine() throws {
        try writeStore110()

        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: ModelConfiguration(schema: AppSchema.schema, url: url, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Baby>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FeedingEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CustomEvent>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DoctorVisit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Medicine>()), 0)
        let feed = try XCTUnwrap(context.fetch(FetchDescriptor<FeedingEntry>()).first)
        XCTAssertEqual(feed.volumeML, 120)
        XCTAssertEqual(feed.type, .formula)

        let baby = try XCTUnwrap(context.fetch(FetchDescriptor<Baby>()).first)
        let event = try XCTUnwrap(context.fetch(FetchDescriptor<CustomEvent>()).first)
        XCTAssertEqual(event.medicationName, "Paracetamol")
        XCTAssertTrue(event.baby === baby)
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360)
        medicine.baby = baby
        context.insert(medicine)
        event.medicine = medicine
        try context.save()
        XCTAssertEqual(medicine.doses?.count, 1)
    }
}
