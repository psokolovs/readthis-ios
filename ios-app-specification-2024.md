# iOS App Specification 2024 - Complete Feature Parity

## 🎯 Overview

This specification defines the requirements for the iOS app to achieve complete feature parity with the Chrome extension's latest improvements (as of 2024). The iOS app must implement all recent enhancements including the smart multi-filter system, enhanced domain filtering, content type detection, and modern UI/UX patterns.

## 🚀 Recent Major Features to Implement

### 1. Smart Multi-Filter System

The Chrome extension now features a sophisticated chip-based filtering system that replaces the simple toggle approach:

#### Filter Categories

**Status Filters (Mutually Exclusive):**
- 📖 **To Read** - Unread items in reading queue
- 📚 **Archive** - Items marked as read

**Content Type Filters (Combinable):**
- ⭐ **Featured** - Newsletter-included items (title starts with ⭐)
- 🎥 **Videos** - Video content (YouTube, Vimeo, etc.)
- 🎵 **Audio** - Podcasts and audio content
- 📰 **Articles** - Default article content

#### iOS Implementation

```swift
// MARK: - Filter Models
enum StatusFilter: String, CaseIterable {
    case toRead = "unread"
    case archive = "read"
    
    var displayName: String {
        switch self {
        case .toRead: return "📖 To Read"
        case .archive: return "📚 Archive"
        }
    }
}

enum ContentFilter: String, CaseIterable {
    case featured = "featured"
    case video = "video"
    case audio = "audio"  
    case article = "article"
    
    var displayName: String {
        switch self {
        case .featured: return "⭐ Featured"
        case .video: return "🎥 Videos"
        case .audio: return "🎵 Audio"
        case .article: return "📰 Articles"
        }
    }
}

// MARK: - Filter State Management
class FilterManager: ObservableObject {
    @Published var activeStatusFilter: StatusFilter = .toRead
    @Published var activeContentFilters: Set<ContentFilter> = []
    @Published var filterCounts: [String: Int] = [:]
    
    func toggleContentFilter(_ filter: ContentFilter) {
        if activeContentFilters.contains(filter) {
            activeContentFilters.remove(filter)
        } else {
            activeContentFilters.insert(filter)
        }
    }
    
    func setStatusFilter(_ filter: StatusFilter) {
        activeStatusFilter = filter
        // Reset content filters when changing status
        activeContentFilters.removeAll()
    }
    
    func updateFilterCounts(from links: [Link]) {
        var counts: [String: Int] = [:]
        
        // Count by status
        counts["unread"] = links.filter { $0.status == "unread" }.count
        counts["read"] = links.filter { $0.status == "read" }.count
        
        // Count by content type
        let categorizedLinks = links.map { link in
            (link, detectContentTypes(for: link))
        }
        
        ContentFilter.allCases.forEach { filter in
            counts[filter.rawValue] = categorizedLinks.filter { 
                $1.contains(filter.rawValue) 
            }.count
        }
        
        DispatchQueue.main.async {
            self.filterCounts = counts
        }
    }
}
```

### 2. Content Type Detection System

