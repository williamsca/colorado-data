# This script combines data from various sources to construct a panel
# with jurisdiction by year observations of mill levies and assessment
# values in Colorado.

# Assessment rates for residential and commercial property are hand-coded
# from the 2023 Assessed Values Manual.

rm(list = ls())
library(here)
library(data.table)
library(readxl)
library(stringr)

# source(here("program", "databuild", "import-levies.R"))
# source(here("program", "databuild", "import-valuations.R"))
# source(here("program", "databuild", "import-pop.R"))
source(here("program", "databuild", "import-hpi.R"))

# import ----
# mill levies
dt_levies <- readRDS(here("derived", "mill-levies.Rds"))

# valuations
dt_val <- readRDS(here("derived", "county-valuations.Rds"))

dt_val_1980 <- dt_val[year == 1980]
dt_val_1980[, assessed_share_resi_1980 := assessed_resi / assessed_total]

# assessment rates
dt_rates <- fread(here("data", "assessment_rates.csv"))
dt_rates[, c("rar", "nrar") := lapply(.SD, function(x) { x / 100 }),
    .SDcols = c("rar", "nrar")]

# population
dt_pop <- readRDS(here("derived", "pop.Rds"))
dt_pop_1980 <- dt_pop[year == 1980]
setnames(dt_pop_1980, "pop", "pop_1980")

# HPI
dt_hpi <- fread(here("derived", "hpi-bdl.csv"))

# building permits
dt_permits <- readRDS(here("derived", "permits-co.Rds"))

# county FIPS codes
dt_fips <- fread(
    here("crosswalk", "counties-co.csv"),
    select = c("STATEFP", "COUNTYFP", "COUNTYNAME"))
dt_fips[, countyfp := STATEFP * 1000 + COUNTYFP]
dt_fips[, county := gsub(" County", "", COUNTYNAME)]
dt_fips <- dt_fips[county != "Broomfield"] # Broomfield was created in 2001

# merge ----
# balanced panel
dt <- CJ(
    countyfp = dt_fips$countyfp, year = unique(dt_levies$year))

dt <- merge(dt, dt_fips[, .(countyfp, county)], by = "countyfp", all.x = TRUE)

dt <- merge(dt, dt_pop[, .(year, countyfp, pop)], by = c("countyfp", "year"),
    all.x = TRUE)
if (nrow(dt[is.na(pop)]) != 0) {
    stop("Missing population data for a county.")
}
dt <- merge(dt, dt_pop_1980[, .(countyfp, pop_1980)], by = "countyfp", all.x = TRUE)

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

# HPI
dt <- merge(dt, dt_hpi[, .(countyfp, year, hpi)], by = c("countyfp", "year"),
    all.x = TRUE)

# building permits
dt <- merge(dt, dt_permits, by = c("year", "countyfp"), all.x = TRUE)

dt[is.na(permits_tot)]

# clean ----
setkey(dt, county, year)


# sanity checks ----
dt[, diff := (
    assessed_valuation - assessed_total) / assessed_valuation]
if (nrow(dt[abs(diff) >= 0.01]) > 0) {
    warning("Assessed valuation in mill-levy and county-valuation tables differ by more than 1%.")
}

dt[diff > 0.01, .(county, year, assessed_valuation, assessed_total, diff)]

dt[, c("diff", "assessed_total") := NULL]

# HPI sanity checks ----
# Check that all observations in base panel match to an HPI for overlapping years
hpi_overlap_years <- intersect(unique(dt$year), unique(dt_hpi$year))
dt_overlap <- dt[year %in% hpi_overlap_years]
missing_hpi <- dt_overlap[is.na(hpi)]
if (nrow(missing_hpi) > 0) {
    cat("Counties missing HPI data for overlapping years:\n")
    print(missing_hpi[, .(county, year, countyfp)])
    cat("Total missing HPI observations:", nrow(missing_hpi), "\n")
}

# Check uniqueness on county-year for the merged dataset
if (anyDuplicated(dt, by = c("county", "year")) > 0) {
    stop("Merged dataset is not unique on county-year.")
}

# outcomes
# implied market valuations
dt[, mkt_val_resi := assessed_resi / rar]
dt[, mkt_val_other := (assessed_valuation - assessed_resi) / nrar]
dt[, mkt_val_total := mkt_val_resi + mkt_val_other]

dt[, val_share_resi := mkt_val_resi / mkt_val_total]

# permits per capita
dt[, permits_tot_pcap := permits_tot / pop_1980]

# TODO: these should be equal
dt[year <= 1982 & val_share_resi != assessed_share_resi]

# high- and low-residential valuation share counties
dt_1980 <- dt[year ==1980]
dt_1980[, resi_group := fifelse(
    val_share_resi > median(val_share_resi), "High", "Low"
)]

dt <- merge(dt, dt_1980[, .(county, resi_group)], by = "county", all.x = TRUE)

# construct instrument for the effective tax rate:
# use variation in residential assessment rate due to the
# Gallagher amendment
dt[, tax_rate := county_mill_levy / 1000]
dt[, tax_rate_res := tax_rate * rar] # effective residential rate
dt[, revenue := assessed_valuation * tax_rate]

# value-weighted average assessment ratio
dt[, eff_ar := val_share_resi * rar + (1 - val_share_resi) * nrar]

# value-weighted average tax rate
dt[, tax_rate_avg := eff_ar * tax_rate]

# instrument for effective assessment ratio using pre-determined shares
dt[, gallagher := assessed_share_resi_1980 * rar +
    (1 - assessed_share_resi_1980) * nrar]

v_logs <- c(
    "tax_rate", "revenue", "gallagher", "mkt_val_total",
    "eff_ar", "mkt_val_resi", "mkt_val_other", "hpi",
    "tax_rate_res", "rar"
)
dt[, paste0(v_logs, "_ln") := lapply(.SD, log), .SDcols = v_logs]

v_pcap <- c(
    "revenue", "mkt_val_total", "mkt_val_resi", "mkt_val_other"
)
dt[, paste0(v_pcap, "_pcap") := lapply(.SD, function(x) { x / pop }),
    .SDcols = v_pcap]

# export ----
saveRDS(dt, here("derived", "sample.Rds"))
