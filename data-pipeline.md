# Mill Levy Data Pipeline

## Overview
This pipeline extracts mill levy data from annual reports PDFs, focusing on the table "Assessed Valuation, Revenue, and Average Levies by County and State" found near the end of each document.

## Pipeline Steps

### 0. Download Annual Reports
- **Input**: Annual reports from Colorado Dept. of Local Affairs: [Annual Reports](https://drive.google.com/drive/folders/1L2hUG8ds64Wkud307-KZ89aOdJpkFgeN)
- **Process**: Download all annual reports and save them in `data/annual-reports/`

### 1. Manual Page Identification
- **Input**: Annual reports in `data/annual-reports/`
- **Process**: 
  - Manually identify the pages containing mill levy and assessed valuation tables in each report
  - Record page numbers in `data/annual-reports/mill-levies/mill-levy-pages.csv` and `data/annual-reports/county-valuation/county-valuation-pages.csv`
  - Format: year, page (can include ranges like "404-405" or multiple pages separated by commas)
- **Output**: CSV file with year and page mappings
- **Status**: Manual step required for accurate page identification

### 2. PDF Page Extraction
- **Input**: 
  - Annual reports in `data/annual-reports/`
  - Page mapping from `mill-levy-pages.csv` and `county-valuation-pages.csv`
- **Process**: 
  - `process_pages.py` reads the CSV and processes each entry
  - For each year/page combination:
    - Locate the appropriate annual report PDF
    - Extract the specified page(s)
    - Handle multi-page tables with appropriate page suffixes ('a', 'b', etc.)
- **Output**: Individual PDF pages saved to `data/annual-reports/mill-levies/[YEAR][SUFFIX].pdf`
- **Tools**: `process_pages.py` and `extract_target_table_pdf.py`

### 3. S3 Upload
- **Input**: Extracted table PDFs from `data/annual-reports/mill-levies/`
- **Process**:
  - `upload_check.py` uploads each PDF to an S3 bucket
  - Checks if file already exists before uploading
  - Implements retry logic with exponential backoff for upload failures
- **Output**: PDFs stored in S3 bucket with consistent naming (`mill-levies/[YEAR].pdf`)
- **Tools**: AWS SDK (boto3)

### 4. Table Extraction with Amazon Textract
- **Input**: PDFs in S3 bucket
- **Process**:
  - `ocr_tables.py` processes each PDF with Amazon Textract
  - Uses asynchronous document analysis with TABLES and FORMS features
  - Monitors job status with appropriate timeout handling (15-minute maximum)
  - Skips files that have already been processed
- **Output**: Tables exported to Excel files in `derived/mill-levies/[YEAR].xlsx`
- **Tools**: Amazon Textract API via Textractor Python package

### 5. Data Processing and Analysis
- **Input**: Excel files from `derived/mill-levies/`
- **Process**: 
  - Clean and structure the data in R
  - Validate data format consistency across years
  - Perform analyses as needed
- **Output**: Processed data and analysis results
- **Tools**: R with data.table, here, lubridate, stringr, ggplot2, and fixest packages

## Current Implementation Details

### `process_pages.py`
- Reads page information from mill-levy-pages.csv
- Handles both single pages and page ranges
- Uses appropriate suffixes for multi-page tables
- Calls `extract_target_table_pdf.py` for each page

### `extract_target_table_pdf.py`
- Extracts specific pages from PDFs
- Converts PDF pages to images for better processing
- Uses OCR (tesseract) to verify content
- Supports optional suffixes for multi-page tables
- Saves extracted pages as separate PDFs

### `upload_check.py`
- Uploads extracted PDFs to S3 bucket
- Implements error handling and retry logic
- Provides upload status reporting
- Lists objects in the S3 bucket for verification

### `extract_tables.py`
- Connects to AWS Textract service
- Processes PDFs stored in S3
- Monitors Textract job status
- Exports extracted tables to Excel
- Reports success/failure for each file

## Quality Assurance
- Check for expected number of counties per year
- Verify mill levy values are within historical ranges
- Compare against known values for select counties/years
- Ensure no missing data or data type issues
- Validate uniqueness on IDs
- Check consistency across different fields
- Identify and handle missing values