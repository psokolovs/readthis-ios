-- Simple working version without complex regex
-- Run this in your Supabase SQL Editor

-- Step 1: Drop the trigger first
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;

-- Step 2: Now drop the function
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Step 3: Create a simple working function
CREATE OR REPLACE FUNCTION fetch_url_metadata()
RETURNS TRIGGER AS $$
DECLARE
    response_data TEXT;
    page_title TEXT;
    page_description TEXT;
    clean_url TEXT;
    title_start INTEGER;
    title_end INTEGER;
    desc_start INTEGER;
    desc_end INTEGER;
BEGIN
    -- Check if raw_url is NULL or empty
    IF NEW.raw_url IS NULL OR NEW.raw_url = '' THEN
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
        -- Use the correct http extension function
        SELECT content INTO response_data 
        FROM http_get(clean_url);
        
        -- If we got content, try to extract title and description using simple string functions
        IF response_data IS NOT NULL AND length(response_data) > 0 THEN
            -- Extract title using position functions (more reliable than regex)
            title_start := position('<title>' in lower(response_data));
            IF title_start > 0 THEN
                title_start := title_start + 7; -- length of '<title>'
                title_end := position('</title>' in lower(response_data));
                IF title_end > title_start THEN
                    page_title := substring(response_data from title_start for (title_end - title_start));
                    page_title := trim(page_title);
                END IF;
            END IF;
            
            -- Extract description from meta tag (simplified approach)
            desc_start := position('name="description"' in lower(response_data));
            IF desc_start = 0 THEN
                desc_start := position('name=''description''' in lower(response_data));
            END IF;
            
            IF desc_start > 0 THEN
                -- Find content attribute after description
                desc_start := position('content=' in lower(substring(response_data from desc_start)));
                IF desc_start > 0 THEN
                    desc_start := desc_start + position('content=' in lower(substring(response_data from desc_start))) + 8; -- Skip 'content='
                    -- Find the closing quote (simplified)
                    desc_end := position('"' in substring(response_data from desc_start + 1));
                    IF desc_end = 0 THEN
                        desc_end := position('''' in substring(response_data from desc_start + 1));
                    END IF;
                    IF desc_end > 0 THEN
                        page_description := substring(response_data from desc_start + 1 for desc_end - 1);
                        page_description := trim(page_description);
                    END IF;
                END IF;
            END IF;
            
            -- Clean up and limit lengths
            IF page_title IS NOT NULL AND length(page_title) > 0 THEN
                -- Remove extra whitespace
                page_title := regexp_replace(page_title, '\s+', ' ', 'g');
                -- Limit title length
                IF length(page_title) > 200 THEN
                    page_title := left(page_title, 197) || '...';
                END IF;
                NEW.title := page_title;
            END IF;
            
            IF page_description IS NOT NULL AND length(page_description) > 0 THEN
                -- Remove extra whitespace
                page_description := regexp_replace(page_description, '\s+', ' ', 'g');
                -- Limit description length
                IF length(page_description) > 500 THEN
                    page_description := left(page_description, 497) || '...';
                END IF;
                NEW.description := page_description;
            END IF;
            
            RAISE LOG 'fetch_url_metadata: Successfully fetched metadata for URL: %', clean_url;
        ELSE
            RAISE LOG 'fetch_url_metadata: No content returned for URL: %', clean_url;
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