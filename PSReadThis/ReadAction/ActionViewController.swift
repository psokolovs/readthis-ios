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
        print("[ReadAction] 🚀 viewDidLoad")
        
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
        print("[ReadAction] 📱 viewDidAppear - UI now visible")
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
        print("[ReadAction] 🔍 startSaveProcess")
        if let inputItem = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = inputItem.attachments {
            print("[ReadAction] 📦 Found input item and attachments")
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    print("[ReadAction] 📦 Found public.url provider")
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (urlItem, error) in
                        guard let self = self else { return }
                        if let url = urlItem as? URL {
                            print("[ReadAction] 🔗 Received URL to save: \(url.absoluteString)")
                            Task { await self.saveAndShowResult(url: url.absoluteString) }
                        } else {
                            print("[ReadAction] ⚠️ public.url item was not a URL")
                            self.tryOtherSources(inputItem: inputItem)
                        }
                    }
                    return
                }
            }
            print("[ReadAction] ⚠️ No public.url found, trying other sources")
            self.tryOtherSources(inputItem: inputItem)
            return
        }
        print("[ReadAction] ⚠️ No inputItem or attachments, trying clipboard")
        self.tryClipboard()
    }

    private func tryOtherSources(inputItem: NSExtensionItem) {
        print("[ReadAction] 🔍 tryOtherSources")
        if let userInfo = inputItem.userInfo {
            for value in userInfo.values {
                if let urlString = value as? String, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                    print("[ReadAction] 🔗 Found URL in userInfo: \(urlString)")
                    Task { await self.saveAndShowResult(url: url.absoluteString) }
                    return
                }
            }
        }
        if let attachments = inputItem.attachments {
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                    print("[ReadAction] 📦 Found public.file-url provider")
                    provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] (urlItem, error) in
                        guard let self = self else { return }
                        if let fileUrl = urlItem as? URL {
                            print("[ReadAction] 📄 Got file URL: \(fileUrl)")
                            self.tryClipboard()
                        } else {
                            print("[ReadAction] ⚠️ public.file-url item was not a URL")
                            self.tryClipboard()
                        }
                    }
                    return
                }
            }
        }
        print("[ReadAction] ⚠️ No other sources found, trying clipboard")
        self.tryClipboard()
    }

    private func tryClipboard() {
        print("[ReadAction] 🔍 tryClipboard")
        if let clipboardString = UIPasteboard.general.string, !clipboardString.isEmpty {
            if let url = URL(string: clipboardString), url.scheme?.hasPrefix("http") == true {
                print("[ReadAction] 📋 Found valid URL in clipboard: \(clipboardString)")
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Use Clipboard URL?",
                        message: "Do you want to save this URL from your clipboard?\n\n\(clipboardString)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        print("[ReadAction] ❌ User cancelled clipboard URL usage")
                        self.showError()
                        self.dismissAfterDelay()
                    })
                    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                        print("[ReadAction] ✅ User confirmed clipboard URL usage")
                        Task { await self.saveAndShowResult(url: url.absoluteString) }
                    })
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                print("[ReadAction] ⚠️ Clipboard does not contain a valid URL")
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
            print("[ReadAction] ⚠️ Clipboard is empty")
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
        print("[ReadAction] 📥 saveToQueue: \(url)")
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
            "source": "ReadAction"
        ]
        queue.append(queueEntry)
        
        defaults.set(queue, forKey: "PSReadQueue")
        print("[ReadAction] 📋 Queue after append: \(queue.count) items")
    }

    private func syncQueueToSupabase() async -> [String: Any] {
        print("[ReadAction] 🔄 syncQueueToSupabase")
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            print("[ReadAction] 🔑 Obtained access token")
            let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
            var queue = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
            print("[ReadAction] 🔁 Syncing unread URLs: \(queue)")
            var sent: [String] = []
                         for entry in queue {
                 if let url = entry["url"] as? String,
                    let status = entry["status"] as? String,
                    await postLink(rawUrl: url, status: status, token: token) {
                     sent.append(url)
                 }
             }
            queue.removeAll(where: { sent.contains($0["url"] as? String ?? "") })
            defaults.set(queue, forKey: "PSReadQueue")
            print("[ReadAction] ✅ Sent unread URLs: \(sent)")
            print("[ReadAction] 📦 Remaining unread queue: \(queue.count) items")
            return ["success": !sent.isEmpty, "sent": sent]
        } catch {
            print("[ReadAction] ⚠️ Failed to get valid token or sync: \(error)")
            return ["success": false]
        }
    }

    private func postLink(rawUrl: String, status: String, token: String) async -> Bool {
        do {
            // Extract user ID from token
            let userId = extractUserIdFromToken(token) ?? "unknown"
            print("[ReadAction] 📡 Fast UPSERT: \(rawUrl) → \(status)")
            
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
                print("[ReadAction] 📡 UPSERT result: \(http.statusCode)")
                
                // Handle both success cases and conflict resolution
                if (200...299).contains(http.statusCode) {
                    return true
                } else if http.statusCode == 409 {
                    // Conflict - do a simple PATCH update
                    print("[ReadAction] 📡 Conflict detected, doing quick update")
                    return await quickUpdateStatus(rawUrl: rawUrl, status: status, userId: userId, token: token)
                }
                return false
            }
        } catch {
            print("[ReadAction] 🌐 Network error: \(error)")
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
                print("[ReadAction] 📡 Quick update: \(http.statusCode)")
                return http.statusCode == 204
            }
            return false
        } catch {
            print("[ReadAction] 🌐 Quick update error: \(error)")
            return false
        }
    }
    

    
    // Helper function to extract user ID from JWT token
    private func extractUserIdFromToken(_ token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("[ReadAction] Invalid JWT format")
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
            print("[ReadAction] Could not extract user ID from token")
            return nil
        }
        
        print("[ReadAction] Successfully extracted user ID: \(sub)")
        return sub
    }

    private func saveAndShowResult(url: String) async {
        print("[ReadAction] 📥 saveAndShowResult: \(url)")
        
        // Always save to queue first (offline-first approach)
        saveToQueue(url: url)
        
        // Extract domain for display
        let domain = URL(string: url)?.host ?? "this page"
        
        // GUARANTEED absolute timeout - this cannot be cancelled
        let absoluteTimeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds absolute max
            if !Task.isCancelled {
                print("[ReadAction] 🚨 10s absolute timeout - force completing")
                await MainActor.run {
                    self.showSavedOffline(domain: domain)
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            }
        }
        
        // Set up a timeout for immediate user feedback
        let feedbackTask = Task {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if !Task.isCancelled {
                print("[ReadAction] ⏰ 2s timeout - showing immediate feedback")
                await MainActor.run {
                    if isNetworkAvailable {
                        self.showSavedOffline(domain: domain) // Show offline even if online but slow
                    } else {
                        self.showSavedOffline(domain: domain)
                    }
                    self.dismissAfterDelay()
                }
            }
        }
        
        // Check network availability and attempt sync if online
        if isNetworkAvailable {
            print("[ReadAction] 🌐 Online: Attempting to sync to Supabase")
            let result = await syncQueueToSupabase()
            
            // Cancel timeout if we got a quick response
            feedbackTask.cancel()
            absoluteTimeoutTask.cancel()
            
            if result["success"] as? Bool == true {
                // Successfully synced online
                DispatchQueue.main.async {
                    print("[ReadAction] ✅ Link saved and uploaded for domain: \(domain)")
                    self.showSaved(domain: domain)
                    self.dismissAfterDelay(delay: 3.0)  // Longer display for success
                }
            } else {
                // Online but sync failed - show error
                DispatchQueue.main.async {
                    print("[ReadAction] ❌ Failed to save or upload link")
                    self.showError()
                    self.dismissAfterDelay(delay: 2.0)  // Standard time for errors
                }
            }
        } else {
            // Cancel timeout since we're handling offline immediately
            feedbackTask.cancel()
            absoluteTimeoutTask.cancel()
            
            // Offline - show "saved for later sync" message
            print("[ReadAction] 📱 Offline: Saved to queue for later sync")
            DispatchQueue.main.async {
                self.showSavedOffline(domain: domain)
                self.dismissAfterDelay(delay: 3.0)  // Longer display for offline success
            }
        }
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
            print("[ReadAction] 🌐 Network status: \(path.status == .satisfied ? "Connected" : "Disconnected")")
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - UI Actions
    
    /// Required method to handle "Done" button taps from storyboard
    @IBAction func done() {
        print("[ReadAction] 🏁 Done button tapped - completing extension")
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
