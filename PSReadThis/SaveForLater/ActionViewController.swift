//
//  ActionViewController.swift
//  ReadAction
//
//  Created by Pavel S on 6/7/25.
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import Network
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

// Constants for remote operations logging
private let remoteLogKey = "PSReadRemoteOperationsLog"
private let appGroupSuite = "group.com.pavels.psreadthis"

// Custom label with padding
class PaddedLabel: UILabel {
    private let padding = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.left + padding.right,
                      height: size.height + padding.top + padding.bottom)
    }
}

class ActionViewController: UIViewController {
    private let label = PaddedLabel()
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = false

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[SaveForLater] 🚀 EXTENSION STARTED - viewDidLoad called")
        print("[SaveForLater] 🚀 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("[SaveForLater] 🚀 Process name: \(ProcessInfo.processInfo.processName)")
        
        // Minimal UI setup first - show immediately
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.isOpaque = false
        setupLabel()
        showSaving()
        
        // Start background operations asynchronously to not block UI
        Task {
            await initializeAndProcess()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[SaveForLater] 📱 viewDidAppear - UI now visible")
    }
    
    private func initializeAndProcess() async {
        // Setup network monitoring in background
        setupNetworkMonitoring()
        
        // Start processing
        startSaveProcess()
    }

    private func setupLabel() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .bold)  // Larger, bolder font
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        label.layer.cornerRadius = 16  // More rounded corners
        label.layer.masksToBounds = true
        label.text = "📥 Saving..."
        
