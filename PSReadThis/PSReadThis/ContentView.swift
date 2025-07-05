//
//  ContentView.swift
//  PSReadThis
//
//  Created by Pavel S on 6/7/25.
//

import SwiftUI
import SafariServices

struct ContentView: View {
    @StateObject private var viewModel = LinksViewModel()
    @State private var isDevMode = false
    @State private var showingSafari = false
    @State private var selectedURL: String?
    @State private var selectedContentFilter: String = "all"

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Filter Section (Performance Optimized)
                VStack(spacing: 12) {
                    // Status Filter Toggle  
                    HStack(spacing: 8) {
                        FilterButton(
                            title: "📖 To Read",
                            isSelected: viewModel.currentFilter == .unread,
                            count: nil
                        ) {
                            Task {
                                viewModel.currentFilter = .unread
                                selectedContentFilter = "all"  // Reset content filter when switching tabs
                                await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
                            }
                        }
                        
                        FilterButton(
                            title: "📚 Archive", 
                            isSelected: viewModel.currentFilter == .read,
                            count: nil
                        ) {
                            Task {
                                viewModel.currentFilter = .read
                                selectedContentFilter = "all"  // Reset content filter when switching tabs
                                await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)  // Add padding to align with content filters
                    
                    // Content Type Filters (Performance Optimized)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ContentFilterChip(
                                title: "📄 All",
                                isSelected: selectedContentFilter == "all"
                            ) {
                                selectedContentFilter = "all"
                                Task {
                                    await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
                                }
                            }
                            
                            // Show Starred filter only for Archive
                            if viewModel.currentFilter == .read {
                                ContentFilterChip(
                                    title: "⭐ Starred",
                                    isSelected: selectedContentFilter == "starred"
                                ) {
                                    print("[ContentView] 🌟 STARRED FILTER BUTTON TAPPED!")
                                    print("[ContentView] 🌟 Setting selectedContentFilter to 'starred'")
                                    selectedContentFilter = "starred"
                                    print("[ContentView] 🌟 selectedContentFilter is now: '\(selectedContentFilter)'")
                                    Task {
                                        print("[ContentView] 🌟 Calling fetchLinks with contentFilter: '\(selectedContentFilter)'")
                                        await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
                                    }
                                }
                            }
                            
                            // Show content type filters only for To Read
                            if viewModel.currentFilter == .unread {
                                ContentFilterChip(
                                    title: "🎬 Videos",
                                    isSelected: selectedContentFilter == "video"
                                ) {
                                    selectedContentFilter = "video"
                                    Task {
                                        await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
                                    }
                                }
                                
                                ContentFilterChip(
                                    title: "🎵 Audio",
                                    isSelected: selectedContentFilter == "audio"
                                ) {
                                    selectedContentFilter = "audio"
                                    Task {
                                        await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
                                    }
                                }
                                
                                ContentFilterChip(
                                    title: "📰 Articles",
                                    isSelected: selectedContentFilter == "article"
                                ) {
                                    selectedContentFilter = "article"
                                    Task {
                                        await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.trailing, 8) // Extra padding to ensure chips are fully visible
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .frame(maxWidth: .infinity)
                
                Divider()
                
                // Enhanced Links List (Performance Optimized)
                SimpleLinksList(
                    viewModel: viewModel, 
                    selectedURL: $selectedURL,
                    contentFilter: selectedContentFilter
                )
            }
            .navigationTitle("PSReadThis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("⚙️") {
                        isDevMode.toggle()
                    }
                }
            }
            .sheet(isPresented: $isDevMode) {
                DeveloperModeView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingSafari) {
                if let urlString = selectedURL, let url = URL(string: urlString) {
                    SafariView(url: url)
                } else {
                    Text("Invalid URL")
                }
            }
            .onChange(of: selectedURL) { url in
                if url != nil {
                    showingSafari = true
                }
            }
            .onChange(of: showingSafari) { isShowing in
                if !isShowing {
                    // Reset selectedURL when Safari is dismissed to allow re-tapping the same link
                    selectedURL = nil
                }
            }
        }
        .task {
            // Simple initial load
            await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
        }
    }
}

