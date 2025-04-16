from textractor import Textractor
from textractor.data.constants import TextractFeatures
from pathlib import Path

try:
    current_dir = Path(__file__).resolve().parent
except NameError:
    current_dir = Path.cwd()

image_path = current_dir / "page37-037.png"

# Initialize Textractor
extractor = Textractor(profile_name="default")

# Test with a sample image (replace with your own image path)
try:
    document = extractor.analyze_document(
        file_source = str(image_path),
        features=[TextractFeatures.TABLES, TextractFeatures.FORMS]
    )
    print("Successfully analyzed document!")
    print(f"Found {len(document.pages)} pages")
except Exception as e:
    print(f"Error: {e}")