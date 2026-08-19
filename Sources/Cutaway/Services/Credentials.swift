import Foundation
import Security

struct Credential {
    let name: String
    let value: String

    /// sk-ant-oat01-... setup tokens need Bearer auth; API keys need x-api-key.
    var isOAuth: Bool { value.hasPrefix("sk-ant-oat") }
}

enum Credentials {
    private static let service = "com.kasparov.cutaway"
    private static let account = "anthropic-api-key"
    private static let groqAccount = "groq-api-key"
    private static let lastWorkingKey = "cutaway.lastWorkingCredential"

    /// Order: user-entered credential → environment variable → embedded token pool.
    /// The pool may hold several tokens; exhausted ones are skipped.
    static var all: [Credential] {
        var list: [Credential] = []
        if let saved = readKeychain(account), !saved.isEmpty {
            list.append(Credential(name: "your credential", value: saved))
        }
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !env.isEmpty {
            list.append(Credential(name: "environment", value: env))
        }
        list.append(contentsOf: embeddedPool())
        return list
    }

    static var available: Bool { !all.isEmpty }

    /// Moves the last working credential to the front so an exhausted token
    /// is not retried on every request.
    static func ordered() -> [Credential] {
        let everyone = all
        guard let last = UserDefaults.standard.string(forKey: lastWorkingKey),
              let i = everyone.firstIndex(where: { $0.name == last }), i > 0 else { return everyone }
        var list = everyone
        let chosen = list.remove(at: i)
        list.insert(chosen, at: 0)
        return list
    }

    static func markWorking(_ credential: Credential) {
        UserDefaults.standard.set(credential.name, forKey: lastWorkingKey)
    }

    static func save(_ value: String) { write(value, account: account) }
    static func saveGroq(_ value: String) { write(value, account: groqAccount) }

    static var groqKey: String? {
        if let saved = readKeychain(groqAccount), !saved.isEmpty { return saved }
        if let env = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !env.isEmpty {
            return env
        }
        return nil
    }

    private static func write(_ value: String, account: String) {
        let data = Data(value.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !data.isEmpty else { return }
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func readKeychain(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var found: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &found) == errSecSuccess,
              let data = found as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Secrets.plist is compiled into fleet builds, never committed (.gitignore).
    /// Format: TOKENS = [ { name, token }, ... ]
    private static func embeddedPool() -> [Credential] {
        guard let path = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: path),
              let root = try? PropertyListSerialization
                .propertyList(from: data, format: nil) as? [String: Any],
              let entries = root["TOKENS"] as? [[String: String]] else { return [] }

        return entries.compactMap { entry in
            guard let token = entry["token"], !token.isEmpty else { return nil }
            return Credential(name: entry["name"] ?? "embedded", value: token)
        }
    }
}
