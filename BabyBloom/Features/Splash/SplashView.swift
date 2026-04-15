import SwiftUI

struct SplashView: View {
    let onDone: () -> Void

    private struct Scene {
        let image: String
        let captionKey: String
        let bgColor: Color
    }

    private let scenes: [Scene] = [
        Scene(image: "SplashScene1", captionKey: "splash.scene1",
              bgColor: Color(hex: "#1C1848").opacity(0.9)),
        Scene(image: "SplashScene2", captionKey: "splash.scene2",
              bgColor: Color(hex: "#D0ECFF").opacity(0.95)),
        Scene(image: "SplashScene3", captionKey: "splash.scene3",
              bgColor: Color(hex: "#FFF3E4").opacity(0.95)),
    ]

    @State private var current = 0
    @State private var sceneOpacity: Double = 0
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            scenes[current].bgColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.7), value: current)

            VStack(spacing: 0) {
                Spacer()

                Image(scenes[current].image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 340)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 28)
                    .opacity(sceneOpacity)
                    .scaleEffect(sceneOpacity == 1 ? 1.0 : 0.93)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: sceneOpacity)

                Text(scenes[current].captionKey.l)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "#4A3E88"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 28)
                    .opacity(sceneOpacity)
                    .animation(.easeIn(duration: 0.4).delay(0.15), value: sceneOpacity)

                Spacer()
                Spacer()

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(0..<scenes.count, id: \.self) { i in
                        Capsule()
                            .fill(i == current
                                  ? Color(hex: "#6B5EA8")
                                  : Color(hex: "#6B5EA8").opacity(0.25))
                            .frame(width: i == current ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: current)
                    }
                }
                .padding(.bottom, 20)
                .opacity(logoOpacity)

                // Logo lockup
                HStack(spacing: 8) {
                    Image("LaunchLogo")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                    Text("BabyBloom")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#6B5EA8"))
                }
                .opacity(logoOpacity)
                .padding(.bottom, 44)
            }
        }
        .onAppear { playScene(0) }
    }

    private func playScene(_ index: Int) {
        guard index < scenes.count else {
            withAnimation(.easeOut(duration: 0.35)) { logoOpacity = 0; sceneOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDone() }
            return
        }

        current = index
        sceneOpacity = 0

        withAnimation(.easeIn(duration: 0.5)) {
            sceneOpacity = 1
            logoOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) { sceneOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                playScene(index + 1)
            }
        }
    }
}
