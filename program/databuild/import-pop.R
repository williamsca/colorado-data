# This script imports population data from the US Census by county.

# Downloaded from:
# https://seer.cancer.gov/popdata/download.html

rm(list = ls())
library(here)
library(data.table)
library(bit64)

# import ----
dt <- fread(here("data", "census-pop", "us.1969_2023.20ages.adjusted.txt"))

dt[, year := as.integer(substr(V1, 1, 4))]
dt[, state := substr(V1, 5, 6)]
dt[, fips := as.integer(substr(V1, 7, 12))]
dt[, pop := as.integer(substr(V2, 6, 14))]

# sanity check
dt[, .(pop = sum(pop)), by = year]

# recoded counties
# https://seer.cancer.gov/popdata/modifications.html
dt[fips == 8911, fips := 8001]
dt[fips == 8912, fips := 8013]
dt[fips == 8913, fips := 8059]
dt[fips == 8914, fips := 8123]

# aggregate by county
dt <- dt[, .(pop = sum(pop)), by = .(year, state, fips)]

# export ----
saveRDS(dt, here("derived", "pop.Rds"))
