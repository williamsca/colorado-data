#!/usr/bin/env python3
import csv
import os
import sys
import subprocess
from pathlib import Path

def get_annual_report_path(year):
    """Get the path to the annual report PDF for a given year."""
    data_dir = Path("data/annual-reports")
    
    # First try to find an exact match
    for pdf_file in data_dir.glob(f"*{year}*.pdf"):
        return pdf_file
    
    print(f"Warning: Could not find annual report for {year}")
    return None

def process_pages(csv_path):
    """
    Process the pages CSV file and extract target tables for each year.
    
    Args:
        csv_path (str): Path to the CSV file containing page information
    """
    csv_path = Path(csv_path)
    
    if not csv_path.exists():
        print(f"Error: File not found - {csv_path}")
        return
    
    print(f"Processing pages from {csv_path}")
    
    # Extract directory name from CSV filename
    dir_name = csv_path.stem
    if "-pages" in dir_name:
        dir_name = dir_name.replace("-pages", "")
    
    print(f"Output directory will be: data/{dir_name}")
    
    with open(csv_path, 'r') as f:
        csv_reader = csv.DictReader(f)
        
        for row in csv_reader:
            year = row.get('year')
            pages = row.get('page')
            orientation = row.get('orientation')
            
            if not year or not pages:
                continue

            if not orientation:
                orientation = 0
            
            try:
                year = year.strip()
                annual_report_path = get_annual_report_path(year)
                
                if not annual_report_path:
                    continue
                
                # Handle multi-page tables
                page_ranges = pages.split(',')
                
                for i, page_range in enumerate(page_ranges):
                    # Handle ranges like "404-405"
                    if '-' in page_range:
                        start_page, end_page = map(int, page_range.split('-'))
                        for j, page_num in enumerate(range(start_page, end_page + 1)):
                            # Use 'a', 'b', etc. as suffix for multiple pages
                            suffix = chr(97 + j) if (end_page - start_page) > 0 else ""
                            
                            # Call extract_target_table_pdf.py with the page number and suffix
                            cmd = [
                                "python3", 
                                "program/databuild/extract_target_table_pdf.py", 
                                str(annual_report_path), 
                                str(page_num),
                                suffix,
                                dir_name,
                                str(orientation)
                            ]
                            
                            print(f"Extracting {year} page {page_num} with suffix '{suffix}' to {dir_name}/")
                            subprocess.run(cmd)
                    else:
                        # Single page
                        page_num = int(page_range)
                        
                        # Use 'a', 'b', etc. as suffix if there are multiple page ranges
                        suffix = chr(97 + i) if len(page_ranges) > 1 else ""
                        
                        cmd = [
                            "python3", 
                            "program/databuild/extract_target_table_pdf.py", 
                            str(annual_report_path), 
                            str(page_num),
                            suffix,
                            dir_name,
                            str(orientation)
                        ]
                        
                        print(f"Extracting {year} page {page_num} with suffix '{suffix}' to {dir_name}/")
                        subprocess.run(cmd)
                        
            except Exception as e:
                print(f"Error processing year {year}, pages {pages}: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        csv_path = sys.argv[1]
    else:
        print("Usage: python process_pages.py <csv_file_path>")
        print("Example: python process_pages.py crosswalk/county-valuation-pages.csv")
        sys.exit(1)
    
    process_pages(csv_path)