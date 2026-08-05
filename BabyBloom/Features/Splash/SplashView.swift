import SwiftUI

// MARK: - Branded Splash
// Staged reveal over the splash artwork (docs/design/splash4.png with the
// baked-in wordmark band stitched out -> BBSplashBg): first the art with the
// logo mark fades in, then the wordmark ("brand.name"), then the tagline.
// The wordmark is drawn as text, never baked into the PNG, so rebranding is a
// localization-token change only.
struct SplashView: View {
    let onDone: () -> Void

    @State private var bgVisible = false
    @State private var titleVisible = false
    @State private var taglineVisible = false
    @State private var fadingOut = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color("BBLaunchBackground")

                // Stage 1: artwork (leaves, ring, wave, logo mark baked in)
                Image("BBSplashBg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(bgVisible ? 1 : 0)
                    .scaleEffect(bgVisible ? 1.0 : 1.06)

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
                        Text("splash.tagline".l.uppercased())
                            .font(.system(size: 14, weight: .medium))
                            .tracking(4.5)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(Color("BBSplashText").opacity(0.85))
                    .opacity(taglineVisible ? 1 : 0)
                    .offset(y: taglineVisible ? 0 : 12)
                }
                // Sits below the crescent's lower rim so the cream text lands on
                // the lavender field rather than on the white artwork.
                .position(x: geo.size.width / 2, y: geo.size.height * 0.82)
            }
            .opacity(fadingOut ? 0 : 1)
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
