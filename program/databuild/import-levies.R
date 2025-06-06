# This script imports and appends the assessment and levy data
# produced by Amazon Textract.

rm(list = ls())
library(here)
library(data.table)
library(readxl)
library(stringr)

# 1. Get list of all Excel files in the mill-levies directory
mill_levy_files <- list.files(
  path = here("derived", "mill-levies"),
  pattern = "*.xlsx",
  full.names = TRUE
)

# 2. Create a function to process each file
process_mill_levy_file <- function(file_path) {
  filename <- basename(file_path)
  year <- as.numeric(str_extract(filename, "^\\d{4}"))

  dt <- as.data.table(read_xlsx(file_path, col_names = TRUE))
  setnames(dt, tolower(gsub(" ", "_", names(dt))))
  dt[, year := year]

  if (!"county" %in% names(dt)) {
    if (names(dt)[1] == "...1") {
      setnames(dt, names(dt)[1], "county")
    } else {
      warning(paste("No county column found in", filename))
      print(paste0("Columns in data: ", names(dt)))
      return(NULL)
    }
  }

  dt[, county := str_to_title(str_trim(gsub("\\$|\\*|\\s+$", "", county)))]

  dt <- dt[!grepl("(?i)(total|state|average)", county)]

  if (!"county_mill_levy" %in% names(dt)) {
    warning(paste("No mill levy column found in", filename))
    return(NULL)
  }

  dt[, county_mill_levy := gsub(",", ".", county_mill_levy)]
  dt[, county_mill_levy := abs(as.numeric(county_mill_levy))]

  if (nrow(dt[county_mill_levy > 50]) > 0) {
    warning(paste("High mill levy values found in", filename))
    print(dt[county_mill_levy > 50])
  }

  valuation_col <- grep(
    "assessed_valuation", names(dt), value = TRUE)
  if (length(valuation_col) == 0) {
    warning(paste("No assessed valuation column found in", filename))
    return(dt[, .(county, county_mill_levy, year)])
  }
  setnames(dt, valuation_col, "assessed_valuation")
  dt[, assessed_valuation := as.numeric(gsub(
    ",|\\$", "", assessed_valuation))]

  dt <- dt[, .(county, assessed_valuation, county_mill_levy, year)]
}

# 3. Process all files and combine results
dt_levies <- rbindlist(
  lapply(mill_levy_files, process_mill_levy_file),
  use.names = TRUE,
  fill = TRUE
)

dt_levies <- dt_levies[!is.na(county) & !is.na(county_mill_levy)]

dt_levies[, county := gsub(" \\+|:|'| #| 4", "", county)]
dt_levies[county == "Adass", county := "Adams"]
dt_levies[county == "Alasosa" | county == "Alomoso", county := "Alamosa"]
dt_levies[county == "Archufeta" | county == "Archuteta", county := "Archuleta"]
dt_levies[county == "Baco", county := "Baca"]
dt_levies[county == "Costillo", county := "Costilla"]
dt_levies[, county := gsub("E1", "El", county)]
dt_levies[county == "Paso", county := "El Paso"]
dt_levies[county == "Layle", county := "Eagle"]
dt_levies[county == "Fresont", county := "Fremont"]
dt_levies[county == "Gorfield" | county == "Carfield", county := "Garfield"]
dt_levies[county == "Sunnison", county := "Gunnison"]
dt_levies[county == "Gr And", county := "Grand"]
dt_levies[county %in% c("Huefrano", "Huer Fano", "Huerfand", "Huerfono"),
  county := "Huerfano"]
dt_levies[county == "Lariser", county := "Larimer"]
dt_levies[county == "Las Anieas", county := "Las Animas"]
dt_levies[county == "Montezuea", county := "Montezuma"]
dt_levies[county == "Borgan", county := "Morgan"]
dt_levies[county == "Promers", county := "Prowers"]
dt_levies[county == "Pueble", county := "Pueblo"]
dt_levies[county == "R10 Grande" | county == "Rio Brande",
  county := "Rio Grande"]
dt_levies[county == "Suemit", county := "Summit"]
dt_levies[county == "Sussit", county := "Summit"]
dt_levies[county == "Utero", county := "Otero"]
dt_levies[county == "Duray", county := "Ouray"]
dt_levies[county == "Yuna", county := "Yuma"]

table(dt_levies$county)

# 4. Validate the data
# Check for missing values
missing_counties <- dt_levies[is.na(county), .N]
missing_levies <- dt_levies[is.na(county_mill_levy), .N]

if (missing_counties > 0) {
  warning(paste("Missing county names:", missing_counties))
}

if (missing_levies > 0) {
  warning(paste("Missing mill levy values:", missing_levies))
}

# Check for duplicates
if (uniqueN(dt_levies[, .(county, year)]) != nrow(dt_levies)) {
  warning("Mill levy data contains duplicates")
}

# Export ----
saveRDS(dt_levies, file = here("derived", "mill-levies.Rds"))
