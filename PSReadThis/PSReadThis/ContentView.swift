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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                FilterSection(viewModel: viewModel)
                
                if isDevMode {
                    DevModeToolbar(viewModel: viewModel)
                }
                
                LinksList(
                    viewModel: viewModel,
                    onTap: openInSafari,
                    onMarkAsRead: markAsRead
                )
            }
            .navigationTitle("Saved Links")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    DevModeToggle(isDevMode: $isDevMode)
                }
            }
            .refreshable {
                await viewModel.fetchLinks(reset: true)
            }
            .onAppear {
                if viewModel.links.isEmpty {
                    Task { 
                        if isDevMode {
                            await viewModel.debugDatabaseContents()
                        }
                        await viewModel.fetchLinks(reset: true) 
                    }
                }
            }
            .alert(item: Binding(
                get: { viewModel.error.map { ErrorWrapper(message: $0) } },
                set: { _ in viewModel.error = nil }
            )) { error in
                Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showingSafari) {
                SafariSheetView(urlString: selectedURL, isPresented: $showingSafari)
            }
        }
    }
    
    private func openInSafari(_ link: Link) {
        // Debug: Print link details to understand the nil URL issue
        print("[ContentView] 🔍 Attempting to open link: id=\(link.id)")
        print("[ContentView] 🔍 raw_url: \(link.raw_url ?? "nil")")
        print("[ContentView] 🔍 resolved_url: \(link.resolved_url ?? "nil")")
        print("[ContentView] 🔍 title: \(link.title ?? "nil")")
        
        // Try resolved_url first, then raw_url as fallback
        guard let urlString = link.resolved_url ?? link.raw_url, !urlString.isEmpty else {
            print("[ContentView] ❌ Invalid URL for link: \(link.id) - both resolved_url and raw_url are nil/empty")
            
            // Better error message with more context
            let errorMessage = """
            No URL found for this link.
            
            Link ID: \(link.id)
            Title: \(link.title ?? "Unknown")
            
            This might be a data loading issue. Try refreshing the list.
            """
            viewModel.error = errorMessage
            return
        }
        
        // Clean and validate URL
        let cleanedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedURL.isEmpty else {
            print("[ContentView] ❌ URL is empty after cleaning: \(link.id)")
            viewModel.error = "URL is empty for this link"
            return
        }
        
        // Ensure URL has a scheme
        let finalURL: String
        if cleanedURL.hasPrefix("http://") || cleanedURL.hasPrefix("https://") {
            finalURL = cleanedURL
        } else {
            finalURL = "https://\(cleanedURL)"
        }
        
        // Validate URL can be created
        guard URL(string: finalURL) != nil else {
            print("[ContentView] ❌ Invalid URL format: \(finalURL)")
            viewModel.error = "Invalid URL format: \(finalURL)"
            return
        }
        
        print("[ContentView] 🌐 Opening URL in Safari: \(finalURL)")
        selectedURL = finalURL
        showingSafari = true
    }
    
    private func markAsRead(_ link: Link) {
        Task {
            await viewModel.markAsRead(link)
        }
    }
}

// MARK: - Filter Section
struct FilterSection: View {
    @ObservedObject var viewModel: LinksViewModel
    
