# This script combines data from various sources to construct a panel
# with jurisdiction by year observations of mill levies and assessment
# values in Colorado.

# Assessment rates for residential and commercial property are hand-coded
# from the 2023 Assessed Values Manual.

# source(here("program", "databuild", "import-levies.R"))
# source(here("program", "databuild", "import-valuations.R"))
# source(here("program", "databuild", "import-pop.R"))

rm(list = ls())
library(here)
library(data.table)
library(readxl)
library(stringr)

# import ----
# mill levies
dt_levies <- readRDS(here("derived", "mill-levies.Rds"))

# valuations
dt_val <- readRDS(here("derived", "county-valuations.Rds"))

dt_val_1980 <- copy(dt_val[year == 1980])
dt_val_1980[, assessed_share_resi_1980 := assessed_resi / assessed_total]

# assessment rates
dt_rates <- fread(here("data", "assessment_rates.csv"))
dt_rates[, c("rar", "nrar") := lapply(.SD, function(x) { x / 100 }),
    .SDcols = c("rar", "nrar")]

# population
dt_pop <- readRDS(here("derived", "pop.Rds"))

# county FIPS codes
dt_fips <- fread(
    here("crosswalk", "counties-co.csv"),
    select = c("STATEFP", "COUNTYFP", "COUNTYNAME"))
dt_fips[, fips := STATEFP * 1000 + COUNTYFP]
dt_fips[, county := gsub(" County", "", COUNTYNAME)]

# merge ----
# balanced panel
dt <- CJ(fips = dt_fips$fips, year = unique(dt_levies$year))

dt <- merge(dt, dt_fips[, .(fips, county)], by = "fips", all.x = TRUE)

# TODO: diagnose this merge
dt <- merge(dt, dt_pop[, .(year, fips, pop)], by = c("fips", "year"),
    all.x = TRUE)

dt <- merge(
    dt, dt_levies, by = c("county", "year"),
    all.x = TRUE)

dt <- merge(
    dt, dt_val_1980[, .(county, assessed_share_resi_1980)],
    by = c("county"), all.x = TRUE)

if (nrow(dt[is.na(assessed_share_resi_1980)]) > 0) {
    stop("Missing residential valuation share for 1980 in a county.")
}

dt <- merge(
    dt, dt_val,
    by = c("county", "year"), all.x = TRUE)

dt <- merge(dt, dt_rates, by = "year", all.x = TRUE)
setkey(dt, county, year)

# sanity checks ----
dt[, diff := (
    assessed_valuation - assessed_total) / assessed_valuation]
if (nrow(dt[abs(diff) >= 0.01]) > 0) {
    warning("Assessed valuation in mill-levy and county-valuation tables differ by more than 1%.")
}

dt[diff > 0.01, .(county, year, assessed_valuation, assessed_total, diff)]

dt[, c("diff", "assessed_total") := NULL]

# export ----
saveRDS(dt, here("derived", "sample.Rds"))
