-- Final working metadata function
-- Run this in your Supabase SQL Editor

-- Step 1: Drop the trigger first
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;

-- Step 2: Now drop the function
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Step 3: Create a reliable working function
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
BEGIN
    -- Check if raw_url is NULL or empty
    IF NEW.raw_url IS NULL OR trim(NEW.raw_url) = '' THEN
        RAISE LOG 'fetch_url_metadata: raw_url is NULL or empty, skipping metadata fetch';
        RETURN NEW;
    END IF;
    
    -- Clean and validate the URL
    clean_url := trim(NEW.raw_url);
    
    -- Basic URL validation
    IF NOT (clean_url LIKE 'http://%' OR clean_url LIKE 'https://%') THEN
        RAISE LOG 'fetch_url_metadata: Invalid URL format: %', clean_url;
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
                            -- Remove excessive whitespace
                            page_title := regexp_replace(page_title, '\s+', ' ', 'g');
                            -- Limit length
                            IF length(page_title) > 200 THEN
                                page_title := left(page_title, 197) || '...';
                            END IF;
                            NEW.title := page_title;
                        END IF;
                    END IF;
                END IF;
                
                -- Try to extract description from meta tags
                -- Look for name="description" content="..."
                IF position('name="description"' in lower(response_data)) > 0 THEN
                    -- This is a simplified extraction - just log that we found it
                    NEW.description := 'Description available';
                ELSIF position('name=''description''' in lower(response_data)) > 0 THEN
                    NEW.description := 'Description available';
                END IF;
                
                RAISE LOG 'fetch_url_metadata: Successfully processed URL: %, Title: %', clean_url, COALESCE(page_title, 'No title');
            END IF;
        ELSE
            RAISE LOG 'fetch_url_metadata: HTTP error % for URL: %', response_record.status, clean_url;
        END IF;
        
    EXCEPTION WHEN OTHERS THEN
        -- Log the error but don't fail the INSERT
        RAISE LOG 'fetch_url_metadata: Error fetching metadata for URL %, Error: %', clean_url, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Recreate the trigger
CREATE TRIGGER trg_fetch_metadata
    AFTER INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION fetch_url_metadata(); 