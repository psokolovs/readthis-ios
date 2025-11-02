# Version Number Analysis

## Current Version Locations

### 1. Xcode Project File (project.pbxproj)
- **MARKETING_VERSION**: 1.0.6 (6 occurrences: Debug/Release × 3 targets)
  - Lines: 481, 513, 540, 568, 596, 624
- **CURRENT_PROJECT_VERSION**: 8 (6 occurrences: Debug/Release × 3 targets)
  - Lines: 467, 499, 529, 557, 585, 613

### 2. Info.plist Files (manual files)
All three Info.plist files currently have:
- **CFBundleShortVersionString**: 0.15.2
- **CFBundleVersion**: 152

Files:
- `PSReadThis/PSReadThis/Info.plist` (GENERATE_INFOPLIST_FILE = NO - uses this file)
- `PSReadThis/PSReadThisShare/Info.plist` (GENERATE_INFOPLIST_FILE = YES - auto-generates, but we manage this too)
- `PSReadThis/ReadAction/Info.plist` (GENERATE_INFOPLIST_FILE = YES - auto-generates, but we manage this too)

### 3. Display Location
- `PSReadThis/PSReadThis/ContentView.swift` (line 626-627)
  - Reads from Bundle.main.infoDictionary at runtime
  - Uses: CFBundleShortVersionString and CFBundleVersion
  - This is dynamically loaded, so no manual updates needed

## Version Synchronization Issues

**CRITICAL MISMATCH:**
- project.pbxproj: 1.0.6 (build 8)
- All Info.plist files: 0.15.2 (build 152)

## Resolution Strategy

### Best Practice
All version numbers should be kept in sync across:
1. MARKETING_VERSION in project.pbxproj (maps to CFBundleShortVersionString)
2. CURRENT_PROJECT_VERSION in project.pbxproj (maps to CFBundleVersion)
3. CFBundleShortVersionString in all Info.plist files
4. CFBundleVersion in all Info.plist files

### Why Keep Them All in Sync?
- Even though GENERATE_INFOPLIST_FILE = YES for extensions, having explicit values ensures consistency
- The main app (PSReadThis) has GENERATE_INFOPLIST_FILE = NO, so it directly uses Info.plist values
- Xcode builds may merge or override values, but having explicit values in all locations prevents confusion
- The display in ContentView.swift reads from the bundle at runtime, which will use whatever is in the final built app

### Version Bump Script Responsibilities
The script will:
1. Update MARKETING_VERSION in project.pbxproj (all 6 occurrences)
2. Update CURRENT_PROJECT_VERSION in project.pbxproj (all 6 occurrences)  
3. Update CFBundleShortVersionString in all 3 Info.plist files
4. Update CFBundleVersion in all 3 Info.plist files
5. Support: patch, minor, major, and build-only increments
6. Show current version with `show` command

## Version Format

- **Marketing Version**: Semantic versioning (MAJOR.MINOR.PATCH), e.g., 1.0.6
- **Build Number**: Integer that increments with each build, e.g., 8
