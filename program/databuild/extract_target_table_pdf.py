import sys
import re
import subprocess
import tempfile
from pathlib import Path
from PIL import Image
import pytesseract

def extract_and_save_page(pdf_path, page_num, verbose=True, dir_name="mill-levies", orientation=0, suffix=""):
    """
    Extract text from a PDF page and save it as a properly oriented single-page PDF.
    
    Args:
        pdf_path (str or Path): Path to the PDF file
        page_num (int): Page number to extract (1-indexed)
        verbose (bool): Whether to print detailed progress messages
        dir_name (str): Directory name where to save the extracted page
        orientation (int): Rotation angle in degrees
        suffix (str): Suffix to append to the year for multi-page tables
        
    Returns:
        bool: True if page was found and saved, False otherwise
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

    # Create output directory structure
    data_dir = Path("data")
    data_dir.mkdir(exist_ok=True, parents=True)
    
    output_dir = data_dir / dir_name
    output_dir.mkdir(exist_ok=True, parents=True)

    output_path = output_dir / f"{year}{suffix}.pdf"

    # Skip if output file already exists
    if output_path.exists():
        print(f"{dir_name} page for {year}{suffix} already exists at {output_path}")
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
        best_orientation = orientation
        max_text_len = 0

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
                str(output_path.with_suffix('.pdf'))
            ]
            subprocess.run(extract_cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        print(f"✓ {dir_name} page saved to {output_path}")
        return True

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python extract_target_table_pdf.py <pdf_path> <page_number> [suffix] [dir_name] [orientation]")
        print("  pdf_path: Path to the PDF file")
        print("  page_number: Page number to extract (1-indexed)")
        print("  suffix: Optional character to append to the year (e.g. 'a', 'b') for multi-page tables")
        print("  dir_name: Name of the directory to save the extracted page (default: 'mill-levies')")
        print("  orientation: Rotation angle in degrees (default: 0)")
        sys.exit(1)
        
    pdf_path = sys.argv[1]
    page_num = int(sys.argv[2])
    
    # Parse optional arguments
    suffix = sys.argv[3] if len(sys.argv) > 3 else ""
    dir_name = sys.argv[4] if len(sys.argv) > 4 else "mill-levies"
    orientation = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    
    extract_and_save_page(pdf_path, page_num, dir_name=dir_name, orientation=orientation, suffix=suffix)
