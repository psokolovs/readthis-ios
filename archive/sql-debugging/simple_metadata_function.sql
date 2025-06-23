-- Simple version without HTTP calls - use this if HTTP extension is not available
-- Run this in your Supabase SQL Editor

-- Drop the existing function
DROP FUNCTION IF EXISTS fetch_url_metadata();

-- Create a simple version that just validates the URL without fetching
CREATE OR REPLACE FUNCTION fetch_url_metadata()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if raw_url is NULL or empty
    IF NEW.raw_url IS NULL OR NEW.raw_url = '' THEN
        RAISE LOG 'fetch_url_metadata: raw_url is NULL or empty, skipping';
        RETURN NEW;
    END IF;
    
    -- Just log the URL for debugging
    RAISE LOG 'fetch_url_metadata: Processing URL: %', NEW.raw_url;
    
    -- Set default values if not provided
    IF NEW.title IS NULL THEN
        NEW.title := 'Untitled';
    END IF;
    
    IF NEW.description IS NULL THEN
        NEW.description := 'No description available';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql; 