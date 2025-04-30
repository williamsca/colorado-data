# This script imports and appends the assessment and levy data
# produced by Amazon Textract.

rm(list = ls())
library(here)
library(data.table)
library(readxl)
library(stringr)

# PLAN FOR MILL LEVY DATA IMPORT AND PROCESSING:
# 1. Get a list of all Excel files in the 'derived/mill-levies/' directory
# 2. Create a function to process each file:
#    a. Extract year from filename (e.g., '1970.xlsx' -> 1970)
#    b. Read the Excel file
#    c. Identify and standardize the county name column
#    d. Identify and standardize the county mill levy column
#    e. Select only the county name, county mill levy, and year columns
#    f. Clean and standardize the data format
# 3. Apply the function to each file and combine results into a single data.table
# 4. Validate the data (check for missing values, duplicates, etc.)
# 5. Save the combined data as 'derived/mill-levies.Rds'

# IMPLEMENTATION

# 1. Get list of all Excel files in the mill-levies directory
mill_levy_files <- list.files(
  path = here("derived", "mill-levies"),
  pattern = "*.xlsx",
  full.names = TRUE
)

file_path <- mill_levy_files[1]

# 2. Create a function to process each file
process_mill_levy_file <- function(file_path) {
  filename <- basename(file_path)
  year <- as.numeric(str_extract(filename, "^\\d{4}"))

  dt <- as.data.table(read_xlsx(file_path, col_names = TRUE))
  setnames(dt, tolower(gsub(" ", "_", names(dt))))

  if (!any(grepl("county", names(dt)))) {
    warning(paste("No county column found in", filename))
    print(paste0("Columns in data: ", names(dt)))
    return(NULL)
  }

  if (!any(grepl("county_mill_levy", names(dt)))) {
    warning(paste("No mill levy column found in", filename))
    return(NULL)
  }

  dt[, county := str_trim(gsub("\\$|\\*|\\s+$", "", county))]

  dt <- dt[!grepl("(?i)(total|state|average)", county)]

  # TODO: check that ',' and '.' are used correctly in raw data
  dt[, county_mill_levy := as.numeric(
    gsub(",|\\$|\\s", "", county_mill_levy))]

  dt[, year := year]

  dt <- dt[, .(county, county_mill_levy, year)]
}

# 3. Process all files and combine results
all_mill_levies <- rbindlist(
  lapply(mill_levy_files, process_mill_levy_file),
  use.names = TRUE,
  fill = TRUE
)

# 4. Validate the data
# Check for missing values
missing_counties <- all_mill_levies[is.na(county), .N]
missing_levies <- all_mill_levies[is.na(county_mill_levy), .N]

if (missing_counties > 0) {
  warning(paste("Missing county names:", missing_counties))
}

if (missing_levies > 0) {
  warning(paste("Missing mill levy values:", missing_levies))
}

# Check for duplicates
duplicate_entries <- all_mill_levies[, .N, by = .(county, year)][N > 1]
if (nrow(duplicate_entries) > 0) {
  warning(paste("Found", nrow(duplicate_entries), "duplicate entries"))
  print(duplicate_entries)
}

# 5. Save the combined data
saveRDS(all_mill_levies, file = here("derived", "mill-levies.Rds"))