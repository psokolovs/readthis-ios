-- Final fix: Drop the ACTUAL interfering triggers and update timestamps
-- Based on the debug results, we know exactly which triggers are active
-- Run this in your Supabase SQL Editor

-- STEP 1: Drop the specific triggers that are interfering
DROP TRIGGER IF EXISTS update_links_updated_at ON links;
DROP TRIGGER IF EXISTS trigger_set_updated_at ON links;

-- Keep the metadata trigger since it's only on INSERT
-- DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;  -- Leave this one alone

-- STEP 2: Now update all records without interference
UPDATE links 
SET updated_at = created_at
WHERE created_at IS NOT NULL 
  AND updated_at IS NOT NULL;

-- STEP 3: Verify the update worked this time
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN updated_at = created_at THEN 1 END) as matching_timestamps,
    COUNT(CASE WHEN updated_at != created_at THEN 1 END) as different_timestamps,
    COUNT(DISTINCT updated_at) as unique_updated_at_values
FROM links 
WHERE created_at IS NOT NULL AND updated_at IS NOT NULL;

-- STEP 4: Sample records to verify success
SELECT 
    id,
    title,
    created_at,
    updated_at,
    CASE 
        WHEN updated_at = created_at THEN 'MATCH ✅'
        ELSE 'DIFFERENT ❌'
    END as timestamp_status
FROM links 
WHERE created_at IS NOT NULL AND updated_at IS NOT NULL
ORDER BY created_at DESC 
LIMIT 10;

-- STEP 5: Recreate only the trigger we want for future records
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    -- For new records, set updated_at = created_at initially
    IF TG_OP = 'INSERT' THEN
        NEW.updated_at = COALESCE(NEW.created_at, NOW());
    -- For updates, set updated_at = NOW()
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger for future records
CREATE TRIGGER trigger_set_updated_at
    BEFORE INSERT OR UPDATE ON links
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- STEP 6: Final verification
SELECT 'SUCCESS: Timestamps should now match created_at dates!' as status; 