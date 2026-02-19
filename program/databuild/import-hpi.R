# This script downloads the housing price index constructed in
# Bogin, Doerner, and Larson (2019). Data downloaded on
# 10/9/2023 from:
# https://www.fhfa.gov/PolicyProgramsResearch/Research/Pages/wp1601.aspx

rm(list = ls())
library(here)
library(data.table)
library(readxl)

CONSTANT_YEAR <- 1998

data_path <- Sys.getenv("DATA_PATH")

# Import ----
dt <- as.data.table(read_xlsx(file.path(
    data_path, "data",
    "hpi", "bogin-doerner-larson",
    "hpi_at_bdl_county.xlsx"
), skip = 6))
setnames(dt, names(dt), tolower(names(dt)))

dt[, year := as.numeric(year)]
dt[, hpi := as.numeric(`hpi with 2000 base`)]

# deflate ----
dt_cpi <- as.data.table(read_xlsx(
    file.path(
        data_path, "crosswalk",
        "bls-cpi", "SeriesReport-20250912131731_9e879e.xlsx"
    ),
    skip = 10
))

dt_cpi[, Annual := Annual / Annual[Year == CONSTANT_YEAR]]
dt <- merge(dt, dt_cpi[, .(year = Year, Annual)],
    by = c("year")
)
if (nrow(dt[is.na(Annual)]) != 0) {
    stop("Some years are missing CPI data.")
}

dt[, hpi := hpi / Annual]

# clean ----
dt[, countyfp := as.integer(`fips code`)]

dt <- dt[, c("countyfp", "year", "hpi")]

# export ----
fwrite(dt, here("derived", "hpi-bdl.csv"))