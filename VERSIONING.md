# Versioning Policy for PSReadThis

- Always increment the version number (CFBundleShortVersionString and CFBundleVersion) in ALL Info.plist files (main app, PSReadThisShare, ReadAction) with every release or significant iteration.
- Use semantic versioning: MAJOR.MINOR.PATCH (e.g., 0.15.1).
- Keep the build number (CFBundleVersion) in sync across all targets.
- Update the version label in the Developer UI if displayed.
- Document version changes in CHANGELOG.md if available. 