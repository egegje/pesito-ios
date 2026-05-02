import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    enum Screen: Equatable {
        case loading
        case login(phone: String)
        case otp(phone: String)
        case dashboard

        // Stable string key — used purely as `value:` for SwiftUI animation
        // triggers (Equatable doesn't play well with associated-value enums
        // for animation diffing).
        var key: String {
            switch self {
            case .loading:           return "loading"
            case .login:             return "login"
            case .otp:               return "otp"
            case .dashboard:         return "dashboard"
            }
        }
    }
    @Published var screen: Screen = .loading
    @Published var me: PesitoAPI.Me?
    @Published var loans: [PesitoAPI.Loan] = []
    @Published var error: String?
    @Published var isBusy = false

    var screenKey: String { screen.key }

    func bootstrap() async {
        do {
            let me = try await PesitoAPI.shared.me()
            self.me = me
            try await loadLoans()
            screen = .dashboard
        } catch {
            screen = .login(phone: "")
        }
    }
    func loadLoans() async throws {
        do {
            loans = try await PesitoAPI.shared.loans()
        } catch PesitoError.sessionExpired {
            await handleSessionExpired()
            throw PesitoError.sessionExpired
        }
    }

    // Centralised "session expired" handling — wipe local state and bounce
    // the user to login. Any view layer caller that catches a thrown error
    // from a PesitoAPI call should let it propagate; the .task that owns
    // the call observes screen change reactively.
    func handleSessionExpired() async {
        me = nil
        loans = []
        error = "Tu sesión expiró. Vuelve a iniciar sesión."
        screen = .login(phone: "")
    }

    func sendOtp(phone: String) async {
        isBusy = true; error = nil
        do {
            try await PesitoAPI.shared.loginStart(phone: phone)
            screen = .otp(phone: phone)
        } catch { self.error = "No se pudo enviar el código" }
        isBusy = false
    }
    func verifyOtp(phone: String, code: String) async {
        isBusy = true; error = nil
        do {
            try await PesitoAPI.shared.loginVerify(phone: phone, code: code)
            await bootstrap()
        } catch { self.error = "Código incorrecto" }
        isBusy = false
    }
    func pay(loanId: String, amount: Double, method: String? = nil) async {
        isBusy = true; error = nil
        do {
            try await PesitoAPI.shared.pay(loanId: loanId, amount: amount, method: method)
            try await loadLoans()
        } catch PesitoError.sessionExpired {
            await handleSessionExpired()
        } catch {
            self.error = "No se pudo procesar el pago"
        }
        isBusy = false
    }
    func logout() async {
        try? await PesitoAPI.shared.logout()
        me = nil; loans = []
        screen = .login(phone: "")
    }
    func deleteAccount() async {
        isBusy = true; error = nil
        do {
            try await PesitoAPI.shared.deleteAccount()
            me = nil; loans = []
            screen = .login(phone: "")
        } catch {
            self.error = "No se pudo eliminar la cuenta. Si tienes préstamos activos, debes liquidar primero."
        }
        isBusy = false
    }
}
