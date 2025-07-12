import UIKit
import UniformTypeIdentifiers
import Network
import Foundation
import Security

// MARK: - Remote Operations Log
struct RemoteOperation: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let operation: String
    let url: String
    let method: String
    let statusCode: Int?
    let success: Bool
    let details: String
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    init(timestamp: Date, operation: String, url: String, method: String, statusCode: Int?, success: Bool, details: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.operation = operation
        self.url = url
        self.method = method
        self.statusCode = statusCode
        self.success = success
        self.details = details
    }
    
    // For decoding
    init(id: UUID, timestamp: Date, operation: String, url: String, method: String, statusCode: Int?, success: Bool, details: String) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.url = url
        self.method = method
        self.statusCode = statusCode
        self.success = success
        self.details = details
    }
}

// Constants for remote operations logging
private let remoteLogKey = "PSReadRemoteOperationsLog"
private let appGroupSuite = "group.com.pavels.psreadthis"

/// Handles Supabase login, refresh, and secure token storage.
final class TokenManager {
    static let shared = TokenManager()
    private init() {}

    // MARK: – Keys
    private let accessTokenKey  = "PSReadThisAccessToken"
    private let refreshTokenKey = "PSReadThisRefreshToken"
    private let expiresAtKey    = "PSReadThisExpiresAt"  // stored in UserDefaults

    // Replace with your own values:
    let supabaseURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co")!
    private var cachedAnonKey: String?

    // MARK: – Public API

