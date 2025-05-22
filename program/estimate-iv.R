# This script inspects the sample of Colorado mill levies,
# assessment rates, and valuation shares as a potential first-stage
# in an IV analysis.

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(kableExtra)

v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E460")

# Set human-friendly variable names
setFixest_dict(c(
    eff_ar = "Effective Assessment Ratio",
    gallagher = "Gallagher Instrument",
    tax_rate_res_ln = "log(effective tax rate)",
    rar_ln = "log(residential assessment rate)",
    hpi_ln = "log(HPI)"
), reset = TRUE)

# import ----
dt <- readRDS(here("derived", "sample.Rds"))
dt <- dt[year != 1970]

# estimate ----

# accounting identity: coefficients should all equal 1
rev <- feols(
    revenue_ln ~ -1 + eff_ar_ln + tax_rate_ln + mkt_val_total_ln,
    data = dt
)
etable(rev, digits = 3)

# IV for effective assessment ratio using pre-determined shares
v_out <- c(
    "revenue_ln", "revenue_pcap", "mkt_val_total_ln",
    "mkt_val_resi_ln", "mkt_val_other_ln", "tax_rate_ln",
    "val_share_resi", "hpi_ln"
)
s_out <- paste0("c(", paste(v_out, collapse = ", "), ")")

fmla_iv <- as.formula(paste0(
    s_out, " ~ -1 | county + year | eff_ar ~ gallagher"
))

rev_iv <- feols(
    fmla_iv,
    data = dt, weights = ~pop_1980
)

# counties hit with a Gallagher shock to their effective assessment rates see *lower* "market" values (driven by lower non-residential values), *higher* mill rates, and higher revenues.

# In other words, counties that are forced to lower residential assessment rates have to raise the "market" value of non-residential property (by assessing more aggressively) to maintain revenues, though point estimates suggest they are not fully able to do so.
etable(
    rev_iv[lhs = "revenue"],
    digits = 3, stage = 2,
    fitstat = c("N", "R2", "my", "ivf")
)

etable(rev_iv[lhs = "mkt_val_total"], digits = 3, stage = 2, fitstat = "ivf")

etable(rev_iv[lhs = "mkt_val_resi"], digits = 3, stage = 2, fitstat = "ivf")

etable(rev_iv[lhs = "mkt_val_other"], digits = 3, stage = 2, fitstat = "ivf")

etable(rev_iv[lhs = "tax_rate"], digits = 3, stage = 2, fitstat = "ivf")

etable(rev_iv[lhs = "val_share_resi"], digits = 3, stage = 2, fitstat = "ivf")

# HPI analysis ----

# OLS regression
hpi_ols <- feols(
    hpi_ln ~ eff_ar | county + year,
    data = dt, weights = ~pop_1980
)

etable(hpi_ols, rev_iv[lhs = "hpi"], digits = 3, stage = 2,
    fitstat = c("N", "R2", "ivf")
)

# IV regression  
hpi_iv <- feols(
    hpi_ln ~ 1 | county + year | tax_rate_res_ln ~ rar_ln,
    data = dt, weights = ~pop_1980
)


rate_iv <- feols(hpi_ln ~ 1 | county + year | tax_rate_res_ln ~ gallagher_ln,
    data = dt, weights = ~pop_1980
)
rate_ols <- feols(hpi_ln ~ tax_rate_res_ln | county + year,
    data = dt, weights = ~pop_1980
)
rate_table <- etable(
    rate_ols, rate_iv, digits = 3, stage = 2,
    fitstat = c("N", "R2", "ivf"), tex = TRUE,
    headers = c("OLS", "IV")
)

# Save table
if (!dir.exists(here("results", "tables"))) {
    dir.create(here("results", "tables"), recursive = TRUE)
}

writeLines(rate_table, here("results", "tables", "hpi-eff_ar-iv.tex"))
