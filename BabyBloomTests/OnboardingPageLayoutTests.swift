import XCTest
import SwiftUI
@testable import BabyBloom

/// The onboarding pages are laid out at the screen's width, and the pages with
/// a button of their own keep it on screen when their content is taller than
/// the room above it.
@MainActor
final class OnboardingPageLayoutTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// The ground's blobs are larger than a small phone. As layout children
    /// they made the flow's stack 380 pt wide, and the stack then placed every
    /// page at that width, past both edges of a 320- or 375-pt screen.
    func testTheGroundTakesTheSizeItIsOffered() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)] {
            let fit = UIHostingController(rootView: OnboardingBackground()).sizeThatFits(in: size)
            XCTAssertEqual(fit.width, size.width, accuracy: 0.5, "\(size)")
            XCTAssertEqual(fit.height, size.height, accuracy: 0.5, "\(size)")
        }
    }

    /// 320 × 380 at the default text size leaves the content less height than
    /// it needs, as AX2 does on a 568-pt screen: the content scrolls and the
    /// button stays whole on screen; nothing reaches past either side.
    func testTheButtonStaysOnScreenWhenTheContentIsTallerThanTheRoom() throws {
        LocalizationManager.shared.setLanguage(.en)
        let screen = CGRect(x: 0, y: 0, width: 320, height: 380)
        let birth = Date().addingTimeInterval(-60 * 86_400)
        let pages: [(button: String, page: AnyView)] = [
            ("button.next".l, AnyView(FactPage(babyName: "Mia", birthDate: birth, feedingType: .breast, onContinue: {}))),
            ("onboarding.widget.cta".l, AnyView(WidgetShowcasePage(babyName: "Mia", onContinue: {}))),
        ]
        for (button, page) in pages {
            // The page on the flow's ground, as OnboardingView stacks them.
            let root = try accessibility.host(ZStack {
                OnboardingBackground()
                VStack(spacing: 0) { page }
            }, size: screen.size)
            let elements = accessibility.elements(root)
            let found = try XCTUnwrap(elements.first { $0.label.contains(button) }, "«\(button)» is not in the tree")
            XCTAssertTrue(screen.contains(found.frame), "«\(button)» at \(found.frame), screen \(screen.size)")
            for element in elements {
                XCTAssertGreaterThanOrEqual(element.frame.minX, -0.5, "\(element)")
                XCTAssertLessThanOrEqual(element.frame.maxX, screen.width + 0.5, "\(element)")
            }
            accessibility.close()
        }
    }
}
