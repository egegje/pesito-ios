import SwiftUI

// Account / settings tab. Profile read-only (edits go through admin in V0),
// language toggle (es/en), legal, logout, and the Apple-required "delete
// account" entry (App Store rejection if missing for any login app).
struct AccountView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("locale") private var locale: String = "es"
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PesitoSpace.lg) {
                Text("Cuenta")
                    .font(.pesitoTitleL)
                    .foregroundColor(PesitoColor.ink)
                    .padding(.top, PesitoSpace.md)

                // Profile card
                VStack(alignment: .leading, spacing: PesitoSpace.sm) {
                    HStack {
                        Circle()
                            .fill(PesitoColor.brandSoft)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(initials)
                                    .font(.pesitoDisplay(22))
                                    .foregroundColor(PesitoColor.brand)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.me?.fullName ?? "—")
                                .font(.pesitoBody(17, weight: .bold))
                                .foregroundColor(PesitoColor.ink)
                            Text(store.me?.phone ?? store.me?.email ?? "")
                                .font(.pesitoBodyS)
                                .foregroundColor(PesitoColor.inkSoft)
                        }
                        Spacer()
                    }
                    if let score = store.me?.internalScore {
                        Divider().background(PesitoColor.line)
                        HStack {
                            Text("Tu score interno").pesitoEyebrow()
                            Spacer()
                            Text("\(score) / 1000")
                                .font(.pesitoBody(15, weight: .bold))
                                .foregroundColor(PesitoColor.ink)
                        }
                    }
                }
                .pesitoCard(bordered: false)

                // Settings group — language
                section("Idioma") {
                    HStack(spacing: PesitoSpace.xs) {
                        ForEach(["es", "en"], id: \.self) { code in
                            Button {
                                locale = code
                            } label: {
                                Text(code == "es" ? "Español" : "English")
                                    .font(.pesitoBody(14, weight: .bold))
                                    .padding(.horizontal, PesitoSpace.md)
                                    .padding(.vertical, PesitoSpace.xs + 2)
                                    .background(locale == code ? PesitoColor.ink : Color.clear)
                                    .foregroundColor(locale == code ? .white : PesitoColor.ink)
                                    .overlay(
                                        Capsule().stroke(PesitoColor.ink, lineWidth: locale == code ? 0 : 1)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        Spacer()
                    }
                }

                // Legal links
                section("Legal") {
                    legalLink("Aviso de Privacidad", url: "https://gaz.eg.je/aviso-privacidad")
                    legalLink("Términos y Condiciones", url: "https://gaz.eg.je/terminos")
                    legalLink("Soporte UNE (CONDUSEF)", url: "https://gaz.eg.je/une")
                }

                // Sign out + danger zone
                VStack(spacing: PesitoSpace.sm) {
                    Button("Cerrar sesión") {
                        Task { await store.logout() }
                    }
                    .buttonStyle(PesitoSecondaryButton())

                    Button("Eliminar cuenta") {
                        showDeleteConfirm = true
                    }
                    .font(.pesitoBody(13))
                    .foregroundColor(PesitoColor.danger)
                    .padding(.top, PesitoSpace.xs)
                }

                // App version footer
                HStack {
                    Spacer()
                    Text("Pesito v\(version) · Bonum SOFOM ENR")
                        .font(.pesitoCaption)
                        .foregroundColor(PesitoColor.inkMuted)
                    Spacer()
                }
                .padding(.top, PesitoSpace.lg)
            }
            .padding(.horizontal, PesitoSpace.xl)
            .padding(.bottom, PesitoSpace.xxl)
        }
        .background(PesitoColor.bg.ignoresSafeArea())
        .alert("Eliminar cuenta", isPresented: $showDeleteConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                Task { await store.deleteAccount() }
            }
        } message: {
            Text("Esta acción es definitiva. Si tienes préstamos activos no podrás eliminarla hasta liquidar.")
        }
    }

    private var initials: String {
        let name = store.me?.fullName ?? store.me?.phone ?? "?"
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.first!) }.joined()
    }
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: PesitoSpace.sm) {
            Text(title).pesitoEyebrow()
            content()
        }
    }

    @ViewBuilder
    private func legalLink(_ label: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(label)
                    .font(.pesitoBodyM)
                    .foregroundColor(PesitoColor.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(PesitoColor.inkSoft)
            }
            .padding(PesitoSpace.md)
            .background(PesitoColor.bgRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PesitoColor.line, lineWidth: 1)
            )
        }
    }
}
