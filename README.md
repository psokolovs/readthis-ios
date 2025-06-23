# PSReadThis iOS

A read-later iOS app with Chrome extension integration for seamless link management across devices.

## Features

- **📱 Native iOS App**: SwiftUI-based interface with intuitive link management
- **🔗 Share Extensions**: Save links from any iOS app using PSReadThisShare and ReadAction extensions
- **📴 Offline Support**: Queue-based system for offline link saving with automatic sync
- **🔄 Real-time Sync**: Supabase backend with JWT authentication
- **⭐ Newsletter System**: Star links for newsletter inclusion (prefix-based system)
- **📊 Status Management**: Track read/unread status with visual indicators
- **🎯 Smart Gestures**: iOS-native swipe interactions for quick actions

## Architecture

### Core Components

- **Main App** (`PSReadThis`): Primary interface for browsing and managing saved links
- **Share Extension** (`PSReadThisShare`): Save links after reading them
- **Action Extension** (`ReadAction`): Save links for later reading
- **Token Manager**: Handles Supabase JWT authentication with automatic refresh
- **Links View Model**: Manages data fetching, pagination, and offline sync

### Database Schema

Links are stored in Supabase with the following structure:
- `id` (UUID): Unique identifier
- `user_id` (UUID): User authentication reference
- `raw_url` (Text): Original URL
- `resolved_url` (Text): Processed/resolved URL
- `title` (Text): Link title (with ⭐ prefix for newsletter inclusion)
- `description` (Text): Meta description
- `list` (Enum): Link category
- `status` (Enum): Read/unread status
- `device_saved` (Text): Source device identifier
- `created_at` (Timestamp): Creation time
- `updated_at` (Timestamp): Last modification

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Supabase account
- Apple Developer account (for App Groups entitlement)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/readthis-ios.git
   cd readthis-ios
   ```

2. Open `PSReadThis.xcodeproj` in Xcode

3. Configure App Groups in project settings:
   - Target: PSReadThis → Signing & Capabilities → App Groups
   - Add: `group.com.pavels.psreadthis`
   - Repeat for PSReadThisShare and ReadAction targets

4. Update Supabase configuration in `TokenManager.swift`:
   ```swift
   private let supabaseURL = URL(string: "YOUR_SUPABASE_URL")!
   ```

5. Build and run the project

## Usage

### Saving Links

**From iOS Apps:**
1. Tap Share button in any app
2. Choose "Save for Later" (ReadAction) or "Archive Link" (PSReadThisShare)
3. Link is saved with appropriate status

**Within the App:**
- **Swipe Right**: Toggle newsletter star
- **Swipe Left**: Mark as read
- **Long Press**: Access full context menu
- **Tap**: Open link in Safari

### Managing Links

- **Filters**: Switch between "To Read" and "Saved" views
- **Search**: Filter by domain (planned feature)
- **Star System**: Mark links for newsletter inclusion by adding ⭐ prefix

## Development

### Project Structure

```
PSReadThis/
├── PSReadThis/           # Main app target
│   ├── ContentView.swift # Primary interface
│   ├── LinksViewModel.swift # Data management
│   ├── Link.swift        # Data model
│   └── TokenManager.swift # Authentication
├── PSReadThisShare/      # Share extension
├── ReadAction/           # Action extension
└── Documentation/        # Project docs and SQL scripts
```

### Key Features in Development

- **Enhanced Link Cards**: Rich display with descriptions and metadata
- **Gesture System**: Advanced swipe interactions for iOS
- **Domain Filtering**: Search and filter by website domain
- **Independent Pagination**: Separate pagination per filter
- **Real-time Updates**: Live sync between devices

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Technical Notes

### Authentication
- Uses Supabase JWT with automatic token refresh
- Keychain storage for secure token persistence
- App Group sharing for extension access

### Offline Support
- Queue-based system for offline actions
- Automatic sync when network becomes available
- Optimistic UI updates for better UX

### Database Integration
- Row Level Security (RLS) for user data isolation
- Compound cursor pagination for efficient loading
- Metadata extraction with fallback handling

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and Supabase
- Inspired by Pocket and similar read-later applications
- Uses SafariServices for in-app web browsing 