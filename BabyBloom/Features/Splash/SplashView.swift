import SwiftUI

// MARK: - Branded Splash
// Staged reveal over the splash artwork (docs/design/splash4.png with the
// baked-in wordmark band stitched out -> BBSplashBg): first the art with the
// logo mark fades in, then the wordmark ("brand.name"), then the tagline.
// The wordmark is drawn as text, never baked into the PNG, so rebranding is a
// localization-token change only.
struct SplashView: View {
    let onDone: () -> Void

    @Environment(\.layoutDirection) private var direction
    @State private var bgVisible = false
    @State private var titleVisible = false
    @State private var taglineVisible = false
    @State private var fadingOut = false
    // The words' fitting size decides where they go. It changes with the
    // language only, so a rotation is laid out in one pass.
    @State private var wordsSize = CGSize.zero

    var body: some View {
        // Two readers. Only a reader inside the safe area reports the insets
        // (one that ignores it reads them as zero), and the words keep clear of
        // them. The inner reader ignores the safe area so that geo measures the
        // full screen: otherwise the artwork's frame stops at the safe-area edge
        // and the insets show as bare-colour bands around it.
        GeometryReader { safe in
            GeometryReader { geo in
                let layout = SplashLayout(size: geo.size, insets: safe.safeAreaInsets,
                                          stack: wordsSize, rightToLeft: direction == .rightToLeft)
                ZStack {
                    Color("BBLaunchBackground")

                    // Stage 1: artwork (leaves, ring, wave, logo mark baked in).
                    // One modifier chain in every layout, the mask included: the
                    // view keeps its identity through a rotation and the reveal
                    // goes on where it was.
                    Image("BBSplashBg")
                        .resizable()
                        .frame(width: layout.artFrame.width, height: layout.artFrame.height)
                        .mask {
                            // Only the alpha counts: a faded side shows the
                            // launch colour behind the art.
                            LinearGradient(
                                stops: SplashLayout.fadeStops(left: layout.fadesLeft, right: layout.fadesRight)
                                    .map { Gradient.Stop(color: .black.opacity($0.opacity), location: $0.location) },
                                startPoint: .leading, endPoint: .trailing)
                        }
                        .position(x: layout.artFrame.midX, y: layout.artFrame.midY)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(bgVisible ? 1 : 0)
                        .scaleEffect(bgVisible ? 1.0 : 1.06)
                        // Decorative, as are the tagline's leaves: VoiceOver
                        // reads the splash's words only.
                        .accessibilityHidden(true)

                    VStack(spacing: 16) {
                        // Stage 2: wordmark
                        Text("brand.name".l)
                            .font(.system(size: 42, weight: .semibold, design: .serif))
                            .foregroundStyle(Color("BBSplashText"))
                            .opacity(titleVisible ? 1 : 0)
                            .offset(y: titleVisible ? 0 : 18)

                        // Stage 3: tagline with leaf flourishes (as in the mockup)
                        HStack(spacing: 10) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 9))
                                .scaleEffect(x: -1)
                                .accessibilityHidden(true)
                            Text("splash.tagline".l.uppercased())
                                .font(.system(size: 14, weight: .medium))
                                .tracking(BBTheme.Typography.tracking(4.5))
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 9))
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(Color("BBSplashText"))
                        .opacity(taglineVisible ? 1 : 0)
                        .offset(y: taglineVisible ? 0 : 12)
                    }
                    .environment(\.layoutDirection, direction)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { wordsSize = $0 }
                    // Their ink is a deep violet in both modes: the art does not
                    // change with the mode, and cream over the field and its white
                    // clouds read 1.0–1.2.
                    .position(layout.stackCenter)
                }
                // The layout's frames are absolute and the art is never mirrored,
                // so nothing above may flip in a right-to-left language; the
                // words get the language's direction back.
                .environment(\.layoutDirection, .leftToRight)
                .opacity(fadingOut ? 0 : 1)
            }
            .ignoresSafeArea()
        }
        .onAppear { play() }
    }

    private func play() {
        withAnimation(.easeOut(duration: 1.1).delay(0.15)) {
            bgVisible = true
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(1.5)) {
            titleVisible = true
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(2.3)) {
            taglineVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            withAnimation(.easeIn(duration: 0.35)) { fadingOut = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDone() }
        }
    }
}

