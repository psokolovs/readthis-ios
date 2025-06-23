-- Fix the created_at column to have a default timestamp
-- Run this in your Supabase SQL Editor

-- Set default value for created_at column
ALTER TABLE public.links 
ALTER COLUMN created_at SET DEFAULT now();

-- Test that the default is working
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://test-default-timestamp.com', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result
SELECT id, raw_url, created_at 
FROM links 
WHERE raw_url = 'https://test-default-timestamp.com'; 