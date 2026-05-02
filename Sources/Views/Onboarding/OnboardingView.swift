import SwiftUI

// First-launch onboarding — 3 paginated screens. Once dismissed, the
// `seenOnboarding` flag is stored in UserDefaults so we never show it again.
// Skip control is always visible top-right (don't trap users on first run).

struct OnboardingView: View {
    @Binding var done: Bool
    @State private var page: Int = 0

    private let pages: [OnboardingPage] = [
        .init(eyebrow: "EN MINUTOS",
              title: "Dinero rápido,\nsin papeleo",
              body: "Hasta $20,000 MXN directos a tu cuenta CLABE. Solicitud en menos de 5 minutos.",
              tint: PesitoColor.brand),
        .init(eyebrow: "100% DIGITAL",
              title: "Sin filas,\nsin sucursales",
              body: "INE, selfie y ya. Resolución en horas, no días. Todo desde tu teléfono.",
              tint: PesitoColor.ink),
        .init(eyebrow: "REGULADO POR CONDUSEF",
              title: "Seguro y\ntransparente",
              body: "SOFOM ENR Bonum, S.A. de C.V., supervisada por CONDUSEF. CAT y comisiones siempre claros, sin letra chica.",
              tint: PesitoColor.brand),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PesitoColor.bg.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    OnboardingPageView(page: pages[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Skip
            Button("Saltar") { done = true }
                .buttonStyle(PesitoGhostButton())
                .padding(.top, PesitoSpace.md)
                .padding(.trailing, PesitoSpace.md)

            // Pager dots + CTA
            VStack(spacing: PesitoSpace.lg) {
                Spacer()
                HStack(spacing: PesitoSpace.xs) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? PesitoColor.ink : PesitoColor.line)
                            .frame(width: i == page ? 24 : 6, height: 6)
                            .animation(.easeOut(duration: 0.2), value: page)
                    }
                }
                Button(page == pages.count - 1 ? "Empezar" : "Continuar") {
                    if page == pages.count - 1 { done = true }
                    else { withAnimation { page += 1 } }
                }
                .buttonStyle(PesitoPrimaryButton())
                .padding(.horizontal, PesitoSpace.xl)
                .padding(.bottom, PesitoSpace.xl)
            }
        }
    }
}

private struct OnboardingPage {
    let eyebrow: String
    let title: String
    let body: String
    let tint: Color
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    var body: some View {
        VStack(alignment: .leading, spacing: PesitoSpace.lg) {
            Spacer().frame(height: PesitoSpace.xxxl)

            // Editorial accent — a single bold square in tint, asymmetric
            // (flush left, no centering), feels designed not templated.
            Rectangle()
                .fill(page.tint)
                .frame(width: 64, height: 8)

            Text(page.eyebrow).pesitoEyebrow()

            Text(page.title)
                .font(.pesitoTitleL)
                .foregroundColor(PesitoColor.ink)
                .lineSpacing(-2)

            Text(page.body)
                .font(.pesitoBodyL)
                .foregroundColor(PesitoColor.inkSoft)
                .lineSpacing(4)
                .frame(maxWidth: 360, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, PesitoSpace.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
