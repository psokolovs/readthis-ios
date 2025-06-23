# Link Unfurling/Metadata Fix Implementation Plan

## Root Cause Analysis
**Problem**: Metadata extraction fails on redirect/tracking links
**Examples from your data**:
1. **Newsletter tracking**: `marginalrevolution.com/?action=user_content_redirect&encoded_url=aHR0cHM6...`
2. **Email tracking**: `email.curiouscorner.nl/c/eJyMkLEO4yAQRL8Gd0SwgMEFx...`  
3. **Apple News**: `https://apple.news/A_cevwFegRnWY9Bx6olTlPg`
4. **Mailing list**: `ben-evans.us6.list-manage.com/track/click?u=...&id=...`

## Implementation Strategy

### Phase 1: Enhanced Redirect Following
**Current Issue**: Supabase http extension doesn't follow redirects properly
**Solution**: Multi-step redirect resolution with smart parsing

```sql
CREATE OR REPLACE FUNCTION resolve_redirect_chain(input_url TEXT, max_redirects INTEGER DEFAULT 5)
RETURNS TABLE(final_url TEXT, resolved_title TEXT, resolved_description TEXT) AS $$
DECLARE
    current_url TEXT := input_url;
    redirect_count INTEGER := 0;
    response_record RECORD;
    location_header TEXT;
    page_title TEXT;
    page_description TEXT;
    decoded_url TEXT;
BEGIN
    -- Step 1: Try to decode common tracking URL patterns first
    decoded_url := decode_tracking_url(input_url);
    IF decoded_url IS NOT NULL AND decoded_url != input_url THEN
        current_url := decoded_url;
    END IF;
    
    -- Step 2: Follow redirect chain
    WHILE redirect_count < max_redirects LOOP
        BEGIN
            -- Make HTTP request
            SELECT * INTO response_record FROM http_get(current_url);
            
            -- Check for redirects (3xx status codes)
            IF response_record.status >= 300 AND response_record.status < 400 THEN
                -- Extract Location header
                location_header := get_header_value(response_record.headers, 'Location');
                
                IF location_header IS NOT NULL THEN
                    -- Handle relative URLs
                    IF location_header LIKE 'http%' THEN
                        current_url := location_header;
                    ELSE
                        -- Construct absolute URL from relative
                        current_url := construct_absolute_url(current_url, location_header);
                    END IF;
                    
                    redirect_count := redirect_count + 1;
                    CONTINUE;
                END IF;
            END IF;
            
            -- Success response - extract metadata
            IF response_record.status >= 200 AND response_record.status < 300 THEN
                page_title := extract_title_from_html(response_record.content);
                page_description := extract_description_from_html(response_record.content);
                
                RETURN QUERY SELECT current_url, page_title, page_description;
                RETURN;
            END IF;
            
            -- Failed - exit loop
            EXIT;
            
        EXCEPTION WHEN OTHERS THEN
            -- Continue to next URL or exit on error
            EXIT;
        END;
    END LOOP;
    
    -- Return original URL if all else fails
    RETURN QUERY SELECT input_url, NULL::TEXT, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;
```

### Phase 2: Smart URL Pattern Decoding
**Tracking URL Parser for Common Patterns:**

```sql
CREATE OR REPLACE FUNCTION decode_tracking_url(input_url TEXT)
RETURNS TEXT AS $$
DECLARE
    decoded_url TEXT;
    encoded_part TEXT;
    url_param TEXT;
BEGIN
    -- Pattern 1: Base64 encoded URLs in parameters
    -- Example: marginalrevolution.com/?...&encoded_url=aHR0cHM6...
    IF input_url ~ 'encoded_url=' THEN
        encoded_part := substring(input_url from 'encoded_url=([^&]+)');
        IF encoded_part IS NOT NULL THEN
            BEGIN
                decoded_url := convert_from(decode(encoded_part, 'base64'), 'UTF8');
                IF decoded_url ~ '^https?://' THEN
                    RETURN decoded_url;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                -- Continue to next pattern
            END;
        END IF;
    END IF;
    
    -- Pattern 2: URL parameter with encoded URL
    -- Example: redirect.com?url=https%3A//example.com
    IF input_url ~ '[?&]url=' THEN
        url_param := substring(input_url from '[?&]url=([^&]+)');
        IF url_param IS NOT NULL THEN
            decoded_url := uri_decode(url_param);
            IF decoded_url ~ '^https?://' THEN
                RETURN decoded_url;
            END IF;
        END IF;
    END IF;
    
    -- Pattern 3: Common redirect parameter names
    -- Try: target, destination, link, goto, redirect_to
    FOREACH url_param IN ARRAY ARRAY['target', 'destination', 'link', 'goto', 'redirect_to'] LOOP
        IF input_url ~ ('[?&]' || url_param || '=') THEN
            decoded_url := substring(input_url from ('[?&]' || url_param || '=([^&]+)'));
            IF decoded_url IS NOT NULL THEN
                decoded_url := uri_decode(decoded_url);
                IF decoded_url ~ '^https?://' THEN
                    RETURN decoded_url;
                END IF;
            END IF;
        END IF;
    END LOOP;
    
    -- Pattern 4: Apple News special handling
    IF input_url ~ 'apple\.news/' THEN
        -- Apple News URLs need special handling - return as-is for now
        -- Could potentially use Apple News API if available
        RETURN input_url;
    END IF;
    
    RETURN NULL; -- No decoding pattern matched
END;
$$ LANGUAGE plpgsql;
```

### Phase 3: Robust HTML Parsing
**Enhanced Metadata Extraction:**