// MARK: - Enhanced Links List (Performance Optimized)
struct SimpleLinksList: View {
    @ObservedObject var viewModel: LinksViewModel
    @Binding var selectedURL: String?
    let contentFilter: String
    
    private var filteredLinks: [Link] {
        // Always print what filter we're using
        print("[ContentView] 🚀 FILTERING WITH: '\(contentFilter)' (total links: \(viewModel.links.count))")
        
        guard contentFilter != "all" else { 
            print("[ContentView] 🚀 RETURNING ALL LINKS: \(viewModel.links.count)")
            return viewModel.links 
        }
        
        let filtered = viewModel.links.filter { link in
            switch contentFilter {
            case "starred":
                let isStarred = link.isStarred
                let title = link.title ?? "nil"
                // Enhanced debug logging for starred filter
                print("[ContentView] 🔍 Link: '\(title)' -> isStarred: \(isStarred)")
                print("[ContentView] 🔍   - hasPrefix('⭐ '): \(title.hasPrefix("⭐ "))")
                print("[ContentView] 🔍   - hasPrefix('⭐'): \(title.hasPrefix("⭐"))")
                print("[ContentView] 🔍   - cleanTitle: '\(link.cleanTitle)'")
                return isStarred
            case "video":
                return isVideoLink(link)
            case "audio":
                return isAudioLink(link)
            case "article":
                return isArticleLink(link)
            default:
                return true
            }
        }
        
        // Enhanced debug logging for starred filter results
        if contentFilter == "starred" {
            print("[ContentView] 🌟 STARRED FILTER RESULTS:")
            print("[ContentView] 🌟   - Filtered count: \(filtered.count)")
            print("[ContentView] 🌟   - Total links: \(viewModel.links.count)")
            print("[ContentView] 🌟   - All titles: \(viewModel.links.map { $0.title ?? "nil" })")
            let starredTitles = viewModel.links.filter { $0.isStarred }.map { $0.title ?? "nil" }
            print("[ContentView] 🌟   - Starred titles found: \(starredTitles)")
        }
        
        print("[ContentView] 🚀 FILTER RESULT: \(filtered.count) links")
        return filtered
    }
    
    var body: some View {
        List {
            ForEach(filteredLinks) { link in
                SimpleLinkCard(
                    link: link,
                    onTap: { selectedURL = link.resolved_url ?? link.raw_url },
                    onMarkAsRead: { await viewModel.markAsRead(link) },
                    onStarToggle: { await viewModel.toggleStar(link) },
                    onArchive: { await viewModel.markAsRead(link) },
                    onDelete: { await viewModel.deleteLink(link) }
                )
                .onAppear {
                    // Fix: Check against filteredLinks.last instead of viewModel.links.last
                    let isLastLink = link == filteredLinks.last
                    
                    if isLastLink && viewModel.hasMore {
                        // Show visual indicator that lazy loading triggered
                        viewModel.lastLazyLoadTrigger = "🚀 Lazy load triggered for: \(link.cleanTitle.prefix(20))..."
                        Task { await viewModel.fetchLinks(contentFilter: contentFilter) }
                    } else {
                        viewModel.lastLazyLoadTrigger = "❌ Not triggered - isLast: \(isLastLink), hasMore: \(viewModel.hasMore)"
                    }
                }
            }
            
            if viewModel.isLoading {
                LoadingView()
            }
            
            if filteredLinks.isEmpty && !viewModel.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("No links yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Links you save will appear here")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(40)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }
        .refreshable {
            await viewModel.fetchLinks(reset: true, contentFilter: contentFilter)
        }
        .listStyle(.plain)
    }
}

// MARK: - Simplified Link Card
struct SimpleLinkCard: View {
    let link: Link
    let onTap: () -> Void
    let onMarkAsRead: () async -> Void
    let onStarToggle: () async -> Void  
    let onArchive: () async -> Void
    let onDelete: () async -> Void
    
    @State private var isProcessingAction = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title with star
            HStack(alignment: .top, spacing: 8) {
                if link.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                }
                
