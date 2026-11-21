import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// A tile that shows its choice by the selection ring alone tells VoiceOver
/// it is selected: the ring carries the Selected trait, the button takes it,
/// and only the drawn-selected tile has it.
@MainActor
final class SelectedTraitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private static let screen = CGSize(width: 402, height: 1400)

    override func tearDown() {
        accessibility.close()
        super.tearDown()
    }

    func testTheRingGivesItsButtonTheSelectedTrait() throws {
        for shape in [BBSelectionShape.tile, .capsule] {
            let scene = VStack {
                Button {} label: { Text("Ringed").padding().bbSelectedBorder(true, shape: shape) }
                Button {} label: { Text("Plain").padding().bbSelectedBorder(false, shape: shape) }
            }
            let elements = accessibility.elements(try accessibility.host(scene, size: Self.screen))
            accessibility.close()
            let ringed = try XCTUnwrap(elements.first { $0.label == "Ringed" })
            let plain = try XCTUnwrap(elements.first { $0.label == "Plain" })
            XCTAssert(ringed.traits.contains(.selected), "\(shape): the ringed tile is not Selected")
            XCTAssert(ringed.traits.contains(.button), "\(shape): the ringed tile is no longer a button")
            XCTAssertFalse(plain.traits.contains(.selected), "\(shape): the plain tile is Selected")
        }
    }

    func testOnlyTheChosenGenderTileIsSelected() throws {
        let page = BirthPage(birthDate: .constant(Date().addingTimeInterval(-86_400 * 10)), gender: .constant(.female),
                             gestationalWeeks: .constant(39), wasBornEarly: .constant(false), onBack: {})
        let elements = accessibility.elements(try accessibility.host(page, size: Self.screen))
        for gender in Baby.Gender.allCases {
            let tiles = elements.filter { $0.traits.contains(.button) && $0.label.contains(gender.displayName.l) }
            XCTAssertEqual(tiles.count, 1, "\(gender): \(tiles)")
            XCTAssertEqual(tiles.first?.traits.contains(.selected), gender == .female, "\(gender)")
        }
    }

    /// Said once: the row's check mark, drawn on the chosen row, is silent,
    /// so the row is one element and Selected is its trait, not a word.
    func testOnlyTheChosenFeedingRowIsSelectedAndSaysItOnce() throws {
        let page = FeedingPage(feedingType: .constant(.formula), babyName: "Mia", onBack: {})
        let elements = accessibility.elements(try accessibility.host(page, size: Self.screen))
        for type in Baby.FeedingType.allCases {
            let name = type.displayName.l
            let rows = elements.filter { $0.label.contains(name) }
            XCTAssertEqual(rows.count, 1, "\(type): \(rows)")
            guard let row = rows.first else { continue }
            XCTAssertEqual(row.label, name, "\(type): the row says more than its name")
            XCTAssert(row.traits.contains(.button), "\(type)")
            XCTAssertEqual(row.traits.contains(.selected), type == .formula, "\(type)")
        }
    }
}
