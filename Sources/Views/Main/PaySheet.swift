import SwiftUI

// Half-sheet shown from LoanCard "Pagar" button. Lets borrower pick
// payment channel (CARD via Conekta web checkout / OXXO voucher / SPEI
// CLABE+concept). For V0 the sheet records the chosen method and calls
// /pay; the actual external flow (Conekta hosted checkout, OXXO voucher
// PDF, SPEI instructions) is layered on the response.
struct PaySheet: View {
    let loan: PesitoAPI.Loan
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var method: PaymentMethod = .card
    @State private var amountText: String

    init(loan: PesitoAPI.Loan) {
        self.loan = loan
        _amountText = State(initialValue: loan.nextPaymentAmount ?? loan.totalDue)
    }

    enum PaymentMethod: String, CaseIterable, Identifiable {
        case card = "CARD", oxxo = "OXXO", spei = "SPEI"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .card: return "Tarjeta"
            case .oxxo: return "OXXO"
            case .spei: return "Transferencia SPEI"
            }
        }
        var subtitle: String {
            switch self {
            case .card: return "Débito o crédito · pago al instante"
            case .oxxo: return "Voucher con código · pagas en tienda"
            case .spei: return "CLABE y concepto · 1-2 horas"
            }
        }
        var icon: String {
            switch self {
            case .card: return "creditcard"
            case .oxxo: return "barcode"
            case .spei: return "building.columns"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PesitoSpace.lg) {
                VStack(alignment: .leading, spacing: PesitoSpace.xxs) {
                    Text("Pagar préstamo").pesitoEyebrow()
                    Text("$\(amountText)")
                        .font(.pesitoTitleL)
                        .foregroundColor(PesitoColor.ink)
                }

                VStack(alignment: .leading, spacing: PesitoSpace.xs) {
                    Text("Monto").pesitoEyebrow()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pesitoField()
                }

                VStack(alignment: .leading, spacing: PesitoSpace.xs) {
                    Text("Método de pago").pesitoEyebrow()
                    ForEach(PaymentMethod.allCases) { m in
                        Button { method = m } label: {
                            HStack(spacing: PesitoSpace.md) {
                                Image(systemName: m.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(method == m ? PesitoColor.brand : PesitoColor.inkSoft)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.label)
                                        .font(.pesitoBody(16, weight: .bold))
                                        .foregroundColor(PesitoColor.ink)
                                    Text(m.subtitle)
                                        .font(.pesitoBodyS)
                                        .foregroundColor(PesitoColor.inkSoft)
                                }
                                Spacer()
                                Image(systemName: method == m ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(method == m ? PesitoColor.brand : PesitoColor.line)
                                    .font(.system(size: 22))
                            }
                            .padding(PesitoSpace.md)
                            .background(PesitoColor.bgRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(method == m ? PesitoColor.brand : PesitoColor.line, lineWidth: method == m ? 1.5 : 1)
                            )
                        }
                    }
                }

                Button(store.isBusy ? "Procesando…" : "Confirmar pago") {
                    Task {
                        await store.pay(loanId: loan.id, amount: Double(amountText) ?? 0, method: method.rawValue)
                        if store.error == nil { dismiss() }
                    }
                }
                .buttonStyle(PesitoPrimaryButton())
                .disabled(Double(amountText) == nil || store.isBusy)

                if let e = store.error {
                    Text(e)
                        .font(.pesitoBodyS)
                        .foregroundColor(PesitoColor.danger)
                }
            }
            .padding(PesitoSpace.xl)
        }
        .background(PesitoColor.bg.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}
