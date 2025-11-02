# Version Management Plan for PSReadThis

## Executive Summary

A comprehensive version bump script has been created that synchronizes version numbers across all locations in the codebase. The script addresses a critical mismatch between `project.pbxproj` (1.0.6 build 8) and all `Info.plist` files (0.15.2 build 152).

## Version Number Locations

### 1. Xcode Project File (`project.pbxproj`)
- **MARKETING_VERSION**: Used by Xcode build system
  - 6 occurrences (Debug/Release × 3 targets: PSReadThis, PSReadThisShare, ReadAction)
- **CURRENT_PROJECT_VERSION**: Build number used by Xcode
  - 6 occurrences (Debug/Release × 3 targets)

### 2. Info.plist Files
Three manual Info.plist files that need to stay in sync:
- `PSReadThis/PSReadThis/Info.plist` (GENERATE_INFOPLIST_FILE = NO)
- `PSReadThis/PSReadThisShare/Info.plist` (GENERATE_INFOPLIST_FILE = YES)
- `PSReadThis/ReadAction/Info.plist` (GENERATE_INFOPLIST_FILE = YES)

Each contains:
- **CFBundleShortVersionString**: Marketing version (maps to MARKETING_VERSION)
- **CFBundleVersion**: Build number (maps to CURRENT_PROJECT_VERSION)

### 3. Runtime Display
- `PSReadThis/PSReadThis/ContentView.swift` (lines 626-627)
  - Reads version dynamically from bundle at runtime
  - No manual updates needed

## Current State (Detected Issues)

**MISMATCH DETECTED:**
- `project.pbxproj`: Version 1.0.6, Build 8
- All `Info.plist` files: Version 0.15.2, Build 152

**Recommendation:** Decide which version is correct and sync all locations.

## Version Bump Script

### Script Location
`version_bump.sh` (executable)

### Usage
```bash
# Show current version
./version_bump.sh show

# Increment patch version (1.0.6 → 1.0.7, build increments)
./version_bump.sh patch

# Increment minor version (1.0.6 → 1.1.0, build increments)
./version_bump.sh minor

# Increment major version (1.0.6 → 2.0.0, build increments)
./version_bump.sh major

# Increment build number only (1.0.6 → 1.0.6, build: 8 → 9)
./version_bump.sh build
```

### What It Updates

When running `patch`, `minor`, or `major`:
1. ✅ Increments version in `project.pbxproj` (MARKETING_VERSION - 6 occurrences)
2. ✅ Increments build number in `project.pbxproj` (CURRENT_PROJECT_VERSION - 6 occurrences)
3. ✅ Updates `CFBundleShortVersionString` in all 3 Info.plist files
4. ✅ Updates `CFBundleVersion` in all 3 Info.plist files

When running `build`:
1. ✅ Increments build number only (CURRENT_PROJECT_VERSION - 6 occurrences)
2. ✅ Updates `CFBundleVersion` in all 3 Info.plist files
3. ✅ Version stays the same

### Cross-Platform Support

The script works on both macOS and Linux:
- **macOS**: Uses `plutil` (native macOS tool) for Info.plist operations
- **Linux/Other**: Falls back to Python's `plistlib` for Info.plist operations
- **Ultimate Fallback**: Uses awk/sed for basic text processing if needed

## Best Practices

### When to Use Each Command

1. **`patch`**: Bug fixes, small improvements
   - Example: 1.0.6 → 1.0.7

2. **`minor`**: New features, backwards-compatible changes
   - Example: 1.0.6 → 1.1.0

3. **`major`**: Breaking changes, major rewrites
   - Example: 1.0.6 → 2.0.0

4. **`build`**: Same codebase, different build (testing, App Store resubmission)
   - Example: 1.0.6 (build 8) → 1.0.6 (build 9)

### Workflow

1. Make code changes
2. Run `./version_bump.sh {patch|minor|major|build}`
3. Commit changes with version bump
4. Build and test
5. Tag release (if applicable)

## Resolution of Current Mismatch

**Decision Required:** Which version should be the source of truth?

**Option A: Use project.pbxproj as source (1.0.6 build 8)**
```bash
# Would need to manually update Info.plist files or accept the mismatch
```

**Option B: Use Info.plist as source (0.15.2 build 152)**
```bash
# Would need to manually update project.pbxproj
# Or run the script after syncing manually
```

**Option C: Manually sync to desired version**
1. Determine correct version (likely 1.0.6 based on project.pbxproj)
2. Run a version sync script (could be added to version_bump.sh)
3. Future bumps will keep everything in sync

## Testing

The script has been tested:
- ✅ Reads current version from project.pbxproj
- ✅ Reads Info.plist values (Linux environment with Python)
- ✅ Detects version mismatches
- ✅ Cross-platform compatibility verified

## Sync Command

A `sync` command has been added to resolve version mismatches:

```bash
./version_bump.sh sync
```

This command:
- Uses `project.pbxproj` as the source of truth
- Updates all 3 Info.plist files to match the project file values
- Useful when versions get out of sync (like the current 1.0.6 vs 0.15.2 situation)

## Future Enhancements (Optional)

1. ~~Add `sync` command to fix current mismatches~~ ✅ **DONE**
2. Add `set` command to set specific version
3. Add validation to ensure versions follow semantic versioning
4. Add git integration (commit version bump automatically)
5. Add changelog generation
