import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The birth calendar's header at AX2: the month button and the
/// previous-month button stay apart, each with its own hit area, on a 320,
/// 375 and 402-pt phone in every language, with the month whose title is the
/// widest of those a birth date can fall in, with Bold Text off and on. Read
/// from the picker UIKit draws, so a change in the system's header shows here
/// first.
@MainActor
final class BirthCalendarHeaderTests: XCTestCase {

    private var windows: [UIWindow] = []

    override func tearDown() {
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows = []
        super.tearDown()
    }

    func testTheMonthButtonAndThePreviousMonthButtonStayApartAtAX2() throws {
        var misses: [String] = []
        var caps: [String] = []
        for bold in [false, true] {
        for width in [CGFloat(320), 375, 402] {
            for language in SupportedLanguage.allCases {
                try autoreleasepool {
                    let date = Self.widestMonth(language, bold: bold)
                    let root = try host(page(date: date, language: language, bold: bold), width: width, bold: bold)
                    defer { close() }
                    let name = "\(Int(width)) \(language.rawValue)\(bold ? " bold" : "")"
                    let header = try XCTUnwrap(Self.header(in: root), "\(name): no header")
                    let gap = header.previous.minX - header.title.maxX
                    let ink = header.previousArrow.minX - header.chevron.maxX
                    let pickerWidth = width - 2 * (BBTheme.Spacing.lg + BBTheme.Spacing.sm)
                    let cap = BirthCalendar.textSizeCap(width: pickerWidth,
                                                        locale: language.environmentLocale,
                                                        calendar: language.environmentCalendar, bold: bold)
                    caps.append(String(format: "%@: cap %@, title «%@» %.0f pt %@, arrow %.2f, chevron %.2f, label %.1f of %.1f, button gap %.1f, ink gap %.1f, day %.1f pt",
                                       name, "\(cap)", header.text, header.font, header.fontName,
                                       header.previous.width, header.chevron.width, header.labelWidth, header.textWidth, gap, ink, header.dayFont))
                    if gap < 0 {
                        misses.append(String(format: "%@: the buttons overlap by %.1f", name, -gap))
                    }
                    if ink < 12 {
                        misses.append(String(format: "%@: chevron and arrow %.1f apart", name, ink))
                    }
                    if header.dayFont < 15 {
                        misses.append(String(format: "%@: days drawn at %.1f pt", name, header.dayFont))
                    }
                    if header.bold != bold {
                        misses.append("\(name): the title is drawn \(header.fontName)")
                    }
                    // The cap's model reads the drawn header: where UIKit writes
                    // the title in full (it sometimes shortens a long month),
                    // its gap is the drawn one.
                    let year = language.environmentCalendar.component(.year, from: Date())
                    let fullTitles = [year - 1, year].flatMap {
                        BirthCalendar.monthTitles(locale: language.environmentLocale,
                                                  calendar: language.environmentCalendar, year: $0)
                    }
                    if fullTitles.contains(where: { $0.compare(header.text, options: .caseInsensitive) == .orderedSame }),
                       let metrics = BirthCalendar.headerMetrics.first(where: { abs($0.font - header.font) < 0.5 }) {
                        let model = BirthCalendar.headerGap(title: header.text, width: pickerWidth, metrics: metrics,
                                                            bold: bold)
                        if abs(model - gap) > 3 {
                            misses.append(String(format: "%@: model gap %.1f, drawn %.1f", name, model, gap))
                        }
                    }
                }
            }
        }
        }
        let attachment = XCTAttachment(string: caps.joined(separator: "\n"))
        attachment.name = "birth calendar caps at AX2"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("BIRTH_CALENDAR_CAPS\n" + caps.joined(separator: "\n"))
        XCTAssert(misses.isEmpty, "\(misses.count) misses:\n" + misses.joined(separator: "\n"))
    }

    // MARK: Scene

    /// The calendar as the birth page sets it: the card's 8-pt inset inside
    /// the page's 24-pt margins.
    private func page(date: Date, language: SupportedLanguage, bold: Bool) -> some View {
        VStack {
            BirthCalendar(date: .constant(date))
                .padding(BBTheme.Spacing.sm)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BBTheme.Spacing.lg)
        .environment(\.dynamicTypeSize, .accessibility2)
        .environment(\.legibilityWeight, bold ? .bold : .regular)
        .appLanguageEnvironment(language)
    }

