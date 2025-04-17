from textractor import Textractor
from textractor.data.constants import TextractFeatures
from pathlib import Path
import time
import os

# Set paths
current_dir = Path(__file__).resolve().parent.parent
output_dir = current_dir / "derived" / "annual-reports"
output_dir.mkdir(exist_ok=True)

s3_bucket = "colorado-data-bucket"
s3_key = (
    "pdfs/1980 Tenth Annual Report to the Governor and the General Assembly.pdf"
)
s3_uri = f"s3://{s3_bucket}/{s3_key}"
excel_output_path = output_dir / "1980.xlsx"

print("Initializing Textractor...")
extractor = Textractor(profile_name="default")

try:
    # Start asynchronous document analysis using S3 location
    print(f"Starting Textract analysis on {s3_uri}")
    job = extractor.start_document_analysis(
        file_source=s3_uri, features=[TextractFeatures.TABLES, TextractFeatures.FORMS], save_image=False
    )

    max_wait_time = 900
    wait_time = 0
    poll_interval = 60

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

        job.export_tables_to_excel(excel_output_path)
        print(
            f"Successfully exported {len(job.tables)} tables to {excel_output_path}"
        )

except Exception as e:
    print(f"Error: {e}")
