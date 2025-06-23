-- =====================================================================
-- TRIGGER REFERENCE GUIDE - PSReadThis Project
-- =====================================================================
-- This file contains the complete trigger setup that should be active
-- on the 'links' table in the Supabase PostgreSQL database.
-- 
-- USE THIS AS THE AUTHORITATIVE REFERENCE for trigger restoration.
-- =====================================================================

-- =====================================================================
-- SECTION 1: DIAGNOSTIC QUERIES
-- =====================================================================
-- Run these first to see what's currently active

-- Check all current triggers on the links table
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement,
    'CURRENT TRIGGERS' as section
FROM information_schema.triggers 
WHERE event_object_table = 'links'
ORDER BY trigger_name;

-- Check current functions that might be trigger-related
SELECT 
    routine_name,
    routine_type,
    external_language,
    'CURRENT FUNCTIONS' as section
FROM information_schema.routines 
WHERE routine_name IN (
    'fetch_url_metadata',
    'enhanced_fetch_metadata', 
    'set_updated_at',
    'test_trigger_function'
)
ORDER BY routine_name;

-- Check column defaults that might interfere
SELECT 
    column_name,
    column_default,
    data_type,
    'COLUMN DEFAULTS' as section
FROM information_schema.columns 
WHERE table_name = 'links' 
  AND column_name IN ('created_at', 'updated_at');

-- =====================================================================
-- SECTION 2: CLEANUP - REMOVE PROBLEMATIC TRIGGERS
-- =====================================================================
-- These triggers were causing conflicts and should be removed

-- Drop all potentially conflicting triggers
DROP TRIGGER IF EXISTS update_links_updated_at ON links;
DROP TRIGGER IF EXISTS trigger_set_updated_at ON links;
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;
DROP TRIGGER IF EXISTS trg_enhanced_metadata ON links;
DROP TRIGGER IF EXISTS test_trigger ON links;
DROP TRIGGER IF EXISTS handle_updated_at ON links;
DROP TRIGGER IF EXISTS set_updated_at_trigger ON links;
DROP TRIGGER IF EXISTS update_updated_at_column_trigger ON links;

-- Drop potentially conflicting functions
DROP FUNCTION IF EXISTS fetch_url_metadata();
DROP FUNCTION IF EXISTS enhanced_fetch_metadata();
DROP FUNCTION IF EXISTS set_updated_at();
DROP FUNCTION IF EXISTS test_trigger_function();

-- =====================================================================
-- SECTION 3: CORE TRIGGER FUNCTIONS
-- =====================================================================

-- =====================================================================
-- FUNCTION 1: Timestamp Management
-- =====================================================================
-- This function manages created_at and updated_at timestamps
-- - On INSERT: Sets updated_at = created_at initially
-- - On UPDATE: Sets updated_at = NOW()

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    -- For new records, set updated_at = created_at initially
    -- This ensures pagination works correctly (updated_at = created_at for unmodified records)
    IF TG_OP = 'INSERT' THEN
        NEW.updated_at = COALESCE(NEW.created_at, NOW());
    -- For updates, set updated_at = NOW()
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- FUNCTION 2: Basic Metadata Extraction
-- =====================================================================
-- This function extracts title and description from URLs during INSERT
-- Uses Supabase HTTP extension to fetch page content

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

-- =====================================================================
-- FUNCTION 3: Enhanced Metadata Extraction (Alternative)
-- =====================================================================
-- This is an enhanced version that includes redirect resolution
-- Use this instead of basic fetch_url_metadata if you need better handling
-- of tracking URLs and redirects

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
            -- Use the enhanced resolution function (requires resolve_redirect_chain function)
            -- Note: This function may not exist in your setup - use basic version if missing
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

-- =====================================================================
-- SECTION 4: RECOMMENDED TRIGGER SETUP
-- =====================================================================
-- This is the STANDARD configuration that should be active

-- =====================================================================
-- TRIGGER 1: Timestamp Management (CRITICAL - Always needed)
-- =====================================================================
CREATE TRIGGER trigger_set_updated_at
    BEFORE INSERT OR UPDATE ON links
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- =====================================================================
-- TRIGGER 2: Metadata Extraction (Choose ONE of the following)
-- =====================================================================

