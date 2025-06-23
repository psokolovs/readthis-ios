-- IMMEDIATE METADATA FIX
-- Test on existing problematic URLs first, then apply to all links

-- Step 1: URL Decoder Function
CREATE OR REPLACE FUNCTION decode_tracking_url(input_url TEXT)
RETURNS TEXT AS $$
DECLARE
    decoded_url TEXT;
    encoded_part TEXT;
    url_param TEXT;
BEGIN
    -- Pattern 1: Base64 encoded URLs in 'encoded_url' parameter
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
                NULL;
            END;
        END IF;
    END IF;
    
    -- Pattern 2: URL-encoded 'url' parameter
    -- Example: redirect.com?url=https%3A//example.com
    IF input_url ~ '[?&]url=' THEN
        url_param := substring(input_url from '[?&]url=([^&]+)');
        IF url_param IS NOT NULL THEN
            BEGIN
                decoded_url := url_decode(url_param);
                IF decoded_url ~ '^https?://' THEN
                    RETURN decoded_url;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
    END IF;
    
    -- Pattern 3: Common redirect parameter names
    DECLARE
        param_names TEXT[] := ARRAY['target', 'destination', 'link', 'goto', 'redirect_to', 'u'];
        param_name TEXT;
    BEGIN
        FOREACH param_name IN ARRAY param_names LOOP
            IF input_url ~ ('[?&]' || param_name || '=') THEN
                url_param := substring(input_url from ('[?&]' || param_name || '=([^&]+)'));
                IF url_param IS NOT NULL THEN
                    BEGIN
                        decoded_url := url_decode(url_param);
                        IF decoded_url ~ '^https?://' THEN
                            RETURN decoded_url;
                        END IF;
                    EXCEPTION WHEN OTHERS THEN
                        NULL;
                    END;
                END IF;
            END IF;
        END LOOP;
    END;
    
    RETURN input_url; -- Return original if no patterns matched
END;
$$ LANGUAGE plpgsql;

-- Step 2: Enhanced Redirect Following Function
CREATE OR REPLACE FUNCTION resolve_redirect_chain(input_url TEXT, max_redirects INTEGER DEFAULT 3)
RETURNS TABLE(final_url TEXT, final_title TEXT, final_description TEXT) AS $$
DECLARE
    current_url TEXT;
    redirect_count INTEGER := 0;
    response_record RECORD;
    location_header TEXT;
    page_title TEXT;
    page_description TEXT;
    headers_json JSONB;
BEGIN
    -- Start with decoded URL
    current_url := decode_tracking_url(input_url);
    
    -- Follow redirect chain
    WHILE redirect_count < max_redirects LOOP
        BEGIN
            -- Make HTTP request
            SELECT * INTO response_record FROM http_get(current_url);
            
            -- Check for redirect (3xx status codes)
            IF response_record.status >= 300 AND response_record.status < 400 THEN
                -- Try to extract Location header
                headers_json := response_record.headers;
                
                -- Look for Location header (case variations)
                location_header := COALESCE(
                    headers_json->>'Location',
                    headers_json->>'location',
                    headers_json->>'LOCATION'
                );
                
                IF location_header IS NOT NULL AND location_header != '' THEN
                    -- Handle relative URLs
                    IF location_header ~ '^https?://' THEN
                        current_url := location_header;
                    ELSE
                        -- Construct absolute URL from relative
                        current_url := regexp_replace(current_url, '(https?://[^/]+).*', '\1') || location_header;
                    END IF;
                    
                    redirect_count := redirect_count + 1;
                    CONTINUE;
                END IF;
            END IF;
            
            -- Success response (2xx) - extract metadata
            IF response_record.status >= 200 AND response_record.status < 300 AND response_record.content IS NOT NULL THEN
                page_title := extract_title_from_html(response_record.content);
                page_description := extract_description_from_html(response_record.content);
                
                RETURN QUERY SELECT current_url, page_title, page_description;
                RETURN;
            END IF;
            
            -- Failed response - exit
            EXIT;
            
        EXCEPTION WHEN OTHERS THEN
            -- Exit on any error
            EXIT;
        END;
    END LOOP;
    
    -- Return original URL if all failed
    RETURN QUERY SELECT input_url, NULL::TEXT, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Enhanced HTML parsing functions
CREATE OR REPLACE FUNCTION extract_title_from_html(html_content TEXT)
RETURNS TEXT AS $$
DECLARE
    title_text TEXT;
    clean_title TEXT;
