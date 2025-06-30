import Foundation

class PSReadThisConfig {
    static let shared = PSReadThisConfig()
    
    private let configURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/storage/v1/object/public/psreadthis/psreadthis-config.json")!
    private let supabaseURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co")!
    
    // Use the correct anon key provided by the user - hardcoded to bypass remote config issues
    private let correctAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlqZHR3cnNxZ2J3ZmdmdGNreXdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2NTc0OTgsImV4cCI6MjA2NjIzMzQ5OH0.5g-vKzecYOf8fZut3h2lvVewbXoO9AvjYcLDxLN_510"
    
    private var cachedAnonKey: String?
    private let cacheKey = "PSReadThisAnonKey"
    
    private init() {}
    
    func getSupabaseURL() -> URL {
        return supabaseURL
    }
    
    func getAnonKey() async -> String? {
        print("[PSReadThisConfig] 🔑 Using hardcoded correct anon key to bypass remote config issues")
        
        // Return the correct anon key directly - no remote fetching
        cachedAnonKey = correctAnonKey
        UserDefaults.standard.set(correctAnonKey, forKey: cacheKey)
        
        print("[PSReadThisConfig] ✅ Using correct anon key: \(correctAnonKey.prefix(50))...")
        return correctAnonKey
    }
    
    // Legacy method - no longer used but keeping for compatibility
    private func fetchConfigFromRemote() async -> String? {
        print("[PSReadThisConfig] ⚠️ Legacy remote config method - should not be called")
        return correctAnonKey
    }
    
    func clearCache() {
        cachedAnonKey = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
        print("[PSReadThisConfig] 🧹 Cache cleared")
    }
}

private struct ConfigResponse: Codable {
    let anonKey: String
} 