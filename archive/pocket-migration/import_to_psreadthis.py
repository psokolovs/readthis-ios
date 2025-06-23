#!/usr/bin/env python3
"""
Import unread Pocket links to PSReadThis Supabase database.
"""

import csv
import json
import requests
import uuid
from datetime import datetime
from typing import List, Dict, Optional
import time

# PSReadThis Supabase Configuration
SUPABASE_URL = "https://ijdtwrsqgbwfgftckywm.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlqZHR3cnNxZ2J3ZmdmdGNreXdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwOTI0MjUsImV4cCI6MjA2NDY2ODQyNX0.xRydYO7gkOQaU-tec-q3f5sqa0OF9j5LEzu1OvNRx_U"
USER_ID = "3ad801b9-b41d-4cca-a5ba-2065a1d6ce97"  # From existing test files

class PSReadThisImporter:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'apikey': SUPABASE_ANON_KEY,
            'Authorization': f'Bearer {SUPABASE_ANON_KEY}',
            'Prefer': 'return=representation'
        })
        self.endpoint = f"{SUPABASE_URL}/rest/v1/links"
        
    def unix_to_iso(self, unix_timestamp: str) -> str:
        """Convert Unix timestamp to ISO format for PostgreSQL."""
        try:
            if unix_timestamp and unix_timestamp.isdigit():
                dt = datetime.fromtimestamp(int(unix_timestamp))
                return dt.isoformat() + "+00:00"  # Add timezone
        except (ValueError, OSError):
            pass
        # Fallback to current time if timestamp is invalid
        return datetime.now().isoformat() + "+00:00"
    
    def prepare_link_data(self, pocket_link: Dict) -> Dict:
        """Convert pocket link data to PSReadThis format."""
        link_id = str(uuid.uuid4())
        
        return {
            "id": link_id,
            "user_id": USER_ID,
            "raw_url": pocket_link['url'],
            "resolved_url": None,  # Will be populated by metadata function
            "title": pocket_link['title'] if pocket_link['title'] else None,
            "list": "read",  # PSReadThis uses "read" for the list field
            "status": "unread",  # These are unread links
            "device_saved": "import_script",
            "created_at": self.unix_to_iso(pocket_link['time_added'])
        }
    
    def test_connection(self) -> bool:
        """Test connection to Supabase."""
        print("🔍 Testing Supabase connection...")
        try:
            response = self.session.get(f"{self.endpoint}?select=count&limit=1")
            if response.status_code == 200:
                print("✅ Connection successful!")
                return True
            else:
                print(f"❌ Connection failed: {response.status_code}")
                print(f"Response: {response.text}")
                return False
        except Exception as e:
            print(f"❌ Connection error: {e}")
            return False
    
    def batch_insert(self, links: List[Dict], batch_size: int = 50) -> Dict:
        """Insert links in batches."""
        results = {
            'success': 0,
            'failed': 0,
            'errors': []
        }
        
        total_batches = (len(links) + batch_size - 1) // batch_size
        
        for i in range(0, len(links), batch_size):
            batch = links[i:i + batch_size]
            batch_num = (i // batch_size) + 1
            
            print(f"📦 Processing batch {batch_num}/{total_batches} ({len(batch)} links)...")
            
            try:
                response = self.session.post(self.endpoint, json=batch)
                
                if response.status_code in [200, 201]:
                    results['success'] += len(batch)
                    print(f"✅ Batch {batch_num} successful!")
                else:
                    results['failed'] += len(batch)
                    error_msg = f"Batch {batch_num} failed: {response.status_code} - {response.text}"
                    results['errors'].append(error_msg)
                    print(f"❌ {error_msg}")
                    
                    # Try individual inserts for failed batch
                    print(f"🔄 Retrying batch {batch_num} individually...")
                    individual_results = self.individual_insert(batch)
                    results['success'] += individual_results['success']
                    results['failed'] -= individual_results['success']  # Adjust failed count
                    results['errors'].extend(individual_results['errors'])
                
            except Exception as e:
                results['failed'] += len(batch)
                error_msg = f"Batch {batch_num} exception: {str(e)}"
                results['errors'].append(error_msg)
                print(f"❌ {error_msg}")
            
            # Rate limiting - be nice to the API
            time.sleep(0.5)
        
        return results
    
    def individual_insert(self, links: List[Dict]) -> Dict:
        """Insert links one by one for failed batches."""
        results = {
            'success': 0,
            'failed': 0,
            'errors': []
        }
        
        for i, link in enumerate(links, 1):
            try:
                response = self.session.post(self.endpoint, json=[link])
                
                if response.status_code in [200, 201]:
                    results['success'] += 1
                    print(f"  ✅ Individual {i}/{len(links)}: {link['raw_url'][:50]}...")
                else:
                    results['failed'] += 1
                    error_msg = f"Individual {i} failed: {response.status_code} - {link['raw_url']}"
                    results['errors'].append(error_msg)
                    print(f"  ❌ {error_msg}")
                
                time.sleep(0.2)  # Slower for individual retries
                
            except Exception as e:
                results['failed'] += 1
                error_msg = f"Individual {i} exception: {str(e)} - {link['raw_url']}"
                results['errors'].append(error_msg)
                print(f"  ❌ {error_msg}")
        
        return results
    
    def load_pocket_csv(self, filename: str) -> List[Dict]:
        """Load pocket links from CSV file."""
        links = []
        
        print(f"📖 Loading links from {filename}...")
        
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row['status'] == 'unread':  # Double-check it's unread
                        links.append(row)
            
            print(f"✅ Loaded {len(links)} unread links")
            return links
            
        except Exception as e:
            print(f"❌ Error loading CSV: {e}")
            return []
    
    def show_sample_data(self, pocket_links: List[Dict], psreadthis_links: List[Dict]):
        """Display sample data for verification."""
        print("\n🔍 Sample Data Preview:")
        print("=" * 80)
        
        for i, (pocket, psreadthis) in enumerate(zip(pocket_links[:3], psreadthis_links[:3]), 1):
            print(f"\nSample {i}:")
            print(f"  Original: {pocket['title'][:50]}...")
            print(f"  URL: {pocket['url'][:60]}...")
            print(f"  Timestamp: {pocket['time_added']} → {psreadthis['created_at']}")
            print(f"  UUID: {psreadthis['id']}")
    
    def import_links(self, csv_filename: str = "pocket_unread_links.csv"):
        """Main import function."""
        print("🚀 PSReadThis Import Starting...")
        print("=" * 50)
        
        # Test connection first
        if not self.test_connection():
            print("❌ Cannot proceed without database connection")
            return
        
        # Load pocket data
        pocket_links = self.load_pocket_csv(csv_filename)
        if not pocket_links:
            print("❌ No links to import")
            return
        
        # Convert to PSReadThis format
        print(f"🔄 Converting {len(pocket_links)} links to PSReadThis format...")
        psreadthis_links = [self.prepare_link_data(link) for link in pocket_links]
        
        # Show sample data
        self.show_sample_data(pocket_links, psreadthis_links)
        
        # Confirm before import
        print(f"\n📋 Ready to import {len(psreadthis_links)} links")
        print("⚠️  This will add these links to your PSReadThis database")
        
        user_input = input("\nProceed with import? (y/N): ").strip().lower()
        if user_input != 'y':
            print("❌ Import cancelled")
            return
        
        # Perform import
        print(f"\n🔄 Starting batch import...")
        results = self.batch_insert(psreadthis_links)
        
        # Show results
        print("\n📊 Import Results:")
        print("=" * 50)
        print(f"✅ Successfully imported: {results['success']}")
        print(f"❌ Failed imports: {results['failed']}")
        print(f"📈 Success rate: {(results['success'] / len(psreadthis_links) * 100):.1f}%")
        
        if results['errors']:
            print(f"\n⚠️  Error Summary ({len(results['errors'])} errors):")
            for error in results['errors'][:10]:  # Show first 10 errors
                print(f"  - {error}")
            if len(results['errors']) > 10:
                print(f"  ... and {len(results['errors']) - 10} more errors")
        
        if results['success'] > 0:
            print(f"\n🎉 Import completed! {results['success']} links added to PSReadThis")
            print("💡 The PSReadThis app will automatically fetch titles and descriptions")

def main():
    importer = PSReadThisImporter()
    importer.import_links()

if __name__ == "__main__":
    main() 