```swift
// MARK: - Content Type Detection
func detectContentTypes(for link: Link) -> [String] {
    var categories: [String] = []
    let url = (link.resolvedUrl ?? link.rawUrl).lowercased()
    let title = (link.title ?? "").lowercased()
    let domain = extractDomain(from: link.resolvedUrl ?? link.rawUrl).lowercased()
    
    // Video detection
    if isVideoContent(url: url, title: title, domain: domain) {
        categories.append("video")
    }
    
    // Audio detection
    if isAudioContent(url: url, title: title, domain: domain) {
        categories.append("audio")
    }
    
    // Featured detection (newsletter inclusion)
    if link.title?.hasPrefix("⭐") == true {
        categories.append("featured")
    }
    
    // Default to article if no specific type detected
    if categories.isEmpty {
        categories.append("article")
    }
    
    return categories
}

func isVideoContent(url: String, title: String, domain: String) -> Bool {
    // Video platforms
    let videoDomains = [
        "youtube.com", "youtu.be", "vimeo.com", "twitch.tv", "tiktok.com",
        "instagram.com", "facebook.com", "twitter.com", "x.com", "dailymotion.com",
        "wistia.com", "loom.com", "streamable.com", "rumble.com"
    ]
    
    // Check domain
    if videoDomains.contains(where: { domain.contains($0) }) {
        return true
    }
    
    // Check URL patterns
    let videoPatterns = ["/watch", "/video", "/v/", "/embed/", "/player/", "/stream/"]
    if videoPatterns.contains(where: { url.contains($0) }) {
        return true
    }
    
    // Check title keywords
    let videoKeywords = [
        "watch:", "video:", "[video]", "youtube:", "streaming:", "webinar:",
        "tutorial:", "demo:", "presentation:", "interview:"
    ]
    if videoKeywords.contains(where: { title.contains($0) }) {
        return true
    }
    
    return false
}

func isAudioContent(url: String, title: String, domain: String) -> Bool {
    // Audio platforms
    let audioDomains = [
        "spotify.com", "soundcloud.com", "anchor.fm", "podcast.", "podcasts.",
        "apple.com/podcasts", "overcast.fm", "pocketcasts.com", "stitcher.com",
        "podbean.com", "libsyn.com", "buzzsprout.com", "simplecast.com"
    ]
    
    // Check domain
    if audioDomains.contains(where: { domain.contains($0) }) {
        return true
    }
    
    // Check URL patterns
    let audioPatterns = ["/podcast/", "/episode/", "/audio/", "/listen/"]
    if audioPatterns.contains(where: { url.contains($0) }) {
        return true
    }
    
    // Check title keywords
    let audioKeywords = [
        "podcast:", "episode:", "listen:", "[podcast]", "[audio]", "interview:",
        "discussion:", "conversation:", "talk:", "radio:", "show:", "#"
    ]
    if audioKeywords.contains(where: { title.contains($0) }) {
        return true
    }
    
    return false
}
```

### 3. Enhanced Domain Filter with Autocomplete

