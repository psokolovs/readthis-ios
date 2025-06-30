import Foundation
import UIKit

// MARK: - Simplified System (Performance Optimized)
// Complex filtering system removed to prevent iPhone freezing

// Complex content detection functions removed for performance

// MARK: - Legacy Filter Support (keeping for backward compatibility)
enum LinkFilter: String, CaseIterable {
    case all = "all"
    case unread = "unread" 
    case read = "read"
    
    var displayName: String {
        switch self {
        case .all: return "All Saved"
        case .unread: return "To Read" 
        case .read: return "Saved"
        }
    }
    
    // Only show unread and read in main filter UI
    static var mainFilters: [LinkFilter] {
        return [.unread, .read]
    }
}

@MainActor
class LinksViewModel: ObservableObject {
    // Using secure PSReadThisConfig for key management
    
    @Published var links: [Link] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var error: String?
    @Published var currentFilter: LinkFilter = .unread
    
    // Simplified for performance (removed complex filtering)
    private let pageSize = 20
    
    // Basic pagination cursors (simplified)
    private var lastUpdatedAt: String? = nil
    private var lastId: String? = nil

    func fetchLinks(reset: Bool = false) async {
        print("[LinksViewModel] fetchLinks called. reset=\(reset), lastUpdatedAt=\(String(describing: lastUpdatedAt)), lastId=\(String(describing: lastId)), links.count=\(links.count), filter=\(currentFilter.rawValue)")
        
        if reset {
            print("[LinksViewModel] Resetting state.")
            links = []
            lastUpdatedAt = nil
            lastId = nil  // Reset compound cursor
            hasMore = true
        }
        
        guard !isLoading, hasMore else {
            print("[LinksViewModel] Skipping fetch: isLoading=\(isLoading), hasMore=\(hasMore)")
            return
        }
        
        isLoading = true
        error = nil
        
        // Sync any pending mark-as-read actions when fetching
        await syncMarkAsReadQueue()
        
        // Sync any pending extension queues when fetching
        await syncExtensionQueue()
        
        do {
            print("[LinksViewModel] 🔐 Getting access token...")
            let token = try await TokenManager.shared.getValidAccessToken()
            print("[LinksViewModel] ✅ Got access token successfully")
            
            // Extract user ID from the JWT token to explicitly filter by user
            let userId = extractUserIdFromToken(token) ?? "unknown"
            print("[LinksViewModel] Extracted user ID from token: \(userId)")
            
            print("[LinksViewModel] 🔑 Getting anon key...")
            guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                print("[LinksViewModel] ❌ Failed to get anon key")
                self.error = "Configuration error. Please check your connection."
                isLoading = false
                return
            }
            print("[LinksViewModel] ✅ Got anon key successfully")
            
            // Build URL with status filtering and user filtering - sort by updated_at,id for compound cursor pagination
            var urlString = "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?select=*&order=updated_at.desc.nullslast,id.desc&limit=\(pageSize)"
            
            // Add status filter based on current filter
            switch currentFilter {
            case .unread:
                urlString += "&status=eq.unread"
                print("[LinksViewModel] Adding unread filter")
            case .read:
                urlString += "&status=eq.read"
                print("[LinksViewModel] Adding read filter")
            case .all:
                print("[LinksViewModel] No status filter - showing all")
                // No status filter - show all
                break
            }
            
            var url = URL(string: urlString)!
            if let lastTimestamp = lastUpdatedAt, let lastLinkId = lastId {
                // Add compound keyset pagination (updated_at, id) for stable sorting
                // Must encode + as %2B specifically for timestamps
                let encodedTimestamp = lastTimestamp.replacingOccurrences(of: "+", with: "%2B")
                let paginatedUrlString = urlString + "&or=(updated_at.lt.\(encodedTimestamp),and(updated_at.eq.\(encodedTimestamp),id.lt.\(lastLinkId)))"
                url = URL(string: paginatedUrlString)!
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            // Add prefer header to handle RLS properly
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            
            print("[LinksViewModel] 🌐 Making request to URL: \(url)")
            print("[LinksViewModel] 📋 Request headers: \(request.allHTTPHeaderFields ?? [:])")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse {
                print("[LinksViewModel] 📡 HTTP Response - Status: \(http.statusCode)")
                print("[LinksViewModel] 📡 Response headers: \(http.allHeaderFields)")
                
                if http.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    print("[LinksViewModel] ❌ Error Response Body: \(body)")
                    
                    // Provide more specific error messages based on status code
                    let errorMessage: String
                    switch http.statusCode {
                    case 401:
                        errorMessage = "Authentication failed. Please check your login credentials."
                    case 403:
                        errorMessage = "Access forbidden. Check your permissions."
                    case 404:
                        errorMessage = "API endpoint not found. Check your configuration."
                    case 500...599:
                        errorMessage = "Server error (\(http.statusCode)). Please try again later."
                    default:
                        errorMessage = "Request failed with status \(http.statusCode): \(body)"
                    }
                    
                    self.error = errorMessage
                    isLoading = false
                    return
                }
            }
            
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            print("[LinksViewModel] ✅ Response body preview: \(String(responseBody.prefix(200)))...")
            
            let newLinks = try JSONDecoder().decode([Link].self, from: data)
            print("[LinksViewModel] ✅ Decoded \(newLinks.count) links successfully")
            
            // Debug: Print details about the first few links and check for nil URLs
            for (index, link) in newLinks.prefix(5).enumerated() {
                let hasValidURL = (link.raw_url != nil && !link.raw_url!.isEmpty) || (link.resolved_url != nil && !link.resolved_url!.isEmpty)
                print("[LinksViewModel] Link \(index): id=\(link.id), title=\(link.title ?? "nil"), raw_url=\(link.raw_url ?? "nil"), resolved_url=\(link.resolved_url ?? "nil"), hasValidURL=\(hasValidURL)")
                
                if !hasValidURL {
                    print("[LinksViewModel] ⚠️ WARNING: Link \(link.id) has no valid URL!")
                }
            }
            
            // Filter out links with invalid URLs to prevent UI errors
            let validLinks = newLinks.filter { link in
                let hasValidURL = (link.raw_url != nil && !link.raw_url!.isEmpty) || (link.resolved_url != nil && !link.resolved_url!.isEmpty)
                if !hasValidURL {
                    print("[LinksViewModel] 🚫 Filtering out link with invalid URL: \(link.id)")
                }
                return hasValidURL
            }
            
            links.append(contentsOf: validLinks)
            hasMore = newLinks.count == pageSize
            
            if validLinks.count != newLinks.count {
                print("[LinksViewModel] ⚠️ Filtered out \(newLinks.count - validLinks.count) links with invalid URLs")
            }
            // Update compound cursor with both timestamp and ID
            lastUpdatedAt = newLinks.last?.updated_at
            lastId = newLinks.last?.id
            print("[LinksViewModel] ✅ Fetch complete: links.count=\(links.count), hasMore=\(hasMore), lastUpdatedAt=\(String(describing: lastUpdatedAt)), lastId=\(String(describing: lastId))")
            
        } catch let urlError as URLError {
            print("[LinksViewModel] ❌ URLError: \(urlError)")
            print("[LinksViewModel] ❌ URLError code: \(urlError.code.rawValue)")
            print("[LinksViewModel] ❌ URLError description: \(urlError.localizedDescription)")
            
            let errorMessage: String
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "No internet connection. Please check your network settings."
            case .timedOut:
                errorMessage = "Request timed out. Please try again."
            case .badServerResponse:
                errorMessage = "Server returned an invalid response. This might be a configuration issue."
            case .userAuthenticationRequired:
                errorMessage = "Authentication required. Please check your login credentials."
            case .cannotFindHost:
                errorMessage = "Cannot connect to server. Please check your network connection."
            default:
                errorMessage = "Network error: \(urlError.localizedDescription)"
            }
            
