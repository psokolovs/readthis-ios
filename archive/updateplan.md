# ReadThis iOS App Restructuring Plan

## Current State Analysis

### Table Schema
- `id`: UUID primary key
- `user_id`: UUID (foreign key to users)
- `raw_url`: Text (original URL)
- `resolved_url`: Text nullable (processed URL)
- `title`: Text nullable (page title)
- `list`: link_list enum (appears to support "read", "candidate")
- `status`: link_status enum (default "unread", supports "read")
- `device_saved`: Text nullable (device identifier)
- `created_at`: Timestamp (when first saved)

### Current Behavior
- **PSReadThisShare**: Saves links with `list="read"` and `status="unread"`
- **ReadAction**: Presumably also saves links for reading later
- Both extensions currently serve similar "save for later" functionality
- **Issue**: Multiple duplicate rows exist for same URLs per user

### Duplicate Analysis Required
Before implementing the new workflow, we need to:
1. **Count duplicates**: How many duplicate URL groups exist per user?
2. **Analyze patterns**: Are duplicates from same extension or both?
3. **Check status distribution**: Do any duplicates have different status values?
4. **Metadata completeness**: Which duplicates have better title/resolved_url data?

**Sample Query for Analysis**:
```sql
-- Count duplicate groups per user
SELECT 
  user_id,
  raw_url,
  COUNT(*) as duplicate_count,
  ARRAY_AGG(status) as status_values,
  ARRAY_AGG(created_at ORDER BY created_at) as save_times
FROM links 
GROUP BY user_id, raw_url 
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
```

## Proposed New Workflow

### ReadAction Extension (Save for Later)
**Purpose**: Save links to read later (traditional "read later" functionality)

**Behavior**:
- Save with `list="read"` and `status="unread"`
- This represents items in the user's reading queue
- Links remain with `status="unread"` until actually read

### PSReadThisShare Extension (Mark as Read/Completed)
**Purpose**: Save links after they have been read (archive/completion tracking)

**Behavior**: 
1. **Check for existing link**: Query for existing row with same `raw_url` and `user_id`
2. **If exists**: Update `status="read"` (add `read_at` timestamp if we add that column)
3. **If not exists**: Create new row with `list="read"` and `status="read"`

## Implementation Strategy

### Option 1: Update Existing Rows (Recommended)
**Advantages**:
- Maintains single source of truth per URL
- Natural progression: unread → read
- Simpler queries and UI logic
- Leverages existing `status` field design

**Workflow**:
```
ReadAction: URL → { list: "read", status: "unread", created_at: now }
PSReadThisShare: URL → UPDATE status="read" WHERE raw_url=URL AND user_id=USER
```

### Option 2: Multiple Rows per URL
**Advantages**:
- Complete history tracking
- Can track multiple reads/shares of same URL
- No data loss

**Disadvantages**:
- More complex queries
- Potential duplicates in UI
- Storage inefficiency

### Option 3: Separate List Types
**Advantages**:
- Clear separation of concerns
- Could use `list="candidate"` for shared/read items

**Disadvantages**:
- Changes meaning of existing `list` values
- More complex filtering logic

## Recommended Approach: Option 1 with Enhancements

### Core Logic
1. **ReadAction Extension**:
   ```sql
   INSERT INTO links (user_id, raw_url, list, status, created_at)
   VALUES (?, ?, 'read', 'unread', now())
   ON CONFLICT (user_id, raw_url) DO NOTHING
   ```

2. **PSReadThisShare Extension**:
   ```sql
   INSERT INTO links (user_id, raw_url, list, status, created_at)
   VALUES (?, ?, 'read', 'read', now())
   ON CONFLICT (user_id, raw_url) DO UPDATE SET
     status = 'read',
     -- optionally: read_at = now() if we add this column
   ```

### Database Schema Enhancements (Optional)
Consider adding:
- `read_at`: Timestamp nullable (when marked as read)
- `read_count`: Integer (how many times shared/marked as read)
- Composite unique constraint on `(user_id, raw_url)` to prevent true duplicates

### UI/UX Implications

#### Main App Views
1. **"To Read" List**: `list="read" AND status="unread"`
2. **"Completed" List**: `list="read" AND status="read"`
3. **All Saved**: `list="read"` (regardless of status)

#### Extension Behavior
- **ReadAction**: Quick save for later reading
- **PSReadThisShare**: "I've read this, archive it" or "Share after reading"

### Migration Strategy

