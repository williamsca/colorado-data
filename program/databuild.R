# This script combines data from various sources to construct a panel
# with jurisdiction by year observations of mill levies and assessment
# values in Colorado.

rm(list = ls())
library(here)
library(data.table)

# import ----
dt <- readRDS(here("derived", "annual-report-1980.Rds"))

