import SwiftUI

struct LoginPhoneView: View {
    @EnvironmentObject var store: AppStore
    @State var phone: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PesitoSpace.lg) {
            Spacer().frame(height: PesitoSpace.xl)

            // Brand mark — small accent square then wordmark, mirrors landing.
            HStack(spacing: PesitoSpace.sm) {
                Rectangle()
                    .fill(PesitoColor.brand)
                    .frame(width: 18, height: 18)
                Text("pesito")
                    .font(.pesitoDisplay(36))
                    .foregroundColor(PesitoColor.ink)
            }

            VStack(alignment: .leading, spacing: PesitoSpace.xs) {
                Text("Tu cuenta")
                    .font(.pesitoTitleL)
                    .foregroundColor(PesitoColor.ink)
                Text("Ingresa con tu teléfono. Te mandamos un código por SMS.")
                    .font(.pesitoBodyM)
                    .foregroundColor(PesitoColor.inkSoft)
            }

            VStack(alignment: .leading, spacing: PesitoSpace.xs) {
                Text("Teléfono").pesitoEyebrow()
                TextField("+52 55 0000 0044", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focused)
                    .pesitoField()
            }

            Button(store.isBusy ? "Enviando…" : "Enviar código") {
                Task { await store.sendOtp(phone: phone) }
            }
            .buttonStyle(PesitoPrimaryButton())
            .disabled(phone.count < 7 || store.isBusy)

            if let e = store.error {
                Text(e)
                    .font(.pesitoBodyS)
                    .foregroundColor(PesitoColor.danger)
            }

            Spacer()

            // Legal — short, on-brand. Tap reveals full Aviso de Privacidad.
            Text("Al continuar aceptas el Aviso de Privacidad y los Términos de uso de Pesito.")
                .font(.pesitoCaption)
                .foregroundColor(PesitoColor.inkMuted)
                .lineSpacing(2)
        }
        .padding(.horizontal, PesitoSpace.xl)
        .padding(.top, PesitoSpace.lg)
        .padding(.bottom, PesitoSpace.xl)
        .background(PesitoColor.bg)
        .onAppear { focused = true }
    }
}
