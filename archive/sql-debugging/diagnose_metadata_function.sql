-- Diagnose why the metadata function isn't working
-- Run this in your Supabase SQL Editor

-- 1. Check if trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'trg_fetch_metadata' AND event_object_table = 'links';

-- 2. Check if function exists  
SELECT 
    routine_name,
    routine_type,
    external_language
FROM information_schema.routines 
WHERE routine_name = 'fetch_url_metadata';

-- 3. Test the HTTP extension directly
SELECT status, content_type, length(content) as content_length
FROM http_get('https://httpbin.org/html');

-- 4. Manually call the function by inserting a test record and see what happens
-- First, create a simple test function to see if triggers work at all
CREATE OR REPLACE FUNCTION test_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    RAISE LOG 'TEST TRIGGER: Function called for URL: %', NEW.raw_url;
    NEW.title := 'TEST TITLE: ' || COALESCE(NEW.raw_url, 'NO URL');
    NEW.description := 'TEST DESCRIPTION: Function executed successfully';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Create a temporary test trigger
DROP TRIGGER IF EXISTS test_trigger ON links;
CREATE TRIGGER test_trigger
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION test_trigger_function();

-- 6. Test the simple trigger
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://test-trigger-function.com', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- 7. Check if the test trigger worked
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://test-trigger-function.com';

-- 8. Remove the test trigger
DROP TRIGGER IF EXISTS test_trigger ON links; 