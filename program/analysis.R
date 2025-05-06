# This script inspects the sample of Colorado mill levies,
# assessment rates, and valuation shares as a potential first-stage
# in an IV analysis.

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(ggplot2)
library(kableExtra)

# import ----
dt <- readRDS(here("derived", "sample.Rds"))
dt <- dt[year != 1970]

# construct instrument for the effective tax rate:
# use variation in residential assessment rate due to the
# Gallagher amendment
dt[, tax_rate_res := county_mill_levy * rar]
dt[, delta_rar := rar - shift(rar), by = "county"]
dt[, gallagher := rar * res_val_share_1980]

# inspect ----
fs <- feols(
    tax_rate_res ~ gallagher | county + year,
    data = dt
)
etable(fs)
