import Foundation

struct APIUser: Codable, Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let phone: String?
    let username: String
    let avatarId: String
    let avatarUrl: String
    let createdAt: String
    var displayName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
}

struct Avatar: Decodable, Identifiable {
    let id: String
    let name: String
    let url: String
}
struct AvatarList: Decodable { let avatars: [Avatar] }
struct UserList: Decodable {
    let users: [APIUser]
    let total: Int
    let limit: Int
    let offset: Int
}
struct AuthResponse: Decodable { let user: APIUser; let accessToken: String }
struct RegistrationResponse: Decodable {
    let registrationToken: String
    let currentStep: Int
    let expiresAt: String
}
struct OTPResponse: Decodable {
    let registrationToken: String?
    let loginToken: String?
    let username: String?
    let expiresAt: String?
    let otpSent: Bool
    let maskedPhone: String
    let otpExpiresIn: Int
    let retryAfter: Int
    let debugOtpCode: String?
}
struct RegisterDetails: Encodable {
    let firstName: String; let lastName: String; let phone: String; let pin: String
}
struct RegisterProfile: Encodable { let registrationToken: String; let avatarId: String }
struct LoginDetails: Encodable { let phone: String; let pin: String }
// The Go decoder rejects unknown fields: keep login and registration payloads separate.
struct RegisterVerification: Encodable { let registrationToken: String; let otpCode: String }
struct LoginVerification: Encodable { let loginToken: String; let otpCode: String }
struct RegisterResend: Encodable { let registrationToken: String }
struct LoginResend: Encodable { let loginToken: String }
struct DeleteAccount: Encodable { let username: String; let pin: String }

struct APIError: Decodable, LocalizedError {
    let code: String
    let message: String
    var fieldErrors: [String: String]?
    var retryAfter: Int?
    var errorDescription: String? { message }
    var invalidSession: Bool { code == "UNAUTHORIZED" }
}

enum ClientError: LocalizedError {
    case configuration, invalidResponse, http(Int), decoding, keychain(OSStatus), busy
    var errorDescription: String? {
        switch self {
        case .configuration: return "Sunucu adresi yapılandırılmamış veya geçersiz. Bağlantı ayarlarını kontrol edin."
        case .invalidResponse, .decoding: return "Sunucudan beklenmeyen bir yanıt geldi. Lütfen tekrar deneyin."
        case .http(let status): return "Sunucu isteği tamamlayamadı (\(status)). Lütfen tekrar deneyin."
        case .keychain: return "Oturum cihazda güvenle saklanamadı. Lütfen tekrar deneyin."
        case .busy: return "Devam eden işlem tamamlandığında tekrar deneyin."
        }
    }
}

func friendlyError(_ error: Error) -> String {
    if let e = error as? URLError {
        switch e.code {
        case .notConnectedToInternet, .networkConnectionLost: return "İnternet bağlantınızı kontrol edip tekrar deneyin."
        case .timedOut: return "Sunucu yanıt vermedi. Lütfen tekrar deneyin."
        case .cannotConnectToHost, .cannotFindHost: return "Sunucuya ulaşılamadı. Sunucunun açık olduğunu ve bağlantı adresini kontrol edin."
        case .secureConnectionFailed, .serverCertificateUntrusted: return "Sunucuyla güvenli bağlantı kurulamadı."
        default: break
        }
    }
    return error.localizedDescription
}

enum InputValidation {
    static func digits(_ value: String, limit: Int = 6) -> String {
        String(value.filter { $0 >= "0" && $0 <= "9" }.prefix(limit))
    }
    static func sixDigits(_ value: String) -> Bool { value.count == 6 && digits(value) == value }
    static func phone(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        [" ", "-", "(", ")"].forEach { value = value.replacingOccurrences(of: $0, with: "") }
        if value.hasPrefix("05"), value.count == 11 { value = "+9" + value }
        else if value.hasPrefix("5"), value.count == 10 { value = "+90" + value }
        else if value.hasPrefix("0090") { value = "+" + value.dropFirst(2) }
        return value.range(of: #"^\+[1-9][0-9]{7,14}$"#, options: .regularExpression) != nil ? value : nil
    }
}
