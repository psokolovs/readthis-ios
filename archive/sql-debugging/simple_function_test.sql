-- Simple test to isolate the issue
-- Run this in your Supabase SQL Editor

-- Replace with a minimal function that doesn't use HTTP
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Create minimal function that just sets static values
CREATE OR REPLACE FUNCTION fetch_url_metadata()
RETURNS TRIGGER AS $$
BEGIN
    RAISE LOG 'SIMPLE TEST: Function called for URL: %', NEW.raw_url;
    
    -- Just set static values without any HTTP calls
    NEW.title := 'SIMPLE TEST: Function executed for ' || COALESCE(NEW.raw_url, 'NULL URL');
    NEW.description := 'SIMPLE TEST: No HTTP calls made';
    
    RAISE LOG 'SIMPLE TEST: Returning with title: %', NEW.title;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trg_fetch_metadata
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION fetch_url_metadata();

-- Test with a simple insert
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://test-simple-function.com', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://test-simple-function.com'
ORDER BY created_at DESC 
LIMIT 1; 