import SwiftUI

// MARK: - Branded Splash
// Staged reveal: logo mark → wordmark → tagline, then hands off to the app.
// Visual source: docs/design/splash2.png (sage/mint botanical direction).
struct SplashView: View {
    let onDone: () -> Void

    @State private var logoVisible = false
    @State private var titleVisible = false
    @State private var taglineVisible = false
    @State private var fadingOut = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#EDF6EF"), Color("BBLaunchBackground"), Color(hex: "#CDE5D6")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo mark, feathered into the background
                Image("BBLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .mask(
                        RadialGradient(
                            colors: [.black, .black, .clear],
                            center: .center, startRadius: 0, endRadius: 120
                        )
                    )
                    .opacity(logoVisible ? 1 : 0)
                    .scaleEffect(logoVisible ? 1.0 : 0.86)

                // Wordmark
                Text("BabyBloom")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .foregroundStyle(BBTheme.Colors.primary)
                    .padding(.top, 8)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 12)

                // Tagline
                Text("splash.tagline".l.uppercased())
                    .font(.system(size: 13, weight: .medium))
                    .tracking(4)
                    .foregroundStyle(BBTheme.Colors.primary.opacity(0.65))
                    .padding(.top, 14)
                    .opacity(taglineVisible ? 1 : 0)
                    .offset(y: taglineVisible ? 0 : 8)

                Spacer()
                Spacer()
            }
            .opacity(fadingOut ? 0 : 1)
        }
        .onAppear { play() }
    }

    private func play() {
        withAnimation(.spring(response: 0.65, dampingFraction: 0.75).delay(0.15)) {
            logoVisible = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.85)) {
            titleVisible = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(1.35)) {
            taglineVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.9) {
            withAnimation(.easeIn(duration: 0.35)) { fadingOut = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDone() }
        }
    }
}
