import SwiftUI

struct LoginOTPView: View {
    @EnvironmentObject var store: AppStore
    @State var phone: String
    @State var code: String = ""
    @State private var resendSeconds: Int = 30
    @State private var resendTimer: Timer?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PesitoSpace.lg) {
            Spacer().frame(height: PesitoSpace.xl)

            HStack(spacing: PesitoSpace.sm) {
                Rectangle().fill(PesitoColor.brand).frame(width: 18, height: 18)
                Text("pesito")
                    .font(.pesitoDisplay(28))
                    .foregroundColor(PesitoColor.ink)
            }

            VStack(alignment: .leading, spacing: PesitoSpace.xs) {
                Text("Código por SMS")
                    .font(.pesitoTitleL)
                    .foregroundColor(PesitoColor.ink)
                Text("Te enviamos un código de 6 dígitos a \(phone). En sandbox usa 000000.")
                    .font(.pesitoBodyM)
                    .foregroundColor(PesitoColor.inkSoft)
            }

            // Single big OTP field — iOS auto-pastes incoming SMS code via
            // textContentType(.oneTimeCode). Keep it ONE field; per-digit
            // boxes break paste handoff in iOS.
            TextField("000000", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .tracking(8)
                .focused($focused)
                .pesitoField()
                .onChange(of: code) { _, new in
                    let digits = new.filter(\.isNumber)
                    if digits.count > 6 { code = String(digits.prefix(6)) }
                    else if digits.count != new.count { code = digits }
                    if digits.count == 6 {
                        Task { await store.verifyOtp(phone: phone, code: digits) }
                    }
                }

            HStack {
                Button("Cambiar número") {
                    store.screen = .login(phone: phone)
                }
                .buttonStyle(PesitoGhostButton())

                Spacer()

                if resendSeconds > 0 {
                    Text("Reenviar en \(resendSeconds)s")
                        .font(.pesitoBodyS)
                        .foregroundColor(PesitoColor.inkMuted)
                } else {
                    Button("Reenviar") {
                        Task { await store.sendOtp(phone: phone); startTimer() }
                    }
                    .buttonStyle(PesitoGhostButton())
                }
            }

            Button(store.isBusy ? "Verificando…" : "Entrar") {
                Task { await store.verifyOtp(phone: phone, code: code) }
            }
            .buttonStyle(PesitoPrimaryButton(tint: PesitoColor.ink))
            .disabled(code.count != 6 || store.isBusy)

            if let e = store.error {
                Text(e)
                    .font(.pesitoBodyS)
                    .foregroundColor(PesitoColor.danger)
            }

            Spacer()
        }
        .padding(.horizontal, PesitoSpace.xl)
        .padding(.top, PesitoSpace.lg)
        .padding(.bottom, PesitoSpace.xl)
        .background(PesitoColor.bg)
        .onAppear { focused = true; startTimer() }
        .onDisappear { resendTimer?.invalidate() }
    }

    private func startTimer() {
        resendSeconds = 30
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            Task { @MainActor in
                if resendSeconds > 0 { resendSeconds -= 1 }
                if resendSeconds == 0 { t.invalidate() }
            }
        }
    }
}
