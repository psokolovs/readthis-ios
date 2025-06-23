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
                    onMarkAsRead: { onMarkAsRead(link) }
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
struct LinkCardView: View {
    let link: Link
    let onTap: () -> Void
    let onMarkAsRead: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isMarkingAsRead = false
    @State private var swipeProgress: Double = 0
    @State private var hasShownVisualFeedback = false  // Track if user saw visual feedback
    
    private let swipeThreshold: CGFloat = -180  // Increased from -140 (much less sensitive)
    private let maxSwipeDistance: CGFloat = 200  // Increased proportionally
    
    var body: some View {
        ZStack {
            SwipeActionBackground(
                progress: swipeProgress,
                isCompleting: isMarkingAsRead
            )
            
            LinkCardContent(
                link: link,
                isMarkingAsRead: isMarkingAsRead
            )
            .offset(x: offset)
            .onTapGesture { onTap() }
            .gesture(swipeGesture)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)  // Increased from 20 (less accidental triggers)
            .onChanged { value in
                if value.translation.width < 0 {
                    // Progressive resistance as user swipes further
                    let rawProgress = min(abs(value.translation.width) / maxSwipeDistance, 1.0)
                    swipeProgress = rawProgress
                    
                    // Track if user has seen meaningful visual feedback (20% progress)
                    if rawProgress > 0.2 {
                        hasShownVisualFeedback = true
                    }
                    
                    // Apply resistance curve - easier at start, harder at end
                    let resistanceFactor = 1 - (rawProgress * 0.3)
                    offset = value.translation.width * resistanceFactor
                }
            }
            .onEnded { value in
                let swipeDistance = abs(value.translation.width)
                let velocity = abs(value.predictedEndTranslation.width - value.translation.width)
                
                // Trigger mark as read ONLY if user swiped far enough OR fast enough AND saw visual feedback
                if (swipeDistance > abs(swipeThreshold) || velocity > 120) && hasShownVisualFeedback {
                    performMarkAsReadWithAnimation()
                } else {
                    // Bounce back with spring animation
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        offset = 0
                        swipeProgress = 0
                        hasShownVisualFeedback = false  // Reset feedback flag
                    }
                }
            }
    }
    
    private func performMarkAsReadWithAnimation() {
        guard !isMarkingAsRead else { return }
        
        isMarkingAsRead = true
        
        // Animate to completion
        withAnimation(.spring(response: 0.3)) {
            offset = -UIScreen.main.bounds.width
            swipeProgress = 1.0
        }
        
        // Call the action and reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onMarkAsRead()
            
            // Reset for reuse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMarkingAsRead = false
                offset = 0
                swipeProgress = 0
                hasShownVisualFeedback = false  // Reset feedback flag
            }
        }
    }
}

struct SwipeActionBackground: View {
    let progress: Double
    let isCompleting: Bool
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 50, height: 50)
                        .scaleEffect(isCompleting ? 1.2 : (0.8 + progress * 0.4))
                        .animation(.spring(response: 0.3), value: isCompleting)
                    
                    Image(systemName: progress > 0.8 ? "checkmark.circle.fill" : "checkmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .scaleEffect(progress > 0.8 ? 1.2 : 1.0)
                        .animation(.spring(response: 0.2), value: progress > 0.8)
                }
                
                Text("Mark Read")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .opacity(max(0.3, progress))
            }
            .padding(.trailing, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.8), Color.green],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .opacity(max(0.1, progress))
    }
}

struct LinkCardContent: View {
    let link: Link
    let isMarkingAsRead: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                LinkHeader(link: link)
                LinkURL(link: link)
                LinkFooter(link: link, isMarkingAsRead: isMarkingAsRead)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .opacity(0.6)
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
}

struct LinkHeader: View {
    let link: Link
    
    var body: some View {
        HStack {
            Text(link.title ?? link.resolved_url ?? link.raw_url ?? "No Title")
                .font(.headline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if let status = link.status {
                StatusBadge(status: status)
            }
        }
    }
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

struct LinkURL: View {
    let link: Link
    
    var body: some View {
        if let url = link.resolved_url ?? link.raw_url {
            Text(cleanDisplayURL(url))
                .font(.subheadline)
                .foregroundColor(.blue)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    private func cleanDisplayURL(_ url: String) -> String {
        var cleanedURL = url
        
        // Strip protocol prefixes
        if cleanedURL.hasPrefix("https://") {
            cleanedURL = String(cleanedURL.dropFirst(8)) // Remove "https://"
        } else if cleanedURL.hasPrefix("http://") {
            cleanedURL = String(cleanedURL.dropFirst(7))  // Remove "http://"
        }
        
        // Strip "www." prefix if present
        if cleanedURL.hasPrefix("www.") {
            cleanedURL = String(cleanedURL.dropFirst(4)) // Remove "www."
        }
        
        return cleanedURL
    }
}

struct LinkFooter: View {
    let link: Link
    let isMarkingAsRead: Bool
    
    var body: some View {
        HStack {
            Text(formatDate(link.created_at))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if isMarkingAsRead {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Marking as read...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "" }
        
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
            
            if let date = formatter.date(from: dateString) {
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
        if dateString.count > 16 {
            return String(dateString.prefix(16)) + "..."
        }
        return dateString
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
