-- Fix the fetch_url_metadata function to handle NULL URLs properly
-- Run this in your Supabase SQL Editor

-- First, drop the existing function if it exists
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Create the corrected function
CREATE OR REPLACE FUNCTION fetch_url_metadata()
RETURNS TRIGGER AS $$
DECLARE
    response_data TEXT;
    page_title TEXT;
    page_description TEXT;
    clean_url TEXT;
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
        
        -- If we got content, try to extract title and description
        IF response_data IS NOT NULL AND length(response_data) > 0 THEN
            -- Extract title using regex
            page_title := substring(response_data FROM '<title[^>]*>([^<]+)</title>');
            
            -- Extract description from meta tag
            page_description := substring(response_data FROM '<meta[^>]*name=["\']description["\'][^>]*content=["\']([^"'']+)["\'][^>]*>');
            
            -- Alternative description extraction
            IF page_description IS NULL THEN
                page_description := substring(response_data FROM '<meta[^>]*content=["\']([^"'']+)["\'][^>]*name=["\']description["\'][^>]*>');
            END IF;
            
            -- Clean up extracted text (remove extra whitespace, decode HTML entities)
            IF page_title IS NOT NULL THEN
                page_title := trim(regexp_replace(page_title, '\s+', ' ', 'g'));
                -- Limit title length
                IF length(page_title) > 200 THEN
                    page_title := left(page_title, 197) || '...';
                END IF;
            END IF;
            
            IF page_description IS NOT NULL THEN
                page_description := trim(regexp_replace(page_description, '\s+', ' ', 'g'));
                -- Limit description length
                IF length(page_description) > 500 THEN
                    page_description := left(page_description, 497) || '...';
                END IF;
            END IF;
            
            -- Update the NEW record with extracted metadata
            NEW.title := COALESCE(page_title, NEW.title);
            NEW.description := COALESCE(page_description, NEW.description);
            
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