# This script imports population data from the US Census by county.

# Downloaded from:
# https://seer.cancer.gov/popdata/download.html

# Data dictionary:
# https://seer.cancer.gov/popdata/popdic.html

rm(list = ls())
library(here)
library(data.table)
library(bit64)

data_path <- Sys.getenv("DATA_PATH")

# import ----
dt <- fread(file.path(
    data_path, "data", "nih-population",
    "us.1969_2023.20ages.adjusted.txt"
))

dt[, year := as.integer(substr(V1, 1, 4))]
dt[, state := substr(V1, 5, 6)]
dt[, fips := as.integer(substr(V1, 7, 12))]

dt[, sex := substr(V2, 3, 3)]
dt[, sex := fifelse(sex == 1, "M", "F")]

dt[, age := as.integer(substr(V2, 4, 5))]
dt[, childbearing := between(age, 4, 9)] # ages 15-44

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
dt <- dt[, .(
    pop = sum(pop),
    pop_childbearing = sum(pop * (sex == "F") * childbearing)
),
by = .(year, countyfp = fips)
]

# export ----
saveRDS(dt, here("derived", "pop.Rds"))