    var body: some View {
        HStack {
            ForEach(LinkFilter.mainFilters, id: \.rawValue) { filter in
                FilterButton(
                    filter: filter,
                    isSelected: viewModel.currentFilter == filter,
                    action: {
                        Task { await viewModel.setFilter(filter) }
                    }
                )
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct FilterButton: View {
    let filter: LinkFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(filter.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Dev Mode Toolbar
struct DevModeToolbar: View {
    @ObservedObject var viewModel: LinksViewModel
    
    var body: some View {
        VStack {
            Divider()
            
            // Filter section for dev mode
            HStack {
                Button("All Saved") {
                    Task { await viewModel.setFilter(.all) }
                }
                .buttonStyle(.bordered)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.currentFilter == .all ? Color.blue.opacity(0.2) : Color.clear)
                )
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            // Debug tools section
            HStack {
                Button("Debug DB") {
                    Task { await viewModel.debugDatabaseContents() }
                }
                .buttonStyle(.bordered)
                
                Button("Refresh") {
                    Task { await viewModel.fetchLinks(reset: true) }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
        }
        .background(Color.gray.opacity(0.05))
    }
}

struct DevModeToggle: View {
    @Binding var isDevMode: Bool
    
    var body: some View {
        Button(action: { isDevMode.toggle() }) {
            Text("Dev Mode")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDevMode ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isDevMode ? .white : .secondary)
        }
    }
}

// MARK: - Links List
struct LinksList: View {
    @ObservedObject var viewModel: LinksViewModel
    let onTap: (Link) -> Void
    let onMarkAsRead: (Link) -> Void
    
    var body: some View {
        List {
            ForEach(viewModel.links) { link in
                LinkCardView(
                    link: link,
                    onTap: { onTap(link) },
                    onAction: { action in
                        Task {
                            await viewModel.handleLinkAction(action, for: link)
                        }
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .onAppear {
                    if link == viewModel.links.last {
                        Task { await viewModel.fetchLinks() }
                    }
                }
            }
            
            if viewModel.isLoading {
                LoadingView()
            }
        }
        .listStyle(PlainListStyle())
    }
}

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

// MARK: - Link Card View
enum LinkAction {
    case toggleStar
    case markRead
    case copyLink
    case resolve
    case delete
}

struct LinkCardView: View {
    let link: Link
    let onTap: () -> Void
    let onAction: (LinkAction) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var swipeProgress: Double = 0
    @State private var swipeDirection: SwipeDirection = .none
    @State private var isProcessingAction = false
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            // Background indicators for swipe actions
            SwipeIndicatorView(
                direction: swipeDirection,
                progress: swipeProgress,
                dragOffset: dragOffset,
                link: link
            )
            
            // Main card content
            EnhancedLinkCardContent(
                link: link,
                isProcessingAction: isProcessingAction
            )
            .offset(x: dragOffset)
            .scaleEffect(isProcessingAction ? 0.95 : 1.0)
            .onTapGesture { onTap() }
            .gesture(createGestureSystem())
            .contextMenu {
                createContextMenu()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: dragOffset)
        .animation(.spring(response: 0.2), value: isProcessingAction)
        .alert("Delete Link", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onAction(.delete)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this link? This action cannot be undone.")
        }
    }
    
    private func createGestureSystem() -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let translation = value.translation.width
                
                // Determine swipe direction and progress
                if abs(translation) > 10 {
                    swipeDirection = translation < 0 ? .left : .right
                    let maxDistance: CGFloat = 120
                    swipeProgress = min(abs(translation) / maxDistance, 1.0)
                    
                    // Apply resistance curve for natural feel
                    let resistanceFactor = 1 - (swipeProgress * 0.2)
                    dragOffset = translation * resistanceFactor
                } else {
                    swipeDirection = .none
                    swipeProgress = 0
                    dragOffset = 0
                }
            }
            .onEnded { value in
                let translation = value.translation.width
                let velocity = abs(value.velocity.width)
                let distance = abs(translation)
                
                // Determine if action should trigger (increased threshold for longer swipes)
                let shouldTrigger = distance > 80 || velocity > 500
                
                if shouldTrigger {
                    let action: LinkAction
                    
                    if translation < 0 {
                        // Left swipe actions
                        action = distance > 130 || velocity > 800 ? .delete : .markRead
                    } else {
                        // Right swipe actions  
                        if link.status == "read" {
                            // Only allow star/copy actions for read items
                            action = distance > 130 || velocity > 800 ? .copyLink : .toggleStar
                        } else {
                            // For unread items, only copy link action
                            action = .copyLink
                        }
                    }
                    
                    performAction(action)
                } else {
                    // Reset position
                    resetSwipeState()
                }
            }
    }
    
    private func performAction(_ action: LinkAction) {
        if action == .delete {
            // Show confirmation for delete
            resetSwipeState()
            showingDeleteConfirmation = true
        } else {
            // Execute other actions immediately
            isProcessingAction = true
            
            // Animate to completion
            withAnimation(.spring(response: 0.3)) {
                dragOffset = swipeDirection == .left ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width
                swipeProgress = 1.0
            }
            
            // Execute action after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onAction(action)
                
                // Reset state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    resetSwipeState()
                }
            }
        }
    }
    
    private func resetSwipeState() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dragOffset = 0
            swipeProgress = 0
            swipeDirection = .none
            isProcessingAction = false
        }
    }
    
    private func createContextMenu() -> some View {
        Group {
            // Only show star option for read items
            if link.status == "read" {
                Button(action: { onAction(.toggleStar) }) {
                    Label(link.isStarred ? "Remove from Newsletter" : "Add to Newsletter", 
                          systemImage: link.isStarred ? "star.slash" : "star")
                }
            }
            
            Button(action: { onAction(.markRead) }) {
                Label(link.status == "read" ? "Mark Unread" : "Mark Read", 
                      systemImage: "circle")
            }
            
            Button(action: { onAction(.copyLink) }) {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
            
            Button(action: { onAction(.resolve) }) {
                Label("Resolve URL", systemImage: "arrow.triangle.2.circlepath")
            }
            
            Divider()
            
            Button(action: { showingDeleteConfirmation = true }) {
                Label("Delete", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
}

enum SwipeDirection {
    case left, right, none
}

struct SwipeIndicatorView: View {
    let direction: SwipeDirection
    let progress: Double
    let dragOffset: CGFloat
    let link: Link
    
    var body: some View {
        if direction != .none && progress > 0.1 {
            HStack {
                if direction == .left {
                    Spacer()
                }
                
                VStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(.white)
                        .scaleEffect(0.8 + progress * 0.4)
                    
                    Text(actionText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .opacity(max(0.3, min(progress * 1.5, 1.0)))
                
                if direction == .right {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [backgroundColor.opacity(0.3), backgroundColor],
                    startPoint: direction == .left ? .trailing : .leading,
                    endPoint: direction == .left ? .leading : .trailing
                )
            )
            .cornerRadius(12)
        }
    }
    
    private var iconName: String {
        switch direction {
        case .left: return progress > 0.8 ? "trash" : "checkmark"
        case .right: 
            if link.status == "read" {
                return progress > 0.8 ? "doc.on.doc" : "star"
            } else {
                return "doc.on.doc"
            }
        case .none: return ""
        }
    }
    
    private var actionText: String {
        switch direction {
        case .left: return progress > 0.8 ? "Delete" : "Mark Read"
        case .right: 
            if link.status == "read" {
                return progress > 0.8 ? "Copy Link" : "Star"
            } else {
                return "Copy Link"
            }
        case .none: return ""
        }
    }
    
    private var backgroundColor: Color {
        switch direction {
        case .left: return progress > 0.8 ? .red : .green
        case .right: 
            if link.status == "read" {
                return progress > 0.8 ? .blue : .yellow
            } else {
                return .blue
            }
        case .none: return .clear
        }
    }
}

struct EnhancedLinkCardContent: View {
    let link: Link
    let isProcessingAction: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with star and title
            HStack(alignment: .top, spacing: 8) {
                if link.isStarred {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                        .padding(.top, 2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(decodeHtmlEntities(link.cleanTitle))
                        .font(.headline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Description (new!)
                    if let description = link.description, !description.isEmpty {
                        Text(decodeHtmlEntities(description))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatTimestamp(link.created_at))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Footer with domain
            HStack {
                Text(link.displayDomain)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                
                Spacer()
                
                if isProcessingAction {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatTimestamp(_ timestamp: String?) -> String {
        guard let timestamp = timestamp else { return "" }
        
        // Try multiple date formats to handle different timestamp formats
        let formatters = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS+00:00",  // Full microseconds
            "yyyy-MM-dd'T'HH:mm:ss.SSS+00:00",     // Milliseconds
            "yyyy-MM-dd'T'HH:mm:ss+00:00",         // Seconds only
            "yyyy-MM-dd'T'HH:mm:ssZ",              // ISO format with Z
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",          // ISO with milliseconds
            "yyyy-MM-dd HH:mm:ss"                  // Simple format
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
            
            if let date = formatter.date(from: timestamp) {
                let now = Date()
                let timeInterval = now.timeIntervalSince(date)
                
                if timeInterval < 60 {
                    return "Just now"
                } else if timeInterval < 3600 {
                    let minutes = Int(timeInterval / 60)
                    return "\(minutes)m ago"
                } else if timeInterval < 86400 {
                    let hours = Int(timeInterval / 3600)
                    return "\(hours)h ago"
                } else if timeInterval < 86400 * 7 {
                    let days = Int(timeInterval / 86400)
                    return "\(days)d ago"
                } else {
                    // For older dates, show actual date
                    let displayFormatter = DateFormatter()
                    displayFormatter.dateStyle = .medium
                    displayFormatter.timeStyle = .none
                    return displayFormatter.string(from: date)
                }
            }
        }
        
        // If all parsing fails, return a cleaned version of the original string
        if timestamp.count > 16 {
            return String(timestamp.prefix(16)) + "..."
        }
        return timestamp
    }
}

// MARK: - HTML Entity Decoding
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
        "&ldquo;": "\u{201C}",
        "&rdquo;": "\u{201D}",
        "&lsquo;": "'",
        "&rsquo;": "'",
        "&#8217;": "'",
        "&#8216;": "'",
        "&#8220;": "\u{201C}",
        "&#8221;": "\u{201D}",
        "&#8211;": "–",
        "&#8212;": "—",
        "&#8230;": "…"
    ]
    
    for (entity, replacement) in entities {
        decoded = decoded.replacingOccurrences(of: entity, with: replacement)
    }
    
    // Handle numeric entities (&#123;)
    let numericPattern = "&#(\\d+);"
    let regex = try? NSRegularExpression(pattern: numericPattern, options: [])
    let range = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
    
    if let regex = regex {
        let matches = regex.matches(in: decoded, options: [], range: range)
        for match in matches.reversed() { // Process in reverse to maintain indices
            if let matchRange = Range(match.range, in: decoded),
               let numberRange = Range(match.range(at: 1), in: decoded) {
                let numberString = String(decoded[numberRange])
                if let number = Int(numberString),
                   let unicodeScalar = UnicodeScalar(number) {
                    decoded.replaceSubrange(matchRange, with: String(Character(unicodeScalar)))
                }
            }
        }
    }
    
    return decoded
}

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        Text(status.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(status == "read" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
            )
            .foregroundColor(status == "read" ? .green : .orange)
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.dismissButtonStyle = .close
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No update needed
    }
}

struct SafariSheetView: View {
    let urlString: String?
    @Binding var isPresented: Bool
    @State private var showError = false
    
    var body: some View {
        Group {
            if let urlString = urlString,
               let url = URL(string: urlString) {
                SafariView(url: url)
                    .onAppear {
                        print("[SafariSheetView] ✅ Successfully created Safari view for: \(urlString)")
                    }
            } else {
                ErrorView(
                    message: "Unable to open URL: \(urlString ?? "Unknown URL")",
                    urlString: urlString,
                    onDismiss: {
                        print("[SafariSheetView] ❌ Failed to create URL from: \(urlString ?? "nil")")
                        isPresented = false
                    }
                )
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    let urlString: String?
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("Unable to Open Link")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    if let urlString = urlString,
                       let url = URL(string: urlString) {
                        Button("Open in System Browser") {
                            UIApplication.shared.open(url)
                            onDismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Button("Close") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Error")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { onDismiss() })
        }
    }
}

struct ErrorWrapper: Identifiable {
    let id = UUID()
    let message: String
}

#Preview {
    ContentView()
}
