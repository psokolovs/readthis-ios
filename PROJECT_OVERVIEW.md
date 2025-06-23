# PSReadThis - Project Overview & Technical Documentation

## High-Level Overview

**PSReadThis** is a cross-device link saving and reading application for iOS, designed as a personal "read later" service similar to Pocket, Instapaper, or Safari Reading List. The app allows users to save links from anywhere on their device and manage them in a centralized reading queue with offline-first architecture.

### Core Value Proposition
- **Universal Link Capture**: Save links from any app via iOS Share Sheet and Safari Action Extensions
- **Offline-First Architecture**: Links saved instantly to local queue, sync when online
- **Cross-Device Sync**: Real-time synchronization across devices via Supabase
- **Smart Metadata Extraction**: Automatic title, description, and content extraction
- **Swipe Gestures**: Intuitive swipe-to-read workflow with visual feedback
- **PDF-Aware Sharing**: Specialized handling for PDF documents and restricted contexts

## Technical Architecture

### Platform & Stack
- **Frontend**: Native iOS Swift application with SwiftUI
- **Backend**: Supabase (PostgreSQL + Authentication + Real-time sync)
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Architecture Pattern**: MVVM with reactive data binding
- **Deployment**: iOS App Store distribution

### Database Schema

#### Core Tables

##### **links** (Primary Entity)
- `id`: UUID PRIMARY KEY (gen_random_uuid())
- `user_id`: UUID NOT NULL (foreign key to Supabase auth.users)
- `raw_url`: TEXT (original URL as saved by user)
- `resolved_url`: TEXT NULLABLE (final URL after redirect resolution)
- `title`: TEXT NULLABLE (page title, auto-extracted via metadata functions)
- `description`: TEXT NULLABLE (page description/excerpt, auto-extracted)
- `list`: TEXT (category assignment, typically "read") 
- `status`: TEXT DEFAULT 'unread' (values: "unread", "read")
- `device_saved`: TEXT NULLABLE (device identifier where link was saved)
- `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT NOW()
- `updated_at`: TIMESTAMP WITH TIME ZONE (auto-managed via trigger)

##### **Constraints & Indexes**
- **Row Level Security**: `user_id` filtered policies (all operations scoped to authenticated user)
- **Planned**: UNIQUE constraint on `(user_id, raw_url)` to prevent duplicates
- **Indexes**: Compound index on `(updated_at DESC, id DESC)` for pagination
- **Triggers**: 
  - `trigger_set_updated_at`: Auto-updates `updated_at` on INSERT/UPDATE
  - `trg_fetch_metadata`: Auto-extracts metadata on INSERT (calls metadata functions)

##### **Queue Tables** (Offline-First Architecture)
- **PSReadQueue**: Browser localStorage/IndexedDB queue for offline link saves
  - Structure: `{url, status, timestamp, source}` JSON entries
  - Used by: PSReadThisShare and ReadAction extensions
  - Processed by: Main app during `fetchLinks()` operations
  - Conflict handling: UPSERT with `ON CONFLICT DO NOTHING`

##### **Planned Tables** (In Development)
- **url_resolution_queue**: Background metadata processing queue
  - `id`: UUID PRIMARY KEY
  - `link_id`: UUID REFERENCES links(id) ON DELETE CASCADE  
  - `raw_url`: TEXT NOT NULL
  - `attempts`: INTEGER DEFAULT 0
  - `status`: TEXT DEFAULT 'pending' (pending, processing, completed, failed)
  - `resolved_url`: TEXT NULLABLE
  - `resolved_title`: TEXT NULLABLE
  - `resolved_description`: TEXT NULLABLE
  - `error_message`: TEXT NULLABLE
  - `created_at`: TIMESTAMP WITH TIME ZONE DEFAULT NOW()

#### Key Technical Details
- **Database URL**: `https://ijdtwrsqgbwfgftckywm.supabase.co`
- **Automatic Metadata Extraction**: PostgreSQL triggers auto-populate title, description, and other metadata
- **Row Level Security**: All data access filtered by authenticated user_id
- **Real-time Sync**: Supabase real-time subscriptions for cross-device updates

