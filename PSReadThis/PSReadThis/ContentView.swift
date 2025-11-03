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
                // Compact Modern Header
                CompactHeader(
                    currentFilter: $viewModel.currentFilter,
                    selectedContentFilter: $selectedContentFilter,
                    onFilterChange: { filter in
                        Task {
                            selectedContentFilter = "all"  // Reset content filter when switching tabs
                            await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
                        }
                    },
                    onContentFilterChange: { contentFilter in
                        Task {
                            await viewModel.fetchLinks(reset: true, contentFilter: contentFilter)
                        }
                    },
                    onSettingsTap: {
                        isDevMode.toggle()
                    }
                )
                
                // Enhanced Links List (Performance Optimized)
                SimpleLinksList(
                    viewModel: viewModel, 
                    selectedURL: $selectedURL,
                    contentFilter: selectedContentFilter
                )
            }
            .navigationBarHidden(true)
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
            .onChange(of: selectedURL) { _, newValue in
                if newValue != nil {
                    showingSafari = true
                }
            }
            .onChange(of: showingSafari) { _, newValue in
                if !newValue {
                    // Reset selectedURL when Safari is dismissed to allow re-tapping the same link
                    selectedURL = nil
                }
            }
        }
        .task {
            // Defer non-critical init to after first frame to avoid cold-launch stalls
            await viewModel.initializeAfterLaunch()
            await viewModel.fetchLinks(reset: true, contentFilter: selectedContentFilter)
        }
    }
}

// MARK: - Compact Modern Header
struct CompactHeader: View {
    @Binding var currentFilter: LinksViewModel.FilterType
    @Binding var selectedContentFilter: String
    let onFilterChange: (LinksViewModel.FilterType) -> Void
    let onContentFilterChange: (String) -> Void
    let onSettingsTap: () -> Void
    
    @State private var showContentFilters = false
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Header Bar
            HStack(spacing: 12) {
                // App Title with Icon
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("PSReadThis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Compact Tab Switcher
                HStack(spacing: 0) {
                    CompactTabButton(
                        title: "To Read",
                        icon: "book",
                        isSelected: currentFilter == .unread,
                        namespace: animation,
                        id: "unread"
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentFilter = .unread
                            showContentFilters = true
                            onFilterChange(.unread)
                        }
                    }
                    
                    CompactTabButton(
                        title: "Archive",
                        icon: "archivebox",
                        isSelected: currentFilter == .read,
                        namespace: animation,
                        id: "read"
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentFilter = .read
                            showContentFilters = true
                            onFilterChange(.read)
                        }
                    }
                }
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Settings Button
                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // Animated Content Filters Row
            if showContentFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ModernFilterChip(
                            title: "All",
                            icon: "square.grid.2x2",
                            isSelected: selectedContentFilter == "all"
                        ) {
                            selectedContentFilter = "all"
                            onContentFilterChange("all")
                        }
                        
                        if currentFilter == .read {
                            ModernFilterChip(
                                title: "Starred",
                                icon: "star.fill",
                                isSelected: selectedContentFilter == "starred",
                                color: .yellow
                            ) {
                                selectedContentFilter = "starred"
                                onContentFilterChange("starred")
                            }
                        }
                        
