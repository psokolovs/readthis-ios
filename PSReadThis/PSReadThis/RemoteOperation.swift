import Foundation

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