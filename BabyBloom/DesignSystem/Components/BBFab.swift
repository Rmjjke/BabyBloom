import SwiftUI

// MARK: - BBFab
// Floating action button (D6). Reachable in the thumb zone (bottom-trailing)
// for one-handed "add" during night feeds. Mirrors the toolbar "+" action —
// both entry points open the same Add sheet, so the toolbar button stays.
//
// Placement contract: attach as `.overlay(alignment: .bottomTrailing)` on the
// screen's ScrollView with `.padding(.trailing/.bottom, .md)` so it floats md
// above the tab bar. Lists must keep a bottom content inset (≥ xxl) so their
// last row can scroll clear of the button — the FAB never permanently covers
// content.
struct BBFab: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(BBTheme.Colors.primary)
                .clipShape(Circle())
                .bbShadow(BBTheme.Shadow.button)
        }
        .buttonStyle(BBScaleButtonStyle())
        .accessibilityLabel("action.add".l)
    }
}
