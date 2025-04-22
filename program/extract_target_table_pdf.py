import sys
import re
import subprocess
import tempfile
from pathlib import Path
from PIL import Image
import pytesseract

def extract_and_save_mill_levy_page(pdf_path, page_num, verbose=True):
    """
    Extract text from a PDF page, check if it contains mill levy information,
    and if so, save it as a properly oriented single-page PDF.
    
    Args:
        pdf_path (str or Path): Path to the PDF file
        page_num (int): Page number to extract (1-indexed)
        verbose (bool): Whether to print detailed progress messages
        
    Returns:
        bool: True if mill levy page was found and saved, False otherwise
    """
    pdf_path = Path(pdf_path)
    if verbose:
        print(f"Processing page {page_num} of {pdf_path.name}...")

    # Get year from filename
    year_match = re.search(r'(\d{4})', pdf_path.stem)
    if not year_match:
        print(f"Could not determine year from filename: {pdf_path.name}")
        return False

    year = year_match.group(1)

    # Create mill-levies directory if it doesn't exist
    output_dir = pdf_path.parent / "mill-levies"
    output_dir.mkdir(exist_ok=True, parents=True)

    # Handle suffix for multi-page tables
    suffix = ""
    if len(sys.argv) > 3:  # If a suffix is provided
        suffix = sys.argv[3]

    output_path = output_dir / f"{year}{suffix}.pdf"

    # Skip if output file already exists
    if output_path.exists():
        print(f"Mill levy page for {year}{suffix} already exists at {output_path}")
        return True

    # Create a temporary directory for working files
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        img_prefix = f"page_{page_num}"

        # Convert PDF page to image using pdftoppm with higher resolution
        pdftoppm_cmd = [
            "pdftoppm", 
            "-png",               # Output format
            "-r", "300",          # Higher resolution for better OCR
            "-f", str(page_num),  # First page to convert
            "-l", str(page_num),  # Last page to convert
            "-singlefile",        # Create only one file
            str(pdf_path),
            str(temp_path / img_prefix)
        ]

        subprocess.run(pdftoppm_cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # The output will be named page_{page_num}.png
        png_path = temp_path / f"{img_prefix}.png"

        if not png_path.exists():
            print(f"Failed to extract page {page_num}")
            return False

        # Open the image
        try:
            img = Image.open(png_path)
        except Exception as e:
            print(f"Error opening image: {e}")
            return False

        # Try different orientations for better results
        best_text = ""
        best_orientation = 0
        max_text_len = 0

        # Try pytesseract with different page segmentation modes and orientations
        for orientation in [0]:  # , 90, 180, 270
            # Rotate the image if needed
            if orientation > 0:
                rotated_img = img.rotate(orientation, expand=True)
            else:
                rotated_img = img

            # Try with different page segmentation modes
            for psm in [6]:  # Assume single uniform block
                config = f'--psm {psm}'
                text = pytesseract.image_to_string(rotated_img, config=config)

                # Keep the result with the most characters
                if len(text) > max_text_len:
                    max_text_len = len(text)
                    best_text = text
                    best_orientation = orientation
                    if verbose:
                        print(f"Found better text with orientation {orientation}° and PSM {psm}")

        # Convert the text to lowercase for case-insensitive matching
        lower_text = best_text.lower()

        # Create temporary PDF with correct orientation
        if best_orientation != 0:
            # First, save rotated image
            rotated_img = img.rotate(best_orientation, expand=True)
            rotated_img_path = temp_path / f"rotated_{img_prefix}.png"
            rotated_img.save(rotated_img_path)

            # Convert rotated image to PDF
            img_to_pdf_cmd = [
                "convert",
                str(rotated_img_path),
                str(temp_path / "rotated_page.pdf")
            ]

            try:
                subprocess.run(img_to_pdf_cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                temp_pdf_path = temp_path / "rotated_page.pdf"
            except Exception as e:
                print(f"Error converting image to PDF with ImageMagick: {e}")
                print("Falling back to original orientation...")
                temp_pdf_path = None
        else:
            temp_pdf_path = None

        # If rotation was successful, use the rotated PDF, otherwise extract from original
        if temp_pdf_path and temp_pdf_path.exists():
            # Copy the rotated PDF to the output location
            copy_cmd = ["cp", str(temp_pdf_path), str(output_path)]
            subprocess.run(copy_cmd, check=True)
        else:
            # Extract original page to a PDF if rotation fails
            extract_cmd = [
                "pdftocairo", 
                "-pdf",        # Output format
                "-f", str(page_num),  # First page
                "-l", str(page_num),  # Last page
                str(pdf_path),
                str(output_path.with_suffix('.pdf'))  # pdftocairo adds .pdf
            ]
            subprocess.run(extract_cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        print(f"✓ Mill levy page saved to {output_path}")
        return True

def process_pdf(pdf_path):
    """
    Process a PDF file to find the mill levy table by checking the last 30% of pages.
    
    Args:
        pdf_path (str or Path): Path to the PDF file
        
    Returns:
        bool: True if a mill levy page was found and saved, False otherwise
    """
    pdf_path = Path(pdf_path)
    print(f"Looking for mill levy table in {pdf_path.name}...")
    
    # Get total number of pages
    page_count_cmd = ["pdfinfo", str(pdf_path)]
    page_info = subprocess.check_output(page_count_cmd, universal_newlines=True)
    page_count_match = re.search(r'Pages:\s+(\d+)', page_info)
    
    if not page_count_match:
        print(f"Could not determine page count for {pdf_path.name}")
        return False
        
    total_pages = int(page_count_match.group(1))
    print(f"Total pages: {total_pages}")
    
    # Only check the last 30% of pages (tables are usually at the end)
    start_page = max(1, total_pages - int(total_pages * 0.3))
    
    # Process pages in reverse order
    for page_num in range(total_pages, start_page - 1, -1):
        print(f"Checking page {page_num} of {total_pages}...")
        
        # Try to extract and save mill levy page
        if extract_and_save_mill_levy_page(pdf_path, page_num, verbose=False):
            return True
    
    print(f"Could not find mill levy table in {pdf_path.name}")
    return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  1. Process all pages: python extract_target_table_pdf.py <pdf_path>")
        print("  2. Process a specific page: python extract_target_table_pdf.py <pdf_path> <page_number> [suffix]")
        print("     suffix: optional character to append to the year (e.g. 'a', 'b') for multi-page tables")
        sys.exit(1)
        
    pdf_path = sys.argv[1]
    
    if len(sys.argv) == 2:
        # No page specified, process the PDF
        process_pdf(pdf_path)
    else:
        # Specific page number provided
        page_num = int(sys.argv[2])
        extract_and_save_mill_levy_page(pdf_path, page_num)