### iOS App Structure

#### Main App (`PSReadThis/`)
- **PSReadThisApp.swift**: Main app entry point
- **ContentView.swift**: Primary UI (22KB, 681 lines) - Main reading list interface
- **LinksViewModel.swift**: Core data management (24KB, 511 lines) - MVVM pattern implementation
- **Link.swift**: Data model definition
- **TokenManager.swift**: Authentication and API client (12KB, 312 lines)

#### Share Extension (`PSReadThisShare/`)
- **ShareViewController.swift**: iOS Share Sheet integration (22KB, 536 lines)
- **ConfirmationViewController.swift**: Save confirmation UI (20KB, 470 lines)
- Allows saving links from any iOS app via standard share functionality

#### Action Extension (`ReadAction/`)
- **ActionViewController.swift**: Browser extension support (19KB, 451 lines)
- **TokenManager.swift**: Shared authentication logic (8.9KB, 213 lines)
- Enables saving from Safari and other browsers

## Design Decisions & Tradeoffs

### Architecture Choices

#### 1. Supabase Backend
**Decision**: Use Supabase instead of custom backend or Firebase
**Rationale**: 
- PostgreSQL provides robust querying and full-text search
- Built-in authentication and real-time subscriptions
- Row Level Security for multi-tenant data isolation
- SQL flexibility for complex metadata processing

**Tradeoffs**:
- ✅ Rapid development, robust security, SQL power
- ❌ Vendor lock-in, some PostgreSQL limitations for web scraping

#### 2. Native iOS vs Cross-Platform
**Decision**: Native Swift/SwiftUI development
**Rationale**:
- Deep iOS integration (Share Sheet, Safari extensions)
- Performance optimization for reading experience
- Native UI/UX patterns

**Tradeoffs**:
- ✅ Best iOS experience, full platform integration
- ❌ Single platform, higher development cost for multi-platform

#### 3. Automatic Metadata Extraction
**Decision**: Server-side metadata extraction using PostgreSQL + HTTP extension
**Rationale**:
- Consistent extraction across all devices
- Reduce client-side processing and battery usage
- Central caching of metadata

**Tradeoffs**:
- ✅ Consistency, reduced client load
- ❌ Complex server-side logic, limited by Supabase environment

### Data Flow Architecture

```
iOS App → Supabase API → PostgreSQL
    ↓
Share Extension → Authentication → Row Level Security
    ↓
Background Triggers → Metadata Extraction → Real-time Updates
```

## Current Implementation Status

### Completed Features ✅
- **Core Functionality**: Link saving, reading, status tracking with offline-first architecture
- **Cross-Device Sync**: Real-time synchronization via Supabase with queue-based reliability  
- **Share Extensions**: PSReadThisShare and ReadAction with memory protection and timeout handling
- **UI/UX**: Swipe gestures, clean URL display, compound pagination, progressive animations
- **Data Migration**: Successfully imported 506 Pocket links with conflict resolution
- **Metadata Extraction**: Auto-extraction with 50-70% success rate on tracking URLs
- **Network Resilience**: Smart timeouts, offline detection, graceful error handling

### Recently Resolved Issues ✅

#### 1. Swipe-to-Read State Management - **COMPLETED**
- **✅ FIXED**: Offline-first swipe with immediate UI updates and queue-based sync
- **Key Improvements**: Enhanced animations, smart filtering, progressive resistance
- **Files Modified**: `ContentView.swift`, `LinksViewModel.swift`

#### 2. PDF Share Extension Issues - **COMPLETED**  
- **✅ FIXED**: Memory crashes, pasteboard restrictions, and timeout issues resolved
- **Key Improvements**: 50MB memory monitoring, enhanced URL extraction, safe completion
- **Files Modified**: `ShareViewController.swift`, `ConfirmationViewController.swift`