        // Add padding around text
        label.layer.borderWidth = 2
        label.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
    }

    private func showSaving() {
        DispatchQueue.main.async {
            self.label.text = "📥 Saving..."
            self.label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        }
    }

    private func showSaved(domain: String) {
        DispatchQueue.main.async {
            print("[SaveForLater] 🎯 showSaved called with domain: '\(domain)'")
            self.label.text = "✅ Saved!\nLink from \(domain)"
            self.label.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
            
            // Add haptic feedback for success
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    private func showSavedOffline(domain: String) {
        DispatchQueue.main.async {
            self.label.text = "💾 Saved offline!\nWill sync when online"
            self.label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    private func showError() {
        DispatchQueue.main.async {
            self.label.text = "❌ Failed to save"
            self.label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
            
            // Add haptic feedback for error
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }
    }

    private func startSaveProcess() {
        print("[SaveForLater] 🕵️‍♂️ startSaveProcess")
        if let inputItem = extensionContext?.inputItems.first as? NSExtensionItem {
            print("[SaveForLater] 🕵️‍♂️ inputItem: \(inputItem)")
            if let attachments = inputItem.attachments {
                print("[SaveForLater] 🕵️‍♂️ attachments: \(attachments)")
                for provider in attachments {
                    print("[SaveForLater] 🕵️‍♂️ provider: \(provider)")
                    if provider.hasItemConformingToTypeIdentifier("public.url") {
                        print("[SaveForLater] 🕵️‍♂️ Found public.url provider")
                        provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (urlItem, error) in
                            guard let self = self else { return }
                            print("[SaveForLater] 🕵️‍♂️ URL provider callback - urlItem: \(String(describing: urlItem))")
                            print("[SaveForLater] 🕵️‍♂️ URL provider callback - error: \(String(describing: error))")
                            if let url = urlItem as? URL {
                                print("[SaveForLater] 🕵️‍♂️ Received URL to save: \(url.absoluteString)")
                                Task { await self.saveAndShowResult(url: url.absoluteString) }
                            } else {
                                print("[SaveForLater] 🕵️‍♂️ public.url item was not a URL: \(String(describing: urlItem))")
                                self.tryOtherSources(inputItem: inputItem)
                            }
                        }
                        return
                    }
                }
                print("[SaveForLater] 🕵️‍♂️ No public.url found, trying other sources")
                self.tryOtherSources(inputItem: inputItem)
                return
            } else {
                print("[SaveForLater] 🕵️‍♂️ No attachments in inputItem")
            }
        } else {
            print("[SaveForLater] 🕵️‍♂️ No inputItem or attachments, trying clipboard")
        }
        self.tryClipboard()
    }

    private func tryOtherSources(inputItem: NSExtensionItem) {
        print("[SaveForLater] 🔍 tryOtherSources")
        if let userInfo = inputItem.userInfo {
            for value in userInfo.values {
                if let urlString = value as? String, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                    print("[SaveForLater] 🔗 Found URL in userInfo: \(urlString)")
                    Task { await self.saveAndShowResult(url: url.absoluteString) }
                    return
                }
            }
        }
        if let attachments = inputItem.attachments {
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                    print("[SaveForLater] 📦 Found public.file-url provider")
                    provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] (urlItem, error) in
                        guard let self = self else { return }
                        if let fileUrl = urlItem as? URL {
                            print("[SaveForLater] 📄 Got file URL: \(fileUrl)")
                            self.tryClipboard()
                        } else {
                            print("[SaveForLater] ⚠️ public.file-url item was not a URL")
                            self.tryClipboard()
                        }
                    }
                    return
                }
            }
        }
        print("[SaveForLater] ⚠️ No other sources found, trying clipboard")
        self.tryClipboard()
    }

    private func tryClipboard() {
        print("[SaveForLater] 🔍 tryClipboard")
        if let clipboardString = UIPasteboard.general.string, !clipboardString.isEmpty {
            if let url = URL(string: clipboardString), url.scheme?.hasPrefix("http") == true {
                print("[SaveForLater] 📋 Found valid URL in clipboard: \(clipboardString)")
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Use Clipboard URL?",
                        message: "Do you want to save this URL from your clipboard?\n\n\(clipboardString)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        print("[SaveForLater] ❌ User cancelled clipboard URL usage")
                        self.showError()
                        self.dismissAfterDelay()
                    })
                    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                        print("[SaveForLater] ✅ User confirmed clipboard URL usage")
                        Task { await self.saveAndShowResult(url: url.absoluteString) }
                    })
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                print("[SaveForLater] ⚠️ Clipboard does not contain a valid URL")
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Clipboard Invalid",
                        message: "Clipboard does not contain a valid link. Please copy the PDF URL to the clipboard and try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.showError()
                        self.dismissAfterDelay()
                    })
                    self.present(alert, animated: true, completion: nil)
                }
            }
        } else {
            print("[SaveForLater] ⚠️ Clipboard is empty")
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Clipboard Empty",
                    message: "Clipboard empty, please copy the PDF URL to the clipboard and try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    self.showError()
                    self.dismissAfterDelay()
                })
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    private func dismissAfterDelay(delay: TimeInterval = 2.5) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func saveToQueue(url: String) {
        print("[SaveForLater] 🚀 SAVE TO QUEUE CALLED for URL: \(url)")
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        var queue = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
        
        // Remove any existing entry for this URL to avoid duplicates
        queue.removeAll { entry in
            if let existingUrl = entry["url"] as? String {
                return existingUrl == url
            }
            return false
        }
        
        // Add new entry with intent metadata
        let queueEntry: [String: Any] = [
            "url": url,
            "status": "unread",  // ReadAction intent: save for later
            "timestamp": Date().timeIntervalSince1970,
            "source": "SaveForLater"
        ]
        queue.append(queueEntry)
        
        defaults.set(queue, forKey: "PSReadQueue")
        print("[SaveForLater] 📋 Queue after append: \(queue.count) items")
        
        print("[SaveForLater] 🚀 ABOUT TO CALL appendRemoteOperation")
        // Log the queue operation
        let operation = RemoteOperation(
            timestamp: Date(),
            operation: "ReadAction Queue Add",
            url: url,
            method: "QUEUE_ADD",
            statusCode: nil,
            success: true,
            details: "Added to queue with status: unread, Source: SaveForLater"
        )
        appendRemoteOperation(operation)
        print("[SaveForLater] 🚀 FINISHED calling appendRemoteOperation")
    }

    private func appendRemoteOperation(_ op: RemoteOperation) {
        print("[SaveForLater] 🚀 appendRemoteOperation CALLED")
        print("[SaveForLater] 🚀 Operation: \(op.operation)")
        print("[SaveForLater] 🚀 URL: \(op.url)")
        print("[SaveForLater] 🚀 App Group Suite: \(appGroupSuite)")
        
        let defaults = UserDefaults(suiteName: appGroupSuite) ?? .standard
        print("[SaveForLater] 🚀 UserDefaults suite: \(appGroupSuite)")
        
        var log: [RemoteOperation] = []
        if let data = defaults.data(forKey: remoteLogKey),
           let decoded = try? JSONDecoder().decode([RemoteOperation].self, from: data) {
            log = decoded
            print("[SaveForLater] 🚀 Loaded existing log with \(log.count) entries")
        } else {
            print("[SaveForLater] 🚀 No existing log found, creating new one")
        }
        
        log.append(op)
        print("[SaveForLater] 🚀 Log now has \(log.count) entries")
        
        if log.count > 50 { log.removeFirst(log.count - 50) }
        
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: remoteLogKey)
            print("[SaveForLater] 🚀 Successfully saved log to UserDefaults")
        } else {
            print("[SaveForLater] 🚀 ❌ Failed to encode log")
        }
    }

    // REMOVED: syncQueueToSupabase - too slow for extensions
    // Queue sync now happens in main app only

    private func postLink(rawUrl: String, status: String, token: String) async -> Bool {
        do {
            // Extract user ID from token
            let userId = extractUserIdFromToken(token) ?? "unknown"
            print("[SaveForLater] 📡 Fast UPSERT: \(rawUrl) → \(status)")
            
            // Use Supabase UPSERT - single call handles both insert and update
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            let anonKey = try await TokenManager.shared.getAnonKey()
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 8.0  // Fast timeout for share extensions
            
            let body = [
                "raw_url": rawUrl, 
                "list": "read", 
                "status": status,  // Use status from queue metadata
                "user_id": userId
            ]
            request.httpBody = try JSONEncoder().encode(body)
        
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[SaveForLater] 📡 UPSERT result: \(http.statusCode)")
                
                // Handle both success cases and conflict resolution
                if (200...299).contains(http.statusCode) {
                    return true
                } else if http.statusCode == 409 {
                    // Conflict - do a simple PATCH update
                    print("[SaveForLater] 📡 Conflict detected, doing quick update")
                    return await quickUpdateStatus(rawUrl: rawUrl, status: status, userId: userId, token: token)
                }
                return false
            }
        } catch {
            print("[SaveForLater] 🌐 Network error: \(error)")
        }
        return false
    }
    
    private func quickUpdateStatus(rawUrl: String, status: String, userId: String, token: String) async -> Bool {
        do {
            guard let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedUrl = rawUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return false
            }
            
            let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?user_id=eq.\(encodedUserId)&raw_url=eq.\(encodedUrl)")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            let anonKey = try await TokenManager.shared.getAnonKey()
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 5.0
            
            let body = ["status": status]
            request.httpBody = try JSONEncoder().encode(body)
        
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[SaveForLater] 📡 Quick update: \(http.statusCode)")
                return http.statusCode == 204
            }
            return false
        } catch {
            print("[SaveForLater] 🌐 Quick update error: \(error)")
            return false
        }
    }
    

    
    // Helper function to extract user ID from JWT token
    private func extractUserIdFromToken(_ token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("[SaveForLater] Invalid JWT format")
            return nil
        }
        
        let payload = parts[1]
        // Add padding if needed for base64 decoding
        var base64 = payload
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            print("[SaveForLater] Could not extract user ID from token")
            return nil
        }
        
        print("[SaveForLater] Successfully extracted user ID: \(sub)")
        return sub
    }

    private func saveAndShowResult(url: String) async {
        print("[SaveForLater] 📥 saveAndShowResult: \(url)")
        
        // Always save to queue first (offline-first approach)
        saveToQueue(url: url)
        
        // Extract domain for display with better debugging
        let urlObject = URL(string: url)
        let domain = urlObject?.host ?? "this page"
        print("[SaveForLater] 🔍 URL parsing - Original: '\(url)'")
        print("[SaveForLater] 🔍 URL parsing - URL object: \(urlObject?.absoluteString ?? "nil")")
        print("[SaveForLater] 🔍 URL parsing - Host: '\(domain)'")
        
        // IMMEDIATE SUCCESS FEEDBACK - Don't wait for sync
        DispatchQueue.main.async {
            self.showSaved(domain: domain)
        }
        
        // Quick background sync attempt (max 3 seconds)
        if isNetworkAvailable {
            print("[SaveForLater] 🌐 Online: Quick sync attempt")
            
            let quickSyncTask = Task {
                // Only sync the current URL, not the entire queue
                await quickSyncCurrentURL(url)
                
                // Notify main app of new content
                notifyMainApp()
                
                // Complete after quick sync
                DispatchQueue.main.async {
                    self.dismissAfterDelay(delay: 1.5)
                }
            }
            
            // Timeout for quick sync
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds max
                quickSyncTask.cancel()
                DispatchQueue.main.async {
                    self.dismissAfterDelay(delay: 1.5)
                }
            }
        } else {
            // Offline - dismiss quickly
            print("[SaveForLater] 📱 Offline: Saved to queue")
            DispatchQueue.main.async {
                self.showSavedOffline(domain: domain)
                self.dismissAfterDelay(delay: 1.5)
            }
        }
    }
    
    private func quickSyncCurrentURL(_ url: String) async {
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            _ = await postLink(rawUrl: url, status: "unread", token: token)
            print("[SaveForLater] ✅ Quick sync completed for current URL")
        } catch {
            print("[SaveForLater] ⚠️ Quick sync failed: \(error)")
        }
    }
    
    private func notifyMainApp() {
        // Use UserDefaults to signal main app to refresh
        let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
        defaults.set(Date().timeIntervalSince1970, forKey: "PSReadThisLastUpdate")
        defaults.synchronize()
        print("[SaveForLater] 📢 Notified main app of new content via UserDefaults")
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
            print("[SaveForLater] 🌐 Network status: \(path.status == .satisfied ? "Connected" : "Disconnected")")
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - UI Actions
    
    /// Required method to handle "Done" button taps from storyboard
    @IBAction func done() {
        print("[SaveForLater] 🏁 Done button tapped - completing extension")
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