                        if currentFilter == .unread {
                            ModernFilterChip(
                                title: "Videos",
                                icon: "play.rectangle.fill",
                                isSelected: selectedContentFilter == "video",
                                color: .red
                            ) {
                                selectedContentFilter = "video"
                                onContentFilterChange("video")
                            }
                            
                            ModernFilterChip(
                                title: "Audio",
                                icon: "waveform",
                                isSelected: selectedContentFilter == "audio",
                                color: .purple
                            ) {
                                selectedContentFilter = "audio"
                                onContentFilterChange("audio")
                            }
                            
                            ModernFilterChip(
                                title: "Articles",
                                icon: "doc.text.fill",
                                isSelected: selectedContentFilter == "article",
                                color: .blue
                            ) {
                                selectedContentFilter = "article"
                                onContentFilterChange("article")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            ZStack {
                // Base background
                Color(.systemBackground)
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            Rectangle()
                .fill(Color(.separator).opacity(0.3))
                .frame(height: 1),
            alignment: .bottom
        )
        .onAppear {
            // Show content filters by default
            showContentFilters = true
        }
    }
}

// MARK: - Compact Tab Button
struct CompactTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let id: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                            .matchedGeometryEffect(id: "tab", in: namespace)
                    }
                }
            )
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Modern Filter Chip
struct ModernFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var color: Color = .accentColor
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color : Color(.systemGray5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? color.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Enhanced Links List (Performance Optimized)
struct SimpleLinksList: View {
    @ObservedObject var viewModel: LinksViewModel
    @Binding var selectedURL: String?
    let contentFilter: String
    
    private var filteredLinks: [Link] {
        // Remove or comment out excessive debug prints
        // print("[ContentView] ?? FILTERING WITH: '\(contentFilter)' (total links: \(viewModel.links.count))")
        guard contentFilter != "all" else {
            // print("[ContentView] ?? RETURNING ALL LINKS: \(viewModel.links.count)")
            return viewModel.links
        }
        let filtered = viewModel.links.filter { link in
            switch contentFilter {
            case "starred":
                return link.isStarred
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
        // print("[ContentView] ?? FILTER RESULT: \(filtered.count) links")
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
                        viewModel.lastLazyLoadTrigger = "?? Lazy load triggered for: \(link.cleanTitle.prefix(20))..."
                        Task { await viewModel.fetchLinks(contentFilter: contentFilter) }
                    } else {
                        viewModel.lastLazyLoadTrigger = "? Not triggered - isLast: \(isLastLink), hasMore: \(viewModel.hasMore)"
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
                    
                    // Version Label (dynamic from Info.plist)
                    HStack {
                        Text("Version:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
                        Text(shortVersion.isEmpty ? "Unknown" : "\(shortVersion) (\(buildNumber))")
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
                                Text("? Performance Summary")
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
                    
                    // Queue Diagnostics
                    QueueDiagnosticsView(viewModel: viewModel)
                    
                    // Remote Operations Log
                    RemoteOperationsLogView(viewModel: viewModel)
                    
                    // Lazy Load Debug Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("?? Lazy Load Debug")
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
                        Button("?? Refresh & Measure") {
                            Task {
                                await viewModel.fetchLinks(reset: true)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                        
                        Button("?? Clear Performance Caches") {
                            viewModel.clearPerformanceCaches()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                        
                        Button("?? Clear Authentication & Retry") {
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
                        
                        Button("?? Test Network Connection") {
                            Task {
                                await viewModel.testNetworkConnectivity()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                        
                        Button("?? Clear Remote Operations Log") {
                            viewModel.remoteOperationsLog.removeAll()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .clipShape(Capsule())
                        
                        Button("? Create Test Starred Link") {
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
            Text("?? Performance Trend")
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

// MARK: - Queue Diagnostics View
struct QueueDiagnosticsView: View {
    @ObservedObject var viewModel: LinksViewModel
    @State private var queueContents: [[String: Any]] = []
    @State private var statusQueue: [[String: String]] = []
    @State private var lastSyncAttempt: Date?
    @State private var networkStatus: String = "Unknown"
    @State private var showingQueueDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("?? Queue Diagnostics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Details") {
                    showingQueueDetails.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Queue Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extension Queue:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(queueContents.count) items")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(queueContents.count > 0 ? .orange : .green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status Queue:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(statusQueue.count) items")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(statusQueue.count > 0 ? .orange : .green)
                }
            }
            
            // Network Status
            HStack {
                Text("Network:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(networkStatus)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(networkStatus == "Connected" ? .green : .red)
                
                Spacer()
                
                if let lastSync = lastSyncAttempt {
                    Text("Last sync: \(timeAgoString(from: lastSync))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No sync attempts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick Actions
            HStack(spacing: 8) {
                Button("?? Sync Now") {
                    Task {
                        await forceSyncQueues()
                    }
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
                
                Button("?? Clear Queues") {
                    clearAllQueues()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .clipShape(Capsule())
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showingQueueDetails) {
            QueueDetailsView(queueContents: queueContents, statusQueue: statusQueue)
        }
        .onAppear {
            refreshQueueStatus()
        }
    }
    
    private func refreshQueueStatus() {
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        
        // Get extension queue
        queueContents = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
        
        // Get status queue
        statusQueue = defaults.array(forKey: "PSReadStatusQueue") as? [[String: String]] ?? []
        
        // Check network status
        Task {
            await checkNetworkStatus()
        }
    }
    
    private func checkNetworkStatus() async {
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: "https://www.google.com")!)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    self.networkStatus = "Connected"
                }
            } else {
                DispatchQueue.main.async {
                    self.networkStatus = "Disconnected"
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.networkStatus = "Disconnected"
            }
        }
    }
    
    private func forceSyncQueues() async {
        lastSyncAttempt = Date()
        
        // Force sync both queues
        await viewModel.syncExtensionQueue()
        await viewModel.syncMarkAsReadQueue()
        
        // Refresh status
        refreshQueueStatus()
    }
    
    private func clearAllQueues() {
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        defaults.removeObject(forKey: "PSReadQueue")
        defaults.removeObject(forKey: "PSReadStatusQueue")
        refreshQueueStatus()
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            return "\(Int(interval/60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval/3600))h ago"
        } else {
            return "\(Int(interval/86400))d ago"
        }
    }
}

// MARK: - Queue Details View
struct QueueDetailsView: View {
    let queueContents: [[String: Any]]
    let statusQueue: [[String: String]]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Extension Queue Details
                    if !queueContents.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("?? Extension Queue (\(queueContents.count) items)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(queueContents.enumerated()), id: \.offset) { index, entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let url = entry["url"] as? String {
                                        Text(URL(string: url)?.host ?? url)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    HStack {
                                        if let status = entry["status"] as? String {
                                            Text("Status: \(status)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if let timestamp = entry["timestamp"] as? TimeInterval {
                                            Text(timeString(from: Date(timeIntervalSince1970: timestamp)))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Status Queue Details
                    if !statusQueue.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("?? Status Queue (\(statusQueue.count) items)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(statusQueue.enumerated()), id: \.offset) { index, entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    if let linkId = entry["linkId"] {
                                        Text("Link ID: \(linkId)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    if let status = entry["status"] {
                                        Text("New Status: \(status)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    if queueContents.isEmpty && statusQueue.isEmpty {
                        Text("?? All queues are empty!")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Queue Details")
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
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Remote Operations Log View
struct RemoteOperationsLogView: View {
    @ObservedObject var viewModel: LinksViewModel
    @State private var showingFullLog = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("?? Remote Operations Log")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    showingFullLog.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Recent operations summary
            if viewModel.remoteOperationsLog.isEmpty {
                Text("No remote operations yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.remoteOperationsLog.suffix(3).reversed()) { operation in
                        HStack {
                            Text(operation.timeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            Text(operation.operation)
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemName: operation.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(operation.success ? .green : .red)
                        }
                    }
                    
                    if viewModel.remoteOperationsLog.count > 3 {
                        Text("... and \(viewModel.remoteOperationsLog.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showingFullLog) {
            RemoteOperationsFullLogView(operations: viewModel.remoteOperationsLog)
        }
    }
}

// MARK: - Full Remote Operations Log View
struct RemoteOperationsFullLogView: View {
    let operations: [RemoteOperation]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(operations.reversed()) { operation in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(operation.timeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(operation.method)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                            
                            if let statusCode = operation.statusCode {
                                Text("\(statusCode)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(operation.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                    .foregroundColor(operation.success ? .green : .red)
                                    .clipShape(Capsule())
                            }
                            
                            Image(systemName: operation.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(operation.success ? .green : .red)
                        }
                        
                        Text(operation.operation)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(operation.url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        Text(operation.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Remote Operations")
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
}

#Preview {
    ContentView()
}
