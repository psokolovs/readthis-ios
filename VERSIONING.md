# Versioning Policy for PSReadThis

- Always increment the version number (CFBundleShortVersionString and CFBundleVersion) in ALL Info.plist files (main app, PSReadThisShare, ReadAction) with every release or significant iteration.
- Use semantic versioning: MAJOR.MINOR.PATCH (e.g., 0.15.1).
- Keep the build number (CFBundleVersion) in sync across all targets.
- Update the version displayed in the in-app Settings menu to match the app version.
- Document version changes in CHANGELOG.md if available. 