from pathlib import Path
import boto3
from botocore.exceptions import ClientError

current_dir = Path(__file__).resolve().parent.parent
pdf_name = "1980 Tenth Annual Report to the Governor and the General Assembly.pdf"
pdf_path = current_dir / "data" / pdf_name

s3_bucket = "colorado-data-bucket"
s3_key = "pdfs/" + pdf_name
s3_uri = f"s3://{s3_bucket}/{s3_key}"

s3_client = boto3.client('s3')

try:
    try:
        s3_client.head_object(Bucket=s3_bucket, Key=s3_key)
        print(f"PDF already exists at {s3_uri}")
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            print(f"Uploading PDF to S3 bucket {s3_bucket}")
            s3_client.upload_file(str(pdf_path), s3_bucket, s3_key)
            print(f"PDF uploaded to {s3_uri}")
        else:
            print(f"Error: {e}")
            raise
            
    buckets = s3_client.list_buckets()
    print("Available buckets:")
    for bucket in buckets['Buckets']:
        print(f"  {bucket['Name']}")
        
    response = s3_client.list_objects_v2(Bucket=s3_bucket)
    print(f"Objects in {s3_bucket}:")
    if 'Contents' in response:
        for obj in response['Contents']:
            print(f"  {obj['Key']} ({obj['Size']} bytes)")
    else:
        print("  No objects found")

except Exception as e:
    print(f"Error: {e}")