```swift
// MARK: - Domain Filter Management
class DomainFilterManager: ObservableObject {
    @Published var searchText = ""
    @Published var showingSuggestions = false
    @Published var availableDomains: [(domain: String, count: Int)] = []
    @Published var highlightedIndex = -1
    
    func buildDomainStatistics(from links: [Link]) {
        var domainCounts: [String: Int] = [:]
        
        links.forEach { link in
            let domain = extractDomain(from: link.resolvedUrl ?? link.rawUrl)
            domainCounts[domain, default: 0] += 1
        }
        
        // Sort by frequency and take top 20
        availableDomains = domainCounts
            .sorted { $0.value > $1.value }
            .map { (domain: $0.key, count: $0.value) }
            .prefix(20)
            .map { $0 }
    }
    
    var filteredDomains: [(domain: String, count: Int)] {
        guard !searchText.isEmpty else { return availableDomains }
        
        return availableDomains.filter { 
            $0.domain.lowercased().contains(searchText.lowercased())
        }
    }
    
    func selectDomain(_ domain: String) {
        searchText = domain
        showingSuggestions = false
        highlightedIndex = -1
    }
    
    func clearFilter() {
        searchText = ""
        showingSuggestions = false
        highlightedIndex = -1
    }
}

// MARK: - Domain Filter UI
struct DomainFilterView: View {
    @ObservedObject var domainManager: DomainFilterManager
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search Input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Filter by domain...", text: $domainManager.searchText)
                    .focused($isTextFieldFocused)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onTapGesture {
                        domainManager.showingSuggestions = true
                    }
                
                if !domainManager.searchText.isEmpty {
                    Button("Clear") {
                        domainManager.clearFilter()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Suggestions Dropdown
            if domainManager.showingSuggestions && !domainManager.filteredDomains.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(domainManager.filteredDomains.enumerated()), id: \.offset) { index, item in
                            DomainSuggestionRow(
                                domain: item.domain,
                                count: item.count,
                                isHighlighted: index == domainManager.highlightedIndex
                            ) {
                                domainManager.selectDomain(item.domain)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 4)
                .padding(.horizontal)
            }
        }
    }
}

struct DomainSuggestionRow: View {
    let domain: String
    let count: Int
    let isHighlighted: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(domain)
                    .font(.body)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isHighlighted ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

### 4. Updated Link Card with Content Type Indicators

```swift
// MARK: - Enhanced Link Card
struct EnhancedLinkCard: View {
    let link: Link
    let contentTypes: [String]
    @ObservedObject var filterManager: FilterManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with content type indicators
            HStack {
                // Content type badges
                HStack(spacing: 4) {
                    ForEach(contentTypes, id: \.self) { type in
                        ContentTypeBadge(type: type)
                    }
                }
                
                Spacer()
                
                // Newsletter star (if featured)
                if contentTypes.contains("featured") {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                
                // Date
                Text(formatRelativeDate(link.updatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Title with HTML entity decoding
            Text(decodeHtmlEntities(link.title ?? "Untitled"))
                .font(.headline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Description or URL
            let displayDescription = link.description?.isEmpty == false ? 
                decodeHtmlEntities(link.description!) : 
                (link.resolvedUrl ?? link.rawUrl)
            
            Text(displayDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Footer with domain and actions
            HStack {
                // Domain
                Text(extractDomain(from: link.resolvedUrl ?? link.rawUrl))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    // Star button (for archive items)
                    if filterManager.activeStatusFilter == .archive {
                        Button(action: { toggleNewsletterInclusion(for: link) }) {
                            Image(systemName: contentTypes.contains("featured") ? "star.fill" : "star")
                                .foregroundColor(contentTypes.contains("featured") ? .yellow : .gray)
                        }
                    }
                    
                    // Copy button
                    Button(action: { copyToClipboard(link.resolvedUrl ?? link.rawUrl) }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    
                    // Toggle read status
                    Button(action: { toggleReadStatus(for: link) }) {
                        Image(systemName: link.status == "read" ? "circle" : "checkmark.circle.fill")
                            .foregroundColor(link.status == "read" ? .gray : .green)
                    }
                    
                    // Delete button
                    Button(action: { deleteLink(link) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                .font(.system(size: 16))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onTapGesture {
            openLink(link.resolvedUrl ?? link.rawUrl)
        }
    }
}

struct ContentTypeBadge: View {
    let type: String
    
    var body: some View {
        let (icon, color) = iconAndColor(for: type)
        
        HStack(spacing: 2) {
            Text(icon)
                .font(.caption2)
            Text(type.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
    
    private func iconAndColor(for type: String) -> (String, Color) {
        switch type {
        case "featured": return ("⭐", .yellow)
        case "video": return ("🎥", .red)
        case "audio": return ("🎵", .purple)
        case "article": return ("📰", .blue)
        default: return ("📄", .gray)
        }
    }
}
```

### 5. Advanced State Management

```swift
// MARK: - Comprehensive View Model
class EnhancedLinksViewModel: ObservableObject {
    @Published var links: [Link] = []
    @Published var isLoading = false
    @Published var hasMoreData = true
    
    // Filter managers
    @Published var filterManager = FilterManager()
    @Published var domainManager = DomainFilterManager()
    
    // Pagination state per filter
    private var paginationState: [String: PaginationInfo] = [:]
    
    private let pageSize = 50
    private var categorizedLinks: [UUID: [String]] = [:]
    
    struct PaginationInfo {
        var currentPage = 0
        var hasMoreData = true
        var allLinks: [Link] = []
        var hasCompleteData = false
    }
    
    func loadLinks(loadMore: Bool = false) async {
        let filterKey = filterManager.activeStatusFilter.rawValue
        
        guard !isLoading else { return }
        
        if !loadMore {
            // Fresh load - reset pagination
            paginationState[filterKey] = PaginationInfo()
        }
        
        guard let pagination = paginationState[filterKey],
              pagination.hasMoreData || !loadMore else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let offset = (paginationState[filterKey]?.currentPage ?? 0) * pageSize
            let newLinks = try await SupabaseManager.shared.loadLinks(
                filter: filterKey,
                offset: offset,
                limit: pageSize
            )
            
            await MainActor.run {
                var info = paginationState[filterKey] ?? PaginationInfo()
                
                if loadMore {
                    info.allLinks.append(contentsOf: newLinks)
                } else {
                    info.allLinks = newLinks
                    info.hasCompleteData = true
                }
                
                info.currentPage += 1
                info.hasMoreData = newLinks.count == pageSize
                paginationState[filterKey] = info
                
                // Apply filtering
                applyFilters()
                
                // Update filter counts
                categorizeAllLinks()
                filterManager.updateFilterCounts(from: info.allLinks)
                
                // Update domain statistics
                domainManager.buildDomainStatistics(from: info.allLinks)
                
                isLoading = false
                hasMoreData = info.hasMoreData
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func categorizeAllLinks() {
        let filterKey = filterManager.activeStatusFilter.rawValue
        guard let allLinks = paginationState[filterKey]?.allLinks else { return }
        
        categorizedLinks.removeAll()
        
        allLinks.forEach { link in
            let categories = detectContentTypes(for: link)
            categorizedLinks[link.id] = categories
        }
    }
    
    private func applyFilters() {
        let filterKey = filterManager.activeStatusFilter.rawValue
        guard let allLinks = paginationState[filterKey]?.allLinks else { return }
        
        var filteredLinks = allLinks
        
        // Apply domain filter
        if !domainManager.searchText.isEmpty {
            let domainFilter = domainManager.searchText.lowercased()
            filteredLinks = filteredLinks.filter { link in
                let domain = extractDomain(from: link.resolvedUrl ?? link.rawUrl).lowercased()
                return domain.contains(domainFilter)
            }
        }
        
        // Apply content type filters
        if !filterManager.activeContentFilters.isEmpty {
            filteredLinks = filteredLinks.filter { link in
                let categories = categorizedLinks[link.id] ?? []
                return filterManager.activeContentFilters.contains { filter in
                    categories.contains(filter.rawValue)
                }
            }
        }
        
        links = filteredLinks
    }
    
    func switchFilter(to filter: StatusFilter) async {
        await MainActor.run {
            filterManager.setStatusFilter(filter)
        }
        
        let filterKey = filter.rawValue
        
        // Use cached data if available and complete
        if let info = paginationState[filterKey],
           !info.allLinks.isEmpty && info.hasCompleteData {
            await MainActor.run {
                applyFilters()
                hasMoreData = info.hasMoreData
            }
        } else {
            // Load fresh data
            await loadLinks()
        }
    }
    
    func refreshActiveFilter() {
        Task {
            let filterKey = filterManager.activeStatusFilter.rawValue
            paginationState[filterKey] = PaginationInfo()
            await loadLinks()
        }
    }
}
```

### 6. Main Interface Implementation

```swift
// MARK: - Main Reading List View
struct ReadingListView: View {
    @StateObject private var viewModel = EnhancedLinksViewModel()
    @State private var showingFilters = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Section (Collapsible)
                if showingFilters {
                    VStack(spacing: 16) {
                        FilterSection(filterManager: viewModel.filterManager)
                        DomainFilterView(domainManager: viewModel.domainManager)
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .transition(.slide)
                }
                
                // Links List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.links) { link in
                            EnhancedLinkCard(
                                link: link,
                                contentTypes: viewModel.categorizedLinks[link.id] ?? ["article"],
                                filterManager: viewModel.filterManager
                            )
                            .onAppear {
                                // Load more when near bottom
                                if link.id == viewModel.links.last?.id && viewModel.hasMoreData {
                                    Task {
                                        await viewModel.loadLinks(loadMore: true)
                                    }
                                }
                            }
                        }
                        
                        // Loading indicator
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        }
                        
                        // Empty state
                        if viewModel.links.isEmpty && !viewModel.isLoading {
                            EmptyStateView(
                                statusFilter: viewModel.filterManager.activeStatusFilter,
                                contentFilters: viewModel.filterManager.activeContentFilters,
                                domainFilter: viewModel.domainManager.searchText
                            )
                        }
                    }
                    .padding()
                }
                .refreshable {
                    viewModel.refreshActiveFilter()
                }
            }
            .navigationTitle("PS Read This")
            .navigationBarTitleDisplayMode(.automatic)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        withAnimation {
                            showingFilters.toggle()
                        }
                    }) {
                        Image(systemName: showingFilters ? "line.horizontal.3.decrease" : "line.horizontal.3.decrease.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadLinks()
        }
        .onChange(of: viewModel.filterManager.activeStatusFilter) { newFilter in
            Task {
                await viewModel.switchFilter(to: newFilter)
            }
        }
        .onChange(of: viewModel.filterManager.activeContentFilters) { _ in
            viewModel.applyFilters()
        }
        .onChange(of: viewModel.domainManager.searchText) { _ in
            viewModel.applyFilters()
        }
    }
}

struct EmptyStateView: View {
    let statusFilter: StatusFilter
    let contentFilters: Set<ContentFilter>
    let domainFilter: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Nothing here yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    private var emptyStateMessage: String {
        if !domainFilter.isEmpty {
            return "No links found for domain \"\(domainFilter)\""
        } else if !contentFilters.isEmpty {
            let filterNames = contentFilters.map { $0.displayName }.joined(separator: " + ")
            return "No \(filterNames) links found in your \(statusFilter.displayName.lowercased()) list"
        } else if statusFilter == .toRead {
            return "No links to read. Save some links using the extension!"
        } else {
            return "No archived links yet."
        }
    }
}
```

## 🎯 Implementation Priority

### Phase 1: Core Multi-Filter System
1. **Filter Models & Management** - StatusFilter, ContentFilter, FilterManager
2. **Content Type Detection** - detectContentTypes, isVideoContent, isAudioContent
3. **Basic Filter UI** - FilterSection with chips and badges
4. **Updated Link Cards** - ContentTypeBadge, enhanced metadata display

### Phase 2: Enhanced Domain Filtering
1. **Domain Filter Manager** - DomainFilterManager with autocomplete logic
2. **Domain Filter UI** - DomainFilterView with suggestions dropdown
3. **Domain Statistics** - buildDomainStatistics, real-time filtering

### Phase 3: Advanced State Management
1. **Enhanced View Model** - EnhancedLinksViewModel with multi-filter support
2. **Smart Filtering Logic** - applyFilters with combined filter support
3. **Optimized Caching** - Filter-specific pagination and data management

### Phase 4: UI Polish & Optimization
1. **Performance Optimizations** - Lazy loading, efficient filtering
2. **Accessibility Enhancements** - VoiceOver support, Dynamic Type
3. **Animation & Transitions** - Smooth filter changes, loading states

## ✅ Success Criteria

The iOS app achieves complete feature parity when:

1. **✅ Multi-Filter System**: Status + content type filtering with visual indicators
2. **✅ Enhanced Domain Filter**: Autocomplete dropdown with domain suggestions
3. **✅ Content Type Detection**: Accurate categorization of videos, audio, articles
4. **✅ Modern UI/UX**: Filter chips, badges, improved link cards
5. **✅ Smart State Management**: Efficient filtering and caching
6. **✅ Performance**: Smooth scrolling, responsive filtering, optimized loading

This specification provides a complete roadmap for implementing all recent Chrome extension improvements in the iOS app, ensuring users have a consistent and modern experience across all platforms. 