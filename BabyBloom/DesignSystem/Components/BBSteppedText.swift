import SwiftUI

/// A heading in one of the theme's faces that never breaks inside a word.
///
/// It wraps between words at the reader's size; only a word wider than the
/// whole width it is given (es «Medicamentos» in a report card on a 320-pt
/// screen at AX2) sets it a size smaller, from AX1's down to
/// Large's, the steps `PercentileLabel` takes. The theme's fonts scale by the
/// process's content size, so `.dynamicTypeSize` cannot step them: each try
/// is the face at a smaller category's point size, never more than the
/// reader's own. Where every word fits it draws exactly as the plain face.
///
/// A caller that can move a neighbour out of the heading's line (a badge,
/// a glyph) does that first and steps only what still misses.
struct BBSteppedText: View {
    /// A type-scale face, as `BBTheme.Typography` builds it.
    struct Face {
        let size: CGFloat
        let style: UIFont.TextStyle
        let weight: Font.Weight
        let design: Font.Design

        /// `BBTheme.Typography.title3`.
        static let title3 = Face(size: 18, style: .headline, weight: .semibold, design: .default)

        func font(_ pointSize: CGFloat) -> Font {
            .system(size: pointSize, weight: weight, design: design)
        }
    }

    let text: String
    var face: Face = .title3
    /// Measures a word that already holds a hyphen by its parts, where the
    /// design system lets it break (de «WHO-Perzentilen»).
    var breaksAfterHyphens = false
    /// Off draws the reader's size only, for a layout that tries the heading
    /// beside a neighbour before it moves the neighbour away.
    var stepping = true
    /// The text size the heading is set for; nil follows the device.
    var category: UIContentSizeCategory? = nil

    init(_ text: String, face: Face = .title3, breaksAfterHyphens: Bool = false, stepping: Bool = true,
         category: UIContentSizeCategory? = nil) {
        self.text = text
        self.face = face
        self.breaksAfterHyphens = breaksAfterHyphens
        self.stepping = stepping
        self.category = category
    }

    var body: some View {
        Group {
            if stepping {
                // Each try's ideal width is its widest word's: a size is
                // passed over only when a word misses the width.
                ViewThatFits(in: .horizontal) {
                    heading(size: naturalSize)
                    heading(size: steppedSize(PercentileLabel.steps[0]))
                    heading(size: steppedSize(PercentileLabel.steps[1]))
                    heading(size: steppedSize(PercentileLabel.steps[2]))
                    heading(size: steppedSize(PercentileLabel.steps[3]))
                    heading(size: steppedSize(PercentileLabel.steps[4]))
                }
            } else {
                heading(size: naturalSize)
            }
        }
        .wordFitTypesetting()
    }

    var naturalSize: CGFloat {
        BBTheme.Typography.scaledPointSize(face.size, relativeTo: face.style, for: category)
    }

    func steppedSize(_ step: UIContentSizeCategory) -> CGFloat {
        min(naturalSize, BBTheme.Typography.scaledPointSize(face.size, relativeTo: face.style, for: step))
    }

    /// One word a line, and a word cut after each hyphen it holds when that
    /// break is allowed.
    private var probe: String {
        let lines = text.oneWordALine
        return breaksAfterHyphens ? lines.replacingOccurrences(of: "-", with: "-\n") : lines
    }

    private func heading(size: CGFloat) -> some View {
        WidestWordIdeal {
            Text(probe).font(face.font(size)).hidden().accessibilityHidden(true)
            Text(text).font(face.font(size))
        }
    }
}
