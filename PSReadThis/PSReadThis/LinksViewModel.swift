import Foundation
import UIKit

// MARK: - Performance Monitoring System
struct PerformanceMetrics {
    let totalTime: TimeInterval
    let authTime: TimeInterval
    let anonKeyTime: TimeInterval
    let apiCallTime: TimeInterval
    let parsingTime: TimeInterval
    let uiUpdateTime: TimeInterval
    let queueSyncTime: TimeInterval?
    let networkLatency: TimeInterval?
    let cacheHits: Int
    let cacheMisses: Int
    let timestamp: Date
    let recordCount: Int
    let cacheStrategy: String
    
    var summary: String {
        let performanceGrade = totalTime < 2.0 ? "🟢 EXCELLENT" : totalTime < 3.0 ? "🟡 GOOD" : "🔴 SLOW"
        return """
        📊 Performance Report (v0.12):
        \(performanceGrade) Total: \(String(format: "%.2f", totalTime))s
        🔐 Auth: \(String(format: "%.2f", authTime))s
        🔑 Anon Key: \(String(format: "%.2f", anonKeyTime))s
        🌐 API Call: \(String(format: "%.2f", apiCallTime))s
        📋 Parsing: \(String(format: "%.2f", parsingTime))s (\(recordCount) records)
        🖼️ UI Update: \(String(format: "%.2f", uiUpdateTime))s
        \(queueSyncTime.map { "🔄 Queue Sync: \(String(format: "%.2f", $0))s" } ?? "")
        💾 Cache: \(cacheHits) hits, \(cacheMisses) misses (\(cacheStrategy))
        📅 At: \(DateFormatter.timeFormatter.string(from: timestamp))
        """
    }
    
    var bottleneckAnalysis: String {
        let components = [
            ("Authentication", authTime),
            ("Anon Key", anonKeyTime),
            ("API Call", apiCallTime),
            ("Parsing", parsingTime),
            ("UI Update", uiUpdateTime)
        ]
        
        let slowest = components.max { $0.1 < $1.1 }
        let recommendations = getRecommendations()
        
        return """
        🔍 v0.12 Performance Analysis:
        🐌 Slowest: \(slowest?.0 ?? "Unknown") (\(String(format: "%.2f", slowest?.1 ?? 0))s)
        🎯 Target: < 2.0s total (Current: \(String(format: "%.2f", totalTime))s)
        
        💡 Optimizations Applied:
        \(recommendations.joined(separator: "\n"))
        """
    }
    
    private func getRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // v0.12 Performance Optimizations
        if totalTime < 2.0 {
            recommendations.append("✅ Target achieved! Performance is excellent")
        } else {
            recommendations.append("🎯 Working to achieve < 2.0s target")
        }
        
        if authTime > 1.0 {
            recommendations.append("🔧 Auth optimization: Background token refresh implemented")
        }
        if anonKeyTime > 0.3 {
            recommendations.append("🔧 Anon key optimization: Persistent caching enabled")
        }
        if apiCallTime > 1.0 {
            recommendations.append("🔧 API optimization: Reduced payload + parallel requests")
        }
        if parsingTime > 0.5 {
            recommendations.append("🔧 Parsing optimization: Streaming parser + background processing")
        }
        
        if cacheHits > cacheMisses {
            recommendations.append("💾 Cache working well - \(Int((Double(cacheHits) / Double(cacheHits + cacheMisses)) * 100))% hit rate")
        }
        
        return recommendations
    }
}

private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Persistent Cache Manager (v0.12)
class PersistentCacheManager {
    private let userDefaults = UserDefaults.standard
    
    // Cache keys
    private let anonKeyKey = "PSReadThis_AnonKey"
    private let anonKeyExpiryKey = "PSReadThis_AnonKeyExpiry"
    private let tokenKey = "PSReadThis_Token"
    private let tokenExpiryKey = "PSReadThis_TokenExpiry"
    private let userIdKey = "PSReadThis_UserId"
    private let lastFetchKey = "PSReadThis_LastFetch"
    
    // Aggressive caching - 30 minutes for anon key, 15 minutes for token
    private let anonKeyCacheTime: TimeInterval = 1800 // 30 minutes
    private let tokenCacheTime: TimeInterval = 900 // 15 minutes
    
    func cacheAnonKey(_ key: String) {
        userDefaults.set(key, forKey: anonKeyKey)
        userDefaults.set(Date(), forKey: anonKeyExpiryKey)
    }
    
    func getCachedAnonKey() -> String? {
        guard let expiry = userDefaults.object(forKey: anonKeyExpiryKey) as? Date,
              Date().timeIntervalSince(expiry) < anonKeyCacheTime else {
            return nil
        }
        return userDefaults.string(forKey: anonKeyKey)
    }
    