```sql
CREATE OR REPLACE FUNCTION extract_title_from_html(html_content TEXT)
RETURNS TEXT AS $$
DECLARE
    title_text TEXT;
    clean_title TEXT;
BEGIN
    -- Try multiple title extraction methods
    
    -- Method 1: <title> tag
    title_text := extract_tag_content(html_content, 'title');
    
    -- Method 2: OpenGraph og:title
    IF title_text IS NULL OR length(trim(title_text)) = 0 THEN
        title_text := extract_meta_property(html_content, 'og:title');
    END IF;
    
    -- Method 3: Twitter title
    IF title_text IS NULL OR length(trim(title_text)) = 0 THEN
        title_text := extract_meta_name(html_content, 'twitter:title');
    END IF;
    
    -- Method 4: First <h1> tag
    IF title_text IS NULL OR length(trim(title_text)) = 0 THEN
        title_text := extract_tag_content(html_content, 'h1');
    END IF;
    
    -- Clean up the title
    IF title_text IS NOT NULL THEN
        clean_title := trim(title_text);
        clean_title := regexp_replace(clean_title, '\s+', ' ', 'g');
        clean_title := regexp_replace(clean_title, '[\r\n\t]', ' ', 'g');
        
        -- Limit length
        IF length(clean_title) > 200 THEN
            clean_title := left(clean_title, 197) || '...';
        END IF;
        
        RETURN clean_title;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Helper function for tag content extraction
CREATE OR REPLACE FUNCTION extract_tag_content(html TEXT, tag_name TEXT)
RETURNS TEXT AS $$
DECLARE
    pattern TEXT;
    content TEXT;
BEGIN
    pattern := '<' || tag_name || '[^>]*>(.*?)</' || tag_name || '>';
    content := substring(html from pattern for 1);
    
    -- Remove HTML entities and clean up
    IF content IS NOT NULL THEN
        content := replace(content, '&amp;', '&');
        content := replace(content, '&lt;', '<');
        content := replace(content, '&gt;', '>');
        content := replace(content, '&quot;', '"');
        content := replace(content, '&#39;', '''');
        content := trim(content);
    END IF;
    
    RETURN content;
END;
$$ LANGUAGE plpgsql;
```

### Phase 4: Asynchronous Processing
**Background Metadata Resolution:**

```sql
-- Create a queue table for URL resolution
CREATE TABLE IF NOT EXISTS url_resolution_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    link_id UUID REFERENCES links(id) ON DELETE CASCADE,
    raw_url TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    attempts INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending', -- pending, processing, completed, failed
    resolved_url TEXT,
    resolved_title TEXT,
    resolved_description TEXT,
    error_message TEXT
);

-- Background processing function
CREATE OR REPLACE FUNCTION process_url_resolution_queue()
RETURNS INTEGER AS $$
DECLARE
    queue_item RECORD;
    resolution_result RECORD;
    processed_count INTEGER := 0;
BEGIN
    -- Process up to 10 items at a time
    FOR queue_item IN 
        SELECT * FROM url_resolution_queue 
        WHERE status = 'pending' 
        AND attempts < 3
        ORDER BY created_at ASC
        LIMIT 10
    LOOP
        -- Update status to processing
        UPDATE url_resolution_queue 
        SET status = 'processing', attempts = attempts + 1
        WHERE id = queue_item.id;
        
        BEGIN
            -- Resolve the URL
            SELECT * INTO resolution_result 
            FROM resolve_redirect_chain(queue_item.raw_url);
            
            -- Update the original link
            UPDATE links 
            SET 
                resolved_url = resolution_result.final_url,
                title = COALESCE(resolution_result.resolved_title, title),
                description = COALESCE(resolution_result.resolved_description, description)
            WHERE id = queue_item.link_id;
            
            -- Mark as completed
            UPDATE url_resolution_queue
            SET 
                status = 'completed',
                resolved_url = resolution_result.final_url,
                resolved_title = resolution_result.resolved_title,
                resolved_description = resolution_result.resolved_description
            WHERE id = queue_item.id;
            
            processed_count := processed_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            -- Mark as failed
            UPDATE url_resolution_queue
            SET 
                status = 'failed',
                error_message = SQLERRM
            WHERE id = queue_item.id;
        END;
    END LOOP;
    
    RETURN processed_count;
END;
$$ LANGUAGE plpgsql;
```

### Phase 5: Integration with Existing System
**Modified Trigger for Queue-Based Processing:**

```sql
-- Replace the immediate metadata trigger with queue-based processing
DROP TRIGGER IF EXISTS trg_fetch_metadata ON links;

CREATE OR REPLACE FUNCTION queue_metadata_extraction()
RETURNS TRIGGER AS $$
BEGIN
    -- Only queue for processing if we have a URL and no title
    IF NEW.raw_url IS NOT NULL 
       AND trim(NEW.raw_url) != '' 
       AND (NEW.title IS NULL OR trim(NEW.title) = '') THEN
        
        INSERT INTO url_resolution_queue (link_id, raw_url)
        VALUES (NEW.id, NEW.raw_url);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_queue_metadata
    AFTER INSERT ON links 
    FOR EACH ROW
    EXECUTE FUNCTION queue_metadata_extraction();
```

## Testing Strategy
1. **Test specific redirect patterns**:
   - Newsletter tracking URLs  
   - Email campaign redirects
   - Apple News links
   - Social media shorteners

2. **Performance testing**:
   - Queue processing speed
   - Memory usage with large batches
   - Error recovery scenarios

3. **Integration testing**:
   - App shows loading states
   - Metadata updates in real-time
   - Failed resolutions handled gracefully 