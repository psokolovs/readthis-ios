import UIKit
import UniformTypeIdentifiers
import Network

class ConfirmationViewController: UIViewController {
    var urlToSave: String? // This will be set by the extension context
    private let label = UILabel()
    private var hasCompleted = false
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Minimal UI setup first - show immediately  
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.isOpaque = false
        setupLabel()
        showSaving()
        
        // Force timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, !self.hasCompleted else { return }
            print("[ConfirmationVC] ⏰ TIMEOUT: Force completing after 10s")
            self.forceComplete()
        }
        
        // Start background operations asynchronously to not block UI
        Task {
            await initializeAndProcess()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[ConfirmationVC] 📱 viewDidAppear - UI now visible")
    }
    
    private func initializeAndProcess() async {
        // Setup network monitoring in background
        setupNetworkMonitoring()
        
        // Start processing
        startSaveProcess()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
            print("[ConfirmationVC] 🌐 Network status: \(path.status == .satisfied ? "Connected" : "Disconnected")")
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    private func forceComplete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func setupLabel() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.text = "Saving..."
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func showSaving() {
        label.text = "Saving..."
    }

    private func showSaved(domain: String) {
        label.text = "Link from \(domain) saved!"
    }
    
    private func showSavedOffline(domain: String) {
        label.text = "Link from \(domain) saved for later sync!"
    }

    private func showError() {
        label.text = "Failed to save link."
    }

    private func startSaveProcess() {
        // 1. Try public.url from ALL input items
        if let inputItems = extensionContext?.inputItems as? [NSExtensionItem] {
            for inputItem in inputItems {
                if let attachments = inputItem.attachments {
                    for provider in attachments {
                        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                            print("[ConfirmationVC] 🎯 Found URL in input item, extracting...")
                            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (urlItem, error) in
                                guard let self = self else { return }
                                if let error = error {
                                    print("[ConfirmationVC] ❌ Error loading URL: \(error)")
                                    self.tryOtherSources(inputItem: inputItem)
                                    return
                                }
                                guard let url = urlItem as? URL else {
                                    print("[ConfirmationVC] ⚠️ URL item was not a URL: \(String(describing: urlItem))")
                                    self.tryOtherSources(inputItem: inputItem)
                                    return
                                }
                                print("[ConfirmationVC] ✅ Successfully extracted URL: \(url.absoluteString)")
                                Task { await self.saveAndShowResult(url: url.absoluteString) }
                            }
                            return
                        }
                    }
                }
            }
            // 2. If no public.url found in any item, try other sources with first item
            if let firstItem = inputItems.first {
                self.tryOtherSources(inputItem: firstItem)
            } else {
                self.tryClipboard()
            }
            return
        }
        // 3. If no inputItems, try clipboard
        self.tryClipboard()
    }

    private func tryOtherSources(inputItem: NSExtensionItem) {
        // Try userInfo for a URL string
        if let userInfo = inputItem.userInfo {
            for value in userInfo.values {
                if let urlString = value as? String, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                    Task { await self.saveAndShowResult(url: url.absoluteString) }
                    return
                }
            }
        }
        // Try attachments for a file-url and see if the original URL is embedded
        if let attachments = inputItem.attachments {
                    for provider in attachments {
            // Check for direct URL first (this is what we're getting from PDFs)
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                print("[ConfirmationVC] 📦 Found URL provider (public.url)")
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (urlItem, error) in
                    guard let self = self else { return }
                    if let error = error {
                        print("[ConfirmationVC] ❌ Error loading URL item: \(error)")
                        self.tryClipboard()
                        return
                    }
                    guard let url = urlItem as? URL else {
                        print("[ConfirmationVC] ⚠️ URL item was not a URL: \(String(describing: urlItem))")
                        self.tryClipboard()
                        return
                    }
                    print("[ConfirmationVC] 🔗 Successfully extracted URL from extension context: \(url.absoluteString)")
                    Task {
                        await self.saveAndShowResult(url: url.absoluteString)
                    }
                }
                return
            }
            
            // Fallback: Check for file URLs
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                print("[ConfirmationVC] 📦 Found file URL provider")
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] (urlItem, error) in
                    guard let self = self else { return }
                    if urlItem is URL {
                        // Try to extract the original URL from the file URL (not usually possible)
                        // Fallback: try clipboard
                        self.tryClipboard()
                    } else {
                        self.tryClipboard()
                    }
                }
                return
            }
        }
        }
        // Fallback: try clipboard
        self.tryClipboard()
    }

    private func tryClipboard() {
        // Run comprehensive diagnostics first
        debugPasteboardIssue()
        
        do {
            // Try accessing pasteboard with error handling
            let pasteboard = UIPasteboard.general
            print("[PSReadThis] 📋 Pasteboard name: \(pasteboard.name)")
            print("[PSReadThis] 📋 Attempting to access pasteboard...")
            
            // Test basic properties first
            let hasURLs = pasteboard.hasURLs
            let hasStrings = pasteboard.hasStrings
            let itemCount = pasteboard.numberOfItems
            
            print("[PSReadThis] 📋 hasURLs: \(hasURLs), hasStrings: \(hasStrings), itemCount: \(itemCount)")
            
            // Try getting string with explicit error handling
            var clipboardString: String?
            
            if hasStrings {
                clipboardString = pasteboard.string
                print("[PSReadThis] 📋 String retrieval: \(clipboardString != nil ? "SUCCESS" : "FAILED")")
            }
            
            // Validate URL if we got a string
            if let clipboardString = clipboardString,
               let url = URL(string: clipboardString),
               url.scheme?.hasPrefix("http") == true {
                
                print("[PSReadThis] ✅ Valid URL found in clipboard: \(url.absoluteString)")
                
                // Show confirmation alert before saving
                DispatchQueue.main.async {
                    let alert = UIAlertController(
                        title: "Use Clipboard URL?",
                        message: "Do you want to save this URL from your clipboard?\n\n\(clipboardString)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        self.showError()
                        self.dismissAfterDelay()
                    })
                    alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                        Task { await self.saveAndShowResult(url: url.absoluteString) }
                    })
                    self.present(alert, animated: true, completion: nil)
                }
            } else {
                print("[PSReadThis] ❌ No valid URL found in clipboard")
                DispatchQueue.main.async {
                    self.showError()
                    self.dismissAfterDelay()
                }
            }
            
        } catch let error as NSError {
            print("[PSReadThis] ❌ Pasteboard access error: \(error)")
            print("[PSReadThis] ❌ Error domain: \(error.domain)")
            print("[PSReadThis] ❌ Error code: \(error.code)")
            print("[PSReadThis] ❌ Error userInfo: \(error.userInfo)")
            
            DispatchQueue.main.async {
                self.showError()
                self.dismissAfterDelay()
            }
        }
    }
    
    private func debugPasteboardIssue() {
        // Minimal debugging to prevent memory issues
        print("[ConfirmationVC] 📋 Pasteboard check: hasURLs=\(UIPasteboard.general.hasURLs), hasStrings=\(UIPasteboard.general.hasStrings)")
    }

    private func dismissAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.forceComplete()
        }
    }

    private func saveToQueue(url: String) {
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
            "status": "read",  // PSReadThisShare intent: already read
            "timestamp": Date().timeIntervalSince1970,
            "source": "PSReadThisShare"
        ]
        queue.append(queueEntry)
        
        defaults.set(queue, forKey: "PSReadQueue")
        print("[ConfirmationVC] 📋 Queue after append: \(queue.count) items")
    }

    private func syncQueueToSupabase() async -> [String: Any] {
        do {
            let token = try await TokenManager.shared.getValidAccessToken()
            let defaults = UserDefaults(suiteName: "group.com.pavels.psreadthis") ?? .standard
            var queue = defaults.array(forKey: "PSReadQueue") as? [[String: Any]] ?? []
            print("[ConfirmationVC] 🔄 Syncing read URLs: \(queue)")
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
            print("[ConfirmationVC] ✅ Sent read URLs: \(sent)")
            print("[ConfirmationVC] 📦 Remaining read queue: \(queue)")
            return ["success": !sent.isEmpty, "sent": sent]
        } catch {
            return ["success": false]
        }
    }

    private func postLink(rawUrl: String, status: String, token: String) async -> Bool {
        // Extract user ID from token
        let userId = extractUserIdFromToken(token) ?? "unknown"
        print("[ConfirmationVC] 📡 Fast UPSERT: \(rawUrl) → \(status)")
        
        // Use Supabase UPSERT - single call handles both insert and update
        let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.setValue(TokenManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8.0  // Fast timeout for share extensions
        
        let body = [
            "raw_url": rawUrl, 
            "list": "read", 
            "status": status,  // Use status from queue metadata
            "user_id": userId
        ]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[ConfirmationVC] 📡 UPSERT result: \(http.statusCode)")
                
                // Handle both success cases and conflict resolution
                if (200...299).contains(http.statusCode) {
                    return true
                } else if http.statusCode == 409 {
                    // Conflict - do a simple PATCH update
                    print("[ConfirmationVC] 📡 Conflict detected, doing quick update")
                    return await quickUpdateStatus(rawUrl: rawUrl, status: status, userId: userId, token: token)
                }
                return false
            }
        } catch {
            print("[ConfirmationVC] 🌐 Network error: \(error)")
        }
        return false
    }
    
    private func quickUpdateStatus(rawUrl: String, status: String, userId: String, token: String) async -> Bool {
        guard let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedUrl = rawUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return false
        }
        
        let endpoint = URL(string: "https://ijdtwrsqgbwfgftckywm.supabase.co/rest/v1/links?user_id=eq.\(encodedUserId)&raw_url=eq.\(encodedUrl)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue(TokenManager.shared.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5.0
        
        let body = ["status": status]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[ConfirmationVC] 📡 Quick update: \(http.statusCode)")
                return http.statusCode == 204
            }
        } catch {
            print("[ConfirmationVC] 🌐 Quick update error: \(error)")
        }
        return false
    }
    
    // Helper function to extract user ID from JWT token
    private func extractUserIdFromToken(_ token: String) -> String? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            print("[ConfirmationVC] Invalid JWT format")
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
            print("[ConfirmationVC] Could not extract user ID from token")
            return nil
        }
        
        print("[ConfirmationVC] Successfully extracted user ID: \(sub)")
        return sub
    }



    // Removed excessive debugging functions to prevent memory issues

    private func saveAndShowResult(url: String) async {
        print("[ConfirmationVC] 💾 Save and show result for: \(url)")
        
        // 1. ALWAYS save to queue first (this is instant and reliable)
        saveToQueue(url: url)
        
        // 2. Extract domain for display
        let domain = URL(string: url)?.host ?? "this page"
        
        // 3. IMMEDIATELY show success and dismiss - no waiting!
        DispatchQueue.main.async {
            print("[ConfirmationVC] ✅ Showing immediate success for: \(domain)")
            self.showSaved(domain: domain)
            self.dismissAfterDelay()
        }
        
        // 4. OPTIONAL: Try quick background sync (fire-and-forget)
        if isNetworkAvailable {
            print("[ConfirmationVC] 🚀 Starting background sync...")
            Task.detached {
                do {
                    let result = await self.syncQueueToSupabase()
                    if result["success"] as? Bool == true {
                        print("[ConfirmationVC] ✅ Background sync successful")
                    } else {
                        print("[ConfirmationVC] ⚠️ Background sync failed, will retry later")
                    }
                } catch {
                    print("[ConfirmationVC] ⚠️ Background sync error: \(error)")
                }
            }
        } else {
            print("[ConfirmationVC] 📱 Offline: Will sync when network available")
        }
    }
} 