#### Phase 0: Data Cleanup (Handle Existing Duplicates)
**Problem**: Current table contains multiple rows with same `raw_url` for same `user_id`

**Solution Options**:

1. **Merge Strategy (Recommended)**:
   ```sql
   -- For each user_id + raw_url combination, keep the most recent and merge status
   WITH deduplicated AS (
     SELECT 
       user_id,
       raw_url,
       MAX(created_at) as latest_created_at,
       CASE 
         WHEN COUNT(*) FILTER (WHERE status = 'read') > 0 THEN 'read'
         ELSE 'unread'
       END as final_status,
       -- Keep the most complete record (non-null title, resolved_url, etc.)
       COALESCE(MAX(title) FILTER (WHERE title IS NOT NULL), NULL) as title,
       COALESCE(MAX(resolved_url) FILTER (WHERE resolved_url IS NOT NULL), NULL) as resolved_url
     FROM links
     GROUP BY user_id, raw_url
     HAVING COUNT(*) > 1
   )
   -- Implementation would merge these back
   ```

2. **Keep Latest Strategy**:
   - For each duplicate group, keep the row with latest `created_at`
   - Delete older duplicates
   - Simple but loses potential metadata

3. **Status Priority Strategy**:
   - If any duplicate has `status='read'`, final status is 'read'
   - Otherwise 'unread'
   - Preserve most complete metadata across duplicates

**Recommended Implementation**:
```sql
-- Step 1: Create cleaned table
CREATE TABLE links_clean AS
SELECT DISTINCT ON (user_id, raw_url)
  gen_random_uuid() as id,
  user_id,
  raw_url,
  COALESCE(MAX(resolved_url) FILTER (WHERE resolved_url IS NOT NULL), NULL) as resolved_url,
  COALESCE(MAX(title) FILTER (WHERE title IS NOT NULL), NULL) as title,
  list,  -- Assume all duplicates have same list value
  CASE 
    WHEN COUNT(*) FILTER (WHERE status = 'read') > 0 THEN 'read'
    ELSE 'unread'
  END as status,
  device_saved,
  MIN(created_at) as created_at  -- Keep earliest save date
FROM links
GROUP BY user_id, raw_url, list, device_saved
ORDER BY user_id, raw_url;

-- Step 2: Add constraints to prevent future duplicates
ALTER TABLE links_clean 
ADD CONSTRAINT unique_user_url UNIQUE (user_id, raw_url);

-- Step 3: Replace original table (with backup)
ALTER TABLE links RENAME TO links_backup;
ALTER TABLE links_clean RENAME TO links;
```

#### Phase 1: Update Extension Logic
1. **Add Duplicate Prevention**: Implement UPSERT logic in both extensions
2. **ReadAction**: Use `ON CONFLICT (user_id, raw_url) DO NOTHING` to prevent duplicates
3. **PSReadThisShare**: Use `ON CONFLICT (user_id, raw_url) DO UPDATE SET status='read'`
4. Test with cleaned data

#### Phase 2: Database Schema Updates
1. Add unique constraint: `UNIQUE (user_id, raw_url)`
2. Add any new columns (optional): `read_at`, `read_count`
3. Update indexes for performance

#### Phase 3: UI Updates
1. Add filtering options in main app
2. Show status indicators (unread/read badges)
3. Consider separate tabs or sections
4. Handle edge cases where duplicates might still exist

#### Phase 4: Enhanced Features (Future)
1. Reading analytics
2. Reading time tracking
3. Bulk status updates

## Technical Implementation Notes

### Key Changes Required
1. **PSReadThisShare Extension**:
   - Change from INSERT to UPSERT operation
   - Add logic to detect existing URLs
   - Update status to "read"

2. **ReadAction Extension**:
   - Ensure status is always "unread"
   - Handle duplicate saves gracefully

3. **Main App**:
   - Add status-based filtering
   - Update LinksViewModel to handle status field
   - Add UI indicators for read/unread status

### Error Handling
- Network failures during status updates
- Handling URLs that don't exist when trying to mark as read
- Conflict resolution for simultaneous saves

### Performance Considerations
- Index on `(user_id, raw_url)` for efficient lookups
- Consider pagination impact with status filtering
- Batch operations for multiple status updates

## Success Metrics
- Clear separation of "save for later" vs "mark as read" workflows
- No duplicate URLs per user (unless intentionally allowed)
- Intuitive user experience with proper status progression
- Maintained data integrity during migration

This approach provides the most intuitive user experience while leveraging the existing table design effectively. 