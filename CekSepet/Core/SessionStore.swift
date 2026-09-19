import Foundation
import Observation

@MainActor @Observable
final class SessionStore {
    enum Phase: Equatable { case restoring, signedOut, signedIn, unavailable }
    private(set) var phase: Phase = .restoring
    private(set) var user: APIUser?
    private(set) var token: String?
    var message: String?
    var isBusy = false
    private(set) var api: APIClient
    @ObservationIgnored private var storage: TokenStorage
    @ObservationIgnored private var generation = 0

    init(api: APIClient? = nil, storage: TokenStorage? = nil) {
        let api = api ?? APIClient()
        self.api = api
        self.storage = storage ?? KeychainStore(environment: api.baseURL?.absoluteString ?? "unconfigured")
    }
    func restore() async {
        guard !isBusy else { return }
        let version = generation
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            guard let saved = try storage.read() else { phase = .signedOut; return }
            let loaded = try await api.me(token: saved)
            guard version == generation else { return }
            token = saved; user = loaded; phase = .signedIn
        } catch {
            guard version == generation else { return }
            if (error as? APIError)?.invalidSession == true {
                try? storage.remove(); token = nil; user = nil; phase = .signedOut
                message = "Oturumunuz sona erdi. Lütfen yeniden giriş yapın."
            } else {
                phase = .unavailable; message = friendlyError(error)
            }
        }
    }
    func accept(_ response: AuthResponse) throws {
        try storage.save(response.accessToken)
        generation += 1
        token = response.accessToken; user = response.user; phase = .signedIn; message = nil
    }
    func refresh() async {
        guard let token, !isBusy else { return }
        let version = generation
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            let loaded = try await api.me(token: token)
            guard version == generation else { return }
            user = loaded
        } catch {
            guard version == generation else { return }
            handle(error)
        }
    }
    @discardableResult func logout() async -> Bool {
        guard let token, !isBusy else { return false }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            try await api.logout(token: token)
            try clear()
            return true
        } catch {
            if (error as? APIError)?.invalidSession == true { try? clear(); return true }
            message = friendlyError(error); return false
        }
    }
    func delete(username: String, pin: String) async throws {
        guard let token else { throw APIError(code: "UNAUTHORIZED", message: "Lütfen yeniden giriş yapın.") }
        guard !isBusy else { throw ClientError.busy }
        isBusy = true; defer { isBusy = false }
        do {
            try await api.deleteAccount(token: token, username: username, pin: pin)
            try clear()
        } catch {
            // INVALID_CREDENTIALS on DELETE is not a revoked access token.
            if (error as? APIError)?.invalidSession == true { handle(error) }
            throw error
        }
    }
    private func clear() throws {
        try storage.remove()
        generation += 1; token = nil; user = nil; phase = .signedOut; message = nil
    }
    private func handle(_ error: Error) {
        if (error as? APIError)?.invalidSession == true { try? clear() }
        message = friendlyError(error)
    }
    #if DEBUG
    func changeServer(_ raw: String) throws {
        let url = try APIConfiguration.validate(raw)
        generation += 1
        UserDefaults.standard.set(url.absoluteString, forKey: "developmentAPIURL")
        api = APIClient(rawURL: url.absoluteString)
        storage = KeychainStore(environment: url.absoluteString)
        user = nil; token = nil; message = nil; phase = .restoring
    }
    #endif
}
