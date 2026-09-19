import XCTest
@testable import CekSepet

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.notConnectedToInternet) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
final class MemoryTokenStore: TokenStorage {
    var token: String?
    func read() throws -> String? { token }
    func save(_ token: String) throws { self.token = token }
    func remove() throws { token = nil }
}

@MainActor final class CekSepetTests: XCTestCase {
    let userJSON = #"{"id":"user-1","firstName":"Ada","lastName":"Yılmaz","phone":"+905551112233","username":"ada_yilmaz","avatarId":"avatar_01","avatarUrl":"http://localhost:8080/avatars/avatar_01.svg","createdAt":"2026-09-14T09:00:00Z"}"#
    func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        return APIClient(rawURL: "http://localhost:8080/api/v1/", session: URLSession(configuration: config))
    }
    func payload(_ request: URLRequest) throws -> [String: String] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(buffer, count: count) }
        }
        return try JSONDecoder().decode([String: String].self, from: data)
    }
    func testPhoneAndPINMatchBackendValidation() throws {
        for input in ["0555 111 22 33", "5551112233", "+90 (555) 111-22-33", "00905551112233"] { XCTAssertEqual(InputValidation.phone(input), "+905551112233") }
        XCTAssertNil(InputValidation.phone("+00012345678")); XCTAssertNil(InputValidation.phone("555"))
        XCTAssertTrue(InputValidation.sixDigits("012345")); XCTAssertFalse(InputValidation.sixDigits("１２３４５６"))
        XCTAssertFalse(InputValidation.sixDigits("12345"))
    }
    func testURLNormalizationAndRejection() throws {
        XCTAssertEqual(try APIConfiguration.validate("https://api.example.com").absoluteString, "https://api.example.com/api/v1/")
        XCTAssertThrowsError(try APIConfiguration.validate("https://name:secret@host/api/v1/"))
        XCTAssertThrowsError(try APIConfiguration.validate("https://host/wrong/path"))
        XCTAssertThrowsError(try APIConfiguration.validate("file:///api/v1/"))
        XCTAssertThrowsError(try APIConfiguration.validate(""))
    }
    func testRegistrationAndLoginPayloadsAreExact() async throws {
        let api = client(); var seen: [String] = []
        let auth = "{\"user\":\(userJSON),\"accessToken\":\"access\"}"
        let otp = #"{"registrationToken":"reg","loginToken":"login","otpSent":true,"maskedPhone":"+90 **33","otpExpiresIn":180,"retryAfter":60}"#
        StubURLProtocol.handler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.httpMethod, "POST")
            let path = request.url!.path; seen.append(path)
            let body = try self.payload(request)
            switch path {
            case "/api/v1/auth/register/step-1":
                XCTAssertEqual(body, ["firstName":"Ada","lastName":"Yılmaz","phone":"+905551112233","pin":"012345"])
                return (200, Data(#"{"registrationToken":"reg","currentStep":2,"expiresAt":"2026-09-14T09:00:00Z"}"#.utf8))
            case "/api/v1/auth/register/step-2": XCTAssertEqual(body, ["registrationToken":"reg","avatarId":"avatar_01"])
            case "/api/v1/auth/login": XCTAssertEqual(body, ["phone":"+905551112233","pin":"012345"])
            case "/api/v1/auth/register/otp/verify": XCTAssertEqual(body, ["registrationToken":"reg","otpCode":"123456"])
            case "/api/v1/auth/login/otp/verify": XCTAssertEqual(body, ["loginToken":"login","otpCode":"123456"])
            case "/api/v1/auth/register/otp/resend": XCTAssertEqual(body, ["registrationToken":"reg"])
            case "/api/v1/auth/login/otp/resend": XCTAssertEqual(body, ["loginToken":"login"])
            default: XCTFail("Unexpected endpoint \(path)")
            }
            return (200, Data((path.hasSuffix("verify") ? auth : otp).utf8))
        }
        _ = try await api.register(.init(firstName:"Ada",lastName:"Yılmaz",phone:"+905551112233",pin:"012345"))
        _ = try await api.registerProfile(token: "reg", avatar: "avatar_01")
        _ = try await api.login(phone: "+905551112233", pin: "012345")
        _ = try await api.verifyRegistration(token: "reg", code: "123456")
        _ = try await api.verifyLogin(token: "login", code: "123456")
        _ = try await api.resendRegistration(token: "reg")
        _ = try await api.resendLogin(token: "login")
        XCTAssertEqual(Set(seen).count, 7)
    }
    func testAuthenticatedRequestsAndEmpty204() async throws {
        let api = client(); var seen = 0
        StubURLProtocol.handler = { request in
            seen += 1; XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
            if request.httpMethod == "GET" { return (200, Data(self.userJSON.utf8)) }
            if request.httpMethod == "DELETE" { XCTAssertEqual(try self.payload(request), ["username":"ada_yilmaz","pin":"123456"]) }
            return (204, Data())
        }
        _ = try await api.me(token: "secret")
        try await api.deleteAccount(token: "secret", username: "ada_yilmaz", pin: "123456")
        try await api.logout(token: "secret")
        XCTAssertEqual(seen, 3)
    }
    func testPublicCatalogAndPagination() async throws {
        let api = client()
        StubURLProtocol.handler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            if request.url!.path.hasSuffix("avatars") { return (200, Data(#"{"avatars":[{"id":"avatar_01","name":"Yeşil","url":"/avatars/avatar_01.svg"}]}"#.utf8)) }
            XCTAssertEqual(request.url!.query, "limit=20&offset=20")
            return (200, Data("{\"users\":[\(self.userJSON)],\"total\":21,\"limit\":20,\"offset\":20}".utf8))
        }
        let avatars = try await api.avatars(); XCTAssertEqual(avatars.first?.id, "avatar_01")
        let users = try await api.users(offset: 20); XCTAssertEqual(users.total, 21)
    }
    func testRateLimitAndFieldErrorsArePreserved() async throws {
        StubURLProtocol.handler = { _ in (429, Data(#"{"code":"PIN_RATE_LIMITED","message":"Bekleyin","fieldErrors":{"pin":"Hatalı"},"retryAfter":900}"#.utf8)) }
        do { _ = try await client().login(phone: "+905551112233", pin: "123456"); XCTFail() }
        catch let error as APIError { XCTAssertEqual(error.retryAfter, 900); XCTAssertEqual(error.fieldErrors?["pin"], "Hatalı"); XCTAssertFalse(error.invalidSession) }
    }
    func testOfflineRestorePreservesTokenButRevokedSessionClearsIt() async throws {
        let memory = MemoryTokenStore(); memory.token = "saved"
        let session = SessionStore(api: client(), storage: memory)
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await session.restore()
        XCTAssertEqual(session.phase, .unavailable); XCTAssertEqual(memory.token, "saved")
        StubURLProtocol.handler = { _ in (401, Data(#"{"code":"UNAUTHORIZED","message":"Geçersiz oturum"}"#.utf8)) }
        await session.restore()
        XCTAssertEqual(session.phase, .signedOut); XCTAssertNil(memory.token)
    }
    func testWrongDeletionPINDoesNotSignOutAndOfflineLogoutRetainsSession() async throws {
        let memory = MemoryTokenStore(); let session = SessionStore(api: client(), storage: memory)
        let user = try JSONDecoder().decode(APIUser.self, from: Data(userJSON.utf8))
        try session.accept(.init(user: user, accessToken: "saved"))
        StubURLProtocol.handler = { _ in (401, Data(#"{"code":"INVALID_CREDENTIALS","message":"PIN hatalı"}"#.utf8)) }
        do { try await session.delete(username: "ada_yilmaz", pin: "000000"); XCTFail() } catch {}
        XCTAssertEqual(session.phase, .signedIn); XCTAssertEqual(memory.token, "saved")
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let success = await session.logout(); XCTAssertFalse(success); XCTAssertEqual(memory.token, "saved")
    }
    func testSearchActuallyFiltersCategoryAndText() {
        XCTAssertEqual(SampleCatalog.filter(query: "apple", category: "Elektronik").count, 2)
        XCTAssertEqual(SampleCatalog.filter(query: "apple", category: "Giyim").count, 0)
        XCTAssertTrue(SampleCatalog.filter(query: "xyz", category: "Tümü").isEmpty)
        XCTAssertEqual(SampleCatalog.filter(query: "  ", category: "Tümü").count, 6)
    }
    func testDraftPersistenceAndAccountIsolation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CatalogStore(directory: directory); store.activate(scope: "server|alice")
        var draft = ProductDraft(); draft.title = "Bisiklet"; draft.photos = [Data([1,2,3])]
        try store.save(draft); store.toggle(SampleCatalog.products[0])
        store.activate(scope: "server|bob"); XCTAssertTrue(store.drafts.isEmpty); XCTAssertTrue(store.favorites.isEmpty)
        store.activate(scope: "server|alice"); XCTAssertEqual(store.drafts.first?.title, "Bisiklet"); XCTAssertEqual(store.drafts.first?.photos.first, Data([1,2,3]))
        XCTAssertEqual(store.favorites.count, 1)
        try store.eraseCurrentAccount(); store.activate(scope: "server|alice"); XCTAssertTrue(store.drafts.isEmpty)
    }
    func testMalformedServerResponseIsNotAcceptedAsSuccess() async {
        StubURLProtocol.handler = { _ in (200, Data("<html>proxy</html>".utf8)) }
        do { _ = try await client().me(token: "token"); XCTFail() } catch { XCTAssertTrue(error is ClientError) }
    }
    func testDeletionCannotReportSuccessWhenSignedOutOrAnotherRequestIsActive() async throws {
        let memory = MemoryTokenStore(); let session = SessionStore(api: client(), storage: memory)
        do { try await session.delete(username: "ada", pin: "123456"); XCTFail("Missing session must fail") } catch {}
        let user = try JSONDecoder().decode(APIUser.self, from: Data(userJSON.utf8))
        try session.accept(.init(user: user, accessToken: "saved"))
        session.isBusy = true
        do { try await session.delete(username: "ada", pin: "123456"); XCTFail("Concurrent operation must fail") } catch {}
        XCTAssertEqual(memory.token, "saved")
    }
}
