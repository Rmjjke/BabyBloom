import XCTest
import SwiftUI
import UIKit
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
    /// page at that width, past both edges of a 320- or 375-pt screen. A
    /// landscape phone is less than 380 pt tall, so the same held for height.
    func testTheGroundTakesTheSizeItIsOffered() {
        let sizes = [CGSize(width: 320, height: 568), CGSize(width: 375, height: 667),
                     CGSize(width: 402, height: 874), CGSize(width: 568, height: 320)]
        for size in sizes {
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

    // MARK: - The setup page

    private let birth = Date().addingTimeInterval(-60 * 86_400)

    /// Russian on a 320-pt screen (a 548-pt page) at Large: the five rows fit,
    /// each whole on screen.
    func testTheSetupPageListsItsFiveStepsWhileTheyFit() throws {
        try requireSize(.large)
        LocalizationManager.shared.setLanguage(.ru)
        let screen = CGRect(x: 0, y: 0, width: 320, height: 548)
        let elements = accessibility.elements(try accessibility.host(setupPage(), size: screen.size))
        XCTAssertEqual(elements.filter { setupSteps().contains($0.label) }.count, 5, "\(elements)")
        XCTAssertTrue(elements.contains { $0.label == setupTitle() }, "no title in \(elements)")
        assertInside(screen, elements)
    }

    /// 320 × 380 leaves the five rows less height than they need, as the
    /// accessibility sizes do on a full page: the step in progress stands
    /// alone under the title, and the next one takes its place without moving
    /// the title. A long name sets the second step on two lines and the others
    /// on one, so a box that took each step's own height would move it.
    func testTheSetupPageShowsTheStepInProgressWhereTheRowsMiss() throws {
        try requireSize(.large)
        LocalizationManager.shared.setLanguage(.ru)
        let name = "Анастасия-Виктория"
        let screen = CGRect(x: 0, y: 0, width: 320, height: 380)
        let root = try accessibility.host(setupPage(name: name), size: screen.size)
        let steps = setupSteps(name: name)

        // The steps finish at 0.45, 1.45, 2.1, 3.3 and 3.85 s from the start.
        var seen: [String] = []
        var title: CGRect?
        for _ in 0..<14 {
            let elements = accessibility.elements(root)
            let shown = elements.filter { steps.contains($0.label) }
            XCTAssertEqual(shown.count, 1, "\(elements)")
            assertInside(screen, elements)
            if let label = shown.first?.label, seen.last != label { seen.append(label) }
            let found = try XCTUnwrap(elements.first { $0.label == setupTitle(name: name) }, "no title in \(elements)")
            if let title {
                XCTAssertEqual(found.frame.minY, title.minY, accuracy: 0.5, "the title moved at «\(seen.last ?? "")»")
                XCTAssertEqual(found.frame.height, title.height, accuracy: 0.5, "the title moved at «\(seen.last ?? "")»")
            }
            title = title ?? found.frame
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(seen.contains(steps[1]), "the two-line step was not shown: \(seen)")
        XCTAssertGreaterThanOrEqual(seen.count, 3, "the step did not move on: \(seen)")
    }

    /// Opt-in: runs with the device at AX2
    /// (`xcrun simctl ui <device> content_size accessibility-large`). On 320
    /// the five rows miss the page in each language and with Bold Text, so the
    /// page shows one step; on 375 the fit decides (English keeps its rows,
    /// ending at 613 of 647). Either way every word is on screen; the rows
    /// used to run past the bottom.
    func testTheSetupPageAtAX2KeepsEveryStepOnScreen() throws {
        try requireSize(.accessibilityLarge)
        let screens = [CGRect(x: 0, y: 0, width: 320, height: 548), CGRect(x: 0, y: 0, width: 375, height: 647)]
        let cases: [(language: SupportedLanguage, weight: LegibilityWeight)] = [
            (.ru, .regular), (.en, .regular), (.es, .regular), (.ru, .bold),
        ]
        for screen in screens {
            for c in cases {
                LocalizationManager.shared.setLanguage(c.language)
                let name = "\(c.language.rawValue) \(Int(screen.width)) \(c.weight == .bold ? "Bold" : "Regular")"
                let elements = accessibility.elements(try accessibility.host(
                    setupPage().environment(\.legibilityWeight, c.weight), size: screen.size))
                let shown = elements.filter { setupSteps().contains($0.label) }.count
                if screen.width == 320 {
                    XCTAssertEqual(shown, 1, "\(name): \(elements)")
                } else {
                    XCTAssertTrue(shown == 1 || shown == 5, "\(name): \(elements)")
                }
                XCTAssertTrue(elements.contains { $0.label == setupTitle() }, "\(name): no title")
                assertInside(screen, elements, name)
                accessibility.close()
            }
        }
    }

    /// The page on the flow's ground at the full size it is given: the
    /// hosting window may sit under the device's own safe area.
    private func setupPage(name: String = "Mia") -> some View {
        ZStack {
            OnboardingBackground()
            VStack(spacing: 0) { GeneratingPage(babyName: name, birthDate: birth, onDone: {}) }
        }
        .ignoresSafeArea()
    }

    private func setupSteps(name: String = "Mia") -> [String] {
        ["onboarding.gen.step1".l,
         String(format: "onboarding.gen.step_named".l, name, Baby.describeAge(from: birth)),
         "onboarding.gen.step2".l, "onboarding.gen.step3".l, "onboarding.gen.step4".l]
    }

    private func setupTitle(name: String = "Mia") -> String {
        String(format: "onboarding.gen.title_named".l, name)
    }

    private func assertInside(_ screen: CGRect, _ elements: [HostedAccessibility.Element], _ name: String = "",
                              file: StaticString = #filePath, line: UInt = #line) {
        for element in elements {
            XCTAssertTrue(screen.insetBy(dx: -0.5, dy: -0.5).contains(element.frame),
                          "\(name) \(element) is past the screen, \(screen.size)", file: file, line: line)
        }
    }

    private func requireSize(_ size: UIContentSizeCategory) throws {
        let current = UIApplication.shared.preferredContentSizeCategory
        try XCTSkipUnless(current == size, "the case is measured at \(size.rawValue); the device is at \(current.rawValue)")
    }
}
