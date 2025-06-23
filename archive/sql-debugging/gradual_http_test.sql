-- Gradual HTTP test to find exactly where the issue occurs
-- Run this in your Supabase SQL Editor

-- Replace with a function that tests HTTP step by step
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Create function that tests HTTP calls with extensive error handling
CREATE OR REPLACE FUNCTION fetch_url_metadata()
RETURNS TRIGGER AS $$
DECLARE
    response_record RECORD;
    http_status INTEGER;
    http_content TEXT;
    clean_url TEXT;
BEGIN
    RAISE LOG 'HTTP TEST: Starting function for URL: %', NEW.raw_url;
    
    -- Set default values first
    NEW.title := 'HTTP TEST: Starting...';
    NEW.description := 'HTTP TEST: Initial state';
    
    -- Check if raw_url is NULL or empty
    IF NEW.raw_url IS NULL OR trim(NEW.raw_url) = '' THEN
        NEW.title := 'HTTP TEST: NULL URL detected';
        RETURN NEW;
    END IF;
    
    -- Clean and validate the URL
    clean_url := trim(NEW.raw_url);
    NEW.title := 'HTTP TEST: URL cleaned - ' || clean_url;
    
    -- Basic URL validation
    IF NOT (clean_url LIKE 'http://%' OR clean_url LIKE 'https://%') THEN
        NEW.title := 'HTTP TEST: Invalid URL format';
        RETURN NEW;
    END IF;
    
    NEW.title := 'HTTP TEST: URL validated, attempting HTTP call...';
    
    -- Test HTTP call with maximum error handling
    BEGIN
        -- Try the HTTP call
        SELECT * INTO response_record FROM http_get(clean_url);
        
        -- If we get here, HTTP call succeeded
        NEW.title := 'HTTP TEST: HTTP call succeeded!';
        NEW.description := 'HTTP TEST: Status = ' || COALESCE(response_record.status::text, 'NULL');
        
        -- Try to access the status
        http_status := response_record.status;
        NEW.title := 'HTTP TEST: Status accessed - ' || http_status::text;
        
        -- Try to access content length
        IF response_record.content IS NOT NULL THEN
            NEW.description := 'HTTP TEST: Content length = ' || length(response_record.content)::text;
        ELSE
            NEW.description := 'HTTP TEST: Content is NULL';
        END IF;
        
        -- If status is good, try simple title extraction
        IF http_status >= 200 AND http_status < 300 THEN
            http_content := response_record.content;
            
            IF http_content IS NOT NULL AND length(http_content) > 0 THEN
                -- Try to find a title tag
                IF position('<title>' in lower(http_content)) > 0 THEN
                    NEW.title := 'HTTP TEST: Found title tag!';
                ELSE
                    NEW.title := 'HTTP TEST: No title tag found';
                END IF;
            ELSE
                NEW.title := 'HTTP TEST: Content empty or null';
            END IF;
        ELSE
            NEW.title := 'HTTP TEST: Bad HTTP status - ' || http_status::text;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- Catch any HTTP errors
        NEW.title := 'HTTP TEST: Exception - ' || SQLERRM;
        NEW.description := 'HTTP TEST: SQLSTATE = ' || SQLSTATE;
        RAISE LOG 'HTTP TEST: Exception occurred: % (SQLSTATE: %)', SQLERRM, SQLSTATE;
    END;
    
    RAISE LOG 'HTTP TEST: Returning with title: %', NEW.title;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trg_fetch_metadata
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION fetch_url_metadata();

-- Test with example.com (should work)
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://example.com', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://example.com'
ORDER BY created_at DESC 
LIMIT 1; 