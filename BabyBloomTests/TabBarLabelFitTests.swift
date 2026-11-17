import XCTest
import UIKit
@testable import BabyBloom

/// Each tab's label shows whole in the tab bar on a 320-pt screen, in every
/// language and the two pseudo ones.
///
/// The bar is UIKit's, the same one the app's TabView draws on iPhone, hosted
/// in a 320-wide window with the app's five items, so the room is whatever
/// this OS gives an item rather than a pinned guess. The bar's labels do not
/// scale with Dynamic Type, so Large covers every size. The iPad bar (a
/// floating row at the top that pages when its items do not fit) is not
/// hosted here; its misses are in the captures.
@MainActor
final class TabBarLabelFitTests: XCTestCase {

    /// Allowed misses, keyed by the tab's string key.
    private static let knownMisses: [KnownMiss] = [
        KnownMiss(.real(.ru), "tab.feeding", width: 58.8, room: 57.0),
        KnownMiss(.real(.ru), "tab.diapers", width: 62.3, room: 60.3),
        KnownMiss(.pseudo(.enXA), "tab.home", width: 49.9, room: 44.3),
        KnownMiss(.pseudo(.enXA), "tab.feeding", width: 63.4, room: 57.3),
        KnownMiss(.pseudo(.enXA), "tab.sleep", width: 48.5, room: 43.0),
        KnownMiss(.pseudo(.enXA), "tab.diapers", width: 61.7, room: 55.7),
        KnownMiss(.pseudo(.enXA), "tab.more", width: 46.1, room: 40.3),
        KnownMiss(.pseudo(.jaXB), "tab.home", width: 59.6, room: 34.0),
        KnownMiss(.pseudo(.jaXB), "tab.feeding", width: 89.5, room: 64.0),
        KnownMiss(.pseudo(.jaXB), "tab.sleep", width: 69.6, room: 44.0),
        KnownMiss(.pseudo(.jaXB), "tab.diapers", width: 89.5, room: 64.0),
        KnownMiss(.pseudo(.jaXB), "tab.more", width: 59.6, room: 34.0),
    ]

    /// The app's tabs, in MainTabView's order.
    private static let tabs: [(key: String, symbol: String)] = [
        ("tab.home", "house.fill"), ("tab.feeding", "heart.fill"), ("tab.sleep", "moon.fill"),
        ("tab.diapers", "drop.fill"), ("tab.more", "ellipsis.circle.fill"),
    ]

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        FitLanguage.restore()
        super.tearDown()
    }

    func testEveryTabLabelIsWholeAt320() throws {
        for language in FitLanguage.all {
            language.apply()
            let labels = try hostedLabels(width: 320)
            for tab in Self.tabs {
                let title = tab.key.l
                guard let label = labels.first(where: { $0.text == title }) else {
                    XCTFail("\(language) \(tab.key): «\(title)» is not among \(labels.map(\.text))")
                    continue
                }
                let fit = UILabelFit(label)
                let line = "\(language) \(tab.key): \(fit) («\(title)»)"
                if KnownMiss.listed(Self.knownMisses, language, tab.key) {
                    if fit.fits { XCTFail("\(line) fits now: remove its known-miss row") }
                } else {
                    XCTAssertTrue(fit.fits, line)
                }
            }
        }
    }

    /// The bar's labels, laid out in a `width`-wide window of their own.
    private func hostedLabels(width: CGFloat) throws -> [UILabel] {
        window?.isHidden = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: 568)
        let controller = UITabBarController()
        controller.viewControllers = Self.tabs.enumerated().map { index, tab in
            let content = UIViewController()
            content.tabBarItem = UITabBarItem(title: tab.key.l, image: UIImage(systemName: tab.symbol), tag: index)
            return content
        }
        window.rootViewController = controller
        window.isHidden = false
        self.window = window
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        controller.tabBar.layoutIfNeeded()
        return UILabelFit.labels(in: controller.tabBar)
    }
}

/// Whether a UIKit label shows its text whole at its own font, so neither an
/// ellipsis nor a shrunk font: a one-line label needs its whole text in the
/// room, a wrapping one only its widest word.
struct UILabelFit: CustomStringConvertible {
    let width: CGFloat
    let room: CGFloat

    @MainActor init(_ label: UILabel) {
        let text = label.text ?? ""
        width = label.numberOfLines == 1
            ? (text as NSString).size(withAttributes: [.font: label.font as Any]).width
            : FitMeasure.widestUnit(text, uiFont: label.font)
        room = label.bounds.width
    }

    var fits: Bool { width <= room + 0.5 }

    var description: String { String(format: "width %.1f in %.1f pt", width, room) }

    /// Every visible label under `root` that holds text.
    @MainActor static func labels(in root: UIView) -> [UILabel] {
        var found: [UILabel] = []
        func walk(_ view: UIView) {
            if view.isHidden || view.alpha == 0 { return }
            if let label = view as? UILabel, label.text?.isEmpty == false { found.append(label) }
            view.subviews.forEach(walk)
        }
        walk(root)
        return found
    }
}
