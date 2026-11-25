import SwiftUI
import SwiftData

/// What a screen scrolls to, and where VoiceOver focus goes, after a save:
/// the saved row, or the locked footer when the row is hidden by the window.
enum SavedRowTarget: Hashable {
    case row(PersistentIdentifier)
    case footer
}

/// The cue that names a saved row: scroll it into view, ring it for a
/// moment, move VoiceOver focus to it. Shared by Home and the Events history.
@MainActor
@Observable
final class SavedRowCueModel {
    var ringed: SavedRowTarget?
    /// A newer cue must not have its ring faded by an older one's timer.
    private var generation = 0
    /// Longer than the 0.25 s scroll; inside the 1.5 s the ring holds.
    static let focusDelay = 0.4

    /// - Parameters:
    ///   - ring: false for the footer, which is not the event.
    ///   - holdFromScrollEnd: Events starts its hold when the scroll ends;
    ///     Home counts from the start.
    ///   - focus: sets the screen's accessibility focus; it cannot live here.
    func run(_ target: SavedRowTarget,
             ring: Bool,
             holdFromScrollEnd: Bool,
             proxy: ScrollViewProxy,
             reduceMotion: Bool,
             focus: @MainActor (SavedRowTarget) -> Void) async {
        generation += 1
        let mine = generation
        // `anchor: nil` scrolls the least that shows the whole row, and not
        // at all when it is already on screen.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            proxy.scrollTo(target, anchor: nil)
        }
        if ring { ringed = target }
        // Focus after the scroll has ended and after UIKit has made its own
        // move (back to the sheet's button on a dismiss, to the screen on a
        // push): set at once, it is overridden and lands off the row.
        try? await Task.sleep(for: .seconds(Self.focusDelay))
        guard mine == generation else { return }
        focus(target)
        let scroll = holdFromScrollEnd && !reduceMotion ? 0.25 : 0
        try? await Task.sleep(for: .seconds(scroll + 1.5 - Self.focusDelay))
        guard mine == generation else { return }
        // The fade is an opacity change, so it stays with Reduce Motion.
        withAnimation(.easeOut(duration: 0.25)) { ringed = nil }
    }
}

enum SavedRowCue {
    /// What a history list cues for a saved event: its row when drawn (ringed);
    /// else the locked footer when the footer is shown and the event is older
    /// than the free window (no ring, the footer is not the event); else
    /// nothing, and the list opens at its top.
    static func target(highlight: PersistentIdentifier?,
                       rows: [PersistentIdentifier],
                       footerShown: Bool,
                       savedTime: Date?,
                       cutoff: Date?) -> (target: SavedRowTarget, ring: Bool)? {
        guard let highlight else { return nil }
        if rows.contains(highlight) { return (.row(highlight), true) }
        if footerShown, let savedTime, let cutoff, savedTime < cutoff { return (.footer, false) }
        return nil
    }
}

extension View {
    /// The scroll id of a ringed row, on a frame 2 pt larger than the row:
    /// the least scroll then shows the ring whole, not cut by the screen's
    /// edge. The outer padding gives the 2 pt back, so the layout is unchanged.
    func savedRowAnchor(_ target: SavedRowTarget) -> some View {
        padding(2).id(target).padding(-2)
    }

    /// A 2 pt ring outside the row, in the shape `bbSelectedBorder` draws.
    /// A ring leaves the row's text contrast alone, which a tint would not.
    /// Put it on a view the clip of `SwipeToDeleteRow` does not cut.
    func savedRowRing(_ on: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: BBTheme.Radius.md + 2)
                .strokeBorder(BBTheme.Colors.primary, lineWidth: 2)
                .padding(-2)
                .opacity(on ? 1 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
