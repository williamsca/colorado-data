# This script imports and appends the assessment and levy data
# produced by Amazon Textract.

rm(list = ls())
library(here)
library(data.table)
library(readxl)

# import ----
dt <- as.data.table(read_xlsx(
    here("derived", "reports-1980", "annual-report-1980.xlsx"),
    sheet = "Sheet106"), col_names = TRUE)

setnames(
    dt,
    c("TDEVR3-01 COUNTY", "RESIDENTIAL 1000", "ASSESSED TOTAL"),
    c("county", "assessed_resi", "assesed_tot"))
dt <- dt[, .(county, assessed_resi, assesed_tot)]
dt <- dt[!grepl("TOTAL", county)]

v_numeric <- c("assessed_resi", "assesed_tot")
dt[, (v_numeric) := lapply(
    .SD, function(x) gsub(".", ",", x, fixed = TRUE)),
    .SDcols = v_numeric]
dt[, (v_numeric) := lapply(
    .SD, function(x) as.numeric(gsub(",|\\$", "", x))),
    .SDcols = v_numeric]

dt[, county := gsub(" \\$", "", county)]
dt[, year := n_year]
