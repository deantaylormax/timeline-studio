import CryptoKit
import Foundation

/// A subscription license. The private signing key stays outside this repository.
struct SubscriptionLicense: Equatable {
    var tier: SubscriptionTier
    var expires: Date
    /// The full license string. Private AI sends it as the bearer token.
    var token: String

    var isValid: Bool { expires >= Date() }
}

enum LicenseError: LocalizedError {
    case unrecognized
    case expired(Date)
    case invalid

    var errorDescription: String? {
        switch self {
        case .unrecognized:
            "This is not a Timeline Studio license key."
        case .expired(let date):
            "This license expired on \(date.formatted(date: .abbreviated, time: .omitted))."
        case .invalid:
            "This license key could not be verified."
        }
    }
}

enum LicenseVerifier {
    /// Ed25519 public key. Licenses are signed with the matching private key.
    private static let publicKeyBase64 = "Dyr9UkGU/dslc6mQ1d3nAvfgiFizW+FzIEMtLmkDFro="
    private static let licenseAccount = "subscription.license"

    static func stored() -> SubscriptionLicense? {
        guard let token = KeychainStore.string(account: licenseAccount) else { return nil }
        return try? verify(token)
    }

    static func save(_ license: SubscriptionLicense) {
        KeychainStore.set(license.token, account: licenseAccount)
    }

    static func clear() {
        KeychainStore.remove(account: licenseAccount)
    }

    /// `TS1.<pro|private>.<yyyyMMdd>.<signature>`
    static func verify(_ raw: String) throws -> SubscriptionLicense {
        let compact = raw.filter { !$0.isWhitespace }
        let parts = compact.split(separator: ".").map(String.init)
        guard parts.count == 4, parts[0] == "TS1" else { throw LicenseError.unrecognized }
        let tier: SubscriptionTier
        switch parts[1] {
        case "pro": tier = .pro
        case "private": tier = .privateAI
        default: throw LicenseError.unrecognized
        }
        guard let expires = expiry(parts[2]) else { throw LicenseError.unrecognized }
        let payload = "\(parts[0]).\(parts[1]).\(parts[2])"
        guard signatureIsValid(parts[3], payload: payload) else { throw LicenseError.invalid }
        guard expires >= Date() else { throw LicenseError.expired(expires) }
        return SubscriptionLicense(tier: tier, expires: expires, token: compact)
    }

    private static func signatureIsValid(_ encoded: String, payload: String) -> Bool {
        guard let keyData = Data(base64Encoded: publicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              let signature = base64URLDecode(encoded) else { return false }
        return key.isValidSignature(signature, for: Data(payload.utf8))
    }

    private static func expiry(_ day: String) -> Date? {
        guard day.count == 8,
              let year = Int(day.prefix(4)),
              let month = Int(day.dropFirst(4).prefix(2)),
              let date = Int(day.suffix(2)) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = date
        parts.hour = 23
        parts.minute = 59
        parts.second = 59
        return calendar.date(from: parts)
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var text = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while text.count % 4 != 0 { text.append("=") }
        return Data(base64Encoded: text)
    }
}
