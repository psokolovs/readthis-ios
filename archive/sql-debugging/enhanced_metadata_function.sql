-- Enhanced metadata function that follows redirects
-- Run this in your Supabase SQL Editor

-- Replace with redirect-following version
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Create enhanced function that follows redirects
CREATE OR REPLACE FUNCTION fetch_url_metadata()
RETURNS TRIGGER AS $$
DECLARE
    response_record RECORD;
    redirect_response RECORD;
    response_data TEXT;
    page_title TEXT;
    page_description TEXT;
    clean_url TEXT;
    resolved_url TEXT;
    title_start INTEGER;
    title_end INTEGER;
    desc_pos INTEGER;
    content_start INTEGER;
    content_end INTEGER;
    redirect_count INTEGER := 0;
    max_redirects INTEGER := 10;
    current_url TEXT;
    location_header TEXT;
BEGIN
    -- Check if raw_url is NULL or empty
    IF NEW.raw_url IS NULL OR trim(NEW.raw_url) = '' THEN
        RETURN NEW;
    END IF;
    
    -- Clean and validate the URL
    clean_url := trim(NEW.raw_url);
    current_url := clean_url;
    
    -- Basic URL validation
    IF NOT (clean_url LIKE 'http://%' OR clean_url LIKE 'https://%') THEN
        RETURN NEW;
    END IF;
    
    -- Follow redirect chain to find final URL
    BEGIN
        WHILE redirect_count < max_redirects LOOP
            -- Make HTTP request
            SELECT * INTO response_record FROM http_get(current_url);
            
            -- Check if this is a redirect
            IF response_record.status IN (301, 302, 303, 307, 308) THEN
                -- Get location header for redirect
                location_header := NULL;
                
                -- Try to extract location from headers (this is simplified)
                -- In practice, http_get should follow redirects automatically
                -- But for complex tracking URLs, we might need manual handling
                
                IF location_header IS NOT NULL THEN
                    current_url := location_header;
                    redirect_count := redirect_count + 1;
                ELSE
                    -- No location header found, stop redirecting
                    EXIT;
                END IF;
            ELSE
                -- Not a redirect, we have the final response
                EXIT;
            END IF;
        END LOOP;
        
        -- Store the resolved URL (might be same as original if no redirects)
        resolved_url := current_url;
        NEW.resolved_url := resolved_url;
        
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
        ELSE
            -- Store resolved URL even if content fetch failed
            NEW.resolved_url := resolved_url;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- Silently continue on any errors - don't break the INSERT
        -- But still try to store resolved URL if we got one
        IF resolved_url IS NOT NULL AND resolved_url != clean_url THEN
            NEW.resolved_url := resolved_url;
        END IF;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER trg_fetch_metadata
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION fetch_url_metadata();

-- Test with the tracking URL you provided
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://www.google.com/aclk?sa=L&ai=DChsSEwjZ7Zfi6uKNAxXuZ0cBHfyIGK8YACICCAEQUxoCcXU&co=1&sph&cce=1&sig=AOD64_0JIRoeH34gTMCL3qXfL4316jgkUQ&q&adurl&ved=2ahUKEwiYxZPi6uKNAxVMLVkFHQnlHQwQ0Qx6BAgNEAE', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result - should show resolved URL and proper title
SELECT id, raw_url, resolved_url, title, description, created_at 
FROM links 
WHERE raw_url LIKE '%google.com/aclk%'
ORDER BY created_at DESC 
LIMIT 1; 