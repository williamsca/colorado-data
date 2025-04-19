# This script combines data from various sources to construct a panel
# with jurisdiction by year observations of mill levies and assessment
# values in Colorado.

# Assessment rates for residential and commercial property are hand-coded
# from the 2023 Assessed Values Manual.

rm(list = ls())
library(here)
library(data.table)

# import ----
dt_ar <- fread(here("data", "assessment_rates.csv"))

dt <- readRDS(here("derived", "annual-report-1980.Rds"))

