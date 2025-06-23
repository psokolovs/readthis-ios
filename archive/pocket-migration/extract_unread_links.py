#!/usr/bin/env python3
"""
Extract unread links from Pocket CSV exports and save to a new file.
"""

import csv
import os
from datetime import datetime

def extract_unread_links():
    """Extract all unread links from pocket CSV files."""
    
    pocket_dir = "pocket"
    csv_files = ["part_000000.csv", "part_000001.csv"]
    
    unread_links = []
    total_unread = 0
    
    print("Extracting unread links from Pocket exports...")
    print("=" * 50)
    
    for csv_file in csv_files:
        file_path = os.path.join(pocket_dir, csv_file)
        
        if not os.path.exists(file_path):
            print(f"Warning: {file_path} not found, skipping...")
            continue
            
        print(f"Processing {csv_file}...")
        
        file_unread = 0
        
        try:
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                # Use csv.reader to handle the malformed CSV properly
                reader = csv.reader(f)
                
                # Skip header if it exists
                try:
                    header = next(reader)
                    if header[0] == 'title':
                        print(f"  Header found: {header}")
                    else:
                        # Reset file if first line wasn't header
                        f.seek(0)
                except StopIteration:
                    continue
                
                for row_num, row in enumerate(reader, 1):
                    # Handle rows with different lengths due to CSV formatting issues
                    if len(row) >= 5:  # title, url, time_added, tags, status
                        title, url, time_added, tags, status = row[:5]
                        
                        if status.strip() == 'unread':
                            unread_links.append({
                                'title': title.strip(),
                                'url': url.strip(),
                                'time_added': time_added.strip(),
                                'tags': tags.strip(),
                                'status': status.strip(),
                                'source_file': csv_file
                            })
                            file_unread += 1
                    
                    elif len(row) == 1 and row[0].strip() == 'unread':
                        # Handle cases where 'unread' appears on its own line
                        # This might be part of a wrapped CSV entry
                        continue
                    
                    # Log problematic rows for debugging
                    if len(row) < 5 and len(row) > 0:
                        if row_num <= 10:  # Only log first 10 problematic rows
                            print(f"  Warning: Row {row_num} has {len(row)} columns: {row}")
        
        except Exception as e:
            print(f"Error processing {csv_file}: {e}")
            continue
            
        print(f"  Found {file_unread} unread links in {csv_file}")
        total_unread += file_unread
    
    print("=" * 50)
    print(f"Total unread links found: {total_unread}")
    
    # Save unread links to new CSV file
    output_file = "pocket_unread_links.csv"
    
    if unread_links:
        with open(output_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            
            # Write header
            writer.writerow(['title', 'url', 'time_added', 'tags', 'status', 'source_file'])
            
            # Write unread links
            for link in unread_links:
                writer.writerow([
                    link['title'],
                    link['url'],
                    link['time_added'], 
                    link['tags'],
                    link['status'],
                    link['source_file']
                ])
        
        print(f"✅ Unread links saved to: {output_file}")
        
        # Show some sample entries
        print("\nSample unread links:")
        print("-" * 50)
        for i, link in enumerate(unread_links[:5]):
            timestamp = datetime.fromtimestamp(int(link['time_added'])) if link['time_added'].isdigit() else 'Invalid timestamp'
            print(f"{i+1}. {link['title'][:60]}...")
            print(f"   URL: {link['url'][:80]}...")
            print(f"   Added: {timestamp}")
            print()
    
    else:
        print("❌ No unread links found!")
    
    return total_unread

if __name__ == "__main__":
    count = extract_unread_links()
    print(f"\n🎯 Summary: {count} unread links extracted and saved to pocket_unread_links.csv") 