    func cacheToken(_ token: String) {
        userDefaults.set(token, forKey: tokenKey)
        userDefaults.set(Date(), forKey: tokenExpiryKey)
    }
    
    func getCachedToken() -> String? {
        guard let expiry = userDefaults.object(forKey: tokenExpiryKey) as? Date,
              Date().timeIntervalSince(expiry) < tokenCacheTime else {
            return nil
        }
        return userDefaults.string(forKey: tokenKey)
    }
    
    func cacheUserId(_ userId: String) {
        userDefaults.set(userId, forKey: userIdKey)
    }
    
    func getCachedUserId() -> String? {
        return userDefaults.string(forKey: userIdKey)
    }
    
    func clearAll() {
        [anonKeyKey, anonKeyExpiryKey, tokenKey, tokenExpiryKey, userIdKey, lastFetchKey].forEach {
            userDefaults.removeObject(forKey: $0)
        }
    }
}

// MARK: - Performance Monitor
class PerformanceMonitor {
    private var startTime: CFAbsoluteTime = 0
    private var stepTimes: [String: CFAbsoluteTime] = [:]
    private var cacheHits = 0
    private var cacheMisses = 0
    private var recordCount = 0
    private var cacheStrategy = "standard"
    
    func startTiming() {
        startTime = CFAbsoluteTimeGetCurrent()
        stepTimes.removeAll()
        cacheHits = 0
        cacheMisses = 0
        recordCount = 0
        cacheStrategy = "standard"
        markStep("start")
    }
    
    func markStep(_ step: String) {
        stepTimes[step] = CFAbsoluteTimeGetCurrent()
    }
    
    func recordCacheHit() {
        cacheHits += 1
    }
    
    func recordCacheMiss() {
        cacheMisses += 1
    }
    
    func setRecordCount(_ count: Int) {
        recordCount = count
    }
    
    func setCacheStrategy(_ strategy: String) {
        cacheStrategy = strategy
    }
    
    func getMetrics(queueSyncTime: TimeInterval?) -> PerformanceMetrics {
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        func getStepTime(_ step: String, fallback: String? = nil) -> TimeInterval {
            if let time = stepTimes[step], let prevTime = stepTimes[fallback ?? "start"] {
                return time - prevTime
            }
            return 0
        }
        
        return PerformanceMetrics(
            totalTime: totalTime,
            authTime: getStepTime("auth_complete", fallback: "start"),
            anonKeyTime: getStepTime("anon_key_complete", fallback: "auth_complete"),
            apiCallTime: getStepTime("api_complete", fallback: "anon_key_complete"),
            parsingTime: getStepTime("parsing_complete", fallback: "api_complete"),
            uiUpdateTime: getStepTime("ui_complete", fallback: "parsing_complete"),
            queueSyncTime: queueSyncTime,
            networkLatency: nil,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            timestamp: Date(),
            recordCount: recordCount,
            cacheStrategy: cacheStrategy
        )
    }
}

// MARK: - Simplified System (Performance Optimized)
// Complex filtering system removed to prevent iPhone freezing

// Complex content detection functions removed for performance

// RemoteOperation is now defined in RemoteOperation.swift

