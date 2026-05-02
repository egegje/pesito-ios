import SwiftUI

// Top-level router. Order of decisions:
//   1. Splash while AppStore is loading
//   2. Onboarding for first launch (UserDefaults flag, never re-shown)
//   3. Login (phone → OTP) if no session
//   4. MainTabsView with Home / Apply / Account once authenticated
struct RootView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("seenOnboarding") private var seenOnboarding: Bool = false

    var body: some View {
        Group {
            switch store.screen {
            case .loading:
                SplashView()
            case .login(let p):
                if seenOnboarding {
                    LoginPhoneView(phone: p)
                } else {
                    OnboardingView(done: $seenOnboarding)
                }
            case .otp(let p):
                LoginOTPView(phone: p)
            case .dashboard:
                MainTabsView()
            }
        }
        .preferredColorScheme(.light)
        .background(PesitoColor.bg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: store.screenKey)
    }
}
