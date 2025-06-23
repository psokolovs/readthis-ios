import Foundation

struct Link: Identifiable, Codable, Equatable {
    let id: String
    let user_id: String
    let raw_url: String?
    let resolved_url: String?
    let title: String?
    let list: String?
    let status: String?
    let device_saved: String?
    let created_at: String?
    let updated_at: String?  // Added for sorting by last modified
} 