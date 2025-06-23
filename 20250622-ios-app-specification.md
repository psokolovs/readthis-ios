# iOS App Specification - Chrome Extension Feature Parity

## Overview

This specification defines the requirements for the iOS app to achieve feature parity with the Chrome extension's main link viewer page (`reading-list.html`/`reading-list.js`). The iOS app should implement all core functionality, UI patterns, and recent improvements.

## Core Architecture Requirements

### Data Model
```swift
struct Link: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let rawUrl: String
    let resolvedUrl: String?
    let title: String?
    let description: String?
    let list: String // "read" or "archive"
    let status: String // "unread" or "read"
    let deviceSaved: String?
    let createdAt: Date
    let updatedAt: Date
    let isStarred: Bool? // For newsletter inclusion
}
```

### Authentication
- **JWT Token Management**: Automatic token refresh with Supabase
- **Row Level Security**: All queries filtered by authenticated user_id
- **Offline Support**: Local queue for offline link saving

## UI/UX Requirements

### Main Interface Layout
1. **Tab Navigation**: "To Read" and "Archive" tabs with independent pagination
2. **Filter Controls**: Domain filter with search functionality
3. **Link Cards**: Modern card-based layout with hover effects
4. **Infinite Scroll**: Load 50 items at a time when scrolling near bottom
5. **Responsive Design**: Adapt to different screen sizes and orientations

### Link Card Design
```swift
struct LinkCard: View {
    let link: Link
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with HTML entity decoding
            Text(decodeHtmlEntities(link.title ?? "Untitled"))
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Description with HTML entity decoding
            if let description = link.description {
                Text(decodeHtmlEntities(description))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Domain and metadata
            HStack {
                Text(extractDomain(from: link.resolvedUrl ?? link.rawUrl))
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Spacer()
                
                // Star button for newsletter inclusion
                if link.list == "archive" {
                    Button(action: { toggleStar(for: link) }) {
                        Image(systemName: link.isStarred == true ? "star.fill" : "star")
                            .foregroundColor(link.isStarred == true ? .yellow : .gray)
                    }
                }
                
                // Mark read/unread button
                Button(action: { toggleReadStatus(for: link) }) {
                    Image(systemName: link.status == "read" ? "circle" : "checkmark.circle.fill")
                        .foregroundColor(link.status == "read" ? .gray : .green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
```

### HTML Entity Decoding Function
```swift
func decodeHtmlEntities(_ text: String) -> String {
    var decoded = text
    
    // Common HTML entities
    let entities = [
        "&#039;": "'",
        "&quot;": "\"",
        "&amp;": "&",
        "&lt;": "<",
        "&gt;": ">",
        "&apos;": "'",
        "&nbsp;": " ",
        "&mdash;": "—",
        "&ndash;": "–",
        "&hellip;": "…",
        "&ldquo;": """,
        "&rdquo;": """,
        "&lsquo;": "'",
        "&rsquo;": "'"
    ]
    
    for (entity, replacement) in entities {
        decoded = decoded.replacingOccurrences(of: entity, with: replacement)
    }
    
    // Handle numeric entities (&#123;)
    let numericPattern = "&#(\\d+);"
    decoded = decoded.replacingOccurrences(of: numericPattern, with: { match in
        if let number = Int(match.dropFirst(2).dropLast(1)) {
            return String(Character(UnicodeScalar(number)!))
        }
        return match
    }, options: .regularExpression)
    
    return decoded
}
```

## Core Functionality Requirements

### 1. Pagination System
```swift
class PaginationManager: ObservableObject {
    @Published var currentPage = 1
    @Published var hasMorePages = true
    @Published var isLoading = false
    
    let itemsPerPage = 50
    
    func loadNextPage(for filter: String) async {
        guard !isLoading && hasMorePages else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let offset = (currentPage - 1) * itemsPerPage
        
        // Load items from Supabase with pagination
        let items = await loadLinks(filter: filter, offset: offset, limit: itemsPerPage)
        
        if items.count < itemsPerPage {
            hasMorePages = false
        }
        
        currentPage += 1
    }
    
    func resetPagination() {
        currentPage = 1
        hasMorePages = true
    }
}
```

### 2. Independent Filter Pagination
- **Separate pagination state** for "To Read" and "Archive" tabs
- **Reset pagination** when switching between filters
- **Cache filter data** for instant switching
- **Infinite scroll** triggers based on current filter

