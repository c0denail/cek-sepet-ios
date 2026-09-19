import Foundation

enum APIConfiguration {
    static var rawURL: String {
        #if DEBUG
        if let url = ProcessInfo.processInfo.environment["CEKSEPET_TEST_API_URL"] { return url }
        if let url = UserDefaults.standard.string(forKey: "developmentAPIURL"), !url.isEmpty { return url }
        #endif
        return Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String ?? ""
    }
    static func validate(_ raw: String) throws -> URL {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: text), let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.scheme == "https" || parts.scheme == "http" else { throw ClientError.configuration }
        #if !DEBUG
        guard parts.scheme == "https" else { throw ClientError.configuration }
        #endif
        let path = parts.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard path.isEmpty || path == "api/v1" else { throw ClientError.configuration }
        parts.path = "/api/v1/"
        guard let url = parts.url else { throw ClientError.configuration }
        return url
    }
}

// Refuse redirects for API requests so a bearer token cannot be forwarded to another host.
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class APIClient {
    let baseURL: URL?
    private let session: URLSession
    init(rawURL: String = APIConfiguration.rawURL, session: URLSession? = nil) {
        baseURL = try? APIConfiguration.validate(rawURL)
        if let session { self.session = session }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 25
            configuration.timeoutIntervalForResource = 40
            configuration.urlCache = nil
            self.session = URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
        }
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil,
                         token: String? = nil, query: [URLQueryItem] = []) async throws -> Data {
        guard let baseURL else { throw ClientError.configuration }
        var parts = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { parts.queryItems = query }
        guard let url = parts.url else { throw ClientError.configuration }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200...299).contains(response.statusCode) else {
            if var error = try? JSONDecoder().decode(APIError.self, from: data) {
                if error.retryAfter == nil, let value = response.value(forHTTPHeaderField: "Retry-After") {
                    error.retryAfter = Int(value)
                }
                throw error
            }
            throw ClientError.http(response.statusCode)
        }
        return data
    }
    private func get<T: Decodable>(_ path: String, token: String? = nil,
                                   query: [URLQueryItem] = []) async throws -> T {
        let data = try await request(path, token: token, query: query)
        return try decode(data)
    }
    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let data = try await request(path, method: "POST", body: JSONEncoder().encode(body))
        return try decode(data)
    }
    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw ClientError.decoding }
    }
    func avatars() async throws -> [Avatar] { let result: AvatarList = try await get("avatars"); return result.avatars }
    func register(_ details: RegisterDetails) async throws -> RegistrationResponse {
        try await post("auth/register/step-1", body: details)
    }
    func registerProfile(token: String, avatar: String) async throws -> OTPResponse {
        try await post("auth/register/step-2", body: RegisterProfile(registrationToken: token, avatarId: avatar))
    }
    func login(phone: String, pin: String) async throws -> OTPResponse {
        try await post("auth/login", body: LoginDetails(phone: phone, pin: pin))
    }
    func verifyRegistration(token: String, code: String) async throws -> AuthResponse {
        try await post("auth/register/otp/verify", body: RegisterVerification(registrationToken: token, otpCode: code))
    }
    func verifyLogin(token: String, code: String) async throws -> AuthResponse {
        try await post("auth/login/otp/verify", body: LoginVerification(loginToken: token, otpCode: code))
    }
    func resendRegistration(token: String) async throws -> OTPResponse {
        try await post("auth/register/otp/resend", body: RegisterResend(registrationToken: token))
    }
    func resendLogin(token: String) async throws -> OTPResponse {
        try await post("auth/login/otp/resend", body: LoginResend(loginToken: token))
    }
    func me(token: String) async throws -> APIUser { try await get("users/me", token: token) }
    func logout(token: String) async throws { _ = try await request("auth/logout", method: "POST", token: token) }
    func deleteAccount(token: String, username: String, pin: String) async throws {
        _ = try await request("users/me", method: "DELETE", body: JSONEncoder().encode(DeleteAccount(username: username, pin: pin)), token: token)
    }
    func users(offset: Int = 0) async throws -> UserList {
        try await get("users", query: [.init(name: "limit", value: "20"), .init(name: "offset", value: String(offset))])
    }
}
