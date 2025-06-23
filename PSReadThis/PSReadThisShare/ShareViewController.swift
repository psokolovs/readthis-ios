//
//  ShareViewController.swift
//  PSReadThisShare
//
//  Created by Pavel S on 6/7/25.
//

import Foundation
import Security
import os.log

/// Handles Supabase login, refresh, and secure token storage.
final class TokenManager {
    static let shared = TokenManager()
    private init() {}

    // MARK: – Keys
    private let accessTokenKey  = "PSReadThisAccessToken"
    private let refreshTokenKey = "PSReadThisRefreshToken"
    private let expiresAtKey    = "PSReadThisExpiresAt"  // stored in UserDefaults

    // Replace with your own values:
    let supabaseURL     = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co")!
    let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlqZHR3cnNxZ2J3ZmdmdGNreXdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2NTc0OTgsImV4cCI6MjA2NjIzMzQ5OH0.5g-vKzecYOf8fZut3h2lvVewbXoO9AvjYcLDxLN_510"
    
    // MARK: - Keychain Access Group Resolution
    private lazy var keychainAccessGroup: String = {
        // Try to get the resolved access group from the bundle
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            print("[TokenManager] Bundle identifier: \(bundleIdentifier)")
        }
        
        // Use the main app's keychain access group for shared access
        return "$(AppIdentifierPrefix)com.pavels.PSReadThis"
    }()

    // MARK: – Public API

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
        req.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

        print("[PSReadThis] 🔐 login() HTTP Method: \(req.httpMethod ?? "nil")")
        print("[PSReadThis] 🔐 login() Headers: \(req.allHTTPHeaderFields ?? [:])")

        let body = ["email": email, "password": password]
        req.httpBody = try JSONEncoder().encode(body)
        if let bodyData = req.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[PSReadThis] 🔐 login() Request Body: \(bodyString)")
        }

        // Add timeout for faster share extension response
        req.timeoutInterval = 10.0
        
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
        req.setValue(supabaseAnonKey,       forHTTPHeaderField: "apikey")
        let body = ["refresh_token": refreshToken]
        req.httpBody = try JSONEncoder().encode(body)
        req.timeoutInterval = 10.0

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

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // MARK: - Memory & Timeout Protection
    private var processingStartTime = Date()
    private let maxProcessingTime: TimeInterval = 15.0 // 15 second timeout
    private var hasCompleted = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("[PSReadThis] 🚀 viewDidLoad")
        
        // Set up timeout protection
        setupTimeoutProtection()
        
        // Monitor memory usage
        logMemoryUsage(context: "viewDidLoad")
        
        handleIncomingURL()
    }
    
    private func setupTimeoutProtection() {
        // Force completion after maximum processing time
        DispatchQueue.main.asyncAfter(deadline: .now() + maxProcessingTime) { [weak self] in
            guard let self = self, !self.hasCompleted else { return }
            print("[PSReadThis] ⏰ TIMEOUT: Force completing extension after \(self.maxProcessingTime)s")
            self.forceCompleteExtension(reason: "timeout")
        }
    }
    
    private func logMemoryUsage(context: String) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryMB = info.resident_size / 1024 / 1024
            let elapsed = Date().timeIntervalSince(processingStartTime)
            print("[PSReadThis] 📊 Memory: \(memoryMB)MB | Time: \(String(format: "%.1f", elapsed))s | Context: \(context)")
            
            // Emergency shutdown if memory exceeds 50MB
            if memoryMB > 50 {
                print("[PSReadThis] 🚨 EMERGENCY: Memory usage too high (\(memoryMB)MB)")
                forceCompleteExtension(reason: "memory")
            }
        }
    }
    
    private func forceCompleteExtension(reason: String) {
        guard !hasCompleted else { return }
        hasCompleted = true
        print("[PSReadThis] 🛑 Force completing extension - reason: \(reason)")
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func handleIncomingURL() {
        guard !hasCompleted else { return }
        logMemoryUsage(context: "handleIncomingURL")
        
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            print("[PSReadThis] ⚠️ No input items or attachments")
            completeExtension()
            return
        }

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (urlItem, error) in
                    guard let self = self, !self.hasCompleted else { return }
                    
                    if let error = error {
                        print("[PSReadThis] ❌ Error loading URL item: \(error)")
                        self.completeExtension()
                        return
                    }
                    guard let url = urlItem as? URL else {
                        print("[PSReadThis] ⚠️ URL item was not a URL")
                        self.completeExtension()
                        return
                    }
                    
                    // Memory check before processing
                    self.logMemoryUsage(context: "before URL processing")
                    
                    Task {
                        await self.save(url: url.absoluteString)
                        self.completeExtension()
                    }
                }
                return
            }
        }

        completeExtension()
    }

    private func completeExtension() {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        logMemoryUsage(context: "completeExtension")
        print("[PSReadThis] ✅ completeExtension")
        
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func save(url: String) async {
        guard !hasCompleted else { return }
        logMemoryUsage(context: "save start")
        
        // 1) Append URL to local queue
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        var queue = defaults.stringArray(forKey: "PSReadQueue") ?? []
        queue.append(url)
        defaults.set(queue, forKey: "PSReadQueue")

        // 2) Attempt to sync immediately with timeout
        let success = await withTimeout(seconds: 10) {
            await self.syncQueueToSupabase()
        } ?? false
        
        logMemoryUsage(context: "save end")
        
        if success, let urlObj = URL(string: url), let host = urlObj.host {
            print("[PSReadThis] ✅ Successfully saved link from:", host)
        } else {
            print("[PSReadThis] ⚠️ Failed to save link")
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            
            guard let result = await group.next() else { return nil }
            group.cancelAll()
            return result
        }
    }

    private func syncQueueToSupabase() async -> Bool {
        print("[PSReadThis] 🔄 Starting syncQueueToSupabase")
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            print("[PSReadThis] 🔑 Obtained access token:", token)
            let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
            var queue = defaults.stringArray(forKey: "PSReadQueue") ?? []
            print("[PSReadThis] 🔁 Syncing URLs:", queue)

            var sent: [String] = []
            for rawUrl in queue {
                if await postLink(rawUrl: rawUrl, token: token) {
                    sent.append(rawUrl)
                }
            }

            // Remove successfully sent URLs
            queue.removeAll(where: { sent.contains($0) })
            defaults.set(queue, forKey: "PSReadQueue")
            print("[PSReadThis] ✅ Sent URLs:", sent)
            print("[PSReadThis] 📦 Remaining queue:", queue)
            return !sent.isEmpty
        } catch {
            print("[PSReadThis] ⚠️ Failed to get valid token or sync:", error)
            return false
        }
    }

    private func postLink(rawUrl: String, token: String) async -> Bool {
        // Extract user ID from token to explicitly set it
        let userId = extractUserIdFromToken(token) ?? "unknown"
        print("[PSReadThis] 📡 Processing \(rawUrl) with user_id: \(userId) (mark as read)")
        
        // PSReadThisShare: Mark as read after reading
        // First try to update existing link, then create if doesn't exist
        
        // Step 1: Try to update existing link to mark as read
        if await updateExistingLinkAsRead(rawUrl: rawUrl, userId: userId, token: token) {
            print("[PSReadThis] ✅ Updated existing link as read")
            return true
        }
        
        // Step 2: If no existing link, create new one with status=read
        return await createNewLinkAsRead(rawUrl: rawUrl, userId: userId, token: token)
    }
    
    private func updateExistingLinkAsRead(rawUrl: String, userId: String, token: String) async -> Bool {
        let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?user_id=eq.\(userId)&raw_url=eq.\(rawUrl)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue(TokenManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["status": "read"]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                print("[PSReadThis] 📡 PATCH status: \(http.statusCode), response: \(bodyString)")
                
                // Check if any rows were updated (should be in response headers)
                if let contentRange = http.allHeaderFields["content-range"] as? String {
                    print("[PSReadThis] 📡 Content-Range: \(contentRange)")
                    // If content-range contains numbers, rows were updated
                    return contentRange.contains("-") && http.statusCode == 200
                }
                return http.statusCode == 200
            }
        } catch {
            print("[PSReadThis] 🌐 PATCH Network error:", error)
        }
        return false
    }
    
    private func createNewLinkAsRead(rawUrl: String, userId: String, token: String) async -> Bool {
        let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue(TokenManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("[PSReadThis] 📡 Creating new link as read: \(rawUrl)")
        
        let body = [
            "raw_url": rawUrl, 
            "list": "read", 
            "status": "read",  // Mark as read since user is sharing after reading
            "user_id": userId
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                let bodyString = String(data: data, encoding: .utf8) ?? ""
                print("[PSReadThis] 📡 POST status: \(http.statusCode), response: \(bodyString)")
                return (200...299).contains(http.statusCode)
            }
        } catch {
            print("[PSReadThis] 🌐 POST Network error:", error)
        }
        return false
    }
    
    // Helper function to extract user ID from JWT token
    private func extractUserIdFromToken(_ token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("[PSReadThis] Invalid JWT format")
            return nil
        }
        
        let payload = parts[1]
        // Add padding if needed for base64 decoding
        var base64 = payload
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            print("[PSReadThis] Could not extract user ID from token")
            return nil
        }
        
        print("[PSReadThis] Successfully extracted user ID: \(sub)")
        return sub
    }
}
