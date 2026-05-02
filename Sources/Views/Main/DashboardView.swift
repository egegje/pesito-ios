import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PesitoSpace.lg) {
                header
                if store.loans.isEmpty {
                    EmptyLoansView()
                } else {
                    ForEach(store.loans) { LoanCard(loan: $0) }
                }
            }
            .padding(.horizontal, PesitoSpace.xl)
            .padding(.top, PesitoSpace.lg)
            .padding(.bottom, PesitoSpace.xxl)
        }
        .background(PesitoColor.bg.ignoresSafeArea())
        .refreshable { try? await store.loadLoans() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PesitoSpace.xs) {
            Text("Hola").pesitoEyebrow()
            Text(store.me?.fullName?.split(separator: " ").first.map(String.init)
                 ?? store.me?.phone ?? "—")
                .font(.pesitoTitleL)
                .foregroundColor(PesitoColor.ink)
        }
        .padding(.top, PesitoSpace.sm)
    }
}

struct LoanCard: View {
    let loan: PesitoAPI.Loan
    @EnvironmentObject var store: AppStore
    @State private var showPaySheet = false

    var nextAmount: Double { Double(loan.nextPaymentAmount ?? "0") ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: PesitoSpace.md) {
            // Header row: id (debug-y) on left, status pill on right.
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: PesitoSpace.xxs) {
                    Text("Préstamo \(loan.id.suffix(6))").pesitoEyebrow()
                    Text("$\(formatMoney(loan.principal)) MXN")
                        .font(.pesitoTitleM)
                        .foregroundColor(PesitoColor.ink)
                }
                Spacer()
                StatusPill(status: loan.status)
            }

            // Next-payment block — dark inset on cream card to draw eye.
            if loan.status == "ACTIVE" || loan.status == "OVERDUE" {
                VStack(alignment: .leading, spacing: PesitoSpace.sm) {
                    Text("Próximo pago").pesitoEyebrow().foregroundColor(.white.opacity(0.7))
                    HStack(alignment: .firstTextBaseline) {
                        Text("$\(formatMoney(loan.nextPaymentAmount ?? "0"))")
                            .font(.pesitoTitleL)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    if let date = loan.nextPaymentDate {
                        Text("Vence \(formatDate(date))")
                            .font(.pesitoBodyS)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Button("Pagar") { showPaySheet = true }
                        .buttonStyle(PesitoPrimaryButton(tint: PesitoColor.brand))
                        .padding(.top, PesitoSpace.xs)
                }
                .padding(PesitoSpace.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PesitoColor.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Numerical breakdown
            VStack(spacing: PesitoSpace.sm) {
                kvRow("Restante",   "$\(formatMoney(loan.outstandingPrincipal))")
                kvRow("Interés",    "$\(formatMoney(loan.accruedInterest))")
                kvRow("Mora",       "$\(formatMoney(loan.accruedPenalty))")
                kvRow("Pagado",     "$\(formatMoney(loan.totalPaid))")
                Divider().background(PesitoColor.line)
                kvRow("CAT",        "\(loan.cat)%", emphasized: false)
                kvRow("Total a pagar", "$\(formatMoney(loan.totalDue))", emphasized: true)
            }
        }
        .pesitoCard()
        .sheet(isPresented: $showPaySheet) {
            PaySheet(loan: loan)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func kvRow(_ k: String, _ v: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(k)
                .font(.pesitoBodyS)
                .foregroundColor(PesitoColor.inkSoft)
            Spacer()
            Text(v)
                .font(.pesitoBody(emphasized ? 17 : 15, weight: emphasized ? .bold : .regular))
                .foregroundColor(PesitoColor.ink)
        }
    }

    private func formatMoney(_ s: String) -> String {
        guard let d = Double(s) else { return s }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: d)) ?? s
    }
    private func formatDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: iso) ?? f.date(from: iso + "T00:00:00Z") else { return iso }
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_MX")
        out.dateFormat = "d 'de' MMM"
        return out.string(from: d)
    }
}

struct StatusPill: View {
    let status: String
    var body: some View {
        Text(label)
            .font(.pesitoBody(11, weight: .bold))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundColor(.white)
            .padding(.horizontal, PesitoSpace.sm)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
    private var label: String {
        switch status {
        case "ACTIVE":   return "Activo"
        case "OVERDUE":  return "Vencido"
        case "PAID":     return "Pagado"
        case "CHARGED_OFF": return "Castigado"
        default:         return status.lowercased()
        }
    }
    private var color: Color {
        switch status {
        case "ACTIVE":   return PesitoColor.success
        case "OVERDUE":  return PesitoColor.danger
        case "PAID":     return PesitoColor.inkSoft
        default:         return PesitoColor.warning
        }
    }
}

struct EmptyLoansView: View {
    var body: some View {
        VStack(spacing: PesitoSpace.md) {
            Rectangle().fill(PesitoColor.brand).frame(width: 32, height: 6)
            Text("Aún no tienes un préstamo")
                .font(.pesitoTitleS)
                .foregroundColor(PesitoColor.ink)
            Text("Cuando solicites tu primer préstamo, aparecerá aquí con tu fecha de pago y total a pagar.")
                .font(.pesitoBodyM)
                .foregroundColor(PesitoColor.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(PesitoSpace.xl)
        .pesitoCard(bordered: false)
    }
}
