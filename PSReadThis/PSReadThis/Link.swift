import Foundation

struct Link: Identifiable, Codable, Equatable {
    let id: String
    let user_id: String
    let raw_url: String?
    let resolved_url: String?
    let title: String?
    let description: String?  // Added description field
    let list: String?
    let status: String?
    let device_saved: String?
    let created_at: String?
    let updated_at: String?  // Added for sorting by last modified
    
    // MARK: - Computed Properties for Star System
    
    /// Whether this link is starred (has ⭐ prefix in title)
    var isStarred: Bool {
        title?.hasPrefix("⭐ ") ?? false
    }
    
    /// Title without the star prefix
    var cleanTitle: String {
        guard let title = title else { return "Untitled" }
        return title.hasPrefix("⭐ ") ? String(title.dropFirst(2)) : title
    }
    
    /// Create a new link with star status toggled
    func withToggledStar() -> Link {
        let newTitle: String
        if isStarred {
            newTitle = cleanTitle
        } else {
            newTitle = "⭐ " + (title ?? "Untitled")
        }
        
        return Link(
            id: id,
            user_id: user_id,
            raw_url: raw_url,
            resolved_url: resolved_url,
            title: newTitle,
            description: description,
            list: list,
            status: status,
            device_saved: device_saved,
            created_at: created_at,
            updated_at: updated_at
        )
    }
    
    /// Extract domain from URL for display
    var displayDomain: String {
        guard let urlString = resolved_url ?? raw_url,
              let url = URL(string: urlString),
              let host = url.host else { return "Unknown" }
        
        // Remove www. prefix
        return host.replacingOccurrences(of: "www.", with: "")
    }
} 