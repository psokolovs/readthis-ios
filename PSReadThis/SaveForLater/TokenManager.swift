import Foundation
import Security

final class TokenManager {
    static let shared = TokenManager()
    private init() {}

    // MARK: – Keys
    private let accessTokenKey  = "PSReadThisAccessToken"
    private let refreshTokenKey = "PSReadThisRefreshToken"
    private let expiresAtKey    = "PSReadThisExpiresAt"  // stored in UserDefaults

    // Replace with your own values:
    let supabaseURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co")!
    
    // Use the working anon key from the logs (the one that's actually working in main app)
    private let correctAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlqZHR3cnNxZ2J3ZmdmdGNreXdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2NTc0OTgsImV4cCI6MjA2NjIzMzQ5OH0.5g-vKzecYOf8fZut3h2lvVewbXoO9AvjYcLDxLN_510"
    private var cachedAnonKey: String?

    // MARK: – Public API

    func getAnonKey() async throws -> String {
        print("[SaveForLater] 🔑 Using hardcoded correct anon key to match main app")
        
        // Return the correct anon key directly - no remote fetching
        cachedAnonKey = correctAnonKey
        UserDefaults.standard.set(correctAnonKey, forKey: "PSReadThisAnonKey")
        
        print("[SaveForLater] ✅ Using correct anon key: \(correctAnonKey.prefix(50))...")
        return correctAnonKey
    }

    /// Returns a valid access token, auto-refreshing or re-logging-in as needed.
    func getValidAccessToken() async throws -> String {
        if isTokenExpiredOrMissing() {
            try await refreshToken()
        }
        guard let token = loadKeychain(key: accessTokenKey) else {
            try await login()
            guard let newToken = loadKeychain(key: accessTokenKey) else {
                throw URLError(.userAuthenticationRequired)
            }
            return newToken
        }
        return token
    }

    // MARK: – Login / Refresh

    private func login() async throws {
        print("[PSReadThis] 🔐 login() started at \(Date())")
        let email    = "psokolovs@gmail.com"
        let password = "11111"
        print("[PSReadThis] 🔐 login() credentials: email=\(email), password=[REDACTED]")

        // Build URL with query string properly instead of encoding it as a path component
        let loginURL = URL(string: "\(supabaseURL.absoluteString)/auth/v1/token?grant_type=password")!
        print("[PSReadThis] 🔐 login() URL: \(loginURL)")

        var req = URLRequest(url: loginURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let anonKey = try await getAnonKey()
        req.setValue(anonKey, forHTTPHeaderField: "apikey")

        print("[PSReadThis] 🔐 login() HTTP Method: \(req.httpMethod ?? "nil")")
        print("[PSReadThis] 🔐 login() Headers: \(req.allHTTPHeaderFields ?? [:])")

        let body = ["email": email, "password": password]
        req.httpBody = try JSONEncoder().encode(body)
        if let bodyData = req.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[PSReadThis] 🔐 login() Request Body: \(bodyString)")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                print("[PSReadThis] 🔐 login() Response Status: \(http.statusCode)")
                print("[PSReadThis] 🔐 login() Response Headers: \(http.allHeaderFields)")
                let respBody = String(data: data, encoding: .utf8) ?? ""
                print("[PSReadThis] 🔐 login() Response Body: \(respBody)")
                if http.statusCode != 200 {
                    print("[PSReadThis] 🔐 login() Error: Non-200 status")
                    throw URLError(.badServerResponse)
                }
            }
            let session = try JSONDecoder().decode(AuthSession.self, from: data)
            print("[PSReadThis] 🔐 login() Decoded Session: user.id=\(session.user.id), expires_in=\(session.expires_in)")
            try storeSession(session)
            print("[PSReadThis] 🔐 login() Session stored successfully")
        } catch {
            print("[PSReadThis] 🔐 login() Exception thrown: \(error)")
            throw error
        }
    }

    private func refreshToken() async throws {
        guard let refreshToken = loadKeychain(key: refreshTokenKey) else {
            try await login()
            return
        }
        // Build refresh URL with query string properly
        let url = URL(string: "\(supabaseURL.absoluteString)/auth/v1/token?grant_type=refresh_token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let anonKey = try await getAnonKey()
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        let body = ["refresh_token": refreshToken]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, res) = try await URLSession.shared.data(for: req)
        if let http = res as? HTTPURLResponse, http.statusCode != 200 {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            print("[PSReadThis] ❌ refreshToken() failed, status:", http.statusCode, "body:", bodyString)
            try await login()
            return
        }
        let session = try JSONDecoder().decode(AuthSession.self, from: data)
        try storeSession(session)
    }

    // MARK: – Expiry Check

    private func isTokenExpiredOrMissing() -> Bool {
        guard let expiresAt = UserDefaults.standard.object(forKey: expiresAtKey) as? Date else {
            return true
        }
        return Date() >= expiresAt.addingTimeInterval(-60)
    }

    // MARK: – Storage Helpers

    private func storeSession(_ session: AuthSession) throws {
        try saveKeychain(key: accessTokenKey,  value: session.access_token)
        try saveKeychain(key: refreshTokenKey, value: session.refresh_token)
        let expiresAt = Date().addingTimeInterval(TimeInterval(session.expires_in))
        UserDefaults.standard.set(expiresAt, forKey: expiresAtKey)
    }

    private func loadKeychain(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccessGroup: resolveKeychainAccessGroup(),
            kSecAttrAccount:     key,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        print("[TokenManager] loadKeychain(\(key)) status: \(status), group: \(resolveKeychainAccessGroup())")
        guard status == errSecSuccess,
              let data = item as? Data,
              let str  = String(data: data, encoding: .utf8)
        else { 
            print("[TokenManager] loadKeychain(\(key)) failed with status: \(status)")
            return nil 
        }
        return str
    }

    private func saveKeychain(key: String, value: String) throws {
        let accessGroup = resolveKeychainAccessGroup()
        print("[TokenManager] saveKeychain(\(key)) using access group: \(accessGroup)")
        
        let deleteQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccessGroup: accessGroup,
            kSecAttrAccount: key
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        print("[TokenManager] Delete existing item status: \(deleteStatus)")
        
        let addQuery: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccessGroup: accessGroup,
            kSecAttrAccount:     key,
            kSecValueData:       value.data(using: .utf8)!,
            kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        print("[TokenManager] SecItemAdd status: \(status)")
        if status != errSecSuccess {
            print("[Keychain] SecItemAdd failed with status: \(status) for access group: \(accessGroup)")
            print("[Keychain] Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
            print("[Keychain] Team ID: \(getTeamIdentifier() ?? "unknown")")
            throw URLError(.cannotCreateFile)
        }
    }
    
    private func resolveKeychainAccessGroup() -> String {
        // First try the entitlement variable format
        let entitlementFormat = "$(AppIdentifierPrefix)com.pavels.PSReadThis"
        
        // Test if the entitlement format works by attempting a quick operation
        let testQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessGroup: entitlementFormat,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(testQuery as CFDictionary, &result)
        
        // If the query succeeds or fails with "item not found" (not permission denied), the access group works
        if status == errSecSuccess || status == errSecItemNotFound {
            return entitlementFormat
        }
        
        // Fallback to hardcoded team ID format
        return "4MUD97LXVQ.com.pavels.PSReadThis"
    }
    
    private func getTeamIdentifier() -> String? {
        // Return the hardcoded team ID for development
        return "4MUD97LXVQ"
    }
}

private struct AuthSession: Decodable {
    let access_token:  String
    let expires_in:    Int
    let refresh_token: String
    let user:          User
}

private struct User: Decodable {
    let id: String
} 