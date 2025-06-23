-- Debug: Try updating just ONE record to see what happens
-- Run this in your Supabase SQL Editor

-- First, let's see the current state of one record
SELECT 
    id,
    title,
    created_at,
    updated_at,
    'BEFORE UPDATE' as status
FROM links 
WHERE created_at IS NOT NULL 
  AND updated_at IS NOT NULL
ORDER BY created_at DESC 
LIMIT 1;

-- Try updating just this one record
UPDATE links 
SET updated_at = created_at
WHERE id = (
    SELECT id 
    FROM links 
    WHERE created_at IS NOT NULL 
      AND updated_at IS NOT NULL
    ORDER BY created_at DESC 
    LIMIT 1
);

-- Check what happened
SELECT 
    id,
    title,
    created_at,
    updated_at,
    'AFTER UPDATE' as status
FROM links 
WHERE id = (
    SELECT id 
    FROM links 
    WHERE created_at IS NOT NULL 
      AND updated_at IS NOT NULL
    ORDER BY created_at DESC 
    LIMIT 1
);

-- Let's also check if there are any active triggers right now
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'links';

-- And check the column defaults
SELECT 
    column_name,
    column_default,
    data_type
FROM information_schema.columns 
WHERE table_name = 'links' 
  AND column_name IN ('created_at', 'updated_at'); 