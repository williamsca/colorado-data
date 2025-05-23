from pathlib import Path
import boto3
from botocore.exceptions import ClientError
import os
import time
import sys

def upload_pdfs(dir_name):
    """
    Upload PDFs to S3 bucket.
    
    Args:
        dir_name (str): Name of the directory containing PDFs to upload
    """
    project_root = Path(__file__).resolve().parent.parent.parent
    target_dir = project_root / "data" / "annual-reports" / dir_name
    
    # Create directory if it doesn't exist
    target_dir.mkdir(exist_ok=True, parents=True)
    
    s3_bucket = "colorado-data-bucket"
    s3_client = boto3.client('s3')
    
    # Get list of all PDFs
    pdf_files = list(target_dir.glob("*.pdf"))
    
    if not pdf_files:
        print(f"No PDFs found in {target_dir}")
        return
    
    print(f"Found {len(pdf_files)} PDFs in {dir_name}")
    
    # Track successful and failed uploads
    successful = []
    failed = []
    
    for pdf_path in pdf_files:
        year = pdf_path.stem  # Get the year from the filename
        s3_key = f"{dir_name}/{year}.pdf"
        s3_uri = f"s3://{s3_bucket}/{s3_key}"
        
        try:
            # Check if file already exists
            try:
                s3_client.head_object(Bucket=s3_bucket, Key=s3_key)
                print(f"PDF already exists at {s3_uri}")
                successful.append(year)
            except ClientError as e:
                if e.response['Error']['Code'] == '404':
                    # File doesn't exist, upload it
                    print(f"Uploading {pdf_path.name} to S3 bucket {s3_bucket}")
                    
                    # Implement retry logic
                    max_retries = 3
                    retry_delay = 2
                    
                    for attempt in range(max_retries):
                        try:
                            s3_client.upload_file(str(pdf_path), s3_bucket, s3_key)
                            print(f"PDF uploaded to {s3_uri}")
                            successful.append(year)
                            break
                        except Exception as upload_error:
                            if attempt < max_retries - 1:
                                print(f"Upload attempt {attempt+1} failed: {upload_error}")
                                print(f"Retrying in {retry_delay} seconds...")
                                time.sleep(retry_delay)
                                retry_delay *= 2  # Exponential backoff
                            else:
                                print(f"All upload attempts failed for {pdf_path.name}")
                                failed.append(year)
                                raise
                else:
                    print(f"Error checking if file exists: {e}")
                    failed.append(year)
        except Exception as e:
            print(f"Error processing {pdf_path.name}: {e}")
            failed.append(year)
    
    # Print summary
    print("\nUpload Summary:")
    print(f"Successfully uploaded/verified: {len(successful)} files")
    print(f"Failed: {len(failed)} files")
    
    if failed:
        print("Failed files:")
        for year in failed:
            print(f"  - {year}.pdf")
    
    # List objects in bucket
    try:
        response = s3_client.list_objects_v2(Bucket=s3_bucket, Prefix=f"{dir_name}/")
        print(f"\nObjects in {s3_bucket}/{dir_name}/:")
        if 'Contents' in response:
            for obj in response['Contents']:
                print(f"  {obj['Key']} ({obj['Size']} bytes)")
        else:
            print("  No objects found")
    except Exception as e:
        print(f"Error listing objects: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python upload_check.py <directory_name>")
        print("Example: python upload_check.py mill-levy")
        print("Directory name should refer to a subfolder in the data/ directory")
        sys.exit(1)
    
    dir_name = sys.argv[1]
    upload_pdfs(dir_name)
