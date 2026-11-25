import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// `BBFirstFit` shows its first shape alone while that fits the width, and
/// every shape of `otherwise` where it misses. The date-and-time row stands
/// on it: a `ViewThatFits` over all twelve of its shapes made and updated a
/// UIDatePicker for each on every show of the sheet, and the New Event sheet
/// opened a second after Feeding, Sleep and Diapers.
@MainActor
final class BBFirstFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        super.tearDown()
    }

    func testTheFirstShapeAloneWhereItFits() throws {
        let made = Made()
        let root = try accessibility.host(shapes(made), size: CGSize(width: 400, height: 200))
        let labels = accessibility.elements(root).map(\.label)
        XCTAssertTrue(labels.contains(Self.wide), "\(labels)")
        XCTAssertFalse(labels.contains(Self.narrow), "\(labels)")
    }

    /// A sheet's presentation lays its content out more than once, and a
    /// ViewThatFits there makes the UIKit view of a shape it never shows
    /// (once here, for each of twelve pickers in the date-and-time row).
    func testNoOtherShapeIsMadeInASheetWhereTheFirstFits() throws {
        let made = Made()
        _ = try accessibility.host(Color.clear.sheet(isPresented: .constant(true)) {
            ScrollView { VStack { self.shapes(made) } }
        }, size: CGSize(width: 402, height: 800))
        XCTAssertEqual(made.count, 0)
    }

    func testTheOtherShapesWhereTheFirstMisses() throws {
        let made = Made()
        let root = try accessibility.host(shapes(made), size: CGSize(width: 120, height: 200))
        let labels = accessibility.elements(root).map(\.label)
        XCTAssertTrue(labels.contains(Self.narrow), "\(labels)")
        XCTAssertFalse(labels.contains(Self.wide), "\(labels)")
        XCTAssertGreaterThan(made.count, 0)
    }

    private static let wide = "A shape far wider than the narrow window"
    private static let narrow = "Narrow"

    private func shapes(_ made: Made) -> some View {
        BBFirstFit {
            Text(Self.wide).fixedSize()
        } otherwise: {
            CountedLabel(text: Self.narrow, made: made)
        }
    }
}

/// How many times a `CountedLabel`'s UIKit view was made.
@MainActor
private final class Made {
    var count = 0
}

/// A UIKit-backed shape, as a compact date picker is, that counts its makes.
private struct CountedLabel: UIViewRepresentable {
    let text: String
    let made: Made

    func makeUIView(context: Context) -> UILabel {
        made.count += 1
        let label = UILabel()
        label.text = text
        label.isAccessibilityElement = true
        label.accessibilityLabel = text
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {}
}
