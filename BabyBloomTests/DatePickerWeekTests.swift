import XCTest
import SwiftUI
@testable import BabyBloom

/// The date pickers start their week on Monday in every language, as the
/// app's charts and weekly summary count weeks, whatever the phone's region.
@MainActor
final class DatePickerWeekTests: XCTestCase {
    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// 2 November 2026 is a Monday, 1 November a Sunday: in a Monday week the
    /// 2nd sits in the month grid's first column, left of the 1st's row end.
    func testTheGraphicalPickerPutsMondayFirst() throws {
        for language in [SupportedLanguage.en, .ru] {
            LocalizationManager.shared.setLanguage(language)
            let calendar = language.environmentCalendar
            let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12)))
            let picker = DatePicker("", selection: .constant(monday), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .appLanguageEnvironment(language)
            let root = try accessibility.host(picker, size: CGSize(width: 390, height: 520))
            let elements = accessibility.elements(root, automation: true)
            if ProcessInfo.processInfo.environment["BB_PICKER_DUMP"] != nil {
                elements.forEach { print("PICKER \(language.rawValue): \($0)") }
                let renderer = UIGraphicsImageRenderer(bounds: root.bounds)
                let image = renderer.image { _ in root.drawHierarchy(in: root.bounds, afterScreenUpdates: true) }
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("picker-\(language.rawValue).png")
                try image.pngData()?.write(to: url)
                print("PICKER_PNG=\(url.path)")
            }
            let days = elements.filter { $0.frame.width > 10 && $0.frame.width < 80 }
            let second = try XCTUnwrap(days.first { Self.isDay(2, $0.label) }, "\(language): no cell for the 2nd")
            let first = try XCTUnwrap(days.first { Self.isDay(1, $0.label) }, "\(language): no cell for the 1st")
            // Monday first: the 1st (a Sunday) closes the first row, the 2nd opens the next.
            XCTAssertGreaterThan(first.frame.minX, second.frame.minX, "\(language): the week does not start on Monday")
            XCTAssertGreaterThan(second.frame.minY, first.frame.minY, "\(language): the week does not start on Monday")
            accessibility.close()
        }
    }

    private static func isDay(_ day: Int, _ label: String) -> Bool {
        label.range(of: "(^|\\D)\(day)(\\D|$)", options: .regularExpression) != nil
    }
}
