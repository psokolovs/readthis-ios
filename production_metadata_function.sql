-- Final production metadata function
-- Run this in your Supabase SQL Editor

-- Replace with the final production version
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Create the final production function
CREATE OR REPLACE FUNCTION fetch_url_metadata()
RETURNS TRIGGER AS $$
DECLARE
    response_record RECORD;
    response_data TEXT;
    page_title TEXT;
    page_description TEXT;
    clean_url TEXT;
    title_start INTEGER;
    title_end INTEGER;
    desc_pos INTEGER;
    content_start INTEGER;
    content_end INTEGER;
BEGIN
    -- Check if raw_url is NULL or empty
    IF NEW.raw_url IS NULL OR trim(NEW.raw_url) = '' THEN
        RETURN NEW;
    END IF;
    
    -- Clean and validate the URL
    clean_url := trim(NEW.raw_url);
    
    -- Basic URL validation
    IF NOT (clean_url LIKE 'http://%' OR clean_url LIKE 'https://%') THEN
        RETURN NEW;
    END IF;
    
    -- Attempt to fetch the URL content
    BEGIN
        -- Use the http extension to fetch the URL
        SELECT * INTO response_record FROM http_get(clean_url);
        
        -- Check if we got a successful response
        IF response_record.status >= 200 AND response_record.status < 300 THEN
            response_data := response_record.content;
            
            -- Extract title using simple string operations
            IF response_data IS NOT NULL AND length(response_data) > 0 THEN
                -- Look for <title> tags (case insensitive)
                title_start := position('<title' in lower(response_data));
                
                IF title_start > 0 THEN
                    -- Find the end of the opening tag
                    title_start := position('>' in substring(response_data from title_start)) + title_start;
                    -- Find the closing tag
                    title_end := position('</title>' in lower(substring(response_data from title_start)));
                    
                    IF title_end > 0 THEN
                        page_title := substring(response_data from title_start for title_end - 1);
                        page_title := trim(page_title);
                        
                        -- Clean up the title
                        IF page_title IS NOT NULL AND length(page_title) > 0 THEN
                            -- Remove excessive whitespace and newlines
                            page_title := regexp_replace(page_title, '\s+', ' ', 'g');
                            page_title := trim(page_title);
                            
                            -- Limit length
                            IF length(page_title) > 200 THEN
                                page_title := left(page_title, 197) || '...';
                            END IF;
                            
                            NEW.title := page_title;
                        END IF;
                    END IF;
                END IF;
                
                -- Extract description from meta tags
                -- Look for name="description" content="..."
                desc_pos := position('name="description"' in lower(response_data));
                IF desc_pos = 0 THEN
                    desc_pos := position('name=''description''' in lower(response_data));
                END IF;
                
                IF desc_pos > 0 THEN
                    -- Find content attribute in the same tag
                    content_start := position('content=' in lower(substring(response_data from desc_pos for 500)));
                    IF content_start > 0 THEN
                        content_start := desc_pos + content_start + 7; -- Skip 'content='
                        
                        -- Skip opening quote
                        IF substring(response_data from content_start for 1) IN ('"', '''') THEN
                            content_start := content_start + 1;
                            -- Find closing quote
                            content_end := position(substring(response_data from content_start - 1 for 1) in substring(response_data from content_start));
                            IF content_end > 0 THEN
                                page_description := substring(response_data from content_start for content_end - 1);
                                page_description := trim(page_description);
                                
                                -- Clean up description
                                IF page_description IS NOT NULL AND length(page_description) > 0 THEN
                                    page_description := regexp_replace(page_description, '\s+', ' ', 'g');
                                    page_description := trim(page_description);
                                    
                                    -- Limit length
                                    IF length(page_description) > 500 THEN
                                        page_description := left(page_description, 497) || '...';
                                    END IF;
                                    
                                    NEW.description := page_description;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- Silently continue on any errors - don't break the INSERT
        NULL;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trg_fetch_metadata
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION fetch_url_metadata();

-- Test with a fresh URL to see real titles
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://en.wikipedia.org/wiki/PostgreSQL', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result - should show real extracted title!
SELECT id, raw_url, title, description, created_at 
FROM links 
WHERE raw_url = 'https://en.wikipedia.org/wiki/PostgreSQL'
ORDER BY created_at DESC 
LIMIT 1; 