### Known Issues & Bugs 🐛

#### 1. Link Metadata Extraction Failures (PRIORITY: HIGH)
- **Issue**: Redirect/tracking links stored with generic titles instead of actual content
- **Root Cause**: Supabase PostgreSQL HTTP extension limitations with complex redirects
- **Impact**: Poor metadata quality for 30-50% of links from newsletters/email tracking
- **Technical Examples**:
  - Newsletter tracking: `marginalrevolution.com/?...&encoded_url=aHR0cHM6...` (base64 encoded)
  - Email tracking: `email.curiouscorner.nl/c/eJyMkLEO4yAQRL8Gd0SwgMEFx...` (encrypted redirects)
  - Apple News: `https://apple.news/A_cevwFegRnWY9Bx6olTlPg` (proprietary format)
  - Mailing lists: `ben-evans.us6.list-manage.com/track/click?u=...` (click tracking)
- **Files Affected**: PostgreSQL metadata extraction functions, trigger system
- **Solution Status**: Comprehensive decoder system planned in `metadata_fix_plan.md`

## Migration History

### Pocket Import (Completed Successfully)
Successfully migrated 506 unread links from comprehensive Pocket export:

#### **Data Analysis**
- **Source Files**: `part_000000.csv` (2.5MB, ~10,005 lines) + `part_000001.csv` (540KB, 1,816 lines)
- **Annotations**: `part_000000.json` (47KB) with highlights/quotes (not imported)
- **CSV Format**: title, url, time_added, tags, status (archive/unread)
- **Total Links**: ~11,821 (506 unread, 11,315 archived)

#### **Migration Process**
1. **Data Extraction**: `extract_unread_links.py` - filtered to unread-only links
2. **Initial API Attempt**: `import_to_psreadthis.py` - failed due to Row Level Security 401 errors
3. **SQL Generation**: `generate_import_sql.py` - created direct INSERT statements  
4. **Conflict Resolution**: Hit duplicate key constraint for "Tower of Hanoi" Wikipedia link
5. **Safe Import**: `generate_import_sql_safe.py` with `ON CONFLICT DO NOTHING` handling
6. **Final Import**: `import_pocket_links_safe.sql` (292KB, 1,559 lines) executed successfully

#### **Results**
- **Before**: ~2 unread links in system
- **After**: 508 unread links (506 imported + 2 existing)
- **Success Rate**: 100% (no import failures with safe conflict handling)
- **Data Quality**: Preserved original timestamps, titles, and URLs from Pocket

#### **Files Created**
- `pocket_unread_links.csv` (155KB) - filtered unread links
- `import_pocket_links_safe.sql` (292KB) - final import statements
- Multiple Python scripts for extraction and SQL generation

## Development Workflow

### Key Development Files

#### **Active Development**
- `metadata_fix_plan.md` (11KB) - Redirect URL decoding and HTTP client enhancements (ACTIVE)
- `todo.md` (13KB) - Current feature status and implementation tracking

#### **Database Schema & Functions**
- `production_metadata_function.sql` (6KB) - Live metadata extraction function
- `fix_existing_links.sql` (9.8KB) - Batch processing for metadata improvements
- `fix_metadata_immediate.sql` (9.8KB) - Current metadata extraction fixes
- `fix_created_at_default.sql` (544B) - Schema default value fix

#### **Archive Organization**
- `archive/` - Completed bug fix plans (swipe, PDF extension, roadmap, updateplan)
- `archive/sql-debugging/` - Timestamp/pagination fixes and metadata function debugging (30+ files)
- `archive/pocket-migration/` - Completed Pocket import (506 links successfully imported)

