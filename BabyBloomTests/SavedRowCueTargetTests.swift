import XCTest
import SwiftData
@testable import BabyBloom

/// What a history list cues for a saved event.
@MainActor
final class SavedRowCueTargetTests: XCTestCase {

    private func ids(_ count: Int) throws -> [PersistentIdentifier] {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        let events = (0..<count).map { CustomEvent(time: Date(timeIntervalSince1970: Double($0)), type: .bath) }
        events.forEach(context.insert)
        try context.save()
        return events.map(\.persistentModelID)
    }

    private let cutoff = Date(timeIntervalSince1970: 1_000_000)

    func testADrawnRowIsRinged() throws {
        let all = try ids(3)
        let result = SavedRowCue.target(highlight: all[1], rows: all, footerShown: true,
                                        savedTime: Date(timeIntervalSince1970: 2_000_000), cutoff: cutoff)
        XCTAssertEqual(result?.target, .row(all[1]))
        XCTAssertEqual(result?.ring, true)
    }

    func testARowTheWindowHidesCuesTheFooterWithNoRing() throws {
        let all = try ids(3)
        let result = SavedRowCue.target(highlight: all[2], rows: [all[0]], footerShown: true,
                                        savedTime: Date(timeIntervalSince1970: 500_000), cutoff: cutoff)
        XCTAssertEqual(result?.target, .footer)
        XCTAssertEqual(result?.ring, false)
    }

    func testARowBeyondTheCapWithNoFooterCuesNothing() throws {
        let all = try ids(3)
        let result = SavedRowCue.target(highlight: all[2], rows: [all[0]], footerShown: false,
                                        savedTime: Date(timeIntervalSince1970: 2_000_000), cutoff: cutoff)
        XCTAssertNil(result)
    }

    func testARecentRowBeyondTheCapIgnoresTheFooter() throws {
        let all = try ids(3)
        let result = SavedRowCue.target(highlight: all[2], rows: [all[0]], footerShown: true,
                                        savedTime: Date(timeIntervalSince1970: 2_000_000), cutoff: cutoff)
        XCTAssertNil(result)
    }

    func testAFooterWithNoSavedTimeCuesNothing() throws {
        let all = try ids(3)
        XCTAssertNil(SavedRowCue.target(highlight: all[2], rows: [all[0]], footerShown: true,
                                        savedTime: nil, cutoff: cutoff))
    }

    func testPremiumHasNoCutoffSoAHiddenRowCuesNothing() throws {
        let all = try ids(3)
        XCTAssertNil(SavedRowCue.target(highlight: all[2], rows: [all[0]], footerShown: true,
                                        savedTime: Date(timeIntervalSince1970: 500_000), cutoff: nil))
    }

    func testNoHighlightCuesNothing() throws {
        let all = try ids(2)
        XCTAssertNil(SavedRowCue.target(highlight: nil, rows: all, footerShown: true,
                                        savedTime: nil, cutoff: cutoff))
    }
}
