from textractor import Textractor
from textractor.data.constants import TextractFeatures
from pathlib import Path
import pandas as pd
import csv
import time
import boto3
import os
from botocore.exceptions import ClientError

# Set paths
current_dir = Path(__file__).resolve().parent.parent
pdf_path = current_dir / "data" / "1980 Tenth Annual Report to the Governor and the General Assembly.pdf"
output_dir = current_dir / "derived"

# Create subfolder for tables
tables_dir = output_dir / "reports-1980"
tables_dir.mkdir(exist_ok=True)

# S3 bucket for Textract processing
s3_bucket = "colorado-data-bucket"
s3_key = "pdfs/annual_report_1980.pdf"
s3_uri = f"s3://{s3_bucket}/{s3_key}"

# Initialize Textractor
print("Initializing Textractor...")
extractor = Textractor(profile_name="default")

try:
    # Start asynchronous document analysis using S3 location
    print(f"Starting Textract analysis on {s3_uri}")
    job = extractor.start_document_analysis(
        file_source=s3_uri,
        features=[TextractFeatures.TABLES]
    )
    
    # Poll for job completion with timeout
    max_wait_time = 900  # 15 minutes
    wait_time = 0
    poll_interval = 15
    
    print("Waiting for Textract job to complete...")
    while job.check_status() != "SUCCEEDED" and wait_time < max_wait_time:
        print(f"Waiting... ({wait_time} seconds elapsed)")
        time.sleep(poll_interval)
        wait_time += poll_interval
    
    if wait_time >= max_wait_time:
        print("Warning: Job did not complete within timeout period")
        print("Saving job ID for later retrieval")
        
        # Save job ID to file for later retrieval
        with open(tables_dir / "textract_job_id.txt", "w") as f:
            f.write(job.job_id)
        print(f"Job ID saved to {tables_dir}/textract_job_id.txt")
        exit(0)
    
    # Get the results
    print("Job completed, retrieving results...")
    document = job.get_document()
    print(f"Successfully analyzed document with {len(document.pages)} pages")
    
    # Initialize variables to track the target table
    target_table = None
    target_table_keywords = ["improved", "residential", "land", "assessed", "value", "parcels"]
    
    # Process each page and look for the target table
    for i, page in enumerate(document.pages):
        print(f"Processing page {i+1}")
        for j, table in enumerate(page.tables):
            # Convert table to DataFrame
            rows = []
            for row in table.rows:
                cells = [cell.text for cell in row.cells]
                rows.append(cells)
                
            if not rows:  # Skip empty tables
                continue
                
            df = pd.DataFrame(rows)
            
            # Output table for debugging
            print(f"Table {j+1} on page {i+1}:")
            print(df.head())
            
            # Save all tables to the subfolder
            csv_path = tables_dir / f"table_page{i+1}_num{j+1}.csv"
            df.to_csv(csv_path, index=False, quoting=csv.QUOTE_ALL)
            print(f"Saved table from page {i+1} to {csv_path}")
            
            # Check both header row and all cells for keywords
            table_text = " ".join([" ".join([str(x).lower() for x in row]) for row in rows])
            print(f"Table text (sample): {table_text[:100]}...")  # Print truncated for readability
            match_count = sum(1 for kw in target_table_keywords if kw in table_text)
            print(f"Keywords matched: {match_count}")
            
            if match_count >= 2:  # If at least 2 keywords match, consider it the target
                print(f"Found potential target table on page {i+1}")
                # Save to CSV in both places - main folder and subfolder
                target_csv_path = output_dir / "residential_assessed_values.csv"
                df.to_csv(target_csv_path, index=False, quoting=csv.QUOTE_ALL)
                print(f"Saved target table to {target_csv_path}")
                target_table = df
            
    if target_table is None:
        print("Target table with residential assessed values not found in automatic search.")
        print("Please check the extracted tables in the reports-1980 folder.")
            
except Exception as e:
    print(f"Error: {e}")