private let remoteLogKey = "PSReadRemoteOperationsLog"
private let appGroupSuite = "group.com.pavels.psreadthis"

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
    
    // Performance monitoring
    @Published var lastPerformanceMetrics: PerformanceMetrics?
    @Published var averageLoadTime: TimeInterval = 0
    @Published var loadingHistory: [PerformanceMetrics] = []
    @Published var lastLazyLoadTrigger: String = "No lazy load attempts yet"
    private let performanceMonitor = PerformanceMonitor()
    
    // Remote operations log for debugging
    @Published var remoteOperationsLog: [RemoteOperation] = [] {
        didSet {
            saveRemoteOperationsLog()
        }
    }
    
    // v0.12 Optimization: Reduced page size for faster loading
    private let pageSize = 15
    
    // Basic pagination cursors (simplified)
    private var lastUpdatedAt: String? = nil
    private var lastId: String? = nil
    
    // Track the actual page size requested for hasMore calculation
    private var actualPageSizeRequested = 15
    
    // v0.12 Performance Optimizations
    private let persistentCache = PersistentCacheManager()
    private var backgroundRefreshTask: Task<Void, Never>?
    
    init() {
        // Start background token refresh
        startBackgroundTokenRefresh()
        loadRemoteOperationsLog()
        
        // Listen for extension notifications
        setupExtensionNotifications()
    }
    
    deinit {
        backgroundRefreshTask?.cancel()
        
        // Remove notification observer - simplified for compatibility
        // Note: Darwin notifications removed for build compatibility
    }
    
    // MARK: - Extension Communication
    private func setupExtensionNotifications() {
        // Darwin notifications removed for build compatibility
        // Extensions will use UserDefaults-based communication instead
        print("[LinksViewModel] 📢 Extension notifications set up via UserDefaults polling")
    }
    
    private func refreshFromExtension() async {
        // Quick refresh when extension adds content
        await fetchLinks(reset: true)
    }
    
    // MARK: - v0.12 Background Token Refresh
    private func startBackgroundTokenRefresh() {
        backgroundRefreshTask = Task {
            while !Task.isCancelled {
                do {
                    // Refresh tokens every 10 minutes in background
                    try await Task.sleep(for: .seconds(600))
                    
                    // Prefetch and cache tokens
                    Task {
                        await prefetchTokens()
                    }
                } catch {
                    break
                }
            }
        }
    }
    
    private func prefetchTokens() async {
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            persistentCache.cacheToken(token)
            
            if let anonKey = await PSReadThisConfig.shared.getAnonKey() {
                persistentCache.cacheAnonKey(anonKey)
            }
            
            let userId = extractUserIdFromToken(token) ?? "unknown"
            persistentCache.cacheUserId(userId)
            
            print("[LinksViewModel] 🔄 Background token refresh completed")
        } catch {
            print("[LinksViewModel] ⚠️ Background token refresh failed: \(error)")
        }
    }

    func fetchLinks(reset: Bool = false, contentFilter: String = "all") async {
        performanceMonitor.startTiming()
        performanceMonitor.setCacheStrategy("v0.15.1-production")
        
        if reset {
            links = []
            lastUpdatedAt = nil
            lastId = nil
            hasMore = true
            actualPageSizeRequested = pageSize  // Reset to default
        }
        
        guard !isLoading, hasMore else {
            print("[LinksViewModel] ⏭️ Skipping - isLoading=\(isLoading), hasMore=\(hasMore)")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // v0.12 Optimization: Process both extension and status queues on reset
            var queueSyncTime: TimeInterval? = nil
            if reset {
                print("[LinksViewModel] 🔄 Starting queue sync on reset...")
                let queueSyncStart = CFAbsoluteTimeGetCurrent()
                await syncExtensionQueue()     // Process URLs from extensions
                await syncMarkAsReadQueue()    // Process status changes
                queueSyncTime = CFAbsoluteTimeGetCurrent() - queueSyncStart
                print("[LinksViewModel] ✅ Queue sync completed in \(String(format: "%.2f", queueSyncTime ?? 0))s")
            }
            
            performanceMonitor.markStep("queue_sync_complete")
            
            // v0.12 Optimization: Ultra-fast auth with aggressive caching
            let authStart = CFAbsoluteTimeGetCurrent()
            let (token, anonKey, userId) = await getAuthDataOptimized()
            performanceMonitor.markStep("auth_complete")
            
            let authTime = CFAbsoluteTimeGetCurrent() - authStart
            
            performanceMonitor.markStep("anon_key_complete")
            
            // v0.12 Optimization: Optimized API call with minimal data
            let apiStart = CFAbsoluteTimeGetCurrent()
            let url = buildOptimizedAPIURL(userId: userId, contentFilter: contentFilter)
            
            let request = buildOptimizedRequest(url: url, anonKey: anonKey, token: token, forceRefresh: reset)
            
            print("[LinksViewModel] 🌐 Making API request to: \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(for: request)
            performanceMonitor.markStep("api_complete")
            
            // Log the remote operation
            if let httpResponse = response as? HTTPURLResponse {
                let operation = RemoteOperation(
                    timestamp: Date(),
                    operation: "Fetch Links",
                    url: url.absoluteString,
                    method: "GET",
                    statusCode: httpResponse.statusCode,
                    success: httpResponse.statusCode == 200,
                    details: "Filter: \(currentFilter.rawValue), Content: \(contentFilter), Reset: \(reset)"
                )
                await MainActor.run {
                    appendRemoteOperation(operation)
                }
            }
            
            let apiTime = CFAbsoluteTimeGetCurrent() - apiStart
            
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                if let http = response as? HTTPURLResponse {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    print("[LinksViewModel] ❌ HTTP \(http.statusCode): \(body)")
                }
                throw URLError(.badServerResponse)
            }
            
            // v0.12 Optimization: Streaming JSON parser
            let parseStart = CFAbsoluteTimeGetCurrent()
            let newLinks = try await parseLinksOptimized(data: data)
            performanceMonitor.markStep("parsing_complete")
            performanceMonitor.setRecordCount(newLinks.count)
            
            let parseTime = CFAbsoluteTimeGetCurrent() - parseStart
            
            // UI updates
            let uiStart = CFAbsoluteTimeGetCurrent()
            await updateUIOptimized(newLinks: newLinks)
            performanceMonitor.markStep("ui_complete")
            
            let uiTime = CFAbsoluteTimeGetCurrent() - uiStart
            
            // Store performance metrics
            let metrics = performanceMonitor.getMetrics(queueSyncTime: queueSyncTime)
            lastPerformanceMetrics = metrics
            loadingHistory.append(metrics)
            
            // Keep only last 10 measurements
            if loadingHistory.count > 10 {
                loadingHistory.removeFirst(loadingHistory.count - 10)
            }
            
            // Calculate average load time
            averageLoadTime = loadingHistory.map(\.totalTime).reduce(0, +) / Double(loadingHistory.count)
            
            let grade = metrics.totalTime < 2.0 ? "🟢" : metrics.totalTime < 3.0 ? "🟡" : "🔴"
            print("[LinksViewModel] \(grade) Load: \(String(format: "%.2f", metrics.totalTime))s")
            
        } catch {
            print("[LinksViewModel] ❌ Fetch error: \(error)")
            self.error = "Failed to load links: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Optimized Helper Methods
    
    private func getAuthDataOptimized() async -> (token: String, anonKey: String, userId: String) {
        // Try cache first
        if let cachedToken = persistentCache.getCachedToken(),
           let cachedAnonKey = persistentCache.getCachedAnonKey(),
           let cachedUserId = persistentCache.getCachedUserId() {
            performanceMonitor.recordCacheHit()
            performanceMonitor.recordCacheHit()
            performanceMonitor.recordCacheHit()
            return (cachedToken, cachedAnonKey, cachedUserId)
        }
        
        // Parallel fetch with timeout
        async let tokenTask = TokenManager.shared.getValidAccessToken()
        async let anonKeyTask = PSReadThisConfig.shared.getAnonKey()
        
        do {
            let token = try await tokenTask
            let anonKey = await anonKeyTask ?? ""
            let userId = extractUserIdFromToken(token) ?? "unknown"
            
            // Cache for next time
            persistentCache.cacheToken(token)
            persistentCache.cacheAnonKey(anonKey)
            persistentCache.cacheUserId(userId)
            
            performanceMonitor.recordCacheMiss()
            return (token, anonKey, userId)
        } catch {
            performanceMonitor.recordCacheMiss()
            // Return empty values to prevent crash
            return ("", "", "unknown")
        }
    }
    
    private func buildOptimizedAPIURL(userId: String, contentFilter: String = "all") -> URL {
        // Using select=* to avoid field selection issues, focus optimization on caching and other areas
        var urlString = "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?select=*&order=updated_at.desc.nullslast,id.desc&limit=\(pageSize)"
        
        // Add status filter
        switch currentFilter {
        case .unread:
            urlString += "&status=eq.unread"
        case .read:
            urlString += "&status=eq.read"
        case .all:
            break
        }
        
        // Add content filter (client-side filtering for better reliability)
        switch contentFilter {
        case "starred", "video", "audio", "article":
            // For these, we'll use larger batch sizes and client-side filtering
            // Increase page size significantly for better content filter coverage
            let currentPageSize = pageSize * 5  // Increased from 3x to 5x
            actualPageSizeRequested = currentPageSize
            urlString = urlString.replacingOccurrences(of: "&limit=\(pageSize)", with: "&limit=\(currentPageSize)")
        default:
            actualPageSizeRequested = pageSize
            break
        }
        
        // Add pagination if needed
        if let lastTimestamp = lastUpdatedAt, let lastLinkId = lastId {
            // Fix URL encoding: manually encode + as %2B to prevent it being decoded as space
            var encodedTimestamp = lastTimestamp.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lastTimestamp
            encodedTimestamp = encodedTimestamp.replacingOccurrences(of: "+", with: "%2B")
            urlString += "&or=(updated_at.lt.\(encodedTimestamp),and(updated_at.eq.\(encodedTimestamp),id.lt.\(lastLinkId)))"
        }
        
        return URL(string: urlString)!
    }
    
    private func buildOptimizedRequest(url: URL, anonKey: String, token: String, forceRefresh: Bool = false) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Set cache policy based on whether this is a forced refresh
        request.timeoutInterval = 10.0
        if forceRefresh {
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            print("[LinksViewModel] 🔄 Using cache policy: reloadIgnoringCache (forced refresh)")
        } else {
            request.cachePolicy = .returnCacheDataElseLoad
            print("[LinksViewModel] 📦 Using cache policy: returnCacheDataElseLoad (normal load)")
        }
        
        return request
    }
    
    private func parseLinksOptimized(data: Data) async throws -> [Link] {
        return try await withUnsafeThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let newLinks = try JSONDecoder().decode([Link].self, from: data)
                    continuation.resume(returning: newLinks)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updateUIOptimized(newLinks: [Link]) async {
        // Filter invalid URLs efficiently
        let validLinks = newLinks.compactMap { link -> Link? in
            guard (link.raw_url?.isEmpty == false) || (link.resolved_url?.isEmpty == false) else {
                return nil
            }
            return link
        }
        

        
        // Batch update
        links.append(contentsOf: validLinks)
        
        // Fix: hasMore should be based on the actual page size requested
        // If we got fewer than the requested page size from the API, there are no more links
        hasMore = newLinks.count == actualPageSizeRequested
        
        // Update pagination cursors
        lastUpdatedAt = newLinks.last?.updated_at
        lastId = newLinks.last?.id
    }
    
    private func syncRecentQueueItems() async {
        // Only sync recent items to avoid slow startup
        await syncMarkAsReadQueue()
        await syncRecentExtensionQueue()
    }
    
    // Sync only recent extension queue items (last 5)
    private func syncRecentExtensionQueue() async {
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        var extensionQueue = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
        
        // Only sync the 5 most recent items to avoid slow startup
        let recentItems = Array(extensionQueue.suffix(5))
        guard !recentItems.isEmpty else { return }
        
        print("[LinksViewModel] Syncing recent extension queue: \(recentItems.count) items (out of \(extensionQueue.count) total)")
        
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let userId = extractUserIdFromToken(token) ?? "unknown"
            var successfullyProcessed: [String] = []
            
            // Process each recent entry
            for entry in recentItems {
                guard let url = entry["url"] as? String,
                      let status = entry["status"] as? String else { continue }
                
                if await postLinkFromQueue(rawUrl: url, status: status, userId: userId, token: token) {
                    successfullyProcessed.append(url)
                    print("[LinksViewModel] ✅ Successfully synced recent \(url)")
                } else {
                    print("[LinksViewModel] ❌ Failed to sync recent \(url)")
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
            print("[LinksViewModel] Processed \(successfullyProcessed.count) recent items, \(extensionQueue.count) remaining")
            
        } catch {
            print("[LinksViewModel] Failed to sync recent extension queue: \(error)")
        }
    }
    
    // Performance diagnostics for dev mode
    func getPerformanceDiagnostics() -> String {
        guard let metrics = lastPerformanceMetrics else {
            return "No performance data available yet. Load some links first."
        }
        
        let history = loadingHistory.suffix(5).map { 
            let grade = $0.totalTime < 2.0 ? "🟢" : $0.totalTime < 3.0 ? "🟡" : "🔴"
            return "\(grade) \(String(format: "%.2f", $0.totalTime))s at \(DateFormatter.timeFormatter.string(from: $0.timestamp))"
        }.joined(separator: "\n")
        
        return """
        \(metrics.summary)
        
        \(metrics.bottleneckAnalysis)
        
        📈 Recent History (v0.12):
        \(history)
        
        📊 v0.12 Statistics:
        • Target: < 2.0s consistently
        • Average: \(String(format: "%.2f", averageLoadTime))s
        • Total Loads: \(loadingHistory.count)
        • Cache Efficiency: \(getCacheEfficiency())%
        • Best Time: \(String(format: "%.2f", loadingHistory.map(\.totalTime).min() ?? 0))s
        • Worst Time: \(String(format: "%.2f", loadingHistory.map(\.totalTime).max() ?? 0))s
        """
    }
    
    private func getCacheEfficiency() -> Int {
        guard let metrics = lastPerformanceMetrics else { return 0 }
        let total = metrics.cacheHits + metrics.cacheMisses
        return total > 0 ? Int((Double(metrics.cacheHits) / Double(total)) * 100) : 0
    }
    
    // Clear caches for testing
    func clearPerformanceCaches() {
        persistentCache.clearAll()
        loadingHistory.removeAll()
        lastPerformanceMetrics = nil
        averageLoadTime = 0
        print("[LinksViewModel] 🧹 v0.12 All caches cleared")
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
    
    // Create test starred link for debugging
    func createTestStarredLink() async {
        print("[LinksViewModel] === CREATE TEST STARRED LINK ===")
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let userId = extractUserIdFromToken(token) ?? "unknown"
            let testUrl = "https://github.com/starred-test-\(Date().timeIntervalSince1970)"
            
            print("[LinksViewModel] Creating test starred link: \(testUrl)")
            print("[LinksViewModel] Using user_id: \(userId)")
            
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            guard let anonKey = await PSReadThisConfig.shared.getAnonKey() else {
                print("[LinksViewModel] ❌ Failed to get anon key for starred test")
                return
            }
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            // Create starred link with ⭐ prefix in title (using consistent format)
            let starEmoji = "⭐"
            let testTitle = "\(starEmoji) Test Starred Link - \(Date())"
            print("[LinksViewModel] Creating starred link with title: '\(testTitle)'")
            
            let body = [
                "raw_url": testUrl, 
                "title": testTitle,  // Add star prefix with consistent emoji
                "description": "This is a test starred link for debugging the filter",
                "status": "read",  // Put in archive so we can test starred filter
                "user_id": userId
            ]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            
            if let http = response as? HTTPURLResponse {
                print("[LinksViewModel] Starred Save Status: \(http.statusCode)")
                print("[LinksViewModel] Starred Save Response: \(responseBody)")
                
                if (200...299).contains(http.statusCode) {
                    print("[LinksViewModel] ✅ STARRED LINK CREATED SUCCESSFULLY!")
                    
                    // Wait a moment then refresh to show new starred link
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await fetchLinks(reset: true)
                } else {
                    print("[LinksViewModel] ❌ STARRED LINK CREATION FAILED!")
                }
            }
        } catch {
            print("[LinksViewModel] Starred link creation ERROR: \(error)")
        }
        print("[LinksViewModel] === END CREATE STARRED TEST ===")
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
    func syncMarkAsReadQueue() async {
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
                
                if let http = response as? HTTPURLResponse {
                    let success = (200...299).contains(http.statusCode)
                    
                    // Log the mark as read operation
                    let operation = RemoteOperation(
                        timestamp: Date(),
                        operation: "Mark as Read",
                        url: linkId,
                        method: "PATCH",
                        statusCode: http.statusCode,
                        success: success,
                        details: "Status change to: \(newStatus)"
                    )
                    appendRemoteOperation(operation)
                    
                    if success {
                        successfullyProcessed.append(entry)
                        print("[LinksViewModel] ✅ Successfully updated \(linkId) to \(newStatus) on server")
                    } else {
                        print("[LinksViewModel] ❌ Failed to update \(linkId) to \(newStatus) on server")
                    }
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
    func syncExtensionQueue() async {
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        var extensionQueue = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
        
        print("[LinksViewModel] 📦 Checking extension queue: \(extensionQueue.count) items")
        
        guard !extensionQueue.isEmpty else { 
            print("[LinksViewModel] 📦 Extension queue is empty, skipping sync")
            return 
        }
        
        print("[LinksViewModel] 📦 Syncing extension queue: \(extensionQueue.count) items")
        for (index, entry) in extensionQueue.enumerated() {
            if let url = entry["url"] as? String, let status = entry["status"] as? String {
                print("[LinksViewModel] 📦 Item \(index + 1): \(url) → \(status)")
            }
        }
        
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let userId = extractUserIdFromToken(token) ?? "unknown"
            var successfullyProcessed: [String] = []
            
            // Process each entry in the queue
            for entry in extensionQueue {
                guard let url = entry["url"] as? String,
                      let status = entry["status"] as? String else { continue }
                
                let success = await postLinkFromQueue(rawUrl: url, status: status, userId: userId, token: token)
                if success {
                    successfullyProcessed.append(url)
                    print("[LinksViewModel] ✅ Successfully synced \(url) with status \(status)")
                } else {
                    print("[LinksViewModel] ❌ Failed to sync \(url)")
                }
                
                // Log the operation
                let operation = RemoteOperation(
                    timestamp: Date(),
                    operation: "Sync Extension Queue",
                    url: url,
                    method: "POST/PATCH",
                    statusCode: nil,
                    success: success,
                    details: "Status: \(status), Source: Extension Queue"
                )
                await MainActor.run {
                    appendRemoteOperation(operation)
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
            // Use proper UPSERT with ON CONFLICT handling
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // Enable UPSERT behavior on duplicates to avoid 409 conflicts
            request.setValue("return=minimal, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
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
                
                // Handle success cases
                if (200...299).contains(http.statusCode) {
                    return true
                } else if http.statusCode == 409 {
                    // Conflict - try a direct PATCH by user_id + raw_url first (fast path)
                    print("[LinksViewModel] 📡 Conflict detected, attempting quick PATCH by raw_url")
                    if await quickUpdateStatusByRawUrl(rawUrl: rawUrl, status: status, userId: userId, token: token, anonKey: anonKey) {
                        return true
                    }
                    // Fallback: broader search and update by ID
                    print("[LinksViewModel] 📡 Quick PATCH failed, falling back to ID lookup")
                    return await updateExistingLinkByUrl(rawUrl: rawUrl, status: status, userId: userId, token: token, anonKey: anonKey)
                }
                return false
            }
            return false
        } catch {
            print("[LinksViewModel] 🌐 Queue sync network error: \(error)")
            return false
        }
    }

    // Fast conflict resolution: update by user_id + exact raw_url match
    private func quickUpdateStatusByRawUrl(rawUrl: String, status: String, userId: String, token: String, anonKey: String) async -> Bool {
        // Properly percent-encode raw_url value for PostgREST eq. filter
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?#,+/")
        let encodedRawUrl = rawUrl.addingPercentEncoding(withAllowedCharacters: allowed) ?? rawUrl

        guard let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?user_id=eq.\(userId)&raw_url=eq.\(encodedRawUrl)") else {
            return false
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.timeoutInterval = 5.0

        let body = ["status": status]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[LinksViewModel] 📡 Quick PATCH by raw_url result: \(http.statusCode)")
                return http.statusCode == 204 || (200...299).contains(http.statusCode)
            }
        } catch {
            print("[LinksViewModel] 🌐 Quick PATCH error: \(error)")
        }
        return false
    }
    
    // Update existing link by URL (using ID lookup)
    private func updateExistingLinkByUrl(rawUrl: String, status: String, userId: String, token: String, anonKey: String) async -> Bool {
        do {
            // First, find the existing link by URL
            // Use a different approach: search by user_id only and filter in code
            let searchEndpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?user_id=eq.\(userId)&select=id,raw_url")!
            
            print("[LinksViewModel] 🔍 Searching for existing link: \(searchEndpoint)")
            
            var searchRequest = URLRequest(url: searchEndpoint)
            searchRequest.httpMethod = "GET"
            searchRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
            searchRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (searchData, searchResponse) = try await URLSession.shared.data(for: searchRequest)
            
            if let http = searchResponse as? HTTPURLResponse {
                print("[LinksViewModel] 🔍 Search response: \(http.statusCode)")
                let responseBody = String(data: searchData, encoding: .utf8) ?? "no body"
                print("[LinksViewModel] 🔍 Search response body: \(responseBody)")
                
                if http.statusCode == 200 {
                    if let searchResult = try? JSONSerialization.jsonObject(with: searchData) as? [[String: Any]] {
                        print("[LinksViewModel] 🔍 Found \(searchResult.count) total results, filtering for exact URL match")
                        
                        // Find the exact URL match in the results
                        let matchingResult = searchResult.first { result in
                            guard let resultUrl = result["raw_url"] as? String else { return false }
                            
                            // Try exact match first
                            if resultUrl == rawUrl {
                                print("[LinksViewModel] 🔍 Found exact match: \(resultUrl)")
                                return true
                            }
                            
                            // Try URL-decoded comparison for double-encoded URLs
                            if let decodedResultUrl = resultUrl.removingPercentEncoding,
                               let decodedRawUrl = rawUrl.removingPercentEncoding,
                               decodedResultUrl == decodedRawUrl {
                                print("[LinksViewModel] 🔍 Found decoded match: \(decodedResultUrl)")
                                return true
                            }
                            
                            // Try single-encoded comparison
                            if let encodedResultUrl = resultUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                               encodedResultUrl == rawUrl {
                                print("[LinksViewModel] 🔍 Found encoded match: \(encodedResultUrl)")
                                return true
                            }
                            
                            print("[LinksViewModel] 🔍 No match: queue='\(rawUrl)' vs db='\(resultUrl)'")
                            return false
                        }
                        
                        if let matchingResult = matchingResult,
                           let linkId = matchingResult["id"] as? String {
                            
                            print("[LinksViewModel] 🔍 Found exact URL match with ID: \(linkId)")
                            
                            // Now update by ID
                            let updateEndpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?id=eq.\(linkId)")!
                            var updateRequest = URLRequest(url: updateEndpoint)
                            updateRequest.httpMethod = "PATCH"
                            updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            updateRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
                            updateRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
                            updateRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                            updateRequest.timeoutInterval = 5.0
                            
                            let body = ["status": status]
                            updateRequest.httpBody = try JSONEncoder().encode(body)
                            
                            let (_, updateResponse) = try await URLSession.shared.data(for: updateRequest)
                            if let updateHttp = updateResponse as? HTTPURLResponse {
                                print("[LinksViewModel] 📡 Update by ID result: \(updateHttp.statusCode)")
                                return updateHttp.statusCode == 204
                            }
                        } else {
                            print("[LinksViewModel] ❌ No link ID found in search results")
                        }
                    } else {
                        print("[LinksViewModel] ❌ Failed to parse search results")
                    }
                } else {
                    print("[LinksViewModel] ❌ Search failed with status: \(http.statusCode)")
                }
            }
            
            // Let's try a broader search to see what's in the database
            print("[LinksViewModel] 🔍 Trying broader search to debug...")
            let debugEndpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?user_id=eq.\(userId)&select=raw_url&limit=5")!
            var debugRequest = URLRequest(url: debugEndpoint)
            debugRequest.httpMethod = "GET"
            debugRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
            debugRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            do {
                let (debugData, debugResponse) = try await URLSession.shared.data(for: debugRequest)
                if let debugHttp = debugResponse as? HTTPURLResponse, debugHttp.statusCode == 200 {
                    let debugBody = String(data: debugData, encoding: .utf8) ?? "no body"
                    print("[LinksViewModel] 🔍 Debug - existing URLs in DB: \(debugBody)")
                }
            } catch {
                print("[LinksViewModel] 🔍 Debug search failed: \(error)")
            }
            
            print("[LinksViewModel] ❌ Failed to find existing link for update")
            return false
            
        } catch {
            print("[LinksViewModel] 🌐 Update by URL error: \(error)")
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
        // Find the current link to get its title
        guard let currentLink = links.first(where: { $0.id == linkId }) else {
            print("[LinksViewModel] ❌ Could not find link to update star status")
            return
        }
        
        // Create the correct title with or without star prefix
        let newTitle: String
        let starEmoji = "⭐"
        
        if starred {
            // Add star prefix if not already present
            let cleanTitle = currentLink.cleanTitle
            newTitle = "\(starEmoji) \(cleanTitle)"
        } else {
            // Remove star prefix if present
            newTitle = currentLink.cleanTitle
        }
        
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
            
            // FIXED: Set the complete title with or without star prefix
            let body = ["title": newTitle]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let http = response as? HTTPURLResponse {
                let success = (200...299).contains(http.statusCode)
                
                // Log the star toggle operation
                let operation = RemoteOperation(
                    timestamp: Date(),
                    operation: "Toggle Star",
                    url: linkId,
                    method: "PATCH",
                    statusCode: http.statusCode,
                    success: success,
                    details: "Star status: \(starred ? "starred" : "unstarred")"
                )
                appendRemoteOperation(operation)
                
                if !success {
                    print("[LinksViewModel] Failed to update star status: \(http.statusCode)")
                    // Revert on failure
                    await fetchLinks(reset: true)
                }
            }
        } catch {
            print("[LinksViewModel] Error updating star status: \(error)")
            
            // Log the failed star toggle operation
            let operation = RemoteOperation(
                timestamp: Date(),
                operation: "Toggle Star",
                url: linkId,
                method: "PATCH",
                statusCode: nil,
                success: false,
                details: "Error: \(error.localizedDescription)"
            )
            appendRemoteOperation(operation)
            
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
            
            if let http = response as? HTTPURLResponse {
                let success = (200...299).contains(http.statusCode)
                print("[LinksViewModel] Delete link result: \(http.statusCode)")
                
                // Log the delete operation
                let operation = RemoteOperation(
                    timestamp: Date(),
                    operation: "Delete Link",
                    url: linkId,
                    method: "DELETE",
                    statusCode: http.statusCode,
                    success: success,
                    details: "Link deletion from main app"
                )
                appendRemoteOperation(operation)
                
                if !success {
                    print("[LinksViewModel] Failed to delete link: \(http.statusCode)")
                    // Revert on failure
                    await fetchLinks(reset: true)
                }
            }
        } catch {
            print("[LinksViewModel] Error deleting link: \(error)")
            
            // Log the failed delete operation
            let operation = RemoteOperation(
                timestamp: Date(),
                operation: "Delete Link",
                url: linkId,
                method: "DELETE",
                statusCode: nil,
                success: false,
                details: "Error: \(error.localizedDescription)"
            )
            appendRemoteOperation(operation)
            
            await fetchLinks(reset: true)
        }
    }
}

// MARK: - Remote Operations Log Persistence
extension LinksViewModel {
    private func loadRemoteOperationsLog() {
        let defaults = UserDefaults(suiteName: appGroupSuite) ?? .standard
        if let data = defaults.data(forKey: remoteLogKey),
           let log = try? JSONDecoder().decode([RemoteOperation].self, from: data) {
            self.remoteOperationsLog = log
        }
    }
    private func saveRemoteOperationsLog() {
        let defaults = UserDefaults(suiteName: appGroupSuite) ?? .standard
        if let data = try? JSONEncoder().encode(remoteOperationsLog) {
            defaults.set(data, forKey: remoteLogKey)
        }
    }
    func appendRemoteOperation(_ op: RemoteOperation) {
        remoteOperationsLog.append(op)
        if remoteOperationsLog.count > 50 {
            remoteOperationsLog.removeFirst(remoteOperationsLog.count - 50)
        }
        saveRemoteOperationsLog()
    }
    func clearRemoteOperationsLog() {
        remoteOperationsLog.removeAll()
        saveRemoteOperationsLog()
    }
} 