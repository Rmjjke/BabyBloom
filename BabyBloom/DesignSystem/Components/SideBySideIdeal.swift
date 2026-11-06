import SwiftUI

/// A side-by-side row, `HStack { icon; label; Spacer(minLength:); value }`,
/// whose ideal width is the least width at which both texts keep every word
/// whole. Under `ViewThatFits` the row then stands only where no word breaks,
/// and a card can put all its rows beside or all under by one decision.
///
/// Lays out its last subview, the row itself, and every concrete proposal
/// reaches it untouched, so a row that fits draws exactly as the bare stack.
/// The four subviews before it are hidden copies that only measure: the label,
/// the label one word a line, the value, the value one word a line, each in
/// the font the row draws it in.
struct SideBySideIdeal: Layout {
    /// What the row takes besides its two texts: the icon's column, the three
    /// gaps between the stack's four children and the spacer's least length.
    let chrome: CGFloat

    struct Cache {
        var ideal: CGFloat?
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let row = subviews[4]
        guard proposal.width == nil else { return row.sizeThatFits(proposal) }
        let ideal = cache.ideal ?? chrome + Self.leastRoom(label: Measure(subviews[0], words: subviews[1]),
                                                           value: Measure(subviews[2], words: subviews[3]))
        cache.ideal = ideal
        return row.sizeThatFits(ProposedViewSize(width: ideal, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        for copy in subviews.dropLast() {
            copy.place(at: bounds.origin, proposal: .zero)
        }
        subviews[4].place(at: bounds.origin,
                          proposal: proposal.width == nil ? ProposedViewSize(bounds.size) : proposal)
    }

    /// A text's widths, as the stack reads them.
    struct Measure {
        /// Offered any width: its one line.
        let oneLine: CGFloat
        /// Offered none. With `oneLine` it gives the text's flexibility, the
        /// order in which the stack offers its children room.
        let least: CGFloat
        let widestWord: CGFloat
        /// Offered a width: its widest line there.
        let width: (CGFloat) -> CGFloat
    }

    /// The least room for the two texts (the row less `chrome`) from which up
    /// neither breaks inside a word, divided as the stack divides it: the less
    /// flexible text is offered half and takes what it needs, and the other is
    /// offered the rest, never under half. So the first keeps its words from
    /// twice its widest word, and the second from wherever its share reaches
    /// its own widest word. Checked against a real stack in the tests.
    static func leastRoom(label: Measure, value: Measure) -> CGFloat {
        // A tie goes to the label, the stack's earlier child.
        let labelFirst = label.oneLine - label.least <= value.oneLine - value.least
        let first = labelFirst ? label : value
        let second = labelFirst ? value : label
        // From twice its one line the first takes that line, and the second's
        // share grows with the room.
        if second.widestWord >= first.oneLine {
            return first.oneLine + second.widestWord
        }
        // Below that the first wraps, and what it leaves goes up and down with
        // its lines. From twice the wider widest word both hold; walk down to
        // the first miss. A step is taken only when the second holds across
        // all of it: the first's width never shrinks as its share grows, so
        // the step's top bounds what the first takes anywhere in the step.
        let step: CGFloat = 0.5
        var room = 2 * max(first.widestWord, second.widestWord)
        while room - step >= 2 * first.widestWord,
              room - step - first.width(room / 2) >= second.widestWord {
            room -= step
        }
        return room
    }
}

extension SideBySideIdeal.Measure {
    init(_ text: LayoutSubview, words: LayoutSubview) {
        oneLine = text.sizeThatFits(.unspecified).width
        least = text.sizeThatFits(ProposedViewSize(width: 0, height: nil)).width
        widestWord = words.sizeThatFits(.unspecified).width
        width = { text.sizeThatFits(ProposedViewSize(width: $0, height: nil)).width }
    }
}

extension String {
    /// The text one word a line, so its ideal width is its widest word. Words
    /// part at plain spaces; a no-break space keeps a number with its unit.
    var oneWordALine: String {
        split(separator: " ").joined(separator: "\n")
    }
}