            self.error = errorMessage
        } catch {
            print("[LinksViewModel] ❌ Unexpected error: \(error)")
            self.error = "Unexpected error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func setFilter(_ filter: LinkFilter) async {
        guard filter != currentFilter else { return }
        print("[LinksViewModel] Changing filter from \(currentFilter.rawValue) to \(filter.rawValue)")
        currentFilter = filter
        await fetchLinks(reset: true)
    }
    
    // Helper function to extract user ID from JWT token
    private func extractUserIdFromToken(_ token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("[LinksViewModel] Invalid JWT format")
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
            print("[LinksViewModel] Could not extract user ID from token")
            return nil
        }
        
        print("[LinksViewModel] Successfully extracted user ID: \(sub)")
        return sub
    }
    
    // Add a debug method to check what's in the database without RLS
    func debugDatabaseContents() async {
        print("[LinksViewModel] === DEBUG DATABASE CONTENTS ===")
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            
            // Test 1: Basic query (what we saw failing)
            await testQuery(
                name: "Basic Query", 
                url: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?select=id,user_id,raw_url,created_at,updated_at&limit=10",
                token: token
            )
            
            // Test 2: Count all rows (bypasses RLS differently)
            await testQuery(
                name: "Count Query", 
                url: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?select=count&limit=1",
                token: token
            )
            
            // Test 3: Explicit user filter
            let userId = extractUserIdFromToken(token) ?? "unknown"
            await testQuery(
                name: "User Filtered Query", 
                url: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?select=*&user_id=eq.\(userId)&limit=5",
                token: token
            )
            
        } catch {
            print("[LinksViewModel] Debug ERROR: \(error)")
        }
        print("[LinksViewModel] === END DEBUG ===")
    }
    
    private func testQuery(name: String, url: String, token: String) async {
        print("[LinksViewModel] Testing: \(name)")
        do {
            guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                print("[LinksViewModel] ❌ Failed to get anon key for \(name)")
                return
            }
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            
            if let http = response as? HTTPURLResponse {
                print("[LinksViewModel] \(name) - Status: \(http.statusCode)")
                print("[LinksViewModel] \(name) - Response: \(responseBody)")
                
                // Check for specific RLS error messages
                if responseBody.contains("row-level security") || responseBody.contains("permission denied") {
                    print("[LinksViewModel] 🚨 RLS BLOCKING ACCESS!")
                } else if responseBody == "[]" {
                    print("[LinksViewModel] ⚠️ No data found (could be RLS or empty table)")
                } else if responseBody.contains("error") {
                    print("[LinksViewModel] ❌ API Error detected")
                } else if !responseBody.isEmpty && responseBody != "[]" {
                    print("[LinksViewModel] ✅ Data found!")
                }
            }
        } catch {
            print("[LinksViewModel] \(name) ERROR: \(error)")
        }
    }
    
    // Test saving a link directly from main app
    func testSaveLink() async {
        print("[LinksViewModel] === TEST SAVE LINK ===")
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let userId = extractUserIdFromToken(token) ?? "unknown"
            let testUrl = "https://example.com/test-\(Date().timeIntervalSince1970)"
            
            print("[LinksViewModel] Saving test link: \(testUrl)")
            print("[LinksViewModel] Using user_id: \(userId)")
            
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                print("[LinksViewModel] ❌ Failed to get anon key for save test")
                return
            }
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let body = ["raw_url": testUrl, "list": "read", "user_id": userId]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            
            if let http = response as? HTTPURLResponse {
                print("[LinksViewModel] Save Status: \(http.statusCode)")
                print("[LinksViewModel] Save Response: \(responseBody)")
                
                if (200...299).contains(http.statusCode) {
                    print("[LinksViewModel] ✅ SAVE SUCCESSFUL!")
                    
                    // Wait a moment then try to fetch
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await debugDatabaseContents()
                } else {
                    print("[LinksViewModel] ❌ SAVE FAILED!")
                }
            }
        } catch {
            print("[LinksViewModel] Save test ERROR: \(error)")
        }
        print("[LinksViewModel] === END TEST SAVE ===")
    }
    
    // Toggle read status contextually - offline-first approach
    func markAsRead(_ link: Link) async {
        let newStatus = link.status == "read" ? "unread" : "read"
        print("[LinksViewModel] Toggling link status: \(link.id) from \(link.status ?? "unknown") to \(newStatus)")
        
        // 1. IMMEDIATE UI UPDATE based on current filter
        if (currentFilter == .unread && newStatus == "read") || (currentFilter == .read && newStatus == "unread") {
            // Remove from current filter list immediately for better UX
            links.removeAll { $0.id == link.id }
            print("[LinksViewModel] Removed link from \(currentFilter.rawValue) list immediately")
        } else {
            // Update status for other filters (all)
            if let index = links.firstIndex(where: { $0.id == link.id }) {
                let updatedLinkData = Link(
                    id: link.id,
                    user_id: link.user_id,
                    raw_url: link.raw_url,
                    resolved_url: link.resolved_url,
                    title: link.title,
                    description: link.description,
                    list: link.list,
                    status: newStatus, // Update status contextually
                    device_saved: link.device_saved,
                    created_at: link.created_at,
                    updated_at: link.updated_at  // Keep existing updated_at (server will update it)
                )
                links[index] = updatedLinkData
                print("[LinksViewModel] Updated link status to \(newStatus) in UI")
            }
        }
        
        // 2. Add to offline queue for later sync
        addMarkAsReadToQueue(linkId: link.id, newStatus: newStatus)
        
        // 3. Try immediate sync (if online)
        await syncMarkAsReadQueue()
    }
    
    // Add status toggle action to offline queue
    private func addMarkAsReadToQueue(linkId: String, newStatus: String) {
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        var statusQueue = defaults.array(forKey: "PSReadStatusQueue") as? [[String: String]] ?? []
        
        // Remove any existing entry for this link to avoid conflicts
        statusQueue.removeAll { $0["linkId"] == linkId }
        
        // Add new entry
        statusQueue.append(["linkId": linkId, "status": newStatus])
        defaults.set(statusQueue, forKey: "PSReadStatusQueue")
        print("[LinksViewModel] Added \(linkId) → \(newStatus) to status queue")
    }
    
    // Sync status queue with server
    private func syncMarkAsReadQueue() async {
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        var statusQueue = defaults.array(forKey: "PSReadStatusQueue") as? [[String: String]] ?? []
        
        guard !statusQueue.isEmpty else { return }
        
        print("[LinksViewModel] Syncing status queue: \(statusQueue.count) items")
        
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            var successfullyProcessed: [[String: String]] = []
            
            // Process each status change in the queue
            for entry in statusQueue {
                guard let linkId = entry["linkId"], let newStatus = entry["status"] else { continue }
                
                let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?id=eq.\(linkId)")!
                var request = URLRequest(url: endpoint)
                request.httpMethod = "PATCH"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                    print("[LinksViewModel] ❌ Failed to get anon key for status sync")
                    continue
                }
                request.setValue(anonKey, forHTTPHeaderField: "apikey")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
                
                let updateData = ["status": newStatus]
                request.httpBody = try JSONEncoder().encode(updateData)
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    successfullyProcessed.append(entry)
                    print("[LinksViewModel] ✅ Successfully updated \(linkId) to \(newStatus) on server")
                } else {
                    print("[LinksViewModel] ❌ Failed to update \(linkId) to \(newStatus) on server")
                }
            }
            
            // Remove successfully processed items from queue
            statusQueue.removeAll { entry in
                successfullyProcessed.contains { $0["linkId"] == entry["linkId"] }
            }
            defaults.set(statusQueue, forKey: "PSReadStatusQueue")
            print("[LinksViewModel] Processed \(successfullyProcessed.count) items, \(statusQueue.count) remaining in queue")
            
        } catch {
            print("[LinksViewModel] Failed to sync status queue: \(error)")
            // Queue items remain for next sync attempt
        }
    }
    
    // Sync extension queue (PSReadQueue) with server
    private func syncExtensionQueue() async {
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        var extensionQueue = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
        
        guard !extensionQueue.isEmpty else { return }
        
        print("[LinksViewModel] Syncing extension queue: \(extensionQueue.count) items")
        
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let userId = extractUserIdFromToken(token) ?? "unknown"
            var successfullyProcessed: [String] = []
            
            // Process each entry in the queue
            for entry in extensionQueue {
                guard let url = entry["url"] as? String,
                      let status = entry["status"] as? String else { continue }
                
                if await postLinkFromQueue(rawUrl: url, status: status, userId: userId, token: token) {
                    successfullyProcessed.append(url)
                    print("[LinksViewModel] ✅ Successfully synced \(url) with status \(status)")
                } else {
                    print("[LinksViewModel] ❌ Failed to sync \(url)")
                }
            }
            
            // Remove successfully processed items from queue
            extensionQueue.removeAll { entry in
                if let url = entry["url"] as? String {
                    return successfullyProcessed.contains(url)
                }
                return false
            }
            defaults.set(extensionQueue, forKey: "PSReadQueue")
            print("[LinksViewModel] Processed \(successfullyProcessed.count) items, \(extensionQueue.count) remaining in extension queue")
            
        } catch {
            print("[LinksViewModel] Failed to sync extension queue: \(error)")
            // Queue items remain for next sync attempt
        }
    }
    
    // Post link from extension queue to server
    private func postLinkFromQueue(rawUrl: String, status: String, userId: String, token: String) async -> Bool {
        print("[LinksViewModel] 📡 Syncing from queue: \(rawUrl) → \(status)")
        
        do {
            // Use Supabase UPSERT - single call handles both insert and update
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                print("[LinksViewModel] ❌ Failed to get anon key for queue sync")
                return false
            }
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10.0
        
            let body = [
                "raw_url": rawUrl, 
                "list": "read", 
                "status": status,
                "user_id": userId
            ]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[LinksViewModel] 📡 Queue sync result: \(http.statusCode)")
                
                // Handle both success cases and conflict resolution
                if (200...299).contains(http.statusCode) {
                    return true
                } else if http.statusCode == 409 {
                    // Conflict - do a simple PATCH update
                    print("[LinksViewModel] 📡 Conflict detected, doing quick update")
                    return await quickUpdateFromQueue(rawUrl: rawUrl, status: status, userId: userId, token: token)
                }
                return false
            }
            return false
        } catch {
            print("[LinksViewModel] 🌐 Queue sync network error: \(error)")
            return false
        }
    }
    
    // Quick update status for conflicting entries
    private func quickUpdateFromQueue(rawUrl: String, status: String, userId: String, token: String) async -> Bool {
        guard let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedUrl = rawUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }
        
        do {
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?user_id=eq.\(encodedUserId)&raw_url=eq.\(encodedUrl)")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                print("[LinksViewModel] ❌ Failed to get anon key for quick update")
                return false
            }
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 5.0
            
            let body = ["status": status]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[LinksViewModel] 📡 Queue quick update: \(http.statusCode)")
                return http.statusCode == 204
            }
            return false
        } catch {
            print("[LinksViewModel] 🌐 Queue quick update error: \(error)")
            return false
        }
    }
    
    // Add a simple network connectivity test
    func testNetworkConnectivity() async {
        print("[LinksViewModel] 🌐 Testing network connectivity...")
        
        do {
            // Test 1: Basic internet connectivity
            let (_, response) = try await URLSession.shared.data(from: URL(string: "https://www.google.com")!)
            if let http = response as? HTTPURLResponse {
                print("[LinksViewModel] ✅ Internet connectivity: Status \(http.statusCode)")
            }
            
            // Test 2: Supabase server connectivity
            let supabaseURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/")!
            let (_, supabaseResponse) = try await URLSession.shared.data(from: supabaseURL)
            if let http = supabaseResponse as? HTTPURLResponse {
                print("[LinksViewModel] ✅ Supabase server connectivity: Status \(http.statusCode)")
            }
            
            // Test 3: Config file accessibility
            let configURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/storage/v1/object/public/psreadthis/psreadthis-config.json")!
            let (configData, configResponse) = try await URLSession.shared.data(from: configURL)
            if let http = configResponse as? HTTPURLResponse {
                print("[LinksViewModel] ✅ Config file accessibility: Status \(http.statusCode)")
                let configBody = String(data: configData, encoding: .utf8) ?? ""
                print("[LinksViewModel] 📄 Config content: \(configBody)")
            }
            
            // Test 4: Authentication test
            do {
                let token = try await TokenManager.shared.getValidAccessToken()
                print("[LinksViewModel] ✅ Authentication successful, token length: \(token.count)")
            } catch {
                print("[LinksViewModel] ❌ Authentication failed: \(error)")
            }
            
        } catch {
            print("[LinksViewModel] ❌ Network connectivity test failed: \(error)")
            if let urlError = error as? URLError {
                print("[LinksViewModel] ❌ URLError code: \(urlError.code.rawValue)")
            }
        }
    }
    
    // Add authentication clearing method for debugging
    func clearAuthentication() async {
        print("[LinksViewModel] 🔐 Clearing authentication...")
        
        do {
            // Clear all stored tokens from keychain
            await TokenManager.shared.clearAllTokens()
            
            // Reset view state
            await MainActor.run {
                self.links = []
                self.lastUpdatedAt = nil
                self.lastId = nil
                self.hasMore = true
                self.error = nil
                self.isLoading = false
            }
            
            print("[LinksViewModel] ✅ Authentication cleared successfully")
            
            // Trigger a fresh authentication attempt
            await fetchLinks(reset: true)
            
        } catch {
            print("[LinksViewModel] ❌ Error clearing authentication: \(error)")
            await MainActor.run {
                self.error = "Failed to clear authentication: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Performance Optimization (Removed Complex Filtering)
    // Enhanced filtering methods removed to prevent iPhone freezing
    // Using basic filtering only via existing fetchLinks method
}

// MARK: - Basic Link Actions (Simplified for performance)

extension LinksViewModel {
    /// Toggle star status (simplified version)
    func toggleStar(_ link: Link) async {
        print("[LinksViewModel] Toggling star for link: \(link.id)")
        
        // Update UI immediately
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            links[index] = link.withToggledStar()
        }
        
        // Sync with database (simplified)
        await updateLinkStarStatus(linkId: link.id, starred: !link.isStarred)
    }
    
    /// Update star status in database
    private func updateLinkStarStatus(linkId: String, starred: Bool) async {
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?id=eq.\(linkId)")!
            
            var request = URLRequest(url: endpoint)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                print("[LinksViewModel] ❌ Failed to get anon key")
                return
            }
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let body = ["title": starred ? "⭐" : ""]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[LinksViewModel] Failed to update star status: \(http.statusCode)")
                // Revert on failure
                await fetchLinks(reset: true)
            }
        } catch {
            print("[LinksViewModel] Error updating star status: \(error)")
            await fetchLinks(reset: true)
        }
    }
    
    /// Delete a link (simplified version)
    func deleteLink(_ link: Link) async {
        print("[LinksViewModel] Deleting link: \(link.id)")
        
        // Remove from UI immediately
        links.removeAll { $0.id == link.id }
        
        // Sync with database (simplified)
        await deleteLinkFromDatabase(linkId: link.id)
    }
    
    /// Delete link from database
    private func deleteLinkFromDatabase(linkId: String) async {
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?id=eq.\(linkId)")!
            
            var request = URLRequest(url: endpoint)
            request.httpMethod = "DELETE"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                print("[LinksViewModel] ❌ Failed to get anon key")
                return
            }
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[LinksViewModel] Failed to delete link: \(http.statusCode)")
                // Revert on failure
                await fetchLinks(reset: true)
            }
        } catch {
            print("[LinksViewModel] Error deleting link: \(error)")
            await fetchLinks(reset: true)
        }
    }
} 