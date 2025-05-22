# Import and clean HPI data for Colorado counties
# 
# This script reads the Bogin, Doerner, and Larson county-level HPI data,
# filters to Colorado counties, and saves as an R data file.

# https://www.fhfa.gov/research/papers/wp1601?redirect=

rm(list = ls())
library(here)
library(data.table)
library(readxl)
library(stringr)

# import ----
dt_hpi <- data.table(read_excel(
    here("data", "bogin_doerner_larson_hpi", "hpi_at_bdl_county.xlsx"),
    sheet = 1, skip = 4
))

# Set proper column names based on the data description
names(dt_hpi) <- c(
    "state", "county", "fips", "year", "annual_change", 
    "hpi_base_first", "hpi_base_1990", "hpi_base_2000"
)

# filter to Colorado and clean ----
dt_hpi <- dt_hpi[state == "CO"]

# Convert data types
dt_hpi[, year := as.numeric(year)]
dt_hpi[, fips := as.numeric(fips)]
dt_hpi[, annual_change := as.numeric(annual_change)]
dt_hpi[, hpi_base_first := as.numeric(hpi_base_first)]
dt_hpi[, hpi_base_1990 := as.numeric(hpi_base_1990)]
dt_hpi[, hpi_base_2000 := as.numeric(hpi_base_2000)]

# Remove Broomfield since it was created in 2001 and is excluded from sample
# Broomfield FIPS code is 08014
dt_hpi <- dt_hpi[fips != 8014]

# Use hpi_base_1990 as primary HPI measure since it's more standardized
# but fallback to hpi_base_first if 1990 base is missing
dt_hpi[, hpi := fcoalesce(hpi_base_1990, hpi_base_first)]

# Keep only essential columns
dt_hpi <- dt_hpi[, .(county, fips, year, hpi, annual_change)]

# sanity checks ----
cat("Colorado counties in HPI data:", uniqueN(dt_hpi$county), "\n")
cat("Year range:", min(dt_hpi$year, na.rm = TRUE), "to", 
    max(dt_hpi$year, na.rm = TRUE), "\n")
cat("Missing HPI values:", sum(is.na(dt_hpi$hpi)), "\n")

# Check uniqueness on county-year
if (anyDuplicated(dt_hpi, by = c("fips", "year")) > 0) {
    stop("HPI data is not unique on county-year.")
}

# Remove rows with missing HPI values
dt_hpi <- dt_hpi[!is.na(hpi)]

cat("Final observations:", nrow(dt_hpi), "\n")
cat("Counties with any HPI data:", uniqueN(dt_hpi$county), "\n")

# export ----
saveRDS(dt_hpi, here("derived", "hpi.Rds"))

cat("HPI data saved to derived/hpi.Rds\n")