### 3. Smart Duplicate Detection
```swift
func normalizeUrl(_ url: String) -> String {
    guard let urlComponents = URLComponents(string: url) else { return url }
    
    var components = urlComponents
    
    // Remove UTM parameters
    components.queryItems = components.queryItems?.filter { item in
        !item.name.lowercased().hasPrefix("utm_")
    }
    
    // Remove trailing slash
    var normalized = components.string ?? url
    if normalized.hasSuffix("/") {
        normalized = String(normalized.dropLast())
    }
    
    return normalized
}

func detectDuplicates(_ links: [Link]) -> [Link] {
    var seen = Set<String>()
    var uniqueLinks: [Link] = []
    
    for link in links {
        let normalized = normalizeUrl(link.resolvedUrl ?? link.rawUrl)
        if !seen.contains(normalized) {
            seen.insert(normalized)
            uniqueLinks.append(link)
        }
    }
    
    return uniqueLinks
}
```

### 4. Newsletter Star System
```swift
func toggleStar(for link: Link) async {
    // Update local state immediately for responsive UI
    // Then sync with database
    
    let newStarredValue = !(link.isStarred ?? false)
    
    // Optimistic update
    // Update UI immediately
    
    // Sync with database
    await updateLinkStarStatus(linkId: link.id, isStarred: newStarredValue)
}

func getStarredLinks() async -> [Link] {
    return await loadLinks(filter: "archive", additionalFilter: "is_starred = true")
}
```

### 5. Domain Filtering
```swift
func extractDomain(from url: String) -> String {
    guard let url = URL(string: url),
          let host = url.host else { return "Unknown" }
    
    // Remove www. prefix
    return host.replacingOccurrences(of: "www.", with: "")
}

func filterByDomain(_ links: [Link], domain: String) -> [Link] {
    guard !domain.isEmpty else { return links }
    
    return links.filter { link in
        let linkDomain = extractDomain(from: link.resolvedUrl ?? link.rawUrl)
        return linkDomain.lowercased().contains(domain.lowercased())
    }
}
```

## Data Management Requirements

### 1. Supabase Integration
```swift
class SupabaseManager: ObservableObject {
    private let supabaseUrl = "https://ijdtwrsqgbwfgftckywm.supabase.co"
    private let supabaseKey = "your-anon-key"
    
    func loadLinks(filter: String, offset: Int = 0, limit: Int = 50) async -> [Link] {
        var query = supabase
            .from("links")
            .select("*")
            .eq("list", filter)
            .order("updated_at", ascending: false)
            .range(offset, offset + limit - 1)
        
        // Apply Row Level Security automatically via user_id
        
        do {
            let response = try await query.execute()
            return try response.decoded(to: [Link].self)
        } catch {
            print("Error loading links: \(error)")
            return []
        }
    }
    
    func updateLinkStatus(linkId: UUID, status: String) async {
        do {
            try await supabase
                .from("links")
                .update(["status": status])
                .eq("id", linkId)
                .execute()
        } catch {
            print("Error updating link status: \(error)")
        }
    }
    
    func updateLinkStarStatus(linkId: UUID, isStarred: Bool) async {
        do {
            try await supabase
                .from("links")
                .update(["is_starred": isStarred])
                .eq("id", linkId)
                .execute()
        } catch {
            print("Error updating star status: \(error)")
        }
    }
}
```

### 2. Real-time Sync
```swift
func setupRealtimeSync() {
    supabase
        .channel("links")
        .on("postgres_changes", filter: .init(event: .all, schema: "public", table: "links")) { payload in
            // Handle real-time updates
            DispatchQueue.main.async {
                self.handleRealtimeUpdate(payload)
            }
        }
        .subscribe()
}
```

### 3. Offline Queue Management
```swift
struct OfflineAction {
    let id = UUID()
    let type: ActionType
    let linkId: UUID?
    let data: [String: Any]
    let timestamp = Date()
    
    enum ActionType {
        case markRead
        case markUnread
        case toggleStar
        case delete
    }
}

class OfflineQueueManager: ObservableObject {
    @Published var pendingActions: [OfflineAction] = []
    
    func addAction(_ action: OfflineAction) {
        pendingActions.append(action)
        saveToLocalStorage()
    }
    
    func processPendingActions() async {
        guard !pendingActions.isEmpty else { return }
        
        for action in pendingActions {
            await processAction(action)
        }
        
        pendingActions.removeAll()
        saveToLocalStorage()
    }
}
```

## Performance Requirements

