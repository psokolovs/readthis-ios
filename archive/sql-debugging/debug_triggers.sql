-- Debug what triggers and automations exist on the links table
-- Run this in your Supabase SQL Editor to see what's interfering

-- Check all triggers on the links table
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'links';

-- Check if there are any column defaults that might be interfering
SELECT 
    column_name,
    column_default,
    data_type
FROM information_schema.columns 
WHERE table_name = 'links' 
  AND column_name IN ('created_at', 'updated_at');

-- Check for any functions that mention 'updated_at'
SELECT 
    proname as function_name,
    prosrc as function_body
FROM pg_proc 
WHERE prosrc ILIKE '%updated_at%'; 