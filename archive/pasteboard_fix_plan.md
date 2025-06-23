# PSReadThisShare Pasteboard Fix Implementation Plan

## Root Cause Analysis
**Error**: `PBErrorDomain Code=10/11` - Pasteboard access restricted from certain contexts
**Context**: Share extension called from PDF apps (Files, Safari PDF, etc.)
**Issue**: PDF viewers have restricted pasteboard access for security reasons

## Implementation Strategy

### Phase 1: Enhanced Input Detection
**Problem**: Share extension falls back to clipboard when PDF context doesn't provide URL
**Solution**: Better extraction from extension context before clipboard fallback

```swift
private func startSaveProcess() {
    // 1. Try ALL extension context sources first
    if let inputItem = extensionContext?.inputItems.first as? NSExtensionItem {
        // Try in priority order:
        tryPublicURL(inputItem: inputItem)           // public.url
        tryPublicText(inputItem: inputItem)         // public.plain-text  
        tryWebURL(inputItem: inputItem)             // public.web-url
        tryFileURL(inputItem: inputItem)            // public.file-url
        tryUserInfo(inputItem: inputItem)           // NSExtensionItem.userInfo
        tryAttributedContent(inputItem: inputItem)  // NSAttributedString
        return
    }
    
    // 2. Only use clipboard as LAST resort
    tryClipboardWithUserConsent()
}
```

### Phase 2: Robust Content Extraction
**Enhanced Extraction Methods:**

```swift
private func tryPublicText(inputItem: NSExtensionItem) {
    guard let attachments = inputItem.attachments else { return }
    
    for provider in attachments {
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, error in
                if let text = item as? String {
                    // Extract URLs from plain text
                    self?.extractURLFromText(text)
                } else if let data = item as? Data,
                         let text = String(data: data, encoding: .utf8) {
                    self?.extractURLFromText(text)
                }
            }
            return
        }
    }
    tryNextMethod()
}

private func extractURLFromText(_ text: String) {
    // Use NSDataDetector to find URLs in text
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    let matches = detector?.matches(in: text, range: NSRange(location: 0, length: text.count))
    
    for match in matches ?? [] {
        if let url = match.url {
            Task { await self.saveAndShowResult(url: url.absoluteString) }
            return
        }
    }
    
    // Fallback: Look for anything that looks like a URL
    let urlPattern = #"https?://[^\s<>\"]+|www\.[^\s<>\"]+\.[^\s<>\"]+"#
    if let regex = try? NSRegularExpression(pattern: urlPattern) {
        let range = NSRange(location: 0, length: text.count)
        if let match = regex.firstMatch(in: text, range: range) {
            let urlString = String(text[Range(match.range, in: text)!])
            let finalURL = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
            Task { await self.saveAndShowResult(url: finalURL) }
            return
        }
    }
    
    tryNextMethod()
}
```

### Phase 3: Alternative to Clipboard Access
**PDF-Specific Solutions:**

```swift
private func tryClipboardWithUserConsent() {
    // 1. Check if pasteboard is accessible
    guard UIPasteboard.general.hasURLs || UIPasteboard.general.hasStrings else {
        showManualURLEntry()
        return
    }
    
    // 2. Try to access pasteboard with error handling
    do {
        let pasteboardContent = try accessPasteboardSafely()
        if let url = extractURLFromPasteboardContent(pasteboardContent) {
            showClipboardConfirmation(url: url)
        } else {
            showManualURLEntry()
        }
    } catch {
        print("[PSReadThis] Pasteboard access failed: \(error)")
        showManualURLEntry()
    }
}

private func showManualURLEntry() {
    DispatchQueue.main.async {
        let alert = UIAlertController(
            title: "Share PDF Link",
            message: "To save this PDF link, please paste the URL below:",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "https://example.com/document.pdf"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.showError()
            self.dismissAfterDelay()
        })
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let textField = alert.textFields?.first,
               let urlString = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !urlString.isEmpty,
               let url = URL(string: urlString.hasPrefix("http") ? urlString : "https://\(urlString)") {
                Task { await self.saveAndShowResult(url: url.absoluteString) }
            } else {
                self.showError()
                self.dismissAfterDelay()
            }
        })
        
        self.present(alert, animated: true)
    }
}
```

### Phase 4: Extension Context Debugging
**Diagnostic Tool for Development:**

```swift
private func debugExtensionContext() {
    #if DEBUG
    print("[PSReadThis] 🔍 Extension Context Debug")
    print("Extension Context: \(String(describing: extensionContext))")
    
    if let inputItems = extensionContext?.inputItems {
        print("Input Items Count: \(inputItems.count)")
        
        for (i, item) in inputItems.enumerated() {
            if let nsItem = item as? NSExtensionItem {
                print("Item \(i): \(nsItem)")
                print("  - UserInfo: \(String(describing: nsItem.userInfo))")
                print("  - AttributedTitle: \(String(describing: nsItem.attributedTitle))")
                print("  - AttributedContentText: \(String(describing: nsItem.attributedContentText))")
                
                if let attachments = nsItem.attachments {
                    print("  - Attachments Count: \(attachments.count)")
                    for (j, provider) in attachments.enumerated() {
                        print("    Attachment \(j): \(provider)")
                        print("    - Registered Type Identifiers: \(provider.registeredTypeIdentifiers)")
                    }
                }
            }
        }
    }
    
    // Test pasteboard accessibility
    do {
        let hasURLs = UIPasteboard.general.hasURLs
        let hasStrings = UIPasteboard.general.hasStrings
        print("Pasteboard - URLs: \(hasURLs), Strings: \(hasStrings)")
        
        if hasStrings {
            let string = UIPasteboard.general.string
            print("Pasteboard string: \(String(describing: string))")
        }
    } catch {
        print("Pasteboard access error: \(error)")
    }
    #endif
}
```

## Testing Strategy
1. **Test across PDF contexts**:
   - Safari PDF viewer
   - Files app PDF preview  
   - Third-party PDF apps
   - Mail PDF attachments

2. **Fallback scenarios**:
   - Manual URL entry works
   - User experience is clear
   - Error messages are helpful

3. **Edge cases**:
   - Empty clipboard
   - Invalid URLs in clipboard
   - Network connectivity issues 