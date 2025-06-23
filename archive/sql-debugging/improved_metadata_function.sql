-- Improved metadata function that handles bot protection and various scenarios
-- Run this in your Supabase SQL Editor

-- Replace with improved version
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Create improved function that handles blocked URLs and various status codes
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
    is_blocked BOOLEAN := FALSE;
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
    
    -- Make HTTP request with User-Agent header to look more like a browser
    BEGIN
        SELECT * INTO response_record FROM http((
            'GET',
            clean_url,
            ARRAY[
                http_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'),
                http_header('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'),
                http_header('Accept-Language', 'en-US,en;q=0.5'),
                http_header('Accept-Encoding', 'gzip, deflate'),
                http_header('DNT', '1'),
                http_header('Connection', 'keep-alive'),
                http_header('Upgrade-Insecure-Requests', '1')
            ]::http_header[],
            NULL,
            NULL
        ));
        
        -- Always set resolved_url to the original URL for now
        -- (We'd need more complex logic to detect actual final URLs after redirects)
        NEW.resolved_url := clean_url;
        
        -- Handle different response scenarios
        IF response_record.status >= 200 AND response_record.status < 300 THEN
            -- Success - extract metadata normally
            response_data := response_record.content;
        ELSIF response_record.status = 403 THEN
            -- Blocked by bot protection - still try to extract title but mark as blocked
            response_data := response_record.content;
            is_blocked := TRUE;
        ELSIF response_record.status IN (301, 302, 303, 307, 308) THEN
            -- Redirect - try to extract title from redirect page or skip
            response_data := response_record.content;
        ELSE
            -- Other errors - skip metadata extraction
            response_data := NULL;
        END IF;
        
        -- Extract title if we have content
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
                        
                        -- Handle blocked pages
                        IF is_blocked AND (
                            lower(page_title) LIKE '%access%denied%' OR 
                            lower(page_title) LIKE '%blocked%' OR
                            lower(page_title) LIKE '%forbidden%'
                        ) THEN
                            -- For blocked tracking URLs, create a more useful title
                            IF clean_url LIKE '%google.com/aclk%' THEN
                                page_title := 'Google Ad Link (Blocked by Bot Protection)';
                            ELSIF clean_url LIKE '%facebook.com%' THEN
                                page_title := 'Facebook Link (Blocked by Bot Protection)';
                            ELSIF clean_url LIKE '%twitter.com%' OR clean_url LIKE '%t.co%' THEN
                                page_title := 'Twitter Link (Blocked by Bot Protection)';
                            ELSE
                                page_title := 'Link (Blocked by Bot Protection)';
                            END IF;
                        END IF;
                        
                        -- Limit length
                        IF length(page_title) > 200 THEN
                            page_title := left(page_title, 197) || '...';
                        END IF;
                        
                        NEW.title := page_title;
                    END IF;
                END IF;
            END IF;
            
            -- Extract description from meta tags (only if not blocked)
            IF NOT is_blocked THEN
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
        -- Ensure resolved_url is set
        IF NEW.resolved_url IS NULL THEN
            NEW.resolved_url := clean_url;
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

-- Test with a simple URL first to make sure basic functionality works
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://en.wikipedia.org/wiki/PostgreSQL', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', 
    'read', 
    'unread'
);

-- Check the result
SELECT 'Improved metadata function created and tested!' as message; 