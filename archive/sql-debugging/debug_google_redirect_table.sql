-- Debug script that returns table results instead of RAISE NOTICE
-- Run this in your Supabase SQL Editor

-- Create a temporary function to test the Google URL
CREATE OR REPLACE FUNCTION debug_google_url()
RETURNS TABLE (
    test_step TEXT,
    result_value TEXT,
    status_code INTEGER,
    content_preview TEXT
) AS $$
DECLARE
    test_url TEXT := 'https://www.google.com/aclk?sa=L&ai=DChsSEwjZ7Zfi6uKNAxXuZ0cBHfyIGK8YACICCAEQUxoCcXU&co=1&sph&cce=1&sig=AOD64_0JIRoeH34gTMCL3qXfL4316jgkUQ&q&adurl&ved=2ahUKEwiYxZPi6uKNAxVMLVkFHQnlHQwQ0Qx6BAgNEAE';
    response_record RECORD;
BEGIN
    -- Step 1: Show the URL we're testing
    test_step := 'URL being tested';
    result_value := test_url;
    status_code := NULL;
    content_preview := NULL;
    RETURN NEXT;
    
    -- Step 2: Make the HTTP request
    BEGIN
        SELECT * INTO response_record FROM http_get(test_url);
        
        -- Step 3: Show status
        test_step := 'HTTP Status';
        result_value := response_record.status::TEXT;
        status_code := response_record.status;
        content_preview := NULL;
        RETURN NEXT;
        
        -- Step 4: Show content type
        test_step := 'Content Type';
        result_value := COALESCE(response_record.content_type, 'NULL');
        status_code := response_record.status;
        content_preview := NULL;
        RETURN NEXT;
        
        -- Step 5: Show headers (truncated)
        test_step := 'Headers Preview';
        result_value := COALESCE(left(response_record.headers::TEXT, 200), 'NULL');
        status_code := response_record.status;
        content_preview := NULL;
        RETURN NEXT;
        
        -- Step 6: Show content preview
        test_step := 'Content Preview';
        result_value := CASE 
            WHEN response_record.content IS NOT NULL THEN 'Content exists (' || length(response_record.content) || ' chars)'
            ELSE 'Content is NULL'
        END;
        status_code := response_record.status;
        content_preview := COALESCE(left(response_record.content, 300), 'NULL');
        RETURN NEXT;
        
        -- Step 7: Check for title in content
        IF response_record.content IS NOT NULL THEN
            test_step := 'Title Search';
            result_value := CASE 
                WHEN position('<title' in lower(response_record.content)) > 0 THEN 'Title tag found'
                ELSE 'No title tag found'
            END;
            status_code := response_record.status;
            content_preview := NULL;
            RETURN NEXT;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        test_step := 'ERROR';
        result_value := SQLERRM;
        status_code := NULL;
        content_preview := NULL;
        RETURN NEXT;
    END;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Run the debug function
SELECT * FROM debug_google_url();

-- Clean up
DROP FUNCTION debug_google_url(); 