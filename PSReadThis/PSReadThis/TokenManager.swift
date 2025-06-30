import Foundation
import Security

actor TokenManager {
  static let shared = TokenManager()

  // MARK: - Config
  private let configURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/storage/v1/object/public/psreadthis/psreadthis-config.json")!
  private var anonKey: String?

  // MARK: - Keys & URLs
  private let supabaseURL     = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co")!
  private let accessTokenKey  = "PSReadThisAccessToken"
  private let refreshTokenKey = "PSReadThisRefreshToken"
  private let expiresAtKey    = "PSReadThisExpiresAt"

  private let keychainAccessGroup = "com.pavels.PSReadThis"

  // MARK: - Public

  /// Ensures we have an anonKey loaded, then returns a valid JWT.
  func getValidAccessToken() async throws -> String {
    print("[PSReadThis] 🔑 getValidAccessToken() called (extension)")
    try await loadAnonKeyIfNeeded()
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

  // MARK: - Load anon key

  private func loadAnonKeyIfNeeded() async throws {
    print("[PSReadThis] !! 🔑 loadAnonKeyIfNeeded() start (extension)")
    if anonKey != nil { return }
    
    // Use the working anon key from logs - hardcoded to bypass remote config issues
    let correctAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlqZHR3cnNxZ2J3ZmdmdGNreXdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2NTc0OTgsImV4cCI6MjA2NjIzMzQ5OH0.5g-vKzecYOf8fZut3h2lvVewbXoO9AvjYcLDxLN_510"
    
    anonKey = correctAnonKey
    print("[PSReadThis] 🔑 Using hardcoded correct anonKey in TokenManager: \(correctAnonKey.prefix(50))...")
    UserDefaults.standard.set(correctAnonKey, forKey: "PSReadThisAnonKey")
  }

  // MARK: - Login / Refresh

  private func login() async throws {
    guard let anon = anonKey else { fatalError("anonKey not loaded") }
    let email    = "psokolovs@gmail.com"
    let password = "11111"

    // Correctly build the login URL with query string
    var components = URLComponents(url: supabaseURL, resolvingAgainstBaseURL: false)!
    components.path = "/auth/v1/token"
    components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
    let loginURL = components.url!
    var req = URLRequest(url: loginURL)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField:"Content-Type")
    req.setValue(anon, forHTTPHeaderField:"apikey")
    req.httpBody = try JSONEncoder().encode(["email": email, "password": password])
    print("[PSReadThis] 🔐 login() with anonKey:", anon)
    print("[PSReadThis] 🔐 login() URL:", loginURL)
    print("[PSReadThis] 🔐 login() headers:", req.allHTTPHeaderFields ?? [:])
    if let body = req.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
        print("[PSReadThis] 🔐 login() body:", bodyStr)
    }

    let (data, res) = try await URLSession.shared.data(for: req)
    guard let http = res as? HTTPURLResponse, http.statusCode == 200 else {
      let body = String(data:data, encoding:.utf8) ?? ""
      print("⚠️ login failed:", res, body)
      throw URLError(.badServerResponse)
    }
    let session = try JSONDecoder().decode(AuthSession.self, from: data)
    try storeSession(session)
  }

  private func refreshToken() async throws {
    guard let anon = anonKey else { fatalError("anonKey not loaded") }
    guard let refresh = loadKeychain(key: refreshTokenKey) else {
      try await login(); return
    }

    // Correctly build the refresh URL with query string
    var components = URLComponents(url: supabaseURL, resolvingAgainstBaseURL: false)!
    components.path = "/auth/v1/token"
    components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
    let url = components.url!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField:"Content-Type")
    req.setValue(anon, forHTTPHeaderField:"apikey")
    req.httpBody = try JSONEncoder().encode(["refresh_token": refresh])
    print("[PSReadThis] 🔄 refreshToken() with anonKey:", anon)
    print("[PSReadThis] 🔄 refreshToken() URL:", url)
    print("[PSReadThis] 🔄 refreshToken() headers:", req.allHTTPHeaderFields ?? [:])
    if let body = req.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
        print("[PSReadThis] 🔄 refreshToken() body:", bodyStr)
    }

    let (data, res) = try await URLSession.shared.data(for: req)
    if let http = res as? HTTPURLResponse, http.statusCode != 200 {
      print("⚠️ refresh failed:", http.statusCode)
      try await login(); return
    }
    let session = try JSONDecoder().decode(AuthSession.self, from: data)
    try storeSession(session)
  }

  // MARK: – Helpers (expiry, Keychain)

  private func isTokenExpiredOrMissing() -> Bool {
    guard let d = UserDefaults.standard.object(forKey: expiresAtKey) as? Date else {
      return true
    }
    return Date() >= d.addingTimeInterval(-60)
  }

  private func storeSession(_ s: AuthSession) throws {
    try saveKeychain(key: accessTokenKey,  value: s.access_token)
    try saveKeychain(key: refreshTokenKey, value: s.refresh_token)
    let expiresAt = Date().addingTimeInterval(TimeInterval(s.expires_in))
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
            let string = String(data: data, encoding: .utf8)
      else {
          print("[TokenManager] loadKeychain(\(key)) failed with status: \(status)")
          return nil
      }
      return string
  }
  
  private func saveKeychain(key: String, value: String) throws {
      let accessGroup = resolveKeychainAccessGroup()
      print("[TokenManager] saveKeychain(\(key)) using access group: \(accessGroup)")
      
      // First delete any existing item
      let deleteQuery: [CFString: Any] = [
          kSecClass:       kSecClassGenericPassword,
          kSecAttrAccessGroup: accessGroup,
          kSecAttrAccount: key
      ]
      let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
      print("[TokenManager] Delete existing item status: \(deleteStatus)")

      // Then add the new value
      let addQuery: [CFString: Any] = [
          kSecClass:           kSecClassGenericPassword,
          kSecAttrAccessGroup: accessGroup,
          kSecAttrAccount:     key,
          kSecValueData:       value.data(using: .utf8)!,
          kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlock
      ]
      let status = SecItemAdd(addQuery as CFDictionary, nil)
      print("[TokenManager] SecItemAdd status: \(status)")
      guard status == errSecSuccess else {
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

  // Add this debug method
  func debugPrintAccessToken() {
    let token = loadKeychain(key: accessTokenKey) ?? "none"
    print("[TokenManager] Current access token in keychain: \(token.prefix(16))...")
  }
  
  // Add comprehensive keychain diagnostics
  func debugKeychainAccess() {
      print("=== KEYCHAIN DIAGNOSTICS ===")
      print("Bundle Identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
      print("Team ID: \(getTeamIdentifier() ?? "unknown")")
      print("Resolved Access Group: \(resolveKeychainAccessGroup())")
      print("Original Access Group: \(keychainAccessGroup)")
      
      // Test keychain write/read
      let testKey = "PSReadThisTestKey"
      let testValue = "test-value-\(Date().timeIntervalSince1970)"
      
      do {
          try saveKeychain(key: testKey, value: testValue)
          print("✅ Test write successful")
          
          if let retrievedValue = loadKeychain(key: testKey), retrievedValue == testValue {
              print("✅ Test read successful: \(retrievedValue)")
          } else {
              print("❌ Test read failed or value mismatch")
          }
          
          // Clean up test key
          let deleteQuery: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccessGroup: resolveKeychainAccessGroup(),
              kSecAttrAccount: testKey
          ]
          SecItemDelete(deleteQuery as CFDictionary)
          
      } catch {
          print("❌ Test write failed: \(error)")
      }
      print("=== END DIAGNOSTICS ===")
  }
  
  // Enhanced diagnostics to check entitlement resolution  
  func debugKeychainEntitlements() {
      print("=== ENTITLEMENT DIAGNOSTICS ===")
      
      // Test both access group formats
      let formats = [
          "$(AppIdentifierPrefix)com.pavels.PSReadThis",
          "4MUD97LXVQ.com.pavels.PSReadThis"
      ]
      
      for format in formats {
          print("🧪 Testing access group format: \(format)")
          let testKey = "PSReadThisTest_\(format.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "(", with: "_").replacingOccurrences(of: ")", with: "_").replacingOccurrences(of: "$", with: "_"))"
          
          let addQuery: [CFString: Any] = [
              kSecClass:           kSecClassGenericPassword,
              kSecAttrAccessGroup: format,
              kSecAttrAccount:     testKey,
              kSecValueData:       "test".data(using: .utf8)!,
              kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlock
          ]
          
          let status = SecItemAdd(addQuery as CFDictionary, nil)
          if status == errSecSuccess {
              print("✅ Access group \(format) works!")
              // Clean up
              let deleteQuery: [CFString: Any] = [
                  kSecClass: kSecClassGenericPassword,
                  kSecAttrAccessGroup: format,
                  kSecAttrAccount: testKey
              ]
              SecItemDelete(deleteQuery as CFDictionary)
          } else {
              print("❌ Access group \(format) failed with status: \(status)")
          }
      }
      
      print("=== END ENTITLEMENT DIAGNOSTICS ===")
  }

  // Add method to clear all authentication data
  func clearAllTokens() async {
      print("[TokenManager] 🧹 Clearing all authentication data...")
      
      let accessGroup = resolveKeychainAccessGroup()
      
      // Clear all keychain items
      let keysToDelete = [accessTokenKey, refreshTokenKey]
      for key in keysToDelete {
          let deleteQuery: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccessGroup: accessGroup,
              kSecAttrAccount: key
          ]
          let status = SecItemDelete(deleteQuery as CFDictionary)
          print("[TokenManager] Deleted \(key) with status: \(status)")
      }
      
      // Clear UserDefaults
      UserDefaults.standard.removeObject(forKey: expiresAtKey)
      UserDefaults.standard.removeObject(forKey: "PSReadThisAnonKey")
      
      // Clear cached anon key
      anonKey = nil
      
      print("[TokenManager] ✅ All authentication data cleared")
  }
}

private struct AuthSession: Decodable {
  let access_token:String, expires_in:Int, refresh_token:String, user: User
}
private struct User: Decodable { let id:String }
