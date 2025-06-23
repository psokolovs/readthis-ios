-- Debug the metadata function
-- Run these queries in your Supabase SQL Editor to check if it's working

-- 1. Check if the trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'trg_fetch_metadata';

-- 2. Check if the function exists
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'fetch_url_metadata';

-- 3. Test the function manually by inserting a test record
-- (This will help us see if the function runs and what errors occur)
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://httpbin.org/html', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- 4. Check the most recent logs (this may not work in Supabase dashboard)
-- But you can see function output in the SQL editor
SELECT 'Check the SQL editor output for RAISE LOG messages from the function';

-- 5. Check what was actually inserted
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://httpbin.org/html' 
ORDER BY created_at DESC 
LIMIT 1; 