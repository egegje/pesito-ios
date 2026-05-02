import SwiftUI

// History: closed loans + paid installments. Pulls from existing /me/loans
// and filters; future iteration could hit a dedicated /me/payments endpoint
// once the backend exposes one.
struct HistoryView: View {
    @EnvironmentObject var store: AppStore

    private var pastLoans: [PesitoAPI.Loan] {
        store.loans.filter { $0.status == "PAID" || $0.status == "CHARGED_OFF" }
    }
    private var paidInstallments: [(loan: PesitoAPI.Loan, item: PesitoAPI.SchedItem)] {
        store.loans.flatMap { loan in
            (loan.schedule ?? []).filter { $0.status == "PAID" }.map { (loan, $0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PesitoSpace.lg) {
                Text("Historial")
                    .font(.pesitoTitleL)
                    .foregroundColor(PesitoColor.ink)
                    .padding(.top, PesitoSpace.md)

                if paidInstallments.isEmpty && pastLoans.isEmpty {
                    Text("Aquí verás tus pagos y préstamos cerrados.")
                        .font(.pesitoBodyM)
                        .foregroundColor(PesitoColor.inkSoft)
                        .padding(.top, PesitoSpace.xl)
                } else {
                    if !paidInstallments.isEmpty {
                        Text("Pagos").pesitoEyebrow()
                        VStack(spacing: PesitoSpace.sm) {
                            ForEach(paidInstallments, id: \.item.id) { row in
                                HistoryRow(
                                    label: "Pago — préstamo \(row.loan.id.suffix(6))",
                                    sub:   "Período \(row.item.periodNumber)",
                                    value: "$\(row.item.scheduledTotal)",
                                    date:  row.item.dueDate
                                )
                            }
                        }
                    }

                    if !pastLoans.isEmpty {
                        Text("Préstamos cerrados").pesitoEyebrow()
                            .padding(.top, PesitoSpace.md)
                        VStack(spacing: PesitoSpace.sm) {
                            ForEach(pastLoans) { loan in
                                HistoryRow(
                                    label: "Préstamo \(loan.id.suffix(6))",
                                    sub:   loan.status == "PAID" ? "Liquidado" : "Castigado",
                                    value: "$\(loan.principal)",
                                    date:  loan.maturityDate
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, PesitoSpace.xl)
            .padding(.bottom, PesitoSpace.xxl)
        }
        .background(PesitoColor.bg.ignoresSafeArea())
        .refreshable { try? await store.loadLoans() }
    }
}

private struct HistoryRow: View {
    let label: String
    let sub: String
    let value: String
    let date: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.pesitoBody(15, weight: .bold))
                    .foregroundColor(PesitoColor.ink)
                Text("\(sub) · \(prettyDate(date))")
                    .font(.pesitoBodyS)
                    .foregroundColor(PesitoColor.inkSoft)
            }
            Spacer()
            Text(value)
                .font(.pesitoBody(15, weight: .bold))
                .foregroundColor(PesitoColor.ink)
        }
        .padding(PesitoSpace.md)
        .background(PesitoColor.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PesitoColor.line, lineWidth: 1)
        )
    }
    private func prettyDate(_ s: String) -> String {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: s) ?? f.date(from: s + "T00:00:00Z") {
            let out = DateFormatter()
            out.locale = Locale(identifier: "es_MX")
            out.dateFormat = "d MMM yyyy"
            return out.string(from: d)
        }
        return s
    }
}
