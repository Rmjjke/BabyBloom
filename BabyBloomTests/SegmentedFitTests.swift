import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The segmented controls keep each segment's words whole on a 320-pt screen,
/// in every language and the two pseudo ones. Neither control's text scales
/// with Dynamic Type (UIKit's segments measure the same at Large and AX2), so
/// a run at the simulator's text size covers every size.
@MainActor
final class SegmentedFitTests: XCTestCase {

    /// Allowed misses, keyed by the segment's string key, with " bold" for a
    /// filter segment under Bold Text.
    private static let knownMisses: [KnownMiss] = [
        KnownMiss(.pseudo(.jaXB), "settings.appearance.light", width: 90.3, room: 77.0),
        KnownMiss(.pseudo(.enXA), "filter.month bold", width: 71.0, room: 68.5),
    ]

    private let screen = CGSize(width: 320, height: 568)
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        FitLanguage.restore()
        super.tearDown()
    }

    /// Settings' Appearance picker: UIKit's segmented control, hosted in a
    /// grouped list as Settings draws it, so the segment room is this OS's.
    func testAppearanceSegmentsAreWhole() throws {
        for language in FitLanguage.all {
            language.apply()
            let labels = try hostedAppearanceLabels(language)
            for option in AppAppearance.allCases {
                let title = option.labelKey.l
                guard let label = labels.first(where: { $0.text == title }) else {
                    XCTFail("\(language) \(option.labelKey): «\(title)» is not among \(labels.map(\.text))")
                    continue
                }
                check(language, option.labelKey, title, fits: UILabelFit(label))
            }
        }
    }

    /// The history filter: four equal segments in the screen's 16-pt margins,
    /// the bar's 4-pt padding and 2-pt gaps, at 13 pt rounded (semibold when
    /// selected, the wider); Bold Text is the heavier case.
    func testHistoryFilterSegmentsAreWhole() {
        let count = CGFloat(HistoryFilter.allCases.count)
        let room = (screen.width - 2 * 16 - 2 * 4 - (count - 1) * 2) / count
        let font = Font.system(size: 13, weight: .semibold, design: .rounded)
        for language in FitLanguage.all {
            language.apply()
            for filter in HistoryFilter.allCases {
                let title = filter.rawValue.l
                for bold in [false, true] {
                    let width = FitMeasure.widestUnit(title, font: font, bold: bold, locale: language.environmentLocale)
                    check(language, "\(filter.rawValue)\(bold ? " bold" : "")", title,
                          fits: UILabelFit(width: width, room: room))
                }
            }
        }
    }

    private func check(_ language: FitLanguage, _ key: String, _ title: String, fits: UILabelFit) {
        let line = "\(language) \(key): \(fits) («\(title)»)"
        if KnownMiss.listed(Self.knownMisses, language, key) {
            if fits.fits { XCTFail("\(line) fits now: remove its known-miss row") }
        } else {
            XCTAssertTrue(fits.fits, line)
        }
    }

    private func hostedAppearanceLabels(_ language: FitLanguage) throws -> [UILabel] {
        window?.isHidden = true
        let view = List {
            Section("settings.appearance".l) {
                Picker("settings.appearance".l, selection: .constant(AppAppearance.system.rawValue)) {
                    ForEach(AppAppearance.allCases) { option in
                        Label(option.labelKey.l, systemImage: option.symbolName).tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .environment(\.locale, language.environmentLocale)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: screen)
        let controller = UIHostingController(rootView: view)
        window.rootViewController = controller
        window.isHidden = false
        self.window = window
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let control = try XCTUnwrap(Self.segmentedControl(in: controller.view), "\(language): no segmented control")
        control.layoutIfNeeded()
        return UILabelFit.labels(in: control)
    }

    private static func segmentedControl(in view: UIView) -> UISegmentedControl? {
        if let control = view as? UISegmentedControl { return control }
        return view.subviews.lazy.compactMap(segmentedControl).first
    }
}

extension UILabelFit {
    init(width: CGFloat, room: CGFloat) {
        self.width = width
        self.room = room
    }
}
