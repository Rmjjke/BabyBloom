import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// A primary or secondary button keeps its label md 16 inside each side: a
/// label longer than that room wraps between words, centred, and the button
/// grows past its 56 pt to hold it.
@MainActor
final class BBButtonInsetTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        super.tearDown()
    }

    /// The Russian trial offer in a 272-pt button (a 320-pt screen) at Large:
    /// two centred lines inside 16…256 and 8 pt above and below. The one-line
    /// label used to run to within a point of both edges.
    func testTheTrialLabelWrapsInsideTheInsetOnASmallPhone() throws {
        try requireLarge()
        let title = "Попробовать 7\u{00A0}дн. бесплатно"
        let buttons: [(name: String, found: Ink)] = [
            ("primary", try ink(of: BBPrimaryButton(title, icon: "arrow.right") {},
                                ground: BBTheme.Colors.primary, label: BBTheme.Colors.onPrimary)),
            ("secondary", try ink(of: BBSecondaryButton(title, icon: "arrow.right") {},
                                  ground: BBTheme.Colors.surface, label: BBTheme.Colors.primary)),
        ]
        for (name, found) in buttons {
            let box = found.box
            XCTAssertGreaterThan(found.pixels, 50, "\(name): no label drawn")
            XCTAssertGreaterThanOrEqual(box.minX, 16 - 0.5, "\(name): the label starts at \(box.minX)")
            XCTAssertLessThanOrEqual(box.maxX, 256 + 0.5, "\(name): the label ends at \(box.maxX)")
            XCTAssertEqual(box.midX, 136, accuracy: 3, "\(name): the label is not centred, \(box)")
            // One line of 17 pt draws about 17 pt of ink, two about 37, three about 57.
            XCTAssertGreaterThan(box.height, 24, "\(name): one line, \(box)")
            XCTAssertLessThan(box.height, 48, "\(name): more than two lines, \(box)")
            XCTAssertGreaterThanOrEqual(box.minY, 8 - 0.5, "\(name): \(box) in \(found.height)")
            XCTAssertLessThanOrEqual(box.maxY, found.height - 8 + 0.5, "\(name): \(box) in \(found.height)")
            XCTAssertGreaterThanOrEqual(found.height, 56, name)
            XCTAssertLessThanOrEqual(found.height, 60, name)
        }
    }

    /// While it loads, the button shows its spinner alone.
    func testTheLoadingButtonShowsItsSpinnerAlone() throws {
        let title = "Экспортировать"
        for loading in [false, true] {
            let root = try accessibility.host(
                BBPrimaryButton(title, icon: "square.and.arrow.up", isLoading: loading) {}.frame(width: 272),
                size: CGSize(width: 320, height: 200))
            let labels = accessibility.elements(root).map(\.label)
            XCTAssertEqual(labels.contains { $0.contains(title) }, !loading, "loading \(loading): \(labels)")
            accessibility.close()
        }
    }

    // MARK: - Reading the drawn label

    private struct Ink {
        /// The label's drawn pixels, in points from the button's top-left corner.
        let box: CGRect
        let pixels: Int
        /// The button's height.
        let height: CGFloat
    }

    /// Draws the button 272 pt wide on its ground and finds the pixels of the
    /// label's colour inside it. The button's own fill, sampled 2 pt under its
    /// top edge, is the reference; a pixel counts as label past halfway from
    /// the fill to the label's colour, so the edges' smoothing is not counted
    /// and the secondary's 1.5-pt stroke is skipped by starting 3 pt in.
    private func ink<V: View>(of button: V, ground: Color, label: Color) throws -> Ink {
        let margin: CGFloat = 20, width: CGFloat = 272
        let renderer = ImageRenderer(content: button
            .frame(width: width)
            .padding(margin)
            .background(ground)
            .environment(\.colorScheme, .light))
        renderer.scale = UIScreen.main.scale
        let image = try XCTUnwrap(renderer.cgImage)
        let scale = renderer.scale
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(
                data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        func rgb(_ x: Int, _ y: Int) -> SIMD3<Double> {
            let i = (y * w + x) * 4
            return SIMD3(Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2]))
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(label).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        let target = SIMD3(Double(r), Double(g), Double(b)) * 255

        let height = CGFloat(h) / scale - 2 * margin
        let px = { (points: CGFloat) in Int((points * scale).rounded()) }
        let fill = rgb(px(margin + width / 2), px(margin + 2))
        let toward = target - fill
        let reach = (toward * toward).sum()
        XCTAssertGreaterThan(reach, 40 * 40, "the label's colour is too close to the fill to tell apart")

        var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min, count = 0
        for y in px(margin + 3)..<px(margin + height - 3) {
            for x in px(margin + 3)..<px(margin + width - 3) {
                let t = ((rgb(x, y) - fill) * toward).sum() / reach
                guard t > 0.5 else { continue }
                count += 1
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard count > 0 else { return Ink(box: .zero, pixels: 0, height: height) }
        let box = CGRect(x: CGFloat(minX) / scale - margin, y: CGFloat(minY) / scale - margin,
                         width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
        return Ink(box: box, pixels: count, height: height)
    }

    private func requireLarge() throws {
        try XCTSkipUnless(UIApplication.shared.preferredContentSizeCategory == .large,
                          "the case is measured at Large; the device is at "
                          + UIApplication.shared.preferredContentSizeCategory.rawValue)
    }
}
