import Foundation
import Observation

/// The Anthropic API key, persisted in the Keychain. `ANTHROPIC_API_KEY` in the
/// environment is honored as a development fallback.
@MainActor
@Observable
final class APIKeyStore {
    private(set) var hasKey: Bool = false

    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private var cached: String?

    init(keychain: KeychainStore = .shared) {
        self.keychain = keychain
        cached = keychain.read(KeychainStore.apiKeyAccount)
        hasKey = currentKey != nil
    }

    var currentKey: String? {
        if let cached, !cached.isEmpty { return cached }
        let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        return (env?.isEmpty == false) ? env : nil
    }

    /// True when the key came from the Keychain (as opposed to the environment).
    var isStoredInKeychain: Bool { cached?.isEmpty == false }

    @discardableResult
    func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, keychain.write(trimmed, for: KeychainStore.apiKeyAccount) else { return false }
        cached = trimmed
        hasKey = true
        return true
    }

    func remove() {
        keychain.delete(KeychainStore.apiKeyAccount)
        cached = nil
        hasKey = currentKey != nil
    }

    /// A display-safe version of the key, e.g. "sk-ant-…a1b2".
    var maskedKey: String? {
        guard let key = currentKey else { return nil }
        return "\(key.prefix(7))…\(key.suffix(4))"
    }
}