    /// The 15th of the month, this year up to now or last year, whose title is
    /// the widest at the largest header size.
    private static func widestMonth(_ language: SupportedLanguage, bold: Bool) -> Date {
        let calendar = language.environmentCalendar
        let now = Date()
        let font = UIFont.systemFont(ofSize: BirthCalendar.headerMetrics[0].font, weight: bold ? .heavy : .semibold)
        let formatter = DateFormatter()
        formatter.locale = language.environmentLocale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        let year = calendar.component(.year, from: now)
        let dates = [year - 1, year].flatMap { y in
            (1...12).compactMap { calendar.date(from: DateComponents(year: y, month: $0, day: 15)) }
        }.filter { $0 <= now }
        return dates.max { a, b in
            (formatter.string(from: a) as NSString).size(withAttributes: [.font: font]).width
                < (formatter.string(from: b) as NSString).size(withAttributes: [.font: font]).width
        } ?? now
    }

    private func host<V: View>(_ view: V, width: CGFloat, bold: Bool) throws -> UIView {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: 900)
        // UIKit sizes the picker by the trait, SwiftUI's cap by the
        // environment: the window says AX2 as a phone set to it would.
        window.traitOverrides.preferredContentSizeCategory = .accessibilityLarge
        window.traitOverrides.legibilityWeight = bold ? .bold : .regular
        let controller = UIHostingController(rootView: view)
        window.rootViewController = controller
        window.isHidden = false
        windows.append(window)
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        return controller.view
    }

    private func close() {
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows = []
    }

    // MARK: Reading

    private struct Header {
        let title: CGRect
        let previous: CGRect
        let chevron: CGRect
        let previousArrow: CGRect
        let text: String
        let font: CGFloat
        let fontName: String
        let dayFont: CGFloat
        /// The label's frame and the width its text asks for: under Bold
        /// Text UIKit keeps the semibold frame and draws the title heavy.
        let labelWidth: CGFloat
        let textWidth: CGFloat
        var bold: Bool { fontName.hasSuffix("-Heavy") }
    }

    private static func header(in root: UIView) -> Header? {
        guard let titleButton = views(in: root, named: "_UICalendarHeaderTitleButton").first,
              let label = views(in: titleButton, named: "UILabel").first as? UILabel,
              let text = label.text, let font = label.font,
              let chevron = views(in: titleButton, named: "UIImageView").first else { return nil }
        let title = titleButton.convert(titleButton.bounds, to: nil)
        // The arrow buttons share the title's row; the nearer one goes back.
        guard let previousButton = views(in: root, named: "UIButton")
            .map({ ($0, $0.convert($0.bounds, to: nil)) })
            .filter({ abs($0.1.minY - title.minY) < 4 && $0.1.minX > title.minX })
            .min(by: { $0.1.minX < $1.1.minX }),
              let arrow = views(in: previousButton.0, named: "UIImageView").first else { return nil }
        // The day numbers: one or two digits, below the header.
        let dayFont = views(in: root, named: "UILabel").compactMap { $0 as? UILabel }
            .filter { day in
                guard let text = day.text, (1...2).contains(text.count), text.allSatisfy(\.isNumber) else { return false }
                return day.convert(day.bounds, to: nil).minY > title.maxY
            }
            .map { $0.font.pointSize }
            .min() ?? 0
        return Header(title: title, previous: previousButton.1,
                      chevron: chevron.convert(chevron.bounds, to: nil),
                      previousArrow: arrow.convert(arrow.bounds, to: nil),
                      text: text, font: font.pointSize, fontName: font.fontName,
                      dayFont: dayFont, labelWidth: label.bounds.width,
                      textWidth: label.intrinsicContentSize.width)
    }

    private static func views(in view: UIView, named name: String) -> [UIView] {
        var found: [UIView] = String(describing: type(of: view)) == name ? [view] : []
        for subview in view.subviews { found += views(in: subview, named: name) }
        return found
    }
}
