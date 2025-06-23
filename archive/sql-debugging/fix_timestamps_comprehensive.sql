-- Comprehensive fix: Set updated_at = created_at for existing records
-- Remove ALL automation temporarily to prevent interference
-- Run this in your Supabase SQL Editor

-- STEP 1: Remove the column default that's causing interference
ALTER TABLE links ALTER COLUMN updated_at DROP DEFAULT;

-- STEP 2: Drop ALL triggers that might be interfering
DROP TRIGGER IF EXISTS trigger_set_updated_at ON links;
DROP TRIGGER IF EXISTS set_updated_at_trigger ON links;  
DROP TRIGGER IF EXISTS update_updated_at_column_trigger ON links;
DROP TRIGGER IF EXISTS handle_updated_at ON links;

-- STEP 3: Now update the records without any interference
UPDATE links 
SET updated_at = created_at
WHERE created_at IS NOT NULL 
  AND updated_at IS NOT NULL;

-- STEP 4: Verify the update worked
SELECT 
    COUNT(*) as total_records,
    COUNT(CASE WHEN updated_at = created_at THEN 1 END) as matching_timestamps,
    COUNT(CASE WHEN updated_at != created_at THEN 1 END) as different_timestamps,
    COUNT(DISTINCT updated_at) as unique_updated_at_values
FROM links 
WHERE created_at IS NOT NULL AND updated_at IS NOT NULL;

-- STEP 5: Sample a few records to verify
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

-- STEP 6: Recreate ONLY the trigger we want (not the column default)
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

-- Create the trigger
CREATE TRIGGER trigger_set_updated_at
    BEFORE INSERT OR UPDATE ON links
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- STEP 7: Final verification
SELECT 'Fix completed! Check the results above.' as status; 