// MARK: - Layout
/// Where the splash puts its art and its words in a window.
///
/// Where the words, below the crescent's lower rim at 82 % of the height, clear
/// the figure and the safe bottom, the art fills the window and the words lie
/// on the lavender field, as on a phone held upright. In a wide window (a phone
/// or a full iPad in landscape, iPad Split View 2/3) the filled art would put
/// them on its figure: there the figure and the words stand side by side,
/// centred as one group in the safe area, the figure leading, and the art's
/// sides inside the window fade into the launch colour.
struct SplashLayout {
    /// BBSplashBg's size in pixels and the box of its figure (the crescent, the
    /// baby, the sprout and their shadow), measured on the art. A new art means
    /// measuring the box again.
    static let art = CGSize(width: 941, height: 1362)
    static let figure = CGRect(x: 218, y: 362, width: 559, height: 628)

    /// The figure and the words keep this much from the safe edges, and `gap`
    /// between them.
    static let margin = BBTheme.Spacing.lg
    static let gap = BBTheme.Spacing.xl

    let isBeside: Bool
    let artFrame: CGRect
    /// The words' centre, in the window's own (left-to-right) coordinates.
    let stackCenter: CGPoint
    let fadesLeft: Bool
    let fadesRight: Bool

    init(size: CGSize, insets: EdgeInsets, stack: CGSize, rightToLeft: Bool) {
        let width = size.width, height = size.height
        let art = Self.art, figure = Self.figure
        let fill = max(width / art.width, height / art.height)

        let figureBottom = height / 2 + (figure.maxY - art.height / 2) * fill
        let wordsTop = height * 0.82 - stack.height / 2
        if wordsTop >= figureBottom && wordsTop + stack.height <= height - insets.bottom {
            isBeside = false
            artFrame = CGRect(x: (width - art.width * fill) / 2, y: (height - art.height * fill) / 2,
                              width: art.width * fill, height: art.height * fill)
            stackCenter = CGPoint(x: width / 2, y: height * 0.82)
            fadesLeft = false
            fadesRight = false
            return
        }

        let left = rightToLeft ? insets.trailing : insets.leading
        let right = rightToLeft ? insets.leading : insets.trailing
        let safeWidth = width - left - right
        let safeHeight = height - insets.top - insets.bottom
        // As large as the margins allow, never larger than the filled art.
        let scale = max(0, min(fill,
                               (safeHeight - 2 * Self.margin) / figure.height,
                               (safeWidth - 2 * Self.margin - Self.gap - stack.width) / figure.width))
        let figureWidth = figure.width * scale
        let groupLeft = left + (safeWidth - figureWidth - Self.gap - stack.width) / 2
        let centerY = insets.top + safeHeight / 2
        let figureLeft = rightToLeft ? groupLeft + stack.width + Self.gap : groupLeft
        let stackLeft = rightToLeft ? groupLeft : groupLeft + figureWidth + Self.gap

        isBeside = true
        artFrame = CGRect(x: figureLeft - figure.minX * scale, y: centerY - figure.midY * scale,
                          width: art.width * scale, height: art.height * scale)
        stackCenter = CGPoint(x: stackLeft + stack.width / 2, y: centerY)
        fadesLeft = artFrame.minX > 0
        fadesRight = artFrame.maxX < width
    }

    struct FadeStop: Equatable {
        let location: CGFloat
        let opacity: Double
    }

    /// The art's alpha across its width. A faded side ramps by smoothstep from
    /// the art's edge to the figure's, so the figure is never faded and no line
    /// shows where the art meets the field; a side outside the window stays opaque.
    static func fadeStops(left: Bool, right: Bool) -> [FadeStop] {
        let steps: [CGFloat] = [0, 0.25, 0.5, 0.75, 1]
        let smooth = { (p: CGFloat) in Double(p * p * (3 - 2 * p)) }
        let start = figure.minX / art.width, end = figure.maxX / art.width
        let leading = left
            ? steps.map { FadeStop(location: start * $0, opacity: smooth($0)) }
            : [FadeStop(location: 0, opacity: 1)]
        let trailing = right
            ? steps.map { FadeStop(location: end + (1 - end) * $0, opacity: 1 - smooth($0)) }
            : [FadeStop(location: 1, opacity: 1)]
        return leading + trailing
    }
}
