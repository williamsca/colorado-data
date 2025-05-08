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

# county FIPS codes
dt_fips <- fread(
    here("crosswalk", "counties-co.csv"),
    select = c("STATEFP", "COUNTYFP", "COUNTYNAME"))
dt_fips[, fips := STATEFP * 1000 + COUNTYFP]
dt_fips[, county := gsub(" County", "", COUNTYNAME)]
dt_fips <- dt_fips[county != "Broomfield"] # Broomfield was created in 2001

# merge ----
# balanced panel
dt <- CJ(fips = dt_fips$fips, year = unique(dt_levies$year))

dt <- merge(dt, dt_fips[, .(fips, county)], by = "fips", all.x = TRUE)

dt <- merge(dt, dt_pop[, .(year, fips, pop)], by = c("fips", "year"),
    all.x = TRUE)
if (nrow(dt[is.na(pop)]) != 0) {
    stop("Missing population data for a county.")
}
dt <- merge(dt, dt_pop_1980[, .(fips, pop_1980)], by = "fips", all.x = TRUE)

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

# outcomes
# implied market valuations
dt[, mkt_val_resi := assessed_resi / rar]
dt[, mkt_val_other := (assessed_valuation - assessed_resi) / nrar]
dt[, mkt_val_total := mkt_val_resi + mkt_val_other]

dt[, val_share_resi := mkt_val_resi / mkt_val_total]

# TODO: these should be equal
dt[year <= 1982 & val_share_resi != assessed_share_resi]

# high- and low-residential valuation share counties
median_resi <- median(dt[year == 1980, val_share_resi])
dt[, resi_group := fifelse(
    val_share_resi > median_resi, "High", "Low"
)]

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
    "eff_ar", "mkt_val_resi", "mkt_val_other"
)
dt[, paste0(v_logs, "_ln") := lapply(.SD, log), .SDcols = v_logs]

v_pcap <- c(
    "revenue", "mkt_val_total", "mkt_val_resi", "mkt_val_other"
)
dt[, paste0(v_pcap, "_pcap") := lapply(.SD, function(x) { x / pop }),
    .SDcols = v_pcap]

# export ----
saveRDS(dt, here("derived", "sample.Rds"))
