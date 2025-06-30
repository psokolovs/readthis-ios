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
                                await viewModel.fetchLinks(reset: true)
                            }
                        }
                        
                        FilterButton(
                            title: "📚 Archive", 
                            isSelected: viewModel.currentFilter == .read,
                            count: nil
                        ) {
                            Task {
                                viewModel.currentFilter = .read
                                await viewModel.fetchLinks(reset: true)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Content Type Filters (Performance Optimized)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ContentFilterChip(
                                title: "📄 All",
                                isSelected: selectedContentFilter == "all"
                            ) {
                                selectedContentFilter = "all"
                            }
                            
                            ContentFilterChip(
                                title: "⭐ Featured",
                                isSelected: selectedContentFilter == "featured"
                            ) {
                                selectedContentFilter = "featured"
                            }
                            
                            ContentFilterChip(
                                title: "🎬 Videos",
                                isSelected: selectedContentFilter == "video"
                            ) {
                                selectedContentFilter = "video"
                            }
                            
                            ContentFilterChip(
                                title: "🎵 Audio",
                                isSelected: selectedContentFilter == "audio"
                            ) {
                                selectedContentFilter = "audio"
                            }
                            
                            ContentFilterChip(
                                title: "📰 Articles",
                                isSelected: selectedContentFilter == "article"
                            ) {
                                selectedContentFilter = "article"
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.trailing, 8) // Extra padding to ensure Articles chip is fully visible
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
        }
        .task {
            // Simple initial load
            await viewModel.fetchLinks(reset: true)
        }
    }
}

// MARK: - Enhanced Links List (Performance Optimized)
struct SimpleLinksList: View {
    @ObservedObject var viewModel: LinksViewModel
    @Binding var selectedURL: String?
    let contentFilter: String
    
    private var filteredLinks: [Link] {
        guard contentFilter != "all" else { return viewModel.links }
        
        return viewModel.links.filter { link in
            switch contentFilter {
            case "featured":
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
                    if link == viewModel.links.last && viewModel.hasMore {
                        Task { await viewModel.fetchLinks() }
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
            await viewModel.fetchLinks(reset: true)
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
        VStack(alignment: .leading, spacing: 8) {
            // Title with star
            HStack(alignment: .top, spacing: 8) {
                if link.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
                
                Text(decodeHtmlEntities(betterTitle(for: link)))
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            // URL/Domain
            Text(extractDomain(from: link.resolved_url ?? link.raw_url ?? ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Time  
            Text(formatTimeAgo(from: link.updated_at ?? link.created_at ?? ""))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .stroke(Color(.systemGray4), lineWidth: 0.5)
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
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
    let url = (link.resolved_url ?? link.raw_url ?? "").lowercased()
    
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
    
    // Fall back to a more user-friendly display
    let domain = extractDomain(from: link.resolved_url ?? link.raw_url ?? "")
    return "Link from \(domain)"
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Developer Options")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Button("Clear Authentication & Retry") {
                    Task {
                        await viewModel.clearAuthentication()
                        dismiss()
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .clipShape(Capsule())
                
                Button("Test Network Connection") {
                    Task {
                        await viewModel.testNetworkConnectivity()
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
                
                if let error = viewModel.error {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Developer")
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
