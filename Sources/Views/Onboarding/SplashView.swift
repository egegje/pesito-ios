import SwiftUI

// 600ms branded splash shown while AppStore.bootstrap() decides whether
// to land on onboarding, login, or dashboard. Pure SwiftUI — no launch
// screen storyboard needed (we set UILaunchScreen with the cream color
// in Info.plist so the system launch is also on-brand).
struct SplashView: View {
    var body: some View {
        ZStack {
            PesitoColor.bg.ignoresSafeArea()
            VStack(spacing: PesitoSpace.md) {
                Text("pesito")
                    .font(.pesitoTitleXL)
                    .foregroundColor(PesitoColor.ink)
                Rectangle()
                    .fill(PesitoColor.brand)
                    .frame(width: 48, height: 6)
            }
        }
    }
}