                Text(decodeHtmlEntities(betterTitle(for: link)))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            // Description (if available)
            if let description = link.description, !description.isEmpty {
                Text(decodeHtmlEntities(description))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // URL/Domain and Time
            HStack {
                Text(extractDomain(from: link.resolved_url ?? link.raw_url ?? ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Text(formatTimeAgo(from: link.updated_at ?? link.created_at ?? ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray6), lineWidth: 1)
        )
        // Dark mode aware shadow/border combination
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color.primary.opacity(0.06), 
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: Color.black.opacity(0.03), 
            radius: 1, x: 0, y: 0.5
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button {
                Task { await onStarToggle() }
            } label: {
                Label(
                    link.isStarred ? "Unstar" : "Star",
                    systemImage: link.isStarred ? "star.slash" : "star"
                )
            }
            
            Button {
                Task { await onMarkAsRead() }
            } label: {
                Label(
                    link.status == "unread" ? "Mark as Read" : "Mark as Unread",
                    systemImage: link.status == "unread" ? "checkmark" : "circle"
                )
            }
            
            Button {
                if let url = link.resolved_url ?? link.raw_url {
                    UIPasteboard.general.string = url
                }
            } label: {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                Task { await onDelete() }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete
            Button {
                Task {
                    isProcessingAction = true
                    await onDelete()
                    isProcessingAction = false
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            
            // Archive/Mark as Read
            Button {
                Task {
                    isProcessingAction = true
                    if link.status == "unread" {
                        await onMarkAsRead()
                    } else {
                        await onArchive()
                    }
                    isProcessingAction = false
                }
            } label: {
                Label(
                    link.status == "unread" ? "Archive" : "Unread",
                    systemImage: link.status == "unread" ? "archivebox" : "book"
                )
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            // Star toggle
            Button {
                Task {
                    isProcessingAction = true
                    await onStarToggle()
                    isProcessingAction = false
                }
            } label: {
                Label(
                    link.isStarred ? "Unstar" : "Star",
                    systemImage: link.isStarred ? "star.slash" : "star"
                )
            }
            .tint(.yellow)
        }
        .opacity(isProcessingAction ? 0.6 : 1.0)
        .disabled(isProcessingAction)
        .listRowInsets(EdgeInsets(top: 8, leading: 2, bottom: 8, trailing: 2))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Filter Button (Simplified)
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
                
                if let count = count {
                    Text("\(count)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray4))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }
}

// MARK: - Content Filter Chip
struct ContentFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray4))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Simple Content Detection (Performance Optimized)
func isVideoLink(_ link: Link) -> Bool {
    let url = (link.resolved_url ?? link.raw_url ?? "").lowercased()
    let title = link.cleanTitle.lowercased()
    
    // Simple domain checks (no heavy processing)
    let videoDomains = ["youtube.com", "youtu.be", "vimeo.com", "twitch.tv", "tiktok.com"]
    if videoDomains.contains(where: { url.contains($0) }) {
        return true
    }
    
    // Simple keyword checks
    return title.contains("video") || title.contains("watch") || url.contains("/video/")
}

func isAudioLink(_ link: Link) -> Bool {
    let url = (link.resolved_url ?? link.raw_url ?? "").lowercased()
    let title = link.cleanTitle.lowercased()
    
    // Simple domain checks
    let audioDomains = ["spotify.com", "soundcloud.com", "podcasts.apple.com", "podcast"]
    if audioDomains.contains(where: { url.contains($0) }) {
        return true
    }
    
    // Simple keyword checks
    return title.contains("podcast") || title.contains("audio") || title.contains("music")
}

func isArticleLink(_ link: Link) -> Bool {
    // Everything else is an article (default case)
    return !isVideoLink(link) && !isAudioLink(link)
}

// MARK: - Utility Functions
func betterTitle(for link: Link) -> String {
    let cleanTitle = link.cleanTitle
    
    // If we have a meaningful title, use it
    if !cleanTitle.isEmpty && cleanTitle != "Untitled" {
        return cleanTitle
    }
    
    // Fall back to the domain name directly
    return extractDomain(from: link.resolved_url ?? link.raw_url ?? "")
}

func extractDomain(from urlString: String) -> String {
    guard let url = URL(string: urlString),
          let host = url.host else { return "Unknown" }
    
    // Remove www. prefix
    return host.replacingOccurrences(of: "www.", with: "")
}

func formatTimeAgo(from dateString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    guard let date = formatter.date(from: dateString) else {
        return "Unknown"
    }
    
    let now = Date()
    let interval = now.timeIntervalSince(date)
    
    if interval < 60 {
        return "now"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "\(minutes)m ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "\(hours)h ago"
    } else {
        let days = Int(interval / 86400)
        return "\(days)d ago"
    }
}

// MARK: - HTML Entity Decoding
func decodeHtmlEntities(_ text: String) -> String {
    let entities = [
        "&amp;": "&",
        "&lt;": "<", 
        "&gt;": ">",
        "&quot;": "\"",
        "&apos;": "'",
        "&#x27;": "'",
        "&#x2F;": "/",
        "&#39;": "'",
        "&#34;": "\"",
        "&nbsp;": " "
    ]
    
    var decoded = text
    for (entity, replacement) in entities {
        decoded = decoded.replacingOccurrences(of: entity, with: replacement)
    }
    return decoded
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Developer Mode
struct DeveloperModeView: View {
    @ObservedObject var viewModel: LinksViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPerformanceDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Developer Options")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Version Label
                    HStack {
                        Text("Version:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("0.15.0 (Auto-Starred Links)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Performance Summary
                    if let metrics = viewModel.lastPerformanceMetrics {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("⚡ Performance Summary")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Button("Details") {
                                    showingPerformanceDetails.toggle()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Last Load:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.2f", metrics.totalTime))s")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(metrics.totalTime > 3.0 ? .red : metrics.totalTime > 1.5 ? .orange : .green)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Average:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(String(format: "%.2f", viewModel.averageLoadTime))s")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(viewModel.averageLoadTime > 3.0 ? .red : viewModel.averageLoadTime > 1.5 ? .orange : .green)
                                }
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Cache Hit:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(getCacheEfficiency(metrics: metrics))%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(getCacheEfficiency(metrics: metrics) > 70 ? .green : getCacheEfficiency(metrics: metrics) > 40 ? .orange : .red)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    } else {
                        Text("No performance data yet. Load some links first.")
                            .font(.caption)
                    }
                    
                    // Lazy Load Debug Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🔄 Lazy Load Debug")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Last trigger attempt:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.lastLazyLoadTrigger)
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button("🔄 Refresh & Measure") {
                            Task {
                                await viewModel.fetchLinks(reset: true)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                        
                        Button("🧹 Clear Performance Caches") {
                            viewModel.clearPerformanceCaches()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                        
                        Button("🔐 Clear Authentication & Retry") {
                            Task {
                                await viewModel.clearAuthentication()
                                dismiss()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                        
                        Button("🌐 Test Network Connection") {
                            Task {
                                await viewModel.testNetworkConnectivity()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                        
                        Button("⭐ Create Test Starred Link") {
                            Task {
                                await viewModel.createTestStarredLink()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow.opacity(0.1))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                    }
                    
                    if let error = viewModel.error {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPerformanceDetails) {
                PerformanceDetailsView(viewModel: viewModel)
            }
        }
    }
    
    private func getCacheEfficiency(metrics: PerformanceMetrics) -> Int {
        let total = metrics.cacheHits + metrics.cacheMisses
        return total > 0 ? Int((Double(metrics.cacheHits) / Double(total)) * 100) : 0
    }
}

// MARK: - Performance Details View
struct PerformanceDetailsView: View {
    @ObservedObject var viewModel: LinksViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    diagnosticsSection
                    
                    if !viewModel.loadingHistory.isEmpty {
                        performanceTrendSection
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var diagnosticsSection: some View {
        Text(viewModel.getPerformanceDiagnostics())
            .font(.system(.body, design: .monospaced))
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
    
    private var performanceTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📈 Performance Trend")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(Array(viewModel.loadingHistory.reversed().prefix(5).enumerated()), id: \.offset) { index, metrics in
                performanceHistoryRow(index: index, metrics: metrics)
            }
        }
    }
    
    private func performanceHistoryRow(index: Int, metrics: PerformanceMetrics) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Load #\(viewModel.loadingHistory.count - index)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(String(format: "%.2f", metrics.totalTime))s")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("At \(timeString(from: metrics.timestamp))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Cache: \(metrics.cacheHits)/\(metrics.cacheHits + metrics.cacheMisses)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
