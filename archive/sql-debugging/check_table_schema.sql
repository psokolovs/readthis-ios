-- Check table schema and defaults
-- Run this in your Supabase SQL Editor

-- 1. Check the table structure and defaults
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'links' 
ORDER BY ordinal_position;

-- 2. If created_at doesn't have a default, add one
-- (Only run this if the above query shows created_at has no default)
-- ALTER TABLE links ALTER COLUMN created_at SET DEFAULT now();

-- 3. Test a simple insert to see what happens
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://example.com/test-' || extract(epoch from now()), 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- 4. Check what was actually inserted
SELECT id, raw_url, title, description, created_at, status, list
FROM links 
WHERE raw_url LIKE 'https://example.com/test-%'
ORDER BY created_at DESC 
LIMIT 3; 