from textractor import Textractor
from textractor.data.constants import TextractFeatures
from pathlib import Path
import time
import os
import boto3
import pandas as pd
import sys

def extract_tables(dir_name):
    """
    Extract tables from PDFs using Amazon Textract.
    
    Args:
        dir_name (str): Name of the directory containing PDFs in S3 and where to save results
    """
    # Set paths
    project_root = Path(__file__).resolve().parent.parent.parent
    output_dir = project_root / "derived" / dir_name
    output_dir.mkdir(exist_ok=True, parents=True)
    
    s3_bucket = "colorado-data-bucket"
    s3_client = boto3.client('s3')
    
    # Get list of all PDFs in S3 bucket
    try:
        response = s3_client.list_objects_v2(Bucket=s3_bucket, Prefix=f"{dir_name}/")
        
        if 'Contents' not in response:
            print(f"No PDFs found in S3 bucket under prefix {dir_name}/")
            return
            
        pdf_keys = [obj['Key'] for obj in response['Contents'] if obj['Key'].endswith('.pdf')]
        
        if not pdf_keys:
            print(f"No PDFs found in S3 bucket under prefix {dir_name}/")
            return
            
        print(f"Found {len(pdf_keys)} PDFs in S3 bucket under prefix {dir_name}/")
        
        # Initialize Textract client
        print("Initializing Textractor...")
        extractor = Textractor(profile_name="default")
        
        # Process each PDF
        successful = []
        failed = []
        
        for s3_key in pdf_keys:
            year = s3_key.split('/')[-1].split('.')[0]  # Extract year/part from filename
            s3_uri = f"s3://{s3_bucket}/{s3_key}"
            excel_output_path = output_dir / f"{year}.xlsx"
            
            # Skip if Excel file already exists
            if excel_output_path.exists():
                print(f"Excel file for {year} already exists at {excel_output_path}")
                successful.append(year)
                continue
                
            print(f"\nProcessing {year} PDF at {s3_uri}")
            
            try:
                # Start asynchronous document analysis
                print(f"Starting Textract analysis on {s3_uri}")
                job = extractor.start_document_analysis(
                    file_source=s3_uri, 
                    features=[TextractFeatures.TABLES, TextractFeatures.FORMS], 
                    save_image=False
                )
                
                # Set timeout parameters
                max_wait_time = 900  # 15 minutes
                wait_time = 0
                poll_interval = 60  # Check status every 60 seconds
                
                # Wait for job to complete
                print("Waiting for Textract job to complete...")
                response = extractor.textract_client.get_document_analysis(JobId=job.job_id)
                status = response["JobStatus"]
                
                while status != "SUCCEEDED" and wait_time < max_wait_time:
                    if status in ["FAILED", "ERROR"]:
                        raise Exception(f"Textract job failed with status: {status}")
                    
                    print(f"Current status: {status}. Waiting {poll_interval} seconds...")
                    time.sleep(poll_interval)
                    wait_time += poll_interval
                    
                    response = extractor.textract_client.get_document_analysis(JobId=job.job_id)
                    status = response["JobStatus"]
                    
                    print(f"Still waiting... (elapsed time: {wait_time}s)")
                
                if wait_time >= max_wait_time:
                    raise Exception("Textract job timed out")
                
                if status == "SUCCEEDED":
                    print("Job completed, exporting tables to Excel...")
                    
                    # Check if tables were extracted
                    if not job.tables:
                        print(f"Warning: No tables found in {year} PDF")
                        
                    # Export tables to Excel
                    job.export_tables_to_excel(excel_output_path)
                    print(f"Successfully exported {len(job.tables)} tables to {excel_output_path}")
                                    
                    successful.append(year)
            
            except Exception as e:
                print(f"Error processing {year} PDF: {e}")
                failed.append(year)
        
        # Print summary
        print("\nExtraction Summary:")
        print(f"Successfully processed: {len(successful)} files")
        print(f"Failed: {len(failed)} files")
        
        if failed:
            print("Failed files:")
            for year in failed:
                print(f"  - {year}")
                
    except Exception as e:
        print(f"Error listing objects in S3 bucket: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ocr_tables.py <directory_name>")
        print("Example: python ocr_tables.py mill-levies")
        print("Directory name should match the prefix used in S3 and will be used for the output directory in derived/")
        sys.exit(1)
    
    dir_name = sys.argv[1]
    extract_tables(dir_name)
