import SwiftUI

/// The one padlock treatment in the app. Every gate draws this — the Dashboard
/// quick action, the Events toolbar plus, the Events quick-add tiles — so the
/// user learns a single shape instead of three near-misses.
///
/// The surface-coloured disc is load-bearing: without it the glyph sits
/// directly on a tinted circle or a coloured symbol and reads as part of the
/// icon rather than as an overlay on top of it.
///
/// The badge carries no accessibility of its own — a decorative image VoiceOver
/// must not announce. The *enclosing button* speaks instead, via
/// `bbLockedAccessibility(_:)`; placing the words there is what keeps them in
/// the same element as the button's title.
struct LockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .padding(4)
            .background(Circle().fill(BBTheme.Colors.surface))
            .accessibilityHidden(true)
    }
}

extension View {
    /// Says "locked" to VoiceOver, which cannot see the padlock.
    ///
    /// Without it a gated control reads "Events, button", the user taps, and
    /// gets a paywall — the exact bait-and-switch the visible badge exists to
    /// prevent, done only to blind users. A *value* rather than a replacement
    /// label so the control keeps its own title and the gate is appended to it.
    @ViewBuilder
    func bbLockedAccessibility(_ locked: Bool) -> some View {
        if locked {
            accessibilityValue(Text("premium.locked_a11y".l))
        } else {
            self
        }
    }
}
