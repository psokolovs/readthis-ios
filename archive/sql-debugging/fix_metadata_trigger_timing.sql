-- Fix the trigger timing - change from AFTER to BEFORE INSERT
-- This is why the metadata function wasn't working!

-- Drop the existing AFTER INSERT trigger
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;

-- Create the trigger as BEFORE INSERT so it can modify the NEW record
CREATE TRIGGER trg_fetch_metadata
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION fetch_url_metadata();

-- Test it works
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://httpbin.org/html', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://httpbin.org/html'
ORDER BY created_at DESC 
LIMIT 1; 