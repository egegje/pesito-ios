import Foundation

actor PesitoAPI {
    static let shared = PesitoAPI()
    static let baseURL = URL(string: "https://gaz.eg.je")!

    private let session: URLSession
    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpShouldSetCookies = true
        cfg.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: cfg)
    }

    // MARK: - Models

    struct Me: Codable {
        let id: String
        let phone: String?
        let email: String?
        let fullName: String?
        let internalScore: Int?
    }

    struct Loan: Codable, Identifiable {
        let id: String
        let status: String
        let principal: String
        let outstandingPrincipal: String
        let accruedInterest: String
        let accruedPenalty: String
        let totalPaid: String
        let cat: String
        let nextPaymentDate: String?
        let nextPaymentAmount: String?
        let paymentAmount: String
        let totalDue: String
        let startDate: String
        let maturityDate: String
        let schedule: [SchedItem]?
    }
    struct SchedItem: Codable, Identifiable {
        let id: String
        let periodNumber: Int
        let dueDate: String
        let scheduledTotal: String
        let status: String
    }

    struct Notification: Codable, Identifiable {
        let id: String
        let kind: String
        let title: String
        let body: String
        let read: Bool
        let createdAt: String
    }

    struct ApplyStartResp: Codable {
        let applicationId: String
        let pricingSnapshot: PricingSnapshot?
    }
    struct PricingSnapshot: Codable {
        let totalDue: Double?
        let paymentAmount: Double?
        let cat: Double?
        let interestTotal: Double?
        let originationFee: Double?
    }
    struct ApplicationState: Codable {
        let id: String
        let status: String       // DRAFT | SUBMITTED | KYC_PENDING | APPROVED | REJECTED | MANUAL_REVIEW | SIGNED | DISBURSED
        let amount: String?
        let termCount: Int?
        let termUnit: String?
        let approvedAmount: String?
        let approvedTerm: Int?
        let approvedCAT: String?
        let approvedFee: String?
        let approvedRate: String?
        let pricingSnapshot: PricingSnapshot?
        let rejectReason: String?
        let signedAt: String?
        let data: [String: AnyCodable]?
    }
    // /apply/:id/submit returns this shape, NOT the full ApplicationState.
    // Backend sends { decision, reason, offer }
    struct SubmitDecision: Codable, Equatable {
        let decision: String     // APPROVED | REJECTED | MANUAL_REVIEW
        let reason: String?
        let offer: SubmitOffer?
        struct SubmitOffer: Codable, Equatable {
            let amount: String?
            let term: Int?
            let cat: String?
            let fee: String?
            let dailyRate: String?
        }
    }

    // Loose JSON value — apply form data is dynamic, polished into typed
    // stuff client-side.
    struct AnyCodable: Codable {
        let value: Any
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self)        { value = s }
            else if let i = try? c.decode(Int.self)      { value = i }
            else if let d = try? c.decode(Double.self)   { value = d }
            else if let b = try? c.decode(Bool.self)     { value = b }
            else if c.decodeNil()                        { value = NSNull() }
            else { value = "" }
        }
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            switch value {
            case let s as String: try c.encode(s)
            case let i as Int:    try c.encode(i)
            case let d as Double: try c.encode(d)
            case let b as Bool:   try c.encode(b)
            default: try c.encodeNil()
            }
        }
    }

    // MARK: - Auth (phone + OTP)

    func loginStart(phone: String) async throws {
        try await postEmpty("/api/v1/auth/login/start", body: ["phone": phone])
    }
    func loginVerify(phone: String, code: String) async throws {
        try await postEmpty("/api/v1/auth/login/verify", body: ["phone": phone, "code": code])
    }
    func logout() async throws { try await postEmpty("/api/v1/auth/logout", body: [String: String]()) }

    // MARK: - Borrower data

    func me() async throws -> Me { try await get("/api/v1/me") }
    func loans() async throws -> [Loan] { try await get("/api/v1/me/loans") }
    func notifications() async throws -> [Notification] {
        let wrap: [String: [Notification]] = try await get("/api/v1/me/notifications")
        return wrap["items"] ?? []
    }
    func pay(loanId: String, amount: Double, method: String? = nil) async throws {
        var body: [String: Any] = ["amount": amount]
        if let method = method { body["method"] = method }
        try await postJSON("/api/v1/me/loans/\(loanId)/pay", json: body)
    }
    func rescind(loanId: String) async throws {
        try await postEmpty("/api/v1/me/loans/\(loanId)/rescind", body: [String: String]())
    }
    func deleteAccount() async throws {
        try await postEmpty("/api/v1/me/delete", body: [String: String]())
    }

    // MARK: - Apply (loan application wizard)

    struct ApplyStart: Encodable {
        let amount: Double
        let termCount: Int
        let termUnit: String?     // 'quincena' | 'month' | 'week' | 'day'
    }
    func applyStart(_ s: ApplyStart) async throws -> ApplyStartResp {
        try await postReturning("/api/v1/apply/start", body: s)
    }
    func applyData(id: String, patch: [String: Any]) async throws {
        try await postJSON("/api/v1/apply/\(id)/data", json: patch)
    }
    func applyOtpSend(id: String, phone: String) async throws {
        try await postEmpty("/api/v1/apply/\(id)/otp/send", body: ["phone": phone])
    }
    func applyOtpVerify(id: String, phone: String, code: String) async throws {
        try await postEmpty("/api/v1/apply/\(id)/otp/verify", body: ["phone": phone, "code": code])
    }
    func applySubmit(id: String) async throws -> SubmitDecision {
        try await postReturning("/api/v1/apply/\(id)/submit", body: [String: String]())
    }
    func applyState(id: String) async throws -> ApplicationState {
        try await get("/api/v1/apply/\(id)")
    }
    // OTP-based offer signing → backend creates Mifiel doc + auto-creates Loan
    func applySignStart(id: String) async throws {
        try await postEmpty("/api/v1/apply/\(id)/sign/start", body: [String: String]())
    }
    struct ApplySignResp: Codable { let ok: Bool?; let loanId: String? }
    func applySignConfirm(id: String, code: String) async throws -> ApplySignResp {
        try await postReturning("/api/v1/apply/\(id)/sign/confirm", body: ["code": code])
    }
    func applyDisburse(id: String) async throws -> ApplicationState {
        try await postReturning("/api/v1/apply/\(id)/disburse", body: [String: String]())
    }

    // Multipart document upload (INE front / back / selfie)
    func uploadDocument(applicationId: String, kind: String, jpeg: Data, mime: String = "image/jpeg") async throws {
        let boundary = "pesito-" + UUID().uuidString
        var body = Data()
        // text field 'kind'
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"kind\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(kind)\r\n".data(using: .utf8)!)
        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(kind).jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(jpeg)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: Self.baseURL.appendingPathComponent("/api/v1/apply/\(applicationId)/document"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(Self.tenantHeader, forHTTPHeaderField: "x-tenant")
        req.httpBody = body

        let (data, resp) = try await session.data(for: req)
        try check(resp, body: data)
    }

    // MARK: - Plumbing

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = Self.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.setValue(Self.tenantHeader, forHTTPHeaderField: "x-tenant")
        let (data, resp) = try await session.data(for: req)
        try check(resp, body: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func postEmpty<B: Encodable>(_ path: String, body: B) async throws {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Self.tenantHeader, forHTTPHeaderField: "x-tenant")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        try check(resp, body: data)
    }

    private func postReturning<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Self.tenantHeader, forHTTPHeaderField: "x-tenant")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await session.data(for: req)
        try check(resp, body: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // [String: Any] encoding (apply form data is heterogeneous)
    private func postJSON(_ path: String, json: [String: Any]) async throws {
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Self.tenantHeader, forHTTPHeaderField: "x-tenant")
        req.httpBody = try JSONSerialization.data(withJSONObject: json, options: [])
        let (data, resp) = try await session.data(for: req)
        try check(resp, body: data)
    }

    private func check(_ resp: URLResponse, body: Data) throws {
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let snippet = String(data: body.prefix(200), encoding: .utf8) ?? ""
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "PesitoAPI", code: code,
                          userInfo: [NSLocalizedDescriptionKey: snippet])
        }
    }

    // Default tenant — until we resolve via host header. Mexico-only for V0.
    static let tenantHeader = "mx"
}