BEGIN
    -- Method 1: <title> tag
    title_text := (regexp_matches(html_content, '<title[^>]*>(.*?)</title>', 'i'))[1];
    
    -- Method 2: OpenGraph og:title if no title found
    IF title_text IS NULL OR trim(title_text) = '' THEN
        title_text := (regexp_matches(html_content, '<meta[^>]*property=["\']og:title["\'][^>]*content=["\']([^"\']*)["\']', 'i'))[1];
    END IF;
    
    -- Method 3: Twitter title
    IF title_text IS NULL OR trim(title_text) = '' THEN
        title_text := (regexp_matches(html_content, '<meta[^>]*name=["\']twitter:title["\'][^>]*content=["\']([^"\']*)["\']', 'i'))[1];
    END IF;
    
    -- Clean up the title
    IF title_text IS NOT NULL THEN
        clean_title := trim(title_text);
        -- Remove HTML entities
        clean_title := replace(clean_title, '&amp;', '&');
        clean_title := replace(clean_title, '&lt;', '<');
        clean_title := replace(clean_title, '&gt;', '>');
        clean_title := replace(clean_title, '&quot;', '"');
        clean_title := replace(clean_title, '&#39;', '''');
        -- Clean whitespace
        clean_title := regexp_replace(clean_title, '\s+', ' ', 'g');
        clean_title := trim(clean_title);
        
        -- Limit length
        IF length(clean_title) > 200 THEN
            clean_title := left(clean_title, 197) || '...';
        END IF;
        
        RETURN clean_title;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION extract_description_from_html(html_content TEXT)
RETURNS TEXT AS $$
DECLARE
    desc_text TEXT;
    clean_desc TEXT;
BEGIN
    -- Method 1: meta name="description"
    desc_text := (regexp_matches(html_content, '<meta[^>]*name=["\']description["\'][^>]*content=["\']([^"\']*)["\']', 'i'))[1];
    
    -- Method 2: OpenGraph og:description
    IF desc_text IS NULL OR trim(desc_text) = '' THEN
        desc_text := (regexp_matches(html_content, '<meta[^>]*property=["\']og:description["\'][^>]*content=["\']([^"\']*)["\']', 'i'))[1];
    END IF;
    
    -- Clean up description
    IF desc_text IS NOT NULL THEN
        clean_desc := trim(desc_text);
        -- Remove HTML entities
        clean_desc := replace(clean_desc, '&amp;', '&');
        clean_desc := replace(clean_desc, '&lt;', '<');
        clean_desc := replace(clean_desc, '&gt;', '>');
        clean_desc := replace(clean_desc, '&quot;', '"');
        clean_desc := replace(clean_desc, '&#39;', '''');
        -- Clean whitespace
        clean_desc := regexp_replace(clean_desc, '\s+', ' ', 'g');
        clean_desc := trim(clean_desc);
        
        -- Limit length
        IF length(clean_desc) > 300 THEN
            clean_desc := left(clean_desc, 297) || '...';
        END IF;
        
        RETURN clean_desc;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Step 4: TEST ON YOUR ACTUAL PROBLEMATIC URLs
-- Let's decode your exact examples:

-- Test 1: Marginal Revolution with base64 encoded URL
SELECT 
    'Original' as type,
    'http://marginalrevolution.com/?action=user_content_redirect&uuid=529ad41c6c872c53c73fe2334d0805d924a95757e4acd8e29d71386fc05e1065&blog_id=42693868&post_id=90026&user_id=134837436&subs_id=225325616&signature=211b801b2e6e2e9c3c1aaaaf86fd2a08&email_name=new-post&user_email=psokolovs@gmail.com&encoded_url=aHR0cHM6Ly9wYXBlcnMuc3Nybi5jb20vc29sMy9wYXBlcnMuY2ZtP2Fic3RyYWN0X2lkPTUwNjIwNDk' as url
UNION ALL
SELECT 
    'Decoded' as type,
    decode_tracking_url('http://marginalrevolution.com/?action=user_content_redirect&uuid=529ad41c6c872c53c73fe2334d0805d924a95757e4acd8e29d71386fc05e1065&blog_id=42693868&post_id=90026&user_id=134837436&subs_id=225325616&signature=211b801b2e6e2e9c3c1aaaaf86fd2a08&email_name=new-post&user_email=psokolovs@gmail.com&encoded_url=aHR0cHM6Ly9wYXBlcnMuc3Nybi5jb20vc29sMy9wYXBlcnMuY2ZtP2Fic3RyYWN0X2lkPTUwNjIwNDk') as url;

-- Test 2: Ben Evans newsletter link
SELECT 
    'Original' as type,
    'https://ben-evans.us6.list-manage.com/track/click?u=b98e2de85f03865f1d38de74f&id=54cb67d680&e=af935a5736' as url
UNION ALL
SELECT 
    'Decoded' as type,
    decode_tracking_url('https://ben-evans.us6.list-manage.com/track/click?u=b98e2de85f03865f1d38de74f&id=54cb67d680&e=af935a5736') as url;

-- Step 5: Full metadata resolution test on one URL
SELECT * FROM resolve_redirect_chain(
    'http://marginalrevolution.com/?action=user_content_redirect&uuid=529ad41c6c872c53c73fe2334d0805d924a95757e4acd8e29d71386fc05e1065&blog_id=42693868&post_id=90026&user_id=134837436&subs_id=225325616&signature=211b801b2e6e2e9c3c1aaaaf86fd2a08&email_name=new-post&user_email=psokolovs@gmail.com&encoded_url=aHR0cHM6Ly9wYXBlcnMuc3Nybi5jb20vc29sMy9wYXBlcnMuY2ZtP2Fic3RyYWN0X2lkPTUwNjIwNDk'
); 