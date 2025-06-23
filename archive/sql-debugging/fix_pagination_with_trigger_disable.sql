-- Fix pagination by setting updated_at = created_at
-- Temporarily disable the trigger to prevent it from overriding our update
-- Run this in your Supabase SQL Editor

-- STEP 1: Temporarily disable the trigger
DROP TRIGGER IF EXISTS trigger_set_updated_at ON links;

-- STEP 2: Update all existing records where updated_at != created_at
UPDATE links 
SET updated_at = created_at
WHERE created_at IS NOT NULL 
  AND updated_at IS NOT NULL
  AND updated_at != created_at;

-- STEP 3: Recreate the trigger for future records
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

-- Create the trigger for both INSERT and UPDATE
CREATE TRIGGER trigger_set_updated_at
    BEFORE INSERT OR UPDATE ON links
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- STEP 4: Verify the update worked
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN updated_at = created_at THEN 1 END) as matching_timestamps,
    COUNT(CASE WHEN updated_at != created_at THEN 1 END) as different_timestamps,
    COUNT(DISTINCT updated_at) as unique_updated_at_values
FROM links 
WHERE created_at IS NOT NULL AND updated_at IS NOT NULL;

-- Sample a few records to verify
SELECT 
    id,
    title,
    created_at,
    updated_at,
    CASE 
        WHEN updated_at = created_at THEN 'MATCH'
        ELSE 'DIFFERENT'
    END as timestamp_status
FROM links 
WHERE created_at IS NOT NULL AND updated_at IS NOT NULL
ORDER BY created_at DESC 
LIMIT 10; 