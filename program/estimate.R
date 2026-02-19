# IV estimates: Gallagher Amendment and county fiscal outcomes
# Step 2 of implementation plan: single IV specification across all outcomes

rm(list = ls())
library(here)
library(data.table)
library(fixest)

# import ----
dt <- readRDS(here("derived", "sample.Rds"))
dt <- dt[year != 1970]

# derived outcomes ----
# SF permit share (NA when permit data missing)
dt[, permits_sf_share := permits_sf / permits_tot]

# Note: val_share_resi > 1 for Elbert (1.71) and Lake (1.46) in 1994
# due to negative implied non-residential market values in the assessment data.

# accounting identity check ----
# Revenue = eff_ar * tax_rate * mkt_val_total; all coefficients should = 1
rev_check <- feols(
    revenue_ln ~ -1 + eff_ar_ln + tax_rate_ln + mkt_val_total_ln,
    data = dt
)
etable(rev_check, digits = 3)

# IV specifications ----
# Endogenous: eff_ar (effective assessment ratio, levels)
# Instrument:  gallagher = theta_1980 * RAR_t + (1 - theta_1980) * NRAR_t
# FEs: county + year
# Weights: 1980 population
# SE: clustered at county

setFixest_dict(c(
    eff_ar           = "Eff. Assess. Ratio",
    revenue_ln       = "log(Revenue)",
    revenue_pcap     = "Revenue p.c.",
    tax_rate_ln      = "log(Mill Levy)",
    mkt_val_total_ln = "log(MV Total)",
    mkt_val_resi_ln  = "log(MV Resi.)",
    mkt_val_other_ln = "log(MV Non-res.)",
    val_share_resi   = "Resi. MV Share",
    hpi_ln           = "log(HPI)",
    permits_tot_pcap = "Permits p.c.",
    permits_sf_share = "SF Permit Share"
), reset = TRUE)

# --- Panel A: fiscal outcomes ---
v_fiscal <- c("revenue_ln", "revenue_pcap", "tax_rate_ln")
fmla_a <- as.formula(paste0(
    "c(", paste(v_fiscal, collapse = ", "), ")",
    " ~ -1 | county + year | eff_ar ~ gallagher"
))
iv_fiscal <- feols(fmla_a, data = dt, weights = ~pop_1980, cluster = ~county)

# --- Panel B: assessed/market values ---
v_values <- c("mkt_val_total_ln", "mkt_val_resi_ln", "mkt_val_other_ln", "val_share_resi")
fmla_b <- as.formula(paste0(
    "c(", paste(v_values, collapse = ", "), ")",
    " ~ -1 | county + year | eff_ar ~ gallagher"
))
iv_values <- feols(fmla_b, data = dt, weights = ~pop_1980, cluster = ~county)

# --- Panel C: real outcomes (HPI, permits) ---
v_real <- c("hpi_ln", "permits_tot_pcap", "permits_sf_share")
fmla_c <- as.formula(paste0(
    "c(", paste(v_real, collapse = ", "), ")",
    " ~ -1 | county + year | eff_ar ~ gallagher"
))
iv_real <- feols(fmla_c, data = dt, weights = ~pop_1980, cluster = ~county)

# print to console ----
cat("\n--- Panel A: Fiscal outcomes ---\n")
etable(iv_fiscal, digits = 3, fitstat = c("n", "my", "ivf"))

cat("\n--- Panel B: Market values ---\n")
etable(iv_values, digits = 3, fitstat = c("n", "my", "ivf"))

cat("\n--- Panel C: Real outcomes ---\n")
etable(iv_real, digits = 3, fitstat = c("n", "my", "ivf"))

# export LaTeX table ----
dir.create(here("results", "tables"), showWarnings = FALSE, recursive = TRUE)

style_tex <- style.tex(
    main = "base",
    depvar.title   = "",
    fixef.title    = "\\midrule Fixed effects",
    fixef.suffix   = "\\checkmark",
    stats.title    = "\\midrule"
)

# expected signs row (manual): +  +  -  ?  +  -  +  +/-  +  +
# (revenue_ln revenue_pcap tax_rate_ln mkt_val_total_ln mkt_val_resi_ln
#  mkt_val_other_ln val_share_resi hpi_ln permits_tot_pcap permits_sf_share)

etable(
    c(iv_fiscal, iv_values, iv_real),
    digits     = 3,
    fitstat    = c("n", "my", "ivf"),
    style.tex  = style_tex,
    notes      = paste(
        "IV: eff. assessment ratio instrumented by the Gallagher instrument",
        "(1980 residential value share $\\times$ RAR$_t$ +",
        "(1 - share) $\\times$ NRAR$_t$).",
        "County and year fixed effects; 1980 population weights;",
        "SEs clustered by county.",
        "Expected sign on $\\hat{\\text{eff\\_ar}}$:",
        "$(+)$ revenue\\_ln, revenue\\_pcap, mkt\\_val\\_resi\\_ln, val\\_share\\_resi,",
        "permits\\_tot\\_pcap, permits\\_sf\\_share;",
        "$(-)$ tax\\_rate\\_ln, mkt\\_val\\_other\\_ln;",
        "$(?)$ mkt\\_val\\_total\\_ln, hpi\\_ln."
    ),
    file       = here("results", "tables", "iv_estimates.tex"),
    replace    = TRUE
)

cat("\nTable written to results/tables/iv_estimates.tex\n")
