import SwiftUI
import WebKit

// Shown after a successful submit when status comes back APPROVED.
// Borrower reviews the offer + contract PDF preview, requests a signing
// OTP, enters it. Backend verifies the OTP, calls the e-sign adapter
// (Mifiel for production / mock for dev), marks the Application SIGNED
// and auto-creates the Loan. We then refresh AppStore.loans and bounce
// the user to the dashboard.
struct SignOfferView: View {
    let applicationId: String
    let offerAmount: String
    let offerTerm: Int
    let offerCAT: String?
    let offerPaymentAmount: String?
    let offerTotalDue: String?

    @EnvironmentObject var store: AppStore
    @ObservedObject var model: ApplyWizardModel

    @State private var phase: Phase = .review
    @State private var code: String = ""
    @State private var resendSeconds: Int = 0
    @State private var resendTimer: Timer?
    @State private var showContract: Bool = false
    @State private var error: String?
    @State private var busy: Bool = false

    enum Phase { case review, signing, done }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PesitoSpace.lg) {
                Spacer().frame(height: PesitoSpace.lg)

                Rectangle().fill(PesitoColor.brand).frame(width: 64, height: 8)
                Text("¡Aprobado!")
                    .font(.pesitoTitleL)
                    .foregroundColor(PesitoColor.ink)
                Text("Revisa los términos y firma con tu código por SMS. La firma tiene la misma validez que una firma autógrafa (NOM-151).")
                    .font(.pesitoBodyM)
                    .foregroundColor(PesitoColor.inkSoft)

                // Offer summary card
                VStack(alignment: .leading, spacing: PesitoSpace.sm) {
                    Text("Tu oferta").pesitoEyebrow()
                    kv("Monto aprobado", "$\(offerAmount) MXN")
                    kv("Plazo", "\(offerTerm) quincenas")
                    if let p = offerPaymentAmount { kv("Pago por quincena", "$\(p) MXN") }
                    if let t = offerTotalDue      { kv("Total a pagar",     "$\(t) MXN", emphasized: true) }
                    if let c = offerCAT           { kv("CAT",                "\(c)%") }
                }
                .pesitoCard(bordered: false)

                Button("Ver contrato completo") { showContract = true }
                    .buttonStyle(PesitoSecondaryButton())

                if phase == .review {
                    Button(busy ? "Enviando código…" : "Continuar a firma") {
                        Task { await sendOtp() }
                    }
                    .buttonStyle(PesitoPrimaryButton())
                    .disabled(busy)
                } else if phase == .signing {
                    VStack(alignment: .leading, spacing: PesitoSpace.sm) {
                        Text("Código de firma").pesitoEyebrow()
                        Text("Ingresa el código de 6 dígitos que recibiste por SMS.")
                            .font(.pesitoBodyS)
                            .foregroundColor(PesitoColor.inkSoft)
                        TextField("000000", text: $code)
                            .pesitoField()
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .onChange(of: code) { _, new in
                                let d = new.filter(\.isNumber)
                                if d.count > 6 { code = String(d.prefix(6)) }
                                else if d.count != new.count { code = d }
                            }
                        HStack {
                            if resendSeconds > 0 {
                                Text("Reenviar en \(resendSeconds)s")
                                    .font(.pesitoBodyS)
                                    .foregroundColor(PesitoColor.inkMuted)
                            } else {
                                Button("Reenviar SMS") { Task { await sendOtp() } }
                                    .buttonStyle(PesitoGhostButton())
                            }
                            Spacer()
                        }
                    }

                    Button(busy ? "Firmando…" : "Firmar contrato") {
                        Task { await confirmOtp() }
                    }
                    .buttonStyle(PesitoPrimaryButton(tint: PesitoColor.ink))
                    .disabled(code.count != 6 || busy)
                } else {
                    VStack(spacing: PesitoSpace.sm) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundColor(PesitoColor.success)
                        Text("Contrato firmado")
                            .font(.pesitoTitleM)
                            .foregroundColor(PesitoColor.ink)
                        Text("Procesando tu depósito SPEI…")
                            .font(.pesitoBodyM)
                            .foregroundColor(PesitoColor.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PesitoSpace.lg)
                }

                if let e = error {
                    Text(e).font(.pesitoBodyS).foregroundColor(PesitoColor.danger)
                }

                Spacer()
            }
            .padding(.horizontal, PesitoSpace.xl)
            .padding(.bottom, PesitoSpace.xxl)
        }
        .background(PesitoColor.bg.ignoresSafeArea())
        .sheet(isPresented: $showContract) {
            ContractPreviewView(applicationId: applicationId)
        }
        .onDisappear { resendTimer?.invalidate() }
    }

    private func sendOtp() async {
        busy = true; error = nil
        do {
            try await PesitoAPI.shared.applySignStart(id: applicationId)
            phase = .signing
            startResendTimer()
        } catch let e as NSError {
            error = "No se pudo enviar el código: \(e.localizedDescription)"
        }
        busy = false
    }

    private func confirmOtp() async {
        busy = true; error = nil
        do {
            _ = try await PesitoAPI.shared.applySignConfirm(id: applicationId, code: code)
            phase = .done
            // Reload AppStore loans → bounce to dashboard after a beat
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            try? await store.loadLoans()
            store.screen = .dashboard
            model.reset()
        } catch let e as NSError {
            error = "Código incorrecto: \(e.localizedDescription)"
        }
        busy = false
    }

    private func startResendTimer() {
        resendSeconds = 30
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            Task { @MainActor in
                if resendSeconds > 0 { resendSeconds -= 1 }
                if resendSeconds == 0 { t.invalidate() }
            }
        }
    }

    @ViewBuilder
    private func kv(_ k: String, _ v: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(k).font(.pesitoBodyS).foregroundColor(PesitoColor.inkSoft)
            Spacer()
            Text(v)
                .font(.pesitoBody(emphasized ? 17 : 15, weight: emphasized ? .bold : .regular))
                .foregroundColor(PesitoColor.ink)
        }
    }
}

// In-app contract preview. Backend serves the rendered PDF at
// /api/v1/apply/:id/contract.pdf — WKWebView renders it natively, no
// extra dependency needed (PDFKit also works but WKWebView shows the
// HTML fallback if the PDF render fails server-side).
private struct ContractPreviewView: View {
    let applicationId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContractWeb(url: PesitoAPI.baseURL.appendingPathComponent("/api/v1/apply/\(applicationId)/contract.pdf"))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Contrato")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cerrar") { dismiss() }
                    }
                }
        }
    }
}

private struct ContractWeb: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.backgroundColor = UIColor(red: 0.965, green: 0.945, blue: 0.910, alpha: 1.0)
        wv.isOpaque = false
        // We rely on the existing URLSession cookie jar so the contract
        // endpoint sees us as the logged-in borrower. WKWebView has its
        // own data store, so copy session cookies into it on first show.
        for c in HTTPCookieStorage.shared.cookies ?? [] {
            wv.configuration.websiteDataStore.httpCookieStore.setCookie(c)
        }
        wv.load(URLRequest(url: url))
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
