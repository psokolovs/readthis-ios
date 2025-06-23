-- Simple fix: Set updated_at = created_at for all existing records
-- This makes logical sense - if a record hasn't been updated, updated_at should equal created_at
-- Run this in your Supabase SQL Editor

-- Update all existing records where updated_at != created_at
UPDATE links 
SET updated_at = created_at
WHERE created_at IS NOT NULL 
  AND updated_at IS NOT NULL
  AND updated_at != created_at;

-- For any records where created_at is NULL but updated_at exists, keep updated_at as-is
-- (These are edge cases and shouldn't be common)

-- Verify the update worked
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