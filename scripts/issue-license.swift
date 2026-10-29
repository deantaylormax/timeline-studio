import CryptoKit
import Foundation

/// Signs a Timeline Studio license with the private key in ~/.timeline-studio.
/// Usage: swift scripts/issue-license.swift pro 365
///        swift scripts/issue-license.swift private 365

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    fputs("Usage: swift scripts/issue-license.swift pro|private [days]\n", stderr)
    exit(1)
}
let tier = arguments[1]
guard tier == "pro" || tier == "private" else {
    fputs("Tier must be pro or private.\n", stderr)
    exit(1)
}
let days = arguments.count >= 3 ? Int(arguments[2]) ?? 365 : 365
let keyURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent(".timeline-studio/license-ed25519.key")
guard let encoded = try? String(contentsOf: keyURL, encoding: .utf8),
      let raw = Data(base64Encoded: encoded.trimmingCharacters(in: .whitespacesAndNewlines)),
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
    fputs("Missing private key at \(keyURL.path)\n", stderr)
    exit(1)
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
let expiry = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
let parts = calendar.dateComponents([.year, .month, .day], from: expiry)
let day = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
let payload = "TS1.\(tier).\(day)"
let signature = try key.signature(for: Data(payload.utf8))
let token = payload + "." + base64URL(signature)
print(token)

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
