import Foundation
import Observation

/// The signed-in plan and, for Pro, the subscriber's own model.
@MainActor
@Observable
final class SubscriptionCenter {
    private(set) var license: SubscriptionLicense?
    var provider: ModelProvider
    var modelName: String
    var baseURL: String
    private(set) var hasAPIKey: Bool

    init() {
        let defaults = UserDefaults.standard
        let storedProvider = defaults.string(forKey: PrefKey.aiProvider) ?? ModelProvider.openAI.rawValue
        let resolved = ModelProvider(rawValue: storedProvider) ?? .openAI
        provider = resolved
        modelName = defaults.string(forKey: PrefKey.aiModelName) ?? resolved.defaultModel
        baseURL = defaults.string(forKey: PrefKey.aiBaseURL) ?? resolved.defaultBaseURL
        hasAPIKey = KeychainStore.string(account: Self.apiKeyAccount) != nil
        license = LicenseVerifier.stored()
        adoptEnvironmentKey()
    }

    var tier: SubscriptionTier {
        guard let license, license.isValid else { return .free }
        return license.tier
    }

    /// A model the user connects themselves. The $79 hosted model is separate.
    var usesOwnModel: Bool { tier != .privateAI }

    var modelReady: Bool {
        if tier == .privateAI {
            return !PrivateAIService.baseURL.isEmpty
        }
        return !modelName.trimmingCharacters(in: .whitespaces).isEmpty
            && !activeBaseURL.isEmpty
            && (!provider.requiresKey || hasAPIKey)
    }

    func activate(_ raw: String) throws {
        let verified = try LicenseVerifier.verify(raw)
        LicenseVerifier.save(verified)
        license = verified
    }

    func removeLicense() {
        LicenseVerifier.clear()
        license = nil
    }

    func select(_ next: ModelProvider) {
        let previousDefault = provider.defaultModel
        provider = next
        let trimmed = modelName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == previousDefault {
            modelName = next.defaultModel
        }
        if next.baseURLIsEditable {
            let known = ModelProvider.allCases.map(\.fixedBaseURL).filter { !$0.isEmpty }
            if baseURL.isEmpty || known.contains(baseURL) {
                baseURL = next.defaultBaseURL
            }
        } else {
            baseURL = next.fixedBaseURL
        }
        persistModelSettings()
    }

    func persistModelSettings() {
        let defaults = UserDefaults.standard
        defaults.set(provider.rawValue, forKey: PrefKey.aiProvider)
        defaults.set(modelName, forKey: PrefKey.aiModelName)
        defaults.set(baseURL, forKey: PrefKey.aiBaseURL)
    }

    /// Empty keeps the key already in the keychain.
    func saveAPIKey(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.set(trimmed, account: Self.apiKeyAccount)
        hasAPIKey = true
    }

    func removeAPIKey() {
        KeychainStore.remove(account: Self.apiKeyAccount)
        hasAPIKey = false
    }

    func connection() throws -> AIConnection {
        if tier == .privateAI {
            guard !PrivateAIService.baseURL.isEmpty else { throw AIClientError.privateAIUnconfigured }
            guard let license else { throw AIClientError.locked }
            return AIConnection(
                baseURL: PrivateAIService.baseURL,
                model: PrivateAIService.model,
                apiKey: license.token,
                anthropic: false)
        }
        guard modelReady else { throw AIClientError.modelMissing }
        return AIConnection(
            baseURL: activeBaseURL,
            model: modelName.trimmingCharacters(in: .whitespaces),
            apiKey: KeychainStore.string(account: Self.apiKeyAccount) ?? "",
            anthropic: provider.usesAnthropic)
    }

    /// A debug launch can pass `XAI_API_KEY`. The value is stored in the keychain and is not compiled into the app.
    private func adoptEnvironmentKey() {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["XAI_API_KEY"] else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveAPIKey(trimmed)
        if provider != .xAI { select(.xAI) }
        modelName = ModelProvider.xAI.defaultModel
        persistModelSettings()
        fputs("Developer model key stored in the keychain. It is not part of the app.\n", stderr)
        #endif
    }

    private var activeBaseURL: String {
        let fixed = provider.fixedBaseURL
        if !fixed.isEmpty { return fixed }
        return baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let apiKeyAccount = "ai.apiKey"
}
