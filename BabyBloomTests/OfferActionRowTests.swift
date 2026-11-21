import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The offer card's action line keeps its chevron beside the label's last
/// word, in every language, at AX2 in a 320-pt phone's card (256 pt of text).
///
/// Read from a render: each line of the row is a band of drawn pixels, and a
/// last band no wider than the chevron is the chevron alone on its line. The
/// row as it was, label and chevron joined by a bare space, is drawn beside
/// it: where its chevron already shared the last line, the line count stays.
@MainActor
final class OfferActionRowTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private static let room: CGFloat = 256
    private static let category = UIContentSizeCategory.accessibilityLarge
    private static let scale: CGFloat = 2

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    func testTheChevronStaysWithTheLastWordAtAX2On320() throws {
        let chevron = try inkBands(of: Text(Image(systemName: "chevron.right"))
            .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .semibold, for: Self.category))
            .foregroundStyle(BBTheme.Colors.primary), language: .en).first?.width ?? 0
        XCTAssertGreaterThan(chevron, 4, "the chevron alone drew nothing")

        var misses: [String] = []
        var table: [String] = []
        for language in FitLanguage.all {
            language.apply()
            let row = try inkBands(of: BBOfferCard.actionRow(for: Self.category), language: language.base)
            let before = try inkBands(of: Self.spaceJoinedRow(), language: language.base)
            guard let last = row.last, let beforeLast = before.last else {
                misses.append("\(language): nothing drawn")
                continue
            }
            // Anything beside the chevron adds a space and a letter at least.
            let alone = last.width <= chevron + 6
            let wasAlone = beforeLast.width <= chevron + 6
            table.append("\(language): \(row.count) lines, last \(Int(last.width)) pt; space-joined \(before.count) lines\(wasAlone ? ", chevron alone" : "")")
            if alone {
                misses.append("\(language): the chevron stands alone on line \(row.count)")
            }
            if !wasAlone, row.count != before.count {
                misses.append("\(language): \(before.count) lines space-joined, \(row.count) now")
            }
        }
        // The reference must still show the fault, or the case proves nothing.
        XCTAssert(table.contains { $0.hasSuffix("chevron alone") },
                  "the space-joined row no longer leaves the chevron alone in any language")
        let attachment = XCTAttachment(string: table.joined(separator: "\n"))
        attachment.name = "offer action rows at AX2, 256 pt"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("OFFER_ACTION_ROWS\n" + table.joined(separator: "\n"))
        XCTAssert(misses.isEmpty, "\(misses.count) misses:\n" + misses.joined(separator: "\n"))
    }

    // MARK: Rows

    /// The row as it was: a bare space let the line break before the chevron.
    private static func spaceJoinedRow() -> some View {
        (Text("offer.cta".l)
            + Text("\u{2004}")
            + Text(Image(systemName: "chevron.right"))
                .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .semibold, for: category)))
            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, for: category))
            .foregroundStyle(BBTheme.Colors.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Reading

    private struct Band {
        let top: CGFloat
        let height: CGFloat
        let width: CGFloat
    }

    /// The drawn lines of `view` set `room` wide on white, top to bottom.
    private func inkBands(of view: some View, language: SupportedLanguage) throws -> [Band] {
        defer { accessibility.close() }
        let scene = VStack(alignment: .leading, spacing: 0) {
            view.frame(width: Self.room, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(width: 320, height: 700, alignment: .topLeading)
        .background(Color.white.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .appLanguageEnvironment(language)
        let root = try accessibility.host(scene, size: CGSize(width: 320, height: 700))
        let image = try XCTUnwrap(DrawnTextReader.render(root, scale: Self.scale))
        return bands(image)
    }

    private func bands(_ image: CGImage) -> [Band] {
        let width = image.width, height = image.height
        var gray = [UInt8](repeating: 255, count: width * height)
        gray.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        // The bitmap's first row is the image's top.
        var inked: [(row: Int, minX: Int, maxX: Int)] = []
        for row in 0..<height {
            let line = gray[(row * width)..<((row + 1) * width)]
            guard let first = line.firstIndex(where: { $0 < 230 }) else { continue }
            let last = line.lastIndex(where: { $0 < 230 })!
            inked.append((row, first - row * width, last - row * width))
        }
        var result: [Band] = []
        var start: (row: Int, minX: Int, maxX: Int)?
        var previous = -2
        var minX = Int.max, maxX = Int.min
        func close() {
            guard let begin = start else { return }
            result.append(Band(top: CGFloat(begin.row) / Self.scale,
                               height: CGFloat(previous - begin.row + 1) / Self.scale,
                               width: CGFloat(maxX - minX + 1) / Self.scale))
        }
        for entry in inked {
            if entry.row != previous + 1 {
                close()
                start = entry
                minX = .max
                maxX = .min
            }
            minX = min(minX, entry.minX)
            maxX = max(maxX, entry.maxX)
            previous = entry.row
        }
        close()
        return result
    }
}
