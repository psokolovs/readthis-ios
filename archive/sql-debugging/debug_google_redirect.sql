-- Debug script to understand Google tracking URL behavior
-- Run this in your Supabase SQL Editor

-- Test the Google tracking URL directly
DO $$
DECLARE
    test_url TEXT := 'https://www.google.com/aclk?sa=L&ai=DChsSEwjZ7Zfi6uKNAxXuZ0cBHfyIGK8YACICCAEQUxoCcXU&co=1&sph&cce=1&sig=AOD64_0JIRoeH34gTMCL3qXfL4316jgkUQ&q&adurl&ved=2ahUKEwiYxZPi6uKNAxVMLVkFHQnlHQwQ0Qx6BAgNEAE';
    response_record RECORD;
BEGIN
    RAISE NOTICE 'Testing URL: %', test_url;
    
    -- Make the HTTP request
    SELECT * INTO response_record FROM http_get(test_url);
    
    RAISE NOTICE 'Status: %', response_record.status;
    RAISE NOTICE 'Content Type: %', response_record.content_type;
    RAISE NOTICE 'Headers: %', response_record.headers;
    
    -- Show first 500 characters of content
    IF response_record.content IS NOT NULL THEN
        RAISE NOTICE 'Content preview: %', left(response_record.content, 500);
    ELSE
        RAISE NOTICE 'Content is NULL';
    END IF;
    
    -- Check if it's a redirect
    IF response_record.status IN (301, 302, 303, 307, 308) THEN
        RAISE NOTICE 'This is a redirect response';
    ELSIF response_record.status = 200 THEN
        RAISE NOTICE 'This is a successful response';
    ELSE
        RAISE NOTICE 'Unexpected status code: %', response_record.status;
    END IF;
END;
$$; 