-- OPTION A: Basic metadata extraction (RECOMMENDED)
-- Use this for standard metadata extraction without redirect handling
CREATE TRIGGER trg_fetch_metadata
    BEFORE INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION fetch_url_metadata();

-- OPTION B: Enhanced metadata extraction (ADVANCED)
-- Use this if you have the resolve_redirect_chain function and need better
-- handling of tracking URLs and redirects
-- 
-- CREATE TRIGGER trg_enhanced_metadata
--     BEFORE INSERT ON links 
--     FOR EACH ROW
--     EXECUTE FUNCTION enhanced_fetch_metadata();

-- =====================================================================
-- SECTION 5: VERIFICATION QUERIES
-- =====================================================================
-- Run these after setting up triggers to verify everything works

-- Test the triggers with a sample insert
-- (Replace the user_id with a valid UUID from your system)
INSERT INTO links (raw_url, user_id, list, status) 
VALUES (
    'https://en.wikipedia.org/wiki/PostgreSQL', 
    '3ad801b9-b41d-4cca-a5ba-2065a1d6ce97', -- Replace with valid user_id
    'read', 
    'unread'
);

-- Check the result to see if metadata was extracted
SELECT 
    id, 
    raw_url, 
    title, 
    description, 
    created_at, 
    updated_at,
    CASE 
        WHEN updated_at = created_at THEN 'TIMESTAMPS MATCH ✅'
        ELSE 'TIMESTAMPS DIFFERENT ❌'
    END as timestamp_status,
    CASE 
        WHEN title IS NOT NULL AND title != raw_url THEN 'METADATA EXTRACTED ✅'
        ELSE 'NO METADATA ❌'
    END as metadata_status
FROM links 
WHERE raw_url = 'https://en.wikipedia.org/wiki/PostgreSQL'
ORDER BY created_at DESC 
LIMIT 1;

-- Verify all triggers are active
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    'ACTIVE TRIGGERS' as status
FROM information_schema.triggers 
WHERE event_object_table = 'links'
ORDER BY trigger_name;

-- =====================================================================
-- SECTION 6: TROUBLESHOOTING
-- =====================================================================

-- If metadata extraction isn't working, test the HTTP extension:
-- SELECT status, content_type, length(content) as content_length
-- FROM http_get('https://httpbin.org/html');

-- If timestamp management isn't working, check for column defaults:
-- ALTER TABLE links ALTER COLUMN updated_at DROP DEFAULT;

-- If you're getting duplicate trigger errors, run the cleanup section again

-- =====================================================================
-- SECTION 7: IMPORTANT NOTES
-- =====================================================================

/*
CRITICAL POINTS:

1. ALWAYS have the timestamp trigger (trigger_set_updated_at)
   - This manages created_at and updated_at properly
   - Essential for pagination functionality

2. Choose ONLY ONE metadata trigger:
   - trg_fetch_metadata (basic, recommended)
   - OR trg_enhanced_metadata (advanced, requires additional functions)

3. Problematic triggers to AVOID:
   - update_links_updated_at (interferes with timestamp logic)
   - Any trigger that sets updated_at = NOW() on INSERT
   - Multiple timestamp triggers (causes conflicts)

4. All triggers should be BEFORE triggers:
   - BEFORE INSERT allows modification of NEW record
   - AFTER INSERT cannot modify the inserted record

5. Functions should handle errors gracefully:
   - Use EXCEPTION WHEN OTHERS to prevent failed INSERTs
   - Always RETURN NEW; from trigger functions

6. Test after setup:
   - Insert a test record with a real URL
   - Verify timestamps match (updated_at = created_at for new records)
   - Verify metadata extraction worked (title extracted from URL)

TRIGGER EXECUTION ORDER:
1. trigger_set_updated_at (sets timestamps)
2. trg_fetch_metadata (extracts metadata)
Both run BEFORE INSERT in alphabetical order by trigger name.
*/

-- =====================================================================
-- END OF TRIGGER REFERENCE GUIDE
-- ===================================================================== 