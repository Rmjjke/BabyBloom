import SwiftUI

// MARK: - BrandMark

/// The one brand badge: `BBLogo` clipped to a circle.
///
/// `BBLogo` is square app-icon art carrying its own opaque background. Dropped
/// raw into a layout it reads as a screenshot of the icon; clipped to a circle
/// that same background becomes the badge's fill, so the crop reads as a
/// deliberate round mark instead of an unstyled asset. Every placement in the
/// app goes through here so the four surfaces cannot drift apart again.
struct BrandMark: View {
    let diameter: CGFloat
    /// Over the premium gradient a primary-tinted ring disappears into the
    /// violet; white at low opacity is the same documented gradient-context
    /// exception the widget already relies on.
    var onGradient: Bool = false
    /// The card shadow is diffuse (r20, y8). Inside a tight progress ring it
    /// smudges the track instead of lifting the badge, so a host that frames
    /// the mark itself turns it off.
    var shadowed: Bool = true

    private var badge: some View {
        Image("BBLogo")
            .resizable()
            .scaledToFill()
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    onGradient ? Color.white.opacity(0.35)
                               : BBTheme.Colors.primary.opacity(0.25),
                    lineWidth: 1
                )
            )
    }

    @ViewBuilder
    var body: some View {
        if shadowed {
            badge.bbShadow(BBTheme.Shadow.card)
        } else {
            badge
        }
    }
}
