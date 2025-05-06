# This script combines data from various sources to construct a panel
# with jurisdiction by year observations of mill levies and assessment
# values in Colorado.

# Assessment rates for residential and commercial property are hand-coded
# from the 2023 Assessed Values Manual.

source(here("program", "databuild", "import-levies.R"))

rm(list = ls())
library(here)
library(data.table)
library(readxl)
library(stringr)

# import ----
# mill levies
dt_levies <- readRDS(here("derived", "mill-levies.Rds"))

# valuations by use and county for 1980
dt_valuations <- as.data.table(read_xlsx(here(
    "derived", "county-valuation", "1980.xlsx")), col_names = TRUE)
setnames(dt_valuations, tolower(gsub(" ", "_", names(dt_valuations))))
setnames(dt_valuations, "tdevr3-01_county", "county")
dt_valuations[, county := str_to_title(gsub(" \\$", "", county))]
dt_valuations[county == "K10wa", county := "Kiowa"]
dt_valuations[county == "Curay", county := "Ouray"]

# convert valuations to numeric
v_valuation <- grep("county", names(dt_valuations), invert = TRUE, value = TRUE)
dt_valuations[, (v_valuation) := lapply(.SD, function(x) {
    as.numeric(gsub(
        "\\.|,|\\$", "", x
    ))
}), .SDcols = v_valuation]
dt_valuations[, res_val_share_1980 := residential_1000 / assessed_total]

# assessment rates
dt_rates <- fread(here("data", "assessment_rates.csv"))
dt_rates[, c("rar", "nrar") := lapply(.SD, function(x) { x / 100 }),
    .SDcols = c("rar", "nrar")]

# merge ----
dt <- merge(dt_levies, dt_valuations[, .(county, res_val_share_1980)],
    by = "county", all.x = TRUE)

if (nrow(dt[is.na(res_val_share_1980)]) > 0) {
    stop("Missing residential valuation share for 1980 in a county.")
}

dt <- merge(dt, dt_rates, by = "year", all.x = TRUE)
setkey(dt, county, year)

# export ----
saveRDS(dt, here("derived", "sample.Rds"))