    func getAnonKey() async throws -> String {
        print("[PSReadThis] 🔑 Using hardcoded correct anon key to match other extensions")
        
        // Use the working anon key from the logs (the one that's actually working in main app)
        let correctAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlqZHR3cnNxZ2J3ZmdmdGNreXdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2NTc0OTgsImV4cCI6MjA2NjIzMzQ5OH0.5g-vKzecYOf8fZut3h2lvVewbXoO9AvjYcLDxLN_510"
        
        // Return the correct anon key directly - no remote fetching
        cachedAnonKey = correctAnonKey
        UserDefaults.standard.set(correctAnonKey, forKey: "PSReadThisAnonKey")
        
        print("[PSReadThis] ✅ Using correct anon key: \(correctAnonKey.prefix(50))...")
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
        let anonKey = try await getAnonKey()
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
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

class ConfirmationViewController: UIViewController {
    var urlToSave: String? // This will be set by the extension context
    private let label = UILabel()
    private var hasCompleted = false
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = false
    private let remoteLogKey = "PSReadRemoteOperationsLog"
    private let appGroupSuite = "group.com.pavels.psreadthis"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // CRITICAL DEBUG: This should ALWAYS appear in logs
        print("[ConfirmationVC] 🚀 EXTENSION STARTED - viewDidLoad called")
        print("[ConfirmationVC] 🚀 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("[ConfirmationVC] 🚀 Process Name: \(ProcessInfo.processInfo.processName)")
        
        // Minimal UI setup first - show immediately  
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.isOpaque = false
        setupLabel()
        showSaving()
        
        // Force timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, !self.hasCompleted else { return }
            print("[ConfirmationVC] ⏰ TIMEOUT: Force completing after 10s")
            self.forceComplete()
        }
        
        // Start background operations asynchronously to not block UI
        Task {
            await initializeAndProcess()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[ConfirmationVC] 📱 viewDidAppear - UI now visible")
    }
    
    private func initializeAndProcess() async {
        // Setup network monitoring in background
        setupNetworkMonitoring()
        
        // Start processing
        startSaveProcess()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
            print("[ConfirmationVC] 🌐 Network status: \(path.status == .satisfied ? "Connected" : "Disconnected")")
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    private func forceComplete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func setupLabel() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.text = "Saving..."
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func showSaving() {
        label.text = "Saving..."
    }

    private func showSaved(domain: String) {
        label.text = "Link from \(domain) saved!"
    }
    
    private func showSavedOffline(domain: String) {
        label.text = "Link from \(domain) saved for later sync!"
    }

    private func showError() {
        label.text = "Failed to save link."
    }

    private func startSaveProcess() {
        // 1. Try public.url from ALL input items
        if let inputItems = extensionContext?.inputItems as? [NSExtensionItem] {
            for inputItem in inputItems {
                if let attachments = inputItem.attachments {
                    for provider in attachments {
                        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                            print("[ConfirmationVC] 🎯 Found URL in input item, extracting...")
                            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (urlItem, error) in
                                guard let self = self else { return }
                                if let error = error {
                                    print("[ConfirmationVC] ❌ Error loading URL: \(error)")
                                    self.tryOtherSources(inputItem: inputItem)
                                    return
                                }
                                guard let url = urlItem as? URL else {
                                    print("[ConfirmationVC] ⚠️ URL item was not a URL: \(String(describing: urlItem))")
                                    self.tryOtherSources(inputItem: inputItem)
                                    return
                                }
                                print("[ConfirmationVC] ✅ Successfully extracted URL: \(url.absoluteString)")
                                Task { await self.saveAndShowResult(url: url.absoluteString) }
                            }
                            return
                        }
                    }
                }
            }
            // 2. If no public.url found in any item, try other sources with first item
            if let firstItem = inputItems.first {
                self.tryOtherSources(inputItem: firstItem)
            } else {
                self.tryClipboard()
            }
            return
        }
        // 3. If no inputItems, try clipboard
        self.tryClipboard()
    }

    private func tryOtherSources(inputItem: NSExtensionItem) {
        // Try userInfo for a URL string
        if let userInfo = inputItem.userInfo {
            for value in userInfo.values {
                if let urlString = value as? String, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                    Task { await self.saveAndShowResult(url: url.absoluteString) }
                    return
                }
            }
        }
        // Try attachments for a file-url and see if the original URL is embedded
        if let attachments = inputItem.attachments {
                    for provider in attachments {
            // Check for direct URL first (this is what we're getting from PDFs)
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                print("[ConfirmationVC] 📦 Found URL provider (public.url)")
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (urlItem, error) in
                    guard let self = self else { return }
                    if let error = error {
                        print("[ConfirmationVC] ❌ Error loading URL item: \(error)")
                        self.tryClipboard()
                        return
                    }
                    guard let url = urlItem as? URL else {
                        print("[ConfirmationVC] ⚠️ URL item was not a URL: \(String(describing: urlItem))")
                        self.tryClipboard()
                        return
                    }
                    print("[ConfirmationVC] 🔗 Successfully extracted URL from extension context: \(url.absoluteString)")
                    Task {
                        await self.saveAndShowResult(url: url.absoluteString)
                    }
                }
                return
            }
            
            // Fallback: Check for file URLs
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                print("[ConfirmationVC] 📦 Found file URL provider")
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] (urlItem, error) in
                    guard let self = self else { return }
                    if urlItem is URL {
                        // Try to extract the original URL from the file URL (not usually possible)
                        // Fallback: try clipboard
                        self.tryClipboard()
                    } else {
                        self.tryClipboard()
                    }
                }
                return
            }
        }
        }
        // Fallback: try clipboard
        self.tryClipboard()
    }

    private func tryClipboard() {
        // Run comprehensive diagnostics first
        debugPasteboardIssue()
        
        do {
            // Try accessing pasteboard with error handling
            let pasteboard = UIPasteboard.general
            print("[PSReadThis] 📋 Pasteboard name: \(pasteboard.name)")
            print("[PSReadThis] 📋 Attempting to access pasteboard...")
            
            // Test basic properties first
            let hasURLs = pasteboard.hasURLs
            let hasStrings = pasteboard.hasStrings
            let itemCount = pasteboard.numberOfItems
            
            print("[PSReadThis] 📋 hasURLs: \(hasURLs), hasStrings: \(hasStrings), itemCount: \(itemCount)")
            
            // Try getting string with explicit error handling
            var clipboardString: String?
            
            if hasStrings {
                clipboardString = pasteboard.string
                print("[PSReadThis] 📋 String retrieval: \(clipboardString != nil ? "SUCCESS" : "FAILED")")
            }
            
            // Validate URL if we got a string
            if let clipboardString = clipboardString,
               let url = URL(string: clipboardString),
               url.scheme?.hasPrefix("http") == true {
                
                print("[PSReadThis] ✅ Valid URL found in clipboard: \(url.absoluteString)")
                
                // Show confirmation alert before saving
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Use Clipboard URL?",
                        message: "Do you want to save this URL from your clipboard?\n\n\(clipboardString)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        self.showError()
                        self.dismissAfterDelay()
                    })
                    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                        Task { await self.saveAndShowResult(url: url.absoluteString) }
                    })
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                print("[PSReadThis] ❌ No valid URL found in clipboard")
                DispatchQueue.main.async {
                    self.showError()
                    self.dismissAfterDelay()
                }
            }
            
        } catch let error as NSError {
            print("[PSReadThis] ❌ Pasteboard access error: \(error)")
            print("[PSReadThis] ❌ Error domain: \(error.domain)")
            print("[PSReadThis] ❌ Error code: \(error.code)")
            print("[PSReadThis] ❌ Error userInfo: \(error.userInfo)")
            
            DispatchQueue.main.async {
                self.showError()
                self.dismissAfterDelay()
            }
        }
    }
    
    private func debugPasteboardIssue() {
        // Minimal debugging to prevent memory issues
        print("[ConfirmationVC] 📋 Pasteboard check: hasURLs=\(UIPasteboard.general.hasURLs), hasStrings=\(UIPasteboard.general.hasStrings)")
    }

    private func dismissAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.forceComplete()
        }
    }

    private func saveToQueue(url: String) {
        // CRITICAL DEBUG: This should ALWAYS appear when saving
        print("[ConfirmationVC] 🚀 SAVE TO QUEUE CALLED for URL: \(url)")
        
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        var queue = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
        
        // Remove any existing entry for this URL to avoid duplicates
        queue.removeAll { entry in
            if let existingUrl = entry["url"] as? String {
                return existingUrl == url
            }
            return false
        }
        
        // Add new entry with intent metadata
        let queueEntry: [String: Any] = [
            "url": url,
            "status": "read",  // PSReadThisShare intent: already read
            "timestamp": Date().timeIntervalSince1970,
            "source": "PSReadThisShare"
        ]
        queue.append(queueEntry)
        
        defaults.set(queue, forKey: "PSReadQueue")
        print("[ConfirmationVC] 📋 Queue after append: \(queue.count) items")
        
        // CRITICAL DEBUG: About to log remote operation
        print("[ConfirmationVC] 🚀 ABOUT TO CALL appendRemoteOperation")
        
        // Log the queue operation
        let operation = RemoteOperation(
            timestamp: Date(),
            operation: "ShareExt Queue Add",
            url: url,
            method: "QUEUE_ADD",
            statusCode: nil,
            success: true,
            details: "Added to queue with status: read, Source: PSReadThisShare"
        )
        appendRemoteOperation(operation)
        
        print("[ConfirmationVC] 🚀 FINISHED calling appendRemoteOperation")
    }

    private func syncQueueToSupabase() async -> [String: Any] {
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
            var queue = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
            print("[ConfirmationVC] 🔄 Syncing read URLs: \(queue)")
            var sent: [String] = []
                         for entry in queue {
                 if let url = entry["url"] as? String,
                    let status = entry["status"] as? String,
                    await postLink(rawUrl: url, status: status, token: token) {
                     sent.append(url)
                 }
             }
            queue.removeAll(where: { sent.contains($0["url"] as? String ?? "") })
            defaults.set(queue, forKey: "PSReadQueue")
            print("[ConfirmationVC] ✅ Sent read URLs: \(sent)")
            print("[ConfirmationVC] 📦 Remaining read queue: \(queue)")
            let op = RemoteOperation(
                timestamp: Date(),
                operation: "ShareExt Sync Queue",
                url: sent.first ?? "multiple",
                method: "POST/PATCH",
                statusCode: nil,
                success: !sent.isEmpty,
                details: "Sent \(sent.count) URLs, Source: PSReadThisShare"
            )
            appendRemoteOperation(op)
            return ["success": !sent.isEmpty, "sent": sent]
        } catch {
            return ["success": false]
        }
    }

    private func postLink(rawUrl: String, status: String, token: String) async -> Bool {
        do {
            // Extract user ID from token
            let userId = extractUserIdFromToken(token) ?? "unknown"
            print("[ConfirmationVC] 📡 Fast UPSERT: \(rawUrl) → \(status)")
            
            // Use Supabase UPSERT - single call handles both insert and update
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            let anonKey = try await TokenManager.shared.getAnonKey()
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 8.0  // Fast timeout for share extensions
            
            let body = [
                "raw_url": rawUrl, 
                "list": "read", 
                "status": status,  // Use status from queue metadata
                "user_id": userId
            ]
            request.httpBody = try JSONEncoder().encode(body)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[ConfirmationVC] 📡 UPSERT result: \(http.statusCode)")
                
                // Handle both success cases and conflict resolution
                if (200...299).contains(http.statusCode) {
                    let removalOp = RemoteOperation(
                        timestamp: Date(),
                        operation: "ShareExt Queue Removal",
                        url: rawUrl,
                        method: "QUEUE_REMOVE",
                        statusCode: http.statusCode,
                        success: true,
                        details: "Removed from queue after successful sync"
                    )
                    appendRemoteOperation(removalOp)
                    return true
                } else if http.statusCode == 409 {
                    // Conflict - do a simple PATCH update
                    print("[ConfirmationVC] 📡 Conflict detected, doing quick update")
                    return await quickUpdateStatus(rawUrl: rawUrl, status: status, userId: userId, token: token)
                }
                return false
            }
            return false
        } catch {
            print("[ConfirmationVC] 🌐 Network error: \(error)")
            let removalOp = RemoteOperation(
                timestamp: Date(),
                operation: "ShareExt Queue Removal",
                url: rawUrl,
                method: "QUEUE_REMOVE",
                statusCode: nil,
                success: false,
                details: "Removed from queue after failed sync"
            )
            appendRemoteOperation(removalOp)
            return false
        }
    }
    
    private func quickUpdateStatus(rawUrl: String, status: String, userId: String, token: String) async -> Bool {
        do {
            guard let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedUrl = rawUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return false
            }
            
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?user_id=eq.\(encodedUserId)&raw_url=eq.\(encodedUrl)")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            let anonKey = try await TokenManager.shared.getAnonKey()
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 5.0
            
            let body = ["status": status]
            request.httpBody = try JSONEncoder().encode(body)
        
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[ConfirmationVC] 📡 Quick update: \(http.statusCode)")
                let removalOp = RemoteOperation(
                    timestamp: Date(),
                    operation: "ShareExt Queue Removal",
                    url: rawUrl,
                    method: "QUEUE_REMOVE",
                    statusCode: http.statusCode,
                    success: http.statusCode == 204,
                    details: "Removed from queue after quick update"
                )
                appendRemoteOperation(removalOp)
                return http.statusCode == 204
            }
            return false
        } catch {
            print("[ConfirmationVC] 🌐 Quick update error: \(error)")
            let removalOp = RemoteOperation(
                timestamp: Date(),
                operation: "ShareExt Queue Removal",
                url: rawUrl,
                method: "QUEUE_REMOVE",
                statusCode: nil,
                success: false,
                details: "Removed from queue after failed quick update"
            )
            appendRemoteOperation(removalOp)
            return false
        }
    }
    
    // Helper function to extract user ID from JWT token
    private func extractUserIdFromToken(_ token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("[ConfirmationVC] Invalid JWT format")
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
            print("[ConfirmationVC] Could not extract user ID from token")
            return nil
        }
        
        print("[ConfirmationVC] Successfully extracted user ID: \(sub)")
        return sub
    }

    private func appendRemoteOperation(_ op: RemoteOperation) {
        // CRITICAL DEBUG: This should ALWAYS appear when logging
        print("[ConfirmationVC] 🚀 appendRemoteOperation CALLED")
        print("[ConfirmationVC] 🚀 Operation: \(op.operation)")
        print("[ConfirmationVC] 🚀 URL: \(op.url)")
        print("[ConfirmationVC] 🚀 App Group Suite: \(appGroupSuite)")
        print("[ConfirmationVC] 🚀 Remote Log Key: \(remoteLogKey)")
        
        let defaults = UserDefaults(suiteName: appGroupSuite) ?? .standard
        var log: [RemoteOperation] = []
        if let data = defaults.data(forKey: remoteLogKey),
           let decoded = try? JSONDecoder().decode([RemoteOperation].self, from: data) {
            log = decoded
            print("[ConfirmationVC] 🚀 Loaded existing log with \(log.count) items")
        } else {
            print("[ConfirmationVC] 🚀 No existing log found, starting fresh")
        }
        
        log.append(op)
        print("[ConfirmationVC] 🚀 Log now has \(log.count) items after append")
        
        if log.count > 50 { log.removeFirst(log.count - 50) }
        
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: remoteLogKey)
            print("[ConfirmationVC] 🚀 Successfully saved log to UserDefaults")
        } else {
            print("[ConfirmationVC] 🚀 ❌ FAILED to encode log data")
        }
    }

    // Removed excessive debugging functions to prevent memory issues

    private func saveAndShowResult(url: String) async {
        print("[ConfirmationVC] 💾 Save and show result for: \(url)")
        
        // 1. ALWAYS save to queue first (this is instant and reliable)
        saveToQueue(url: url)
        
        // 2. Extract domain for display
        let domain = URL(string: url)?.host ?? "this page"
        
        // 3. Handle online vs offline scenarios with proper feedback
        if isNetworkAvailable {
            print("[ConfirmationVC] 🌐 Online: Attempting immediate sync...")
            
            // Show saving indicator while we try to sync
            DispatchQueue.main.async {
                self.showSaving()
            }
            
            // Set up a quick sync attempt with timeout
            let syncSucceeded = await withTaskGroup(of: Bool.self) { group in
                // Add sync task
                group.addTask {
                    let result = await self.syncQueueToSupabase()
                    return result["success"] as? Bool == true
                }
                
                // Add timeout task
                group.addTask {
                    do {
                        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                        return false // Timeout
                    } catch {
                        return false
                    }
                }
                
                // Return first result
                guard let firstResult = await group.next() else { return false }
                group.cancelAll()
                return firstResult
            }
            
            DispatchQueue.main.async {
                if syncSucceeded {
                    print("[ConfirmationVC] ✅ Successfully synced online")
                    self.showSaved(domain: domain)
                } else {
                    print("[ConfirmationVC] ⚠️ Sync failed/timeout - saved for later")
                    self.showSavedOffline(domain: domain)
                }
                self.dismissAfterDelay()
            }
        } else {
            // 4. Offline - show immediate "saved for later" feedback
            print("[ConfirmationVC] 📱 Offline: Saved for later sync")
            DispatchQueue.main.async {
                self.showSavedOffline(domain: domain)
                self.dismissAfterDelay()
            }
        }
    }
}