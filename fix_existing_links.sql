-- UPDATE ALL EXISTING LINKS WITH MISSING METADATA
-- Run this after the metadata functions are created

-- Step 1: Create a function to update metadata for existing links
CREATE OR REPLACE FUNCTION update_link_metadata(link_id UUID, raw_url TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    resolution_result RECORD;
    success BOOLEAN := FALSE;
BEGIN
    BEGIN
        -- Resolve the URL and get metadata
        SELECT * INTO resolution_result 
        FROM resolve_redirect_chain(raw_url);
        
        -- Update the link with new metadata
        UPDATE links 
        SET 
            resolved_url = resolution_result.final_url,
            title = COALESCE(resolution_result.final_title, title),
            description = COALESCE(resolution_result.final_description, description)
        WHERE id = link_id;
        
        success := TRUE;
        
    EXCEPTION WHEN OTHERS THEN
        -- Log error but continue
        RAISE NOTICE 'Failed to update link %: %', link_id, SQLERRM;
        success := FALSE;
    END;
    
    RETURN success;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Find all links that need metadata extraction
-- (Links with no title or title = raw_url or very short titles)
SELECT 
    id,
    raw_url,
    title,
    CASE 
        WHEN title IS NULL THEN 'No title'
        WHEN title = raw_url THEN 'Title same as URL'
        WHEN length(title) < 10 THEN 'Title too short'
        ELSE 'Other'
    END as reason
FROM links 
WHERE 
    title IS NULL 
    OR title = raw_url 
    OR length(trim(title)) < 10
    OR title ~ '^https?://'
ORDER BY created_at DESC
LIMIT 50;

-- Step 3: Find your actual problematic tracking URLs
SELECT 
    id,
    raw_url,
    title,
    CASE 
        WHEN raw_url ~ 'encoded_url=' THEN 'Base64 encoded URL (marginalrevolution style)'
        WHEN raw_url ~ 'track/click' THEN 'Click tracking URL'
        WHEN raw_url ~ 'user_content_redirect' THEN 'Content redirect URL'
        WHEN raw_url ~ 'apple\.news' THEN 'Apple News URL'
        WHEN raw_url ~ 'list-manage\.com' THEN 'Mailchimp tracking URL'
        WHEN raw_url ~ 'email\.' THEN 'Email tracking URL'
        WHEN raw_url ~ 'newsletter' THEN 'Newsletter URL'
        WHEN raw_url ~ 'campaign' THEN 'Campaign URL'
        WHEN raw_url ~ 'utm_' THEN 'UTM tracking URL'
        ELSE 'Other tracking pattern'
    END as tracking_type
FROM links 
WHERE 
    raw_url ~ 'encoded_url='
    OR raw_url ~ 'track/click'
    OR raw_url ~ 'user_content_redirect'
    OR raw_url ~ 'apple\.news'
    OR raw_url ~ 'list-manage\.com'
    OR raw_url ~ 'email\.'
    OR raw_url ~ 'newsletter'
    OR raw_url ~ 'campaign'
    OR raw_url ~ 'utm_'
ORDER BY created_at DESC
LIMIT 20;

-- Step 4: Update function to process a batch of links
CREATE OR REPLACE FUNCTION update_batch_metadata(batch_size INTEGER DEFAULT 10)
RETURNS TABLE(
    link_id UUID,
    original_url TEXT,
    resolved_url TEXT,
    extracted_title TEXT,
    success BOOLEAN
) AS $$
DECLARE
    link_record RECORD;
    updated_count INTEGER := 0;
    resolution_result RECORD;
BEGIN
    -- PRIORITY 1: Process tracking URLs first (the ones we know have issues)
    FOR link_record IN 
        SELECT id, raw_url, title
        FROM links 
        WHERE 
            (raw_url ~ 'encoded_url='
             OR raw_url ~ 'track/click'
             OR raw_url ~ 'user_content_redirect'
             OR raw_url ~ 'apple\.news'
             OR raw_url ~ 'list-manage\.com'
             OR raw_url ~ 'email\.'
             OR raw_url ~ 'newsletter'
             OR raw_url ~ 'campaign'
             OR raw_url ~ 'utm_')
            AND raw_url !~ '\.(pdf|doc|docx|xls|xlsx|zip|gz|tar)(\?|$)'  -- Skip file downloads
        ORDER BY created_at DESC
        LIMIT batch_size
    LOOP
        BEGIN
            -- Resolve the URL
            SELECT * INTO resolution_result 
            FROM resolve_redirect_chain(link_record.raw_url);
            
            -- Update the link
            UPDATE links 
            SET 
                resolved_url = resolution_result.final_url,
                title = COALESCE(resolution_result.final_title, title),
                description = COALESCE(resolution_result.final_description, description)
            WHERE id = link_record.id;
            
            -- Return result
            RETURN QUERY SELECT 
                link_record.id,
                link_record.raw_url,
                resolution_result.final_url,
                resolution_result.final_title,
                TRUE;
                
            updated_count := updated_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            -- Return failed result
            RETURN QUERY SELECT 
                link_record.id,
                link_record.raw_url,
                link_record.raw_url,
                NULL::TEXT,
                FALSE;
        END;
    END LOOP;
    
    -- PRIORITY 2: If we haven't filled the batch, get regular links with missing titles
    -- But skip PDFs and other file downloads
    IF updated_count < batch_size THEN
        FOR link_record IN 
            SELECT id, raw_url, title
            FROM links 
            WHERE 
                (title IS NULL 
                 OR title = raw_url 
                 OR length(trim(title)) < 10
                 OR title ~ '^https?://')
                AND raw_url !~ '\.(pdf|doc|docx|xls|xlsx|zip|gz|tar)(\?|$)'  -- Skip file downloads
                AND raw_url !~ '(encoded_url=|track/click|user_content_redirect|apple\.news|list-manage\.com)'  -- Skip already processed
            ORDER BY created_at DESC
            LIMIT (batch_size - updated_count)
        LOOP
            BEGIN
                -- Resolve the URL
                SELECT * INTO resolution_result 
                FROM resolve_redirect_chain(link_record.raw_url);
                
                -- Update the link
                UPDATE links 
                SET 
                    resolved_url = resolution_result.final_url,
                    title = COALESCE(resolution_result.final_title, title),
                    description = COALESCE(resolution_result.final_description, description)
                WHERE id = link_record.id;
                
                -- Return result
                RETURN QUERY SELECT 
                    link_record.id,
                    link_record.raw_url,
                    resolution_result.final_url,
                    resolution_result.final_title,
                    TRUE;
                    
                updated_count := updated_count + 1;
                
            EXCEPTION WHEN OTHERS THEN
                -- Return failed result
                RETURN QUERY SELECT 
                    link_record.id,
                    link_record.raw_url,
                    link_record.raw_url,
                    NULL::TEXT,
                    FALSE;
            END;
        END LOOP;
    END IF;
    
    RAISE NOTICE 'Updated % links', updated_count;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Test the batch update on 5 links
SELECT * FROM update_batch_metadata(5);

-- Step 6: After testing, run on larger batches
-- SELECT * FROM update_batch_metadata(50);
-- SELECT * FROM update_batch_metadata(100);

-- Step 7: Update the trigger for new links
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;

CREATE OR REPLACE FUNCTION enhanced_fetch_metadata()
RETURNS TRIGGER AS $$
DECLARE
    resolution_result RECORD;
BEGIN
    -- Only process if we have a URL and no title
    IF NEW.raw_url IS NOT NULL 
       AND trim(NEW.raw_url) != '' 
       AND (NEW.title IS NULL OR trim(NEW.title) = '' OR NEW.title = NEW.raw_url) THEN
        
        BEGIN
            -- Use the enhanced resolution function
            SELECT * INTO resolution_result 
            FROM resolve_redirect_chain(NEW.raw_url);
            
            -- Update the new record
            NEW.resolved_url := resolution_result.final_url;
            NEW.title := COALESCE(resolution_result.final_title, NEW.title);
            NEW.description := COALESCE(resolution_result.final_description, NEW.description);
            
        EXCEPTION WHEN OTHERS THEN
            -- Continue with original data on error
            NULL;
        END;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the new trigger
CREATE TRIGGER trg_enhanced_metadata
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION enhanced_fetch_metadata();

-- Step 8: Statistics query to see improvement
SELECT 
    COUNT(*) as total_links,
    COUNT(title) as links_with_title,
    COUNT(title) * 100.0 / COUNT(*) as title_percentage,
    COUNT(description) as links_with_description,
    COUNT(description) * 100.0 / COUNT(*) as description_percentage
FROM links;

-- Step 9: Safer bulk processing function with built-in chunking
CREATE OR REPLACE FUNCTION process_all_metadata_safely()
RETURNS TABLE(
    batch_number INTEGER,
    links_processed INTEGER,
    success_count INTEGER
) AS $$
DECLARE
    batch_num INTEGER := 1;
    batch_result RECORD;
    total_processed INTEGER := 0;
    batch_success INTEGER;
BEGIN
    -- Process in chunks of 20 links
    LOOP
        -- Process next batch
        SELECT COUNT(*) INTO batch_success
        FROM update_batch_metadata(20) 
        WHERE success = TRUE;
        
        -- If no links were processed, we're done
        IF batch_success = 0 THEN
            EXIT;
        END IF;
        
        total_processed := total_processed + batch_success;
        
        -- Return batch result
        RETURN QUERY SELECT 
            batch_num,
            20,
            batch_success;
            
        batch_num := batch_num + 1;
        
        -- Stop after 10 batches (200 links max) to prevent runaway
        IF batch_num > 10 THEN
            EXIT;
        END IF;
        
        -- Small delay between batches (if supported)
        PERFORM pg_sleep(0.5);
        
    END LOOP;
    
    RAISE NOTICE 'Bulk processing complete. Total links processed: %', total_processed;
END;
$$ LANGUAGE plpgsql; 