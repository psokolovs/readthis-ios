-- Check if HTTP extension is installed and enabled
-- Run this in your Supabase SQL Editor

-- Method 1: Check if extension is installed
SELECT 
    extname as extension_name,
    extversion as version,
    nspname as schema_name
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE extname = 'http';

-- Method 2: Check available HTTP functions
SELECT 
    proname as function_name,
    prokind as function_type
FROM pg_proc 
WHERE proname LIKE 'http_%'
ORDER BY proname;

-- Method 3: Test if http_get function works
-- (Comment out if you want to avoid making actual HTTP calls)
-- SELECT status, content_type 
-- FROM http_get('https://httpbin.org/status/200'); 