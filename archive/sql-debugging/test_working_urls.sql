-- Test with real working URLs to verify metadata extraction
-- Run this in your Supabase SQL Editor

-- Test with Google (simple, reliable)
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://www.google.com', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Test with a news site (should have good title tags)
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://example.com', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Test with GitHub (tech site with clear titles)
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://github.com', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check all the results
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url IN ('https://www.google.com', 'https://example.com', 'https://github.com')
ORDER BY created_at DESC; 