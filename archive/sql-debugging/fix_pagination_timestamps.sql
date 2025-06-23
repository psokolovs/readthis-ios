-- Fix pagination issue: Diversify updated_at timestamps for keyset pagination
-- Run this in your Supabase SQL Editor

-- STEP 1: Update existing records to have unique updated_at values
-- This spreads existing records' updated_at across time based on their created_at
UPDATE links 
SET updated_at = created_at + INTERVAL '1 second' * (
    -- Add a small random offset based on the record's position
    -- This ensures updated_at is never earlier than created_at
    ROW_NUMBER() OVER (ORDER BY created_at, id) * 0.001
)
WHERE updated_at IS NOT NULL 
  AND created_at IS NOT NULL;

-- STEP 2: For any records where created_at is NULL, use a fallback
UPDATE links 
SET updated_at = NOW() - INTERVAL '1 day' + INTERVAL '1 second' * (
    ROW_NUMBER() OVER (ORDER BY id) * 0.001
)
WHERE updated_at IS NOT NULL 
  AND created_at IS NULL;

-- STEP 3: Update the trigger to set updated_at = created_at for new records initially
-- This ensures new records start with updated_at = created_at, then get updated when modified
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

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS trigger_set_updated_at ON links;

-- Create the trigger for both INSERT and UPDATE
CREATE TRIGGER trigger_set_updated_at
    BEFORE INSERT OR UPDATE ON links
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- STEP 4: Verification queries
-- Check the spread of updated_at values
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT updated_at) as unique_timestamps,
    MIN(updated_at) as earliest_updated,
    MAX(updated_at) as latest_updated,
    AVG(EXTRACT(EPOCH FROM (updated_at - created_at))) as avg_seconds_difference
FROM links 
WHERE updated_at IS NOT NULL AND created_at IS NOT NULL;

-- Check for any duplicate updated_at values (should be 0 or very few)
SELECT 
    updated_at, 
    COUNT(*) as duplicate_count 
FROM links 
WHERE updated_at IS NOT NULL 
GROUP BY updated_at 
HAVING COUNT(*) > 1 
ORDER BY duplicate_count DESC, updated_at DESC
LIMIT 10;

-- Sample the first few records to verify the spread
SELECT 
    id,
    title,
    created_at,
    updated_at,
    EXTRACT(EPOCH FROM (updated_at - created_at)) as seconds_diff
FROM links 
WHERE created_at IS NOT NULL AND updated_at IS NOT NULL
ORDER BY updated_at DESC 
LIMIT 10; 