### 1. Lazy Loading
- **Load 50 items** per page
- **Trigger loading** when user scrolls to 80% of current content
- **Show loading indicator** during data fetch
- **Cache loaded data** to prevent unnecessary API calls

### 2. Efficient State Management
```swift
class LinksViewModel: ObservableObject {
    @Published var toReadLinks: [Link] = []
    @Published var archiveLinks: [Link] = []
    @Published var currentFilter = "read"
    @Published var isLoading = false
    @Published var searchText = ""
    
    private let paginationManager = PaginationManager()
    private let supabaseManager = SupabaseManager()
    
    func loadInitialData() async {
        await loadLinks(for: currentFilter)
    }
    
    func loadMoreIfNeeded() async {
        await paginationManager.loadNextPage(for: currentFilter)
    }
    
    func switchFilter(to filter: String) async {
        currentFilter = filter
        paginationManager.resetPagination()
        await loadLinks(for: filter)
    }
}
```

### 3. Memory Management
- **Release unused images** and data
- **Limit cached items** to prevent memory issues
- **Handle large lists** efficiently with pagination
- **Monitor memory usage** and optimize as needed

## Error Handling Requirements

### 1. Network Errors
```swift
enum NetworkError: Error {
    case noConnection
    case timeout
    case serverError
    case authenticationFailed
}

func handleNetworkError(_ error: NetworkError) {
    switch error {
    case .noConnection:
        // Show offline mode indicator
        // Queue actions for later sync
    case .timeout:
        // Retry with exponential backoff
    case .serverError:
        // Show error message to user
    case .authenticationFailed:
        // Redirect to login
    }
}
```

### 2. Data Validation
- **Validate URLs** before saving
- **Handle malformed data** gracefully
- **Provide fallback values** for missing metadata
- **Log errors** for debugging

## Accessibility Requirements

### 1. VoiceOver Support
- **Proper accessibility labels** for all interactive elements
- **Clear navigation** for screen readers
- **Descriptive button labels** (e.g., "Mark as read", "Star for newsletter")
- **Announce loading states** and error messages

### 2. Dynamic Type
- **Support system font sizes** for better readability
- **Maintain proper contrast** ratios
- **Scale UI elements** appropriately

## Testing Requirements

### 1. Unit Tests
- **HTML entity decoding** function
- **URL normalization** logic
- **Duplicate detection** algorithms
- **Pagination** calculations

### 2. Integration Tests
- **Supabase API** integration
- **Real-time sync** functionality
- **Offline queue** processing
- **Authentication** flows

### 3. UI Tests
- **Navigation** between tabs
- **Infinite scroll** behavior
- **Filter functionality**
- **Star/unstar** actions

## Recent Improvements to Implement

### 1. Debug Logging System
```swift
class DebugLogger {
    static let shared = DebugLogger()
    private var isDevModeEnabled = false
    
    func log(_ message: String, level: LogLevel = .info) {
        guard isDevModeEnabled || level == .error else { return }
        
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] \(message)"
        
        print(logMessage)
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }
}
```

### 2. Enhanced URL Resolution
- **Edge function integration** for complex URLs
- **Anti-bot protection** handling
- **Multiple retry strategies** for failed resolutions
- **Graceful 403 error** handling

### 3. HTML Entity Support
- **Frontend decoding** for immediate display
- **Database cleanup** for existing entries
- **Comprehensive entity** support (&#039;, &quot;, &amp;, etc.)

## Success Criteria

The iOS app will achieve feature parity when it successfully implements:

1. ✅ **Complete UI/UX**: All visual elements and interactions match Chrome extension
2. ✅ **Pagination System**: Independent pagination per filter with infinite scroll
3. ✅ **Smart Features**: Duplicate detection, domain filtering, newsletter stars
4. ✅ **Data Sync**: Real-time synchronization with offline support
5. ✅ **Performance**: Efficient loading and memory management
6. ✅ **Error Handling**: Graceful degradation and user feedback
7. ✅ **Accessibility**: Full VoiceOver and Dynamic Type support
8. ✅ **Recent Features**: Debug logging, HTML entity decoding, enhanced URL resolution

## Implementation Priority

1. **High Priority**: Core UI, pagination, data loading
2. **Medium Priority**: Smart features, real-time sync, error handling
3. **Low Priority**: Debug logging, accessibility enhancements, performance optimizations

This specification provides a comprehensive roadmap for achieving feature parity between the iOS app and Chrome extension, ensuring users have a consistent experience across platforms. 