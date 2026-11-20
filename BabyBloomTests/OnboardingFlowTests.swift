import XCTest
import SwiftUI
import SwiftData
@testable import BabyBloom

/// The flow's shape: nine pages in a fixed order, the widgets page last, and
/// nothing in onboarding that needs the store.
@MainActor
final class OnboardingFlowTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        super.tearDown()
    }

    func testTheFlowIsNinePagesEndingOnTheWidgetsPage() {
        XCTAssertEqual(OnboardingStep.allCases, [
            .welcome, .name, .birth, .feeding, .growth,
            .fact, .growthShowcase, .notifications, .widgets,
        ])
        XCTAssertNil(OnboardingStep.widgets.next, "a page after the widgets page")
    }

    /// Walking forward from the welcome page visits every page once.
    func testNextWalksEveryPageOnce() {
        var walked: [OnboardingStep] = [.welcome]
        while let next = walked.last?.next { walked.append(next) }
        XCTAssertEqual(walked, OnboardingStep.allCases)
    }

    /// Every page, opened through the flow's own switch with no
    /// `SubscriptionManager` in the environment: a page that read it would stop
    /// the test process here, so no page of onboarding can load products, show
    /// a price or wait on an entitlement.
    func testEveryPageRunsWithoutTheStore() throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        LocalizationManager.shared.setLanguage(.en)
        for step in OnboardingStep.allCases {
            let root = try accessibility.host(OnboardingView(onComplete: {}, startingAt: step).modelContainer(container),
                                              size: CGSize(width: 390, height: 844))
            // The pages spring in from zero opacity after a 0.1 s delay.
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            let elements = accessibility.elements(root)
            XCTAssertFalse(elements.isEmpty, "\(step): nothing on the page")
            if step == .welcome {
                XCTAssertTrue(elements.contains { $0.label.contains("button.start".l) }, "no welcome page in \(elements)")
            }
            if step == .widgets {
                XCTAssertTrue(elements.contains { $0.label.contains("onboarding.widget.cta".l) },
                              "no finishing button on the last page in \(elements)")
            }
            accessibility.close()
        }
    }
}
