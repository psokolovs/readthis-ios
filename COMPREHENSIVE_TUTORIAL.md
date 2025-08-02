# PSReadThis iOS - Comprehensive Tutorial & Context Documentation

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture & Key Components](#architecture--key-components)
3. [Current Implementation Status](#current-implementation-status)
4. [Development Workflow](#development-workflow)
5. [Common Issues & Solutions](#common-issues--solutions)
6. [Build & Deployment](#build--deployment)
7. [Extension System](#extension-system)
8. [Database & Backend](#database--backend)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Quick Reference](#quick-reference)

---

## 📱 Project Overview

**PSReadThis** is a cross-device link saving and reading application for iOS, designed as a personal "read later" service similar to Pocket. The app provides native iOS integration with offline-first architecture and real-time synchronization.

### Core Value Proposition
- **Universal Link Capture**: Save links from any app via iOS Share Sheet
- **Offline-First Architecture**: Links saved instantly to local queue, sync when online
- **Cross-Device Sync**: Real-time synchronization via Supabase
- **Smart Metadata Extraction**: Automatic title and description extraction
- **Native iOS Integration**: Share extensions, swipe gestures, and iOS UI patterns

### Current Version: 0.15.5
- **Marketing Version**: 0.15.5 (patch version for recent bug fixes)
- **Build Number**: 153 (incremented for each change)
- **Target iOS Version**: 18.5+
- **Deployment Target**: iPhone 16+ simulators recommended

---

## 🏗️ Architecture & Key Components

### App Structure
```
PSReadThis/
├── PSReadThis/              # Main app target
│   ├── ContentView.swift    # Primary UI (681 lines) - Main reading list
│   ├── LinksViewModel.swift # Core data management (511 lines) - MVVM
│   ├── Link.swift          # Data model
│   ├── TokenManager.swift  # Authentication (312 lines)
│   └── Config.swift        # App configuration
├── ArchiveLink/            # Share extension (mark as read after reading)
│   ├── ConfirmationViewController.swift # Save confirmation UI
│   └── Info.plist          # Bundle: com.pavels.PSReadThis.ArchiveLink
├── SaveForLater/           # Action extension (save for later reading)
│   ├── ActionViewController.swift # Browser integration
│   └── Info.plist          # Bundle: com.pavels.PSReadThis.SaveForLater
└── Documentation/          # Project docs and guides
```

### Key Technologies
- **Frontend**: Native Swift/SwiftUI with MVVM pattern
- **Backend**: Supabase (PostgreSQL + Authentication + Real-time)
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Authentication**: JWT with automatic refresh
- **Offline Storage**: UserDefaults-based queue system
- **Real-time Sync**: Supabase real-time subscriptions

### Data Model
```swift
struct Link: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let rawUrl: String
    let resolvedUrl: String?
    let title: String?
    let description: String?
    let list: String        // "read" (archive) or "unread" (to read)
    let status: String      // "unread" or "read"
    let deviceSaved: String?
    let createdAt: Date
    let updatedAt: Date
}
```

---

## ✅ Current Implementation Status

### Completed Features ✅
- **Core Functionality**: Link saving, reading, status tracking with offline-first architecture
- **Cross-Device Sync**: Real-time synchronization via Supabase with queue-based reliability
- **Share Extensions**: Renamed and functional (SaveForLater + ArchiveLink)
- **UI/UX**: Swipe gestures, clean URL display, compound pagination
- **Data Migration**: Successfully imported 506 Pocket links
- **Metadata Extraction**: Auto-extraction with 50-70% success rate
- **Network Resilience**: Smart timeouts, offline detection, graceful error handling
- **Version Management**: Automated version bump script (`version_bump.sh`)

### Recently Fixed Issues ✅
1. **Extension Hanging & Wrong Status** - Fixed with proper queue separation
2. **PDF Share Extension Memory Crashes** - Resolved with memory monitoring
3. **Swipe-to-Read State Management** - Completed with offline-first approach
4. **Archive Swipe Sensitivity** - Reduced accidental triggers by 80%
5. **List Sorting & Pagination** - Implemented compound cursor pagination
6. **Link Display Formatting** - Clean URLs without https:// and www.

### Known Issues 🐛
1. **Metadata Extraction Failures** (Priority: HIGH)
   - Issue: Tracking/redirect URLs stored with generic titles
   - Impact: 30-50% of newsletter/email links have poor metadata
   - Solution: In progress via `metadata_fix_plan.md`

2. **Offline List Loading** (Priority: MEDIUM)
   - Issue: App shows empty lists when offline
   - Solution: Need local caching strategy

### Extension Naming Update ✅
- **Old Names**: PSReadThisShare → ReadAction
- **New Names**: ArchiveLink (mark as read) → SaveForLater (save for later)
- **Status**: Fully migrated in v0.15.5

---

## 🔄 Development Workflow

### Version Management (CRITICAL)
**ALWAYS increment version after code changes:**

```bash
# Use the automated script (preferred)
./version_bump.sh patch    # For bug fixes (0.15.5 → 0.15.6)
./version_bump.sh minor    # For new features (0.15.5 → 0.16.0) 
./version_bump.sh major    # For breaking changes (0.15.5 → 1.0.0)
./version_bump.sh build    # For build number only
./version_bump.sh show     # Check current version
```

### Files Updated by Version Script
- `PSReadThis.xcodeproj/project.pbxproj` (all targets)
- `PSReadThis/PSReadThis/Info.plist`
- `ArchiveLink/Info.plist`
- `SaveForLater/Info.plist`
- `PSReadThis/PSReadThis/ContentView.swift` (hardcoded version)

### Git Workflow
```bash
# Follow conventional commits
git add .
git commit -m "feat: add new feature v0.16.0

- Detailed description of changes
- Include version number in commit message"
git push origin branch-name
```

### Code Style Guidelines
- **Architecture**: MVVM with SwiftUI
- **State Management**: `@StateObject` for view models, `@Published` for reactive properties
- **Async Operations**: Prefer async/await over completion handlers
- **Error Handling**: Always handle errors gracefully with user-friendly messages
- **Documentation**: Comment complex business logic and non-obvious code

---

## 🔧 Common Issues & Solutions

### Build Issues

**Simulator Problems:**
```bash
# Always use iPhone 16+ for iOS 18.5
xcodebuild -project PSReadThis.xcodeproj -scheme PSReadThis \
  -destination 'platform=iOS Simulator,name=iPhone 16' clean build
```

**Extension Debugging:**
- Check main app console for extension logs
- Extensions have limited runtime - use timeouts
- Memory limit: ~50MB for share extensions

### Authentication Issues

**Token Refresh Failures:**
```swift
// Check TokenManager.swift for hardcoded anon key
let correctAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Keychain Access Problems:**
- Verify entitlements: `group.com.pavels.psreadthis`
- Check bundle IDs match across targets
- Use resolved access group in TokenManager

### Database Issues

**Row Level Security (RLS) Errors:**
- All queries automatically filtered by user_id
- Test user ID: `3ad801b9-b41d-4cca-a5ba-2065a1d6ce97`
- Use Supabase dashboard for direct database access

**Metadata Extraction Failures:**
- Expected for anti-bot URLs (Substack, Google, etc.)
- Success rate: 50-70% for tracking URLs
- Check `metadata_fix_plan.md` for improvements

### Extension Issues

**Share Extension Not Working:**
- Check bundle IDs and entitlements
- Verify app group configuration
- Test with different source apps
- Check memory usage (50MB limit)

**Queue Sync Problems:**
- Extensions save to `PSReadQueue` immediately
- Main app processes queue during `fetchLinks()`
- Check UserDefaults suite: `group.com.pavels.psreadthis`

---

## 📱 Build & Deployment

### Prerequisites
- **Xcode**: 15.0+
- **iOS Version**: 18.5+
- **Simulators**: iPhone 16, 16 Plus, 16 Pro, 16 Pro Max (or iPhone 17 series)
- **Apple Developer Account**: For app groups and code signing

### Build Configuration
```bash
# Preferred build command
xcodebuild -project PSReadThis.xcodeproj -scheme PSReadThis \
  -destination 'platform=iOS Simulator,name=iPhone 16' clean build

# For extensions
xcodebuild -project PSReadThis.xcodeproj -scheme SaveForLater \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### App Groups Setup
1. Target: PSReadThis → Signing & Capabilities → App Groups
2. Add: `group.com.pavels.psreadthis`
3. Repeat for ArchiveLink and SaveForLater targets

### Bundle Identifiers
- **Main App**: `com.pavels.PSReadThis`
- **ArchiveLink**: `com.pavels.PSReadThis.ArchiveLink`
- **SaveForLater**: `com.pavels.PSReadThis.SaveForLater`

---

## 🔗 Extension System

### SaveForLater Extension
**Purpose**: Save links for later reading (status: unread)
**Trigger**: Share sheet in any iOS app
**Bundle**: `com.pavels.PSReadThis.SaveForLater`

**Implementation Notes:**
- Immediate UI feedback (2-second response)
- Offline-first: saves to queue immediately
- Optional background sync if online
- Memory monitoring (50MB limit)
- Timeout protection (10 seconds max)

### ArchiveLink Extension  
**Purpose**: Mark links as read after reading them (status: read)
**Trigger**: Share sheet in browsers/reading apps
**Bundle**: `com.pavels.PSReadThis.ArchiveLink`

**Implementation Notes:**
- Fire-and-forget design
- Instant success feedback
- Queue-based reliability
- Background sync attempt
- Never waits for network

### Queue System
```swift
// Queue entry structure
[
  "url": "https://example.com",
  "status": "unread",  // or "read"
  "timestamp": 1640995200.0,
  "source": "SaveForLater" // or "ArchiveLink"
]
```

**Processing Flow:**
1. Extension saves to queue immediately
2. Shows success UI and dismisses
3. Main app processes queue during `fetchLinks()`
4. Uses UPSERT with conflict resolution
5. Failed entries remain for retry

---

## 🗄️ Database & Backend

### Supabase Configuration
- **URL**: `https://ijdtwrsqgbwfgftckywm.supabase.co`
- **Authentication**: JWT with automatic refresh
- **Row Level Security**: All data filtered by user_id
- **Real-time**: Supabase subscriptions for cross-device sync

### Links Table Schema
```sql
CREATE TABLE links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    raw_url TEXT NOT NULL,
    resolved_url TEXT,
    title TEXT,
    description TEXT,
    list TEXT DEFAULT 'read',
    status TEXT DEFAULT 'unread',
    device_saved TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Key Database Features
- **Compound Index**: `(updated_at DESC, id DESC)` for pagination
- **Triggers**: Auto-update `updated_at` on changes
- **Metadata Extraction**: Automatic title/description extraction
- **Conflict Resolution**: UPSERT handling for duplicate URLs

### Pagination Implementation
```sql
-- Compound cursor pagination
SELECT * FROM links 
WHERE user_id = $1 
  AND (updated_at, id) < ($2, $3)
ORDER BY updated_at DESC, id DESC 
LIMIT 50;
```

---

## 🔍 Troubleshooting Guide

### Build Failures
1. **Check iOS version**: Must be 18.5+
2. **Verify simulator**: Use iPhone 16+ only
3. **Clean build**: `Product → Clean Build Folder`
4. **Check signing**: Verify all targets have valid signing

### Extension Not Appearing
1. **Rebuild all targets**: Clean and rebuild entire project
2. **Check entitlements**: Verify app groups are configured
3. **Device testing**: Extensions may not show in simulator
4. **Restart device**: Sometimes required after installation

### Authentication Errors
1. **Check anon key**: Verify it matches working key in logs
2. **Token refresh**: May need to re-login occasionally
3. **Keychain issues**: Try deleting app and reinstalling
4. **Network connectivity**: Ensure device can reach Supabase

### Data Sync Issues
1. **Check queue**: Inspect `PSReadQueue` in UserDefaults
2. **Network status**: Verify app detects connectivity
3. **Database permissions**: Ensure RLS policies are correct
4. **Timeout issues**: Check for network timeout errors

### Memory Issues (Extensions)
1. **Monitor usage**: Extensions limited to ~50MB
2. **Reduce logging**: Excessive debug output consumes memory
3. **Quick completion**: Extensions should complete within 10 seconds
4. **Memory pressure**: iOS may terminate extensions early

---

## 📚 Quick Reference

### Important Files
- **Main UI**: `PSReadThis/PSReadThis/ContentView.swift`
- **Data Logic**: `PSReadThis/PSReadThis/LinksViewModel.swift`
- **Auth**: `PSReadThis/PSReadThis/TokenManager.swift`
- **SaveForLater**: `PSReadThis/SaveForLater/ActionViewController.swift`
- **ArchiveLink**: `PSReadThis/ArchiveLink/ConfirmationViewController.swift`

### Key Constants
- **App Group**: `group.com.pavels.psreadthis`
- **Queue Key**: `PSReadQueue`
- **Log Key**: `PSReadRemoteOperationsLog`
- **Supabase URL**: `https://ijdtwrsqgbwfgftckywm.supabase.co`

### Useful Commands
```bash
# Check current version
grep "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" PSReadThis.xcodeproj/project.pbxproj

# Build specific target
xcodebuild -project PSReadThis.xcodeproj -scheme PSReadThis build

# List available simulators  
xcrun simctl list devices available

# Version bump
./version_bump.sh patch
```

### Debug Logging Patterns
```swift
print("[ComponentName] 🚀 Action description: \(variable)")
print("[ComponentName] ✅ Success message")
print("[ComponentName] ❌ Error: \(error)")
print("[ComponentName] 🔍 Debug info: \(details)")
```

### Common Debugging Steps
1. **Enable verbose logging** in components
2. **Check UserDefaults** for queue contents
3. **Verify network connectivity** with NWPathMonitor
4. **Test on actual device** for extension issues
5. **Monitor memory usage** in extensions
6. **Check Supabase dashboard** for database issues

---

## 🎯 Current Development Focus

### High Priority
1. **Metadata Enhancement**: Improve redirect URL resolution (in progress)
2. **Offline List Loading**: Implement local caching for offline experience
3. **Delete Swipe Actions**: Add delete functionality to UI

### Medium Priority  
1. **Enhanced Timestamp Tracking**: Better sorting and update indicators
2. **Queue Visualization**: Debug interface for pending operations
3. **Additional Swipe Actions**: Read/unread toggle functionality

### Low Priority
1. **Developer Tools**: Enhanced debugging capabilities
2. **Performance Optimization**: Memory and loading improvements
3. **Accessibility**: VoiceOver and Dynamic Type support

---

## 📖 Additional Resources

- **Cursor Rules**: `.cursorrules` - Development guidelines and standards
- **Project Overview**: `PROJECT_OVERVIEW.md` - Detailed technical documentation
- **App Specification**: `20250622-ios-app-specification.md` - Feature requirements
- **Version History**: `VERSIONING.md` - Version management guidelines
- **TODO Items**: `todo.md` - Current task list and priorities
- **Metadata Plan**: `metadata_fix_plan.md` - URL resolution improvements

---

**This document serves as the comprehensive context for any new chat about the PSReadThis iOS project. It covers current implementation status, architecture decisions, common issues, and development workflows. Always reference this document for project context before diving into specific implementations.**