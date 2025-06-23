import Foundation

class PSReadThisConfig {
    static let shared = PSReadThisConfig()
    
    private let configURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/storage/v1/object/public/psreadthis/psreadthis-config.json")!
    private let supabaseURL = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co")!
    
    private var cachedAnonKey: String?
    private let cacheKey = "PSReadThisAnonKey"
    
    private init() {}
    
    func getSupabaseURL() -> URL {
        return supabaseURL
    }
    
    func getAnonKey() async throws -> String {
        // Return cached key if available
        if let cached = cachedAnonKey {
            return cached
        }
        
        // Try UserDefaults cache
        if let userDefaultsKey = UserDefaults.standard.string(forKey: cacheKey) {
            cachedAnonKey = userDefaultsKey
            return userDefaultsKey
        }
        
        // Fetch from remote config
        let (data, response) = try await URLSession.shared.data(from: configURL)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let config = try JSONDecoder().decode(ConfigResponse.self, from: data)
        
        // Cache the key
        cachedAnonKey = config.anonKey
        UserDefaults.standard.set(config.anonKey, forKey: cacheKey)
        
        return config.anonKey
    }
    
    func clearCache() {
        cachedAnonKey = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}

private struct ConfigResponse: Codable {
    let anonKey: String
} 