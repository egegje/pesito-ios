import SwiftUI

// Bottom tab bar shown after login. 4 tabs:
//   Home    — active loan + next payment
//   Solicitar — start a new application (or resume draft)
//   Historial — past loans + payments
//   Cuenta   — profile + settings + logout
struct MainTabsView: View {
    @State private var tab: Tab = .home
    enum Tab: Hashable { case home, apply, history, account }

    init() {
        // SwiftUI TabView's default look is glass + blur. We want a solid
        // cream bar with ink-on-cream icons to keep editorial tone.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.965, green: 0.945, blue: 0.910, alpha: 1.0)
        appearance.shadowColor = UIColor(red: 0.870, green: 0.840, blue: 0.790, alpha: 1.0)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(red: 0.835, green: 0.380, blue: 0.220, alpha: 1.0)
        UITabBar.appearance().unselectedItemTintColor = UIColor(red: 0.460, green: 0.420, blue: 0.360, alpha: 1.0)
    }

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Inicio", systemImage: "house") }
                .tag(Tab.home)

            ApplyView()
                .tabItem { Label("Solicitar", systemImage: "doc.text") }
                .tag(Tab.apply)

            HistoryView()
                .tabItem { Label("Historial", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            AccountView()
                .tabItem { Label("Cuenta", systemImage: "person.crop.circle") }
                .tag(Tab.account)
        }
        .tint(PesitoColor.brand)
    }
}
