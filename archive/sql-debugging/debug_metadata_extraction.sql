-- Debug version of metadata function to see what's happening
-- Run this in your Supabase SQL Editor

-- Replace the function with a debug version
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Create debug version that logs everything
CREATE OR REPLACE FUNCTION fetch_url_metadata()
RETURNS TRIGGER AS $$
DECLARE
    response_record RECORD;
    response_data TEXT;
    page_title TEXT;
    clean_url TEXT;
    title_start INTEGER;
    title_end INTEGER;
BEGIN
    RAISE LOG 'DEBUG: Starting function for URL: %', NEW.raw_url;
    
    -- Check if raw_url is NULL or empty
    IF NEW.raw_url IS NULL OR trim(NEW.raw_url) = '' THEN
        RAISE LOG 'DEBUG: raw_url is NULL or empty, skipping';
        NEW.title := 'DEBUG: NULL URL';
        RETURN NEW;
    END IF;
    
    -- Clean and validate the URL
    clean_url := trim(NEW.raw_url);
    RAISE LOG 'DEBUG: Clean URL: %', clean_url;
    
    -- Basic URL validation
    IF NOT (clean_url LIKE 'http://%' OR clean_url LIKE 'https://%') THEN
        RAISE LOG 'DEBUG: Invalid URL format: %', clean_url;
        NEW.title := 'DEBUG: Invalid URL format';
        RETURN NEW;
    END IF;
    
    -- Attempt to fetch the URL content
    BEGIN
        RAISE LOG 'DEBUG: Attempting HTTP request to: %', clean_url;
        
        -- Use the http extension to fetch the URL
        SELECT * INTO response_record FROM http_get(clean_url);
        
        RAISE LOG 'DEBUG: HTTP response status: %', response_record.status;
        RAISE LOG 'DEBUG: HTTP response content-type: %', response_record.content_type;
        RAISE LOG 'DEBUG: HTTP response content length: %', length(response_record.content);
        
        -- Check if we got a successful response
        IF response_record.status >= 200 AND response_record.status < 300 THEN
            response_data := response_record.content;
            
            -- Show first 500 characters of content for debugging
            RAISE LOG 'DEBUG: Content preview: %', left(response_data, 500);
            
            -- Extract title using simple string operations
            IF response_data IS NOT NULL AND length(response_data) > 0 THEN
                -- Look for <title> tags (case insensitive)
                title_start := position('<title' in lower(response_data));
                RAISE LOG 'DEBUG: Title start position: %', title_start;
                
                IF title_start > 0 THEN
                    -- Find the end of the opening tag
                    title_start := position('>' in substring(response_data from title_start)) + title_start;
                    RAISE LOG 'DEBUG: Title content start position: %', title_start;
                    
                    -- Find the closing tag
                    title_end := position('</title>' in lower(substring(response_data from title_start)));
                    RAISE LOG 'DEBUG: Title end position: %', title_end;
                    
                    IF title_end > 0 THEN
                        page_title := substring(response_data from title_start for title_end - 1);
                        RAISE LOG 'DEBUG: Extracted raw title: %', page_title;
                        
                        page_title := trim(page_title);
                        
                        -- Clean up the title
                        IF page_title IS NOT NULL AND length(page_title) > 0 THEN
                            -- Remove excessive whitespace
                            page_title := regexp_replace(page_title, '\s+', ' ', 'g');
                            -- Limit length
                            IF length(page_title) > 200 THEN
                                page_title := left(page_title, 197) || '...';
                            END IF;
                            NEW.title := page_title;
                            RAISE LOG 'DEBUG: Final title set to: %', page_title;
                        ELSE
                            NEW.title := 'DEBUG: Empty title extracted';
                            RAISE LOG 'DEBUG: Title was empty after extraction';
                        END IF;
                    ELSE
                        NEW.title := 'DEBUG: No closing title tag found';
                        RAISE LOG 'DEBUG: Could not find closing title tag';
                    END IF;
                ELSE
                    NEW.title := 'DEBUG: No title tag found';
                    RAISE LOG 'DEBUG: Could not find opening title tag';
                END IF;
                
                NEW.description := 'DEBUG: Function executed successfully';
                RAISE LOG 'DEBUG: Successfully processed URL: %', clean_url;
            ELSE
                NEW.title := 'DEBUG: No content returned';
                RAISE LOG 'DEBUG: No content in HTTP response';
            END IF;
        ELSE
            NEW.title := 'DEBUG: HTTP error ' || response_record.status;
            RAISE LOG 'DEBUG: HTTP error % for URL: %', response_record.status, clean_url;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- Log the error and set debug info
        NEW.title := 'DEBUG: Exception - ' || SQLERRM;
        NEW.description := 'DEBUG: Error occurred during fetch';
        RAISE LOG 'DEBUG: Exception occurred: %', SQLERRM;
    END;
    
    RAISE LOG 'DEBUG: Returning NEW with title: %', NEW.title;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trg_fetch_metadata
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION fetch_url_metadata();

-- Test with a simple URL
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