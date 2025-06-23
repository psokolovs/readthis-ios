-- Test with a fresh URL to avoid duplicate constraint
-- Run this in your Supabase SQL Editor

-- Test with a unique URL that won't conflict
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://httpbin.org/json', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://httpbin.org/json'
ORDER BY created_at DESC 
LIMIT 1;

-- Also test with another simple URL
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://httpbin.org/uuid', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check this result too
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://httpbin.org/uuid'
ORDER BY created_at DESC 
LIMIT 1; 