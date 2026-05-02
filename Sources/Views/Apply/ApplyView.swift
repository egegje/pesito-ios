import SwiftUI

// Wizard entry point — either starts a new application or resumes the
// last in-progress one stored in UserDefaults. Keeps a reference to its
// own ApplyWizardModel which talks to PesitoAPI.
struct ApplyView: View {
    @StateObject private var model = ApplyWizardModel()

    var body: some View {
        ZStack {
            PesitoColor.bg.ignoresSafeArea()
            switch model.phase {
            case .quote:
                QuoteStepView(model: model)
            case .form(let step):
                FormStepView(step: step, model: model)
            case .submitting:
                SubmittingView()
            case .result(let state):
                ResultView(state: state, model: model)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.phase)
    }
}

@MainActor
final class ApplyWizardModel: ObservableObject {
    enum Phase: Equatable {
        case quote                       // amount + term picker
        case form(step: FormStep)
        case submitting
        case result(state: PesitoAPI.ApplicationState)
    }
    enum FormStep: Int, CaseIterable, Equatable {
        case identity = 1, address, income, bank, idDocs, otp, review
        var title: String {
            switch self {
            case .identity:  return "Tu identidad"
            case .address:   return "Tu dirección"
            case .income:    return "Tus ingresos"
            case .bank:      return "Cuenta bancaria"
            case .idDocs:    return "Documentos"
            case .otp:       return "Verifica tu teléfono"
            case .review:    return "Revisa y firma"
            }
        }
    }

    @Published var phase: Phase = .quote
    @Published var amount: Double = 5000
    @Published var termCount: Int = 4
    @Published var termUnit: String = "quincena"

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var dob: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var curp: String = ""
    @Published var email: String = ""
    @Published var phone: String = ""
    @Published var addressLine: String = ""
    @Published var city: String = ""
    @Published var state: String = ""
    @Published var postalCode: String = ""
    @Published var monthlyIncome: String = ""
    @Published var employer: String = ""
    @Published var clabe: String = ""
    @Published var consents: Bool = false
    @Published var otpCode: String = ""

    @Published var applicationId: String?
    @Published var quote: PesitoAPI.PricingSnapshot?
    @Published var error: String?
    @Published var busy = false

    func nextStep(from cur: FormStep) {
        if let nxt = FormStep(rawValue: cur.rawValue + 1) { phase = .form(step: nxt) }
    }
    func backStep(from cur: FormStep) {
        if cur.rawValue == 1 { phase = .quote }
        else if let prv = FormStep(rawValue: cur.rawValue - 1) { phase = .form(step: prv) }
    }

    func startApplication() async {
        busy = true; error = nil
        do {
            let r = try await PesitoAPI.shared.applyStart(
                .init(amount: amount, termCount: termCount, termUnit: termUnit)
            )
            applicationId = r.applicationId
            quote = r.pricingSnapshot
            phase = .form(step: .identity)
        } catch let e as NSError {
            error = "No se pudo iniciar: \(e.localizedDescription)"
        }
        busy = false
    }

    // Save current step's fields and advance.
    func saveAndAdvance(_ step: FormStep) async {
        guard let id = applicationId else { return }
        busy = true; error = nil
        let isoDob = ISO8601DateFormatter().string(from: dob).prefix(10)
        var patch: [String: Any] = [:]
        switch step {
        case .identity:
            patch = ["firstName": firstName, "lastName": lastName, "dob": String(isoDob), "curp": curp, "email": email, "phone": phone]
        case .address:
            patch = ["addressLine": addressLine, "city": city, "state": state, "postalCode": postalCode]
        case .income:
            patch = ["monthlyIncome": Double(monthlyIncome) ?? 0, "employer": employer]
        case .bank:
            patch = ["clabe": clabe]
        case .idDocs:
            // Document upload deferred to V0.5 (need Mifiel/INE camera flow)
            patch = ["docsConfirmed": true]
        case .otp, .review: break
        }
        do {
            if !patch.isEmpty {
                try await PesitoAPI.shared.applyData(id: id, patch: patch)
            }
            nextStep(from: step)
        } catch let e as NSError {
            error = "Error guardando: \(e.localizedDescription)"
        }
        busy = false
    }

    func sendOtp() async {
        guard let id = applicationId else { return }
        busy = true; error = nil
        do {
            try await PesitoAPI.shared.applyOtpSend(id: id, phone: phone)
        } catch let e as NSError {
            error = "No se envió el código: \(e.localizedDescription)"
        }
        busy = false
    }
    func verifyOtp() async {
        guard let id = applicationId else { return }
        busy = true; error = nil
        do {
            try await PesitoAPI.shared.applyOtpVerify(id: id, phone: phone, code: otpCode)
            // Persist consents flag too (required server-side)
            try await PesitoAPI.shared.applyData(id: id, patch: ["consents": consents])
            nextStep(from: .otp)
        } catch let e as NSError {
            error = "Código incorrecto: \(e.localizedDescription)"
        }
        busy = false
    }
    func submit() async {
        guard let id = applicationId else { return }
        phase = .submitting
        do {
            let s = try await PesitoAPI.shared.applySubmit(id: id)
            phase = .result(state: s)
        } catch let e as NSError {
            error = "No se pudo enviar: \(e.localizedDescription)"
            phase = .form(step: .review)
        }
    }

    func reset() {
        phase = .quote
        applicationId = nil
        quote = nil
        firstName = ""; lastName = ""; curp = ""; email = ""; phone = ""
        addressLine = ""; city = ""; state = ""; postalCode = ""
        monthlyIncome = ""; employer = ""; clabe = ""; consents = false; otpCode = ""
    }
}

// MARK: - Quote step

private struct QuoteStepView: View {
    @ObservedObject var model: ApplyWizardModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PesitoSpace.lg) {
                VStack(alignment: .leading, spacing: PesitoSpace.xxs) {
                    Text("Solicitar préstamo").pesitoEyebrow()
                    Text("¿Cuánto y por cuánto tiempo?")
                        .font(.pesitoTitleL)
                        .foregroundColor(PesitoColor.ink)
                }
                .padding(.top, PesitoSpace.lg)

                VStack(alignment: .leading, spacing: PesitoSpace.sm) {
                    Text("Monto").pesitoEyebrow()
                    HStack {
                        Text("$\(Int(model.amount))")
                            .font(.pesitoTitleM)
                            .foregroundColor(PesitoColor.ink)
                        Text("MXN").font(.pesitoBodyM).foregroundColor(PesitoColor.inkSoft)
                        Spacer()
                    }
                    Slider(value: $model.amount, in: 1000...20000, step: 500)
                        .tint(PesitoColor.brand)
                    HStack {
                        Text("$1,000").font(.pesitoCaption).foregroundColor(PesitoColor.inkMuted)
                        Spacer()
                        Text("$20,000").font(.pesitoCaption).foregroundColor(PesitoColor.inkMuted)
                    }
                }
                .pesitoCard(bordered: false)

                VStack(alignment: .leading, spacing: PesitoSpace.sm) {
                    Text("Plazo").pesitoEyebrow()
                    HStack(spacing: PesitoSpace.xs) {
                        ForEach([2, 4, 6, 8], id: \.self) { n in
                            Button {
                                model.termCount = n
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(n)")
                                        .font(.pesitoBody(20, weight: .bold))
                                    Text("quincenas")
                                        .font(.pesitoCaption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, PesitoSpace.sm)
                                .background(model.termCount == n ? PesitoColor.ink : Color.clear)
                                .foregroundColor(model.termCount == n ? .white : PesitoColor.ink)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12).stroke(PesitoColor.line, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .pesitoCard(bordered: false)

                Button(model.busy ? "Cargando…" : "Continuar") {
                    Task { await model.startApplication() }
                }
                .buttonStyle(PesitoPrimaryButton())
                .disabled(model.busy)

                if let e = model.error {
                    Text(e).font(.pesitoBodyS).foregroundColor(PesitoColor.danger)
                }
            }
            .padding(.horizontal, PesitoSpace.xl)
            .padding(.bottom, PesitoSpace.xxl)
        }
    }
}

// MARK: - Form step (renders any of identity/address/income/...)

private struct FormStepView: View {
    let step: ApplyWizardModel.FormStep
    @ObservedObject var model: ApplyWizardModel
    @FocusState private var firstFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PesitoSpace.lg) {
                ProgressBar(step: step)
                    .padding(.top, PesitoSpace.md)

                VStack(alignment: .leading, spacing: PesitoSpace.xxs) {
                    Text("Paso \(step.rawValue) de \(ApplyWizardModel.FormStep.allCases.count)")
                        .pesitoEyebrow()
                    Text(step.title)
                        .font(.pesitoTitleM)
                        .foregroundColor(PesitoColor.ink)
                }

                fields
                    .padding(.bottom, PesitoSpace.md)

                if let e = model.error {
                    Text(e).font(.pesitoBodyS).foregroundColor(PesitoColor.danger)
                }

                HStack(spacing: PesitoSpace.sm) {
                    if step.rawValue > 1 {
                        Button("Atrás") { model.backStep(from: step) }
                            .buttonStyle(PesitoSecondaryButton())
                            .frame(maxWidth: 120)
                    }
                    primaryAction
                }
            }
            .padding(.horizontal, PesitoSpace.xl)
            .padding(.bottom, PesitoSpace.xxl)
        }
        .onAppear { firstFocused = true }
    }

    @ViewBuilder
    private var fields: some View {
        switch step {
        case .identity:
            field("Nombre")        { TextField("Juan", text: $model.firstName).pesitoField().focused($firstFocused) }
            field("Apellidos")     { TextField("Pérez González", text: $model.lastName).pesitoField() }
            field("Fecha de nacimiento") {
                DatePicker("", selection: $model.dob, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            field("CURP") {
                TextField("XXXX000000XXXXXX00", text: $model.curp)
                    .pesitoField()
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
            field("Email") {
                TextField("tu@correo.com", text: $model.email)
                    .pesitoField()
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            field("Teléfono") {
                TextField("+52 55 0000 0000", text: $model.phone)
                    .pesitoField()
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
        case .address:
            field("Calle y número") { TextField("Av. Reforma 100", text: $model.addressLine).pesitoField().focused($firstFocused) }
            field("Ciudad")          { TextField("CDMX", text: $model.city).pesitoField() }
            field("Estado")          { TextField("Ciudad de México", text: $model.state).pesitoField() }
            field("Código postal")   { TextField("06600", text: $model.postalCode).pesitoField().keyboardType(.numberPad) }
        case .income:
            field("Ingreso mensual (MXN)") {
                TextField("15000", text: $model.monthlyIncome).pesitoField().keyboardType(.decimalPad).focused($firstFocused)
            }
            field("Empleador") {
                TextField("Empresa donde trabajas", text: $model.employer).pesitoField()
            }
        case .bank:
            field("CLABE de tu cuenta") {
                TextField("18 dígitos", text: $model.clabe)
                    .pesitoField()
                    .keyboardType(.numberPad)
                    .focused($firstFocused)
            }
            Text("Aquí depositamos tu préstamo y de aquí cobramos tus quincenas. Debe estar a tu nombre.")
                .font(.pesitoBodyS)
                .foregroundColor(PesitoColor.inkSoft)
                .padding(.horizontal, PesitoSpace.xs)
        case .idDocs:
            VStack(alignment: .leading, spacing: PesitoSpace.md) {
                Text("Para tu seguridad necesitamos: foto de tu INE (frente y reverso) y una selfie.")
                    .font(.pesitoBodyM)
                    .foregroundColor(PesitoColor.inkSoft)
                docPlaceholder(label: "INE — frente",  icon: "rectangle.split.2x1")
                docPlaceholder(label: "INE — reverso", icon: "rectangle.split.2x1.fill")
                docPlaceholder(label: "Selfie",        icon: "person.fill.viewfinder")
                Text("La cámara llegará en la próxima versión. Por ahora, continúa: capturaremos los documentos por web.")
                    .font(.pesitoCaption)
                    .foregroundColor(PesitoColor.inkMuted)
            }
        case .otp:
            VStack(alignment: .leading, spacing: PesitoSpace.md) {
                Text("Te enviamos un código a \(model.phone). Ingrésalo para confirmar el teléfono.")
                    .font(.pesitoBodyM)
                    .foregroundColor(PesitoColor.inkSoft)
                Button("Enviar código por SMS") { Task { await model.sendOtp() } }
                    .buttonStyle(PesitoSecondaryButton())
                TextField("000000", text: $model.otpCode)
                    .pesitoField()
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .focused($firstFocused)
                Toggle(isOn: $model.consents) {
                    Text("Acepto consultar mi historial en Buró de Crédito y los términos de Pesito.")
                        .font(.pesitoBodyS)
                        .foregroundColor(PesitoColor.ink)
                }
                .tint(PesitoColor.brand)
            }
        case .review:
            VStack(alignment: .leading, spacing: PesitoSpace.sm) {
                Text("Resumen").pesitoEyebrow()
                kv("Monto", "$\(Int(model.amount)) MXN")
                kv("Plazo", "\(model.termCount) quincenas")
                if let q = model.quote {
                    if let pa = q.paymentAmount { kv("Pago por quincena", "$\(Int(pa)) MXN") }
                    if let td = q.totalDue      { kv("Total a pagar",     "$\(Int(td)) MXN") }
                    if let cat = q.cat          { kv("CAT",               String(format: "%.1f%%", cat)) }
                }
                Divider().background(PesitoColor.line).padding(.vertical, PesitoSpace.xs)
                kv("Nombre", "\(model.firstName) \(model.lastName)")
                kv("CURP", model.curp)
                kv("CLABE", model.clabe)
            }
            .pesitoCard(bordered: false)
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch step {
        case .otp:
            Button(model.busy ? "Verificando…" : "Verificar y continuar") {
                Task { await model.verifyOtp() }
            }
            .buttonStyle(PesitoPrimaryButton())
            .disabled(model.otpCode.count != 6 || !model.consents || model.busy)
        case .review:
            Button(model.busy ? "Enviando…" : "Enviar solicitud") {
                Task { await model.submit() }
            }
            .buttonStyle(PesitoPrimaryButton())
            .disabled(model.busy)
        default:
            Button("Continuar") { Task { await model.saveAndAdvance(step) } }
                .buttonStyle(PesitoPrimaryButton())
                .disabled(model.busy)
        }
    }

    @ViewBuilder
    private func field<V: View>(_ label: String, @ViewBuilder _ control: () -> V) -> some View {
        VStack(alignment: .leading, spacing: PesitoSpace.xs) {
            Text(label).pesitoEyebrow()
            control()
        }
    }

    @ViewBuilder
    private func kv(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.pesitoBodyS).foregroundColor(PesitoColor.inkSoft)
            Spacer()
            Text(v).font(.pesitoBody(15, weight: .bold)).foregroundColor(PesitoColor.ink)
        }
    }

    @ViewBuilder
    private func docPlaceholder(label: String, icon: String) -> some View {
        HStack(spacing: PesitoSpace.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(PesitoColor.inkSoft)
                .frame(width: 40)
            Text(label).font(.pesitoBodyM).foregroundColor(PesitoColor.ink)
            Spacer()
            Image(systemName: "camera").foregroundColor(PesitoColor.inkMuted)
        }
        .padding(PesitoSpace.md)
        .background(PesitoColor.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PesitoColor.line, lineWidth: 1))
    }
}

// MARK: - Helpers

private struct ProgressBar: View {
    let step: ApplyWizardModel.FormStep
    var body: some View {
        let total = ApplyWizardModel.FormStep.allCases.count
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(PesitoColor.line).frame(height: 4)
                Capsule().fill(PesitoColor.brand)
                    .frame(width: geo.size.width * CGFloat(step.rawValue) / CGFloat(total), height: 4)
            }
        }
        .frame(height: 4)
    }
}

private struct SubmittingView: View {
    var body: some View {
        VStack(spacing: PesitoSpace.lg) {
            ProgressView().tint(PesitoColor.brand).scaleEffect(1.5)
            Text("Procesando tu solicitud…")
                .font(.pesitoBodyM)
                .foregroundColor(PesitoColor.inkSoft)
        }
    }
}

private struct ResultView: View {
    let state: PesitoAPI.ApplicationState
    @ObservedObject var model: ApplyWizardModel
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PesitoSpace.lg) {
                Spacer().frame(height: PesitoSpace.xl)
                Rectangle().fill(tint).frame(width: 64, height: 8)
                Text(headline)
                    .font(.pesitoTitleL)
                    .foregroundColor(PesitoColor.ink)
                Text(message)
                    .font(.pesitoBodyL)
                    .foregroundColor(PesitoColor.inkSoft)

                if state.status == "APPROVED" || state.status == "SIGNED" {
                    Button("Ver mi préstamo") {
                        Task {
                            try? await store.loadLoans()
                            model.reset()
                        }
                    }
                    .buttonStyle(PesitoPrimaryButton())
                } else if state.status == "MANUAL_REVIEW" {
                    Text("Te avisaremos por SMS y push en cuanto haya respuesta. Normalmente pocas horas.")
                        .font(.pesitoBodyM)
                        .foregroundColor(PesitoColor.inkSoft)
                } else if state.status == "REJECTED" {
                    Button("Volver a solicitar más adelante") { model.reset() }
                        .buttonStyle(PesitoSecondaryButton())
                }
                Spacer()
            }
            .padding(.horizontal, PesitoSpace.xl)
            .padding(.bottom, PesitoSpace.xxl)
        }
    }
    private var tint: Color {
        switch state.status {
        case "APPROVED", "SIGNED", "DISBURSED": return PesitoColor.success
        case "REJECTED":                         return PesitoColor.danger
        default:                                 return PesitoColor.brand
        }
    }
    private var headline: String {
        switch state.status {
        case "APPROVED":       return "¡Aprobado!"
        case "MANUAL_REVIEW":  return "En revisión"
        case "REJECTED":       return "Por ahora no podemos aprobar"
        case "SIGNED":         return "Contrato firmado"
        case "DISBURSED":      return "Dinero en camino"
        default:               return "Solicitud enviada"
        }
    }
    private var message: String {
        switch state.status {
        case "APPROVED":       return "Tu préstamo está aprobado. El siguiente paso es firmar el contrato."
        case "MANUAL_REVIEW":  return "Necesitamos verificar algunos datos. Volvemos contigo en menos de un día."
        case "REJECTED":       return "Tu perfil no califica en este momento. Puedes intentar de nuevo en 30 días."
        case "SIGNED":         return "Listo. El depósito SPEI llega en minutos."
        case "DISBURSED":      return "El SPEI ya salió. Revisa tu cuenta CLABE."
        default:               return "Procesando…"
        }
    }
}