### Testing Approach
- **Device Testing**: iPhone 14 Pro, iOS 18.5 (memory limits, performance, extension contexts)
- **Database Testing**: Direct SQL via Supabase dashboard, metadata function validation
- **Network Scenarios**: Offline/online transitions, timeout handling, queue processing
- **Edge Cases**: Memory constraints, concurrency, error recovery, RLS verification

## Performance Considerations

### Optimization Strategies
- **Client-Side**: SwiftUI optimizations, lazy loading, pagination
- **Server-Side**: PostgreSQL indexing, trigger optimization
- **Network**: Minimal API calls, efficient real-time subscriptions
- **Caching**: Local Core Data cache for offline functionality

### Scalability Limits
- Supabase free tier limits
- PostgreSQL HTTP extension constraints
- iOS app memory limits for large lists
- Real-time subscription overhead

## Security & Privacy

### Data Protection
- All data encrypted in transit (HTTPS)
- Supabase handles encryption at rest
- Row Level Security prevents data leakage between users
- No analytics or tracking beyond basic app functionality

### Authentication
- Supabase Auth integration
- JWT token management across app and extensions
- Secure token storage in iOS Keychain
- Session management and refresh

## Future Considerations

### Potential Enhancements
1. **Enhanced Metadata**: Full-text article extraction, better tracking URL resolution
2. **Search Functionality**: Full-text search across saved content and metadata
3. **Tagging System**: Advanced organization and filtering (currently basic list categorization)
4. **Reading Statistics**: Progress tracking, reading time analytics, completion rates
5. **Export Options**: Data portability beyond current SQL export capabilities
6. **Content Caching**: Offline article content storage for true offline reading
7. **Batch Operations**: Multi-select for archive, delete, status changes

### Technical Debt & Improvements
1. **Three Critical Bugs**: Swipe refresh, PDF pasteboard access, metadata extraction failures
2. **Testing Coverage**: Need unit tests for ViewModel logic, extension context parsing
3. **Error Handling**: More graceful degradation for network failures, better user messaging
4. **Performance Optimization**: Large list rendering, memory usage in extensions
5. **Code Documentation**: Inline documentation for complex SwiftUI state management
6. **Queue System Enhancement**: Better visibility into pending operations, retry mechanisms
7. **Accessibility**: VoiceOver support for swipe gestures, screen reader compatibility
8. **Architecture**: Consider Core Data caching layer for better offline experience

---

## Quick Start for New Developers

### Prerequisites
- Xcode 15+ with iOS 17 SDK
- Supabase account and project access
- Understanding of SwiftUI and MVVM patterns

### Key Files to Understand
1. `LinksViewModel.swift` - Core business logic
2. `ContentView.swift` - Main UI implementation  
3. `TokenManager.swift` - Authentication handling
4. `ShareViewController.swift` - Share extension logic

### Database Access
- Use Supabase dashboard for direct database queries
- Test user ID: `3ad801b9-b41d-4cca-a5ba-2065a1d6ce97`
- All queries filtered by user_id via RLS

### Common Development Tasks
- **Fix Swipe Bug**: Modify `LinksViewModel.markAsRead()` for proper filter state management
- **Debug PDF Sharing**: Enhance `ShareViewController.swift` extension context parsing
- **Improve Metadata**: Create SQL functions for tracking URL decoding and redirect following
- **Add UI Features**: Focus on SwiftUI animations and gesture handling in `ContentView.swift`
- **Database Changes**: Update schema via Supabase dashboard, maintain RLS policies
- **Test Extensions**: Use iPhone 14 Pro device testing for memory and performance validation

### Current Development Focus
1. **Metadata Enhancement** - Improving redirect URL resolution and tracking link decoding
2. **Offline List Loading** - Implement local caching for offline app experience  
3. **Additional Swipe Actions** - Delete and read/unread toggle functionality

---

This documentation serves as a comprehensive starting point for understanding the PSReadThis project architecture, current state, and development context. The project is in active development with three well-documented critical bugs and extensive groundwork laid for their resolution. 