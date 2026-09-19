import Foundation
import Observation

@MainActor @Observable
final class AuthFlow {
    enum Mode { case login, register }
    enum Step { case details, avatar, otp }
    let mode: Mode
    var step: Step = .details
    var firstName = ""
    var lastName = ""
    var phone = ""
    var pin = ""
    var otp = ""
    var avatars: [Avatar] = []
    var selectedAvatar: String?
    var username = ""
    var maskedPhone = ""
    var isBusy = false
    var loadingAvatars = false
    var message: String?
    var fieldErrors: [String: String] = [:]
    var avatarError: String?
    var retryAt = Date.distantPast
    var otpExpiresAt = Date.distantPast
    var flowExpiresAt = Date.distantFuture
    var verifyLocked = false
    var debugCode: String?
    private var flowToken = ""
    @ObservationIgnored private var generation = 0
    @ObservationIgnored let session: SessionStore
    init(mode: Mode, session: SessionStore) { self.mode = mode; self.session = session }

    func submitDetails() async {
        guard !isBusy, retryAt <= Date() else { return }
        fieldErrors = [:]; message = nil
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if mode == .register {
            if first.isEmpty || first.count > 100 { fieldErrors["firstName"] = "Ad 1–100 karakter olmalıdır." }
            if last.isEmpty || last.count > 100 { fieldErrors["lastName"] = "Soyad 1–100 karakter olmalıdır." }
        }
        let normalized = InputValidation.phone(phone)
        if normalized == nil { fieldErrors["phone"] = "Geçerli bir telefon numarası girin." }
        if !InputValidation.sixDigits(pin) { fieldErrors["pin"] = "PIN 6 rakamdan oluşmalıdır." }
        guard fieldErrors.isEmpty, let normalized else { return }
        await perform {
            if self.mode == .register {
                let result = try await self.session.api.register(.init(firstName: first, lastName: last, phone: normalized, pin: self.pin))
                self.flowToken = result.registrationToken
                self.flowExpiresAt = ISO8601DateFormatter().date(from: result.expiresAt) ?? .distantFuture
                self.step = .avatar
            } else {
                let result = try await self.session.api.login(phone: normalized, pin: self.pin)
                guard let token = result.loginToken else { throw ClientError.invalidResponse }
                self.flowToken = token
                self.updateOTP(result); self.step = .otp
            }
            self.pin = ""
        }
        if step == .avatar { await loadAvatars() }
    }
    func loadAvatars() async {
        guard !loadingAvatars else { return }
        loadingAvatars = true; avatarError = nil
        defer { loadingAvatars = false }
        let version = generation
        do {
            let result = try await session.api.avatars()
            guard version == generation else { return }
            avatars = result
            if avatars.isEmpty { avatarError = "Avatar listesi şu anda boş. Lütfen tekrar deneyin." }
        } catch { if version == generation { avatarError = friendlyError(error) } }
    }
    func submitAvatar() async {
        guard let selectedAvatar, !flowToken.isEmpty, ensureFlowActive() else { return }
        await perform {
            let result = try await self.session.api.registerProfile(token: self.flowToken, avatar: selectedAvatar)
            self.username = result.username ?? ""
            self.updateOTP(result); self.step = .otp
        }
    }
    func verify() async {
        guard ensureFlowActive(), otpExpiresAt > Date(), !verifyLocked else { return }
        guard InputValidation.sixDigits(otp) else { fieldErrors["otpCode"] = "SMS kodu 6 rakam olmalıdır."; return }
        await perform {
            let version = self.generation
            let response: AuthResponse
            if self.mode == .register {
                response = try await self.session.api.verifyRegistration(token: self.flowToken, code: self.otp)
            } else { response = try await self.session.api.verifyLogin(token: self.flowToken, code: self.otp) }
            guard version == self.generation else { return }
            do { try self.session.accept(response) }
            catch {
                // OTP is consumed. Revoke the unpersisted session, then restart credentials.
                try? await self.session.api.logout(token: response.accessToken)
                self.restart(); throw error
            }
            self.otp = ""; self.flowToken = ""; self.debugCode = nil
        }
    }
    func resend() async {
        guard retryAt <= Date(), ensureFlowActive() else { return }
        await perform {
            let response: OTPResponse
            if self.mode == .register { response = try await self.session.api.resendRegistration(token: self.flowToken) }
            else { response = try await self.session.api.resendLogin(token: self.flowToken) }
            self.updateOTP(response); self.otp = ""; self.verifyLocked = false
        }
    }
    func restart() {
        generation += 1
        step = .details; flowToken = ""; pin = ""; otp = ""; debugCode = nil
        message = nil; fieldErrors = [:]; verifyLocked = false
        retryAt = .distantPast; flowExpiresAt = .distantFuture
    }
    func abandon() { generation += 1; flowToken = ""; pin = ""; otp = ""; debugCode = nil }
    private func ensureFlowActive() -> Bool {
        guard flowExpiresAt > Date() else {
            restart(); message = "İşlemin süresi doldu. Bilgilerinizi yeniden girin."; return false
        }
        return true
    }
    private func updateOTP(_ response: OTPResponse) {
        maskedPhone = response.maskedPhone
        retryAt = Date().addingTimeInterval(TimeInterval(response.retryAfter))
        otpExpiresAt = Date().addingTimeInterval(TimeInterval(response.otpExpiresIn))
        if let expiry = response.expiresAt { flowExpiresAt = ISO8601DateFormatter().date(from: expiry) ?? flowExpiresAt }
        #if DEBUG
        debugCode = response.debugOtpCode
        #endif
    }
    private func perform(_ action: () async throws -> Void) async {
        guard !isBusy else { return }
        let version = generation
        isBusy = true; message = nil; fieldErrors = [:]
        defer { isBusy = false }
        do { try await action() }
        catch {
            guard version == generation else { return }
            message = friendlyError(error)
            if let error = error as? APIError {
                fieldErrors = error.fieldErrors ?? [:]
                if let seconds = error.retryAfter { retryAt = Date().addingTimeInterval(TimeInterval(seconds)) }
                if error.code == "OTP_ATTEMPTS_EXCEEDED" { verifyLocked = true }
                if error.code == "OTP_EXPIRED" { otpExpiresAt = .distantPast }
                if ["REGISTRATION_SESSION_EXPIRED", "LOGIN_SESSION_EXPIRED", "INVALID_REGISTRATION_STEP"].contains(error.code) {
                    restart(); message = error.message
                }
            }
        }
    }
}
