-- Test with real websites that have HTML title tags
-- Run this in your Supabase SQL Editor

-- Test with Wikipedia (guaranteed to have title tags)
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://en.wikipedia.org/wiki/HTTP', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://en.wikipedia.org/wiki/HTTP'
ORDER BY created_at DESC 
LIMIT 1;

-- Test with another simple site
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://www.w3.org/', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check this result
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://www.w3.org/'
ORDER BY created_at DESC 
LIMIT 1; 