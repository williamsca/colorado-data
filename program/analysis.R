# This script inspects the sample of Colorado mill levies,
# assessment rates, and valuation shares as a potential first-stage
# in an IV analysis.

rm(list = ls())
library(here)
library(data.table)
library(fixest)
library(ggplot2)
library(kableExtra)

v_palette <- c("#0072B2", "#D55E00", "#009E73", "#F0E460")

# import ----
dt <- readRDS(here("derived", "sample.Rds"))
dt <- dt[year != 1970]

# construct instrument for the effective tax rate:
# use variation in residential assessment rate due to the
# Gallagher amendment
dt[, tax_rate := county_mill_levy / 1000]
dt[, tax_rate_res := tax_rate * rar] # effective residential rate
dt[, revenue := assessed_valuation * tax_rate]

dt[, eff_ar := res_val_share * rar + (1 - res_val_share) * nrar] # effective assessment ratio (TODO: get residential shares)

# instrument for effective assessment ratio using pre-determined shares
dt[, gallagher := res_val_share_1980 * rar + (1 - res_val_share_1980) * nrar]

v_logs <- c("tax_rate", "revenue", "gallagher")
dt[, paste0(v_logs, "_ln") := lapply(.SD, log), .SDcols = v_logs]

# inspect ----
ggplot(dt[year == 1980], aes(x = res_val_share_1980 * 100)) +
    geom_histogram(
        aes(y = after_stat(count)), binwidth = 10, boundary = 0) +
    scale_x_continuous(breaks = seq(0, 100, 10)) +
    scale_y_continuous(breaks = seq(0, 12, 3)) +
    labs(
        title = "Distribution of Residential Valuation Share in 1980",
        x = "Residential Valuation Share (%)",
        y = "Count"
    ) +
    theme_classic()

ggplot(dt, aes(x = factor(year), y = tax_rate_res * 100)) +
    geom_boxplot(fill = v_palette[1], alpha = 0.7) +
    scale_y_continuous(breaks = seq(0, 1, 0.25), limits = c(0, 1.2)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
    labs(
        title = "Effective Residential Rates by Year",
        x = "", y = "Tax Rate (%)"
    ) +
    theme_classic()

# estimate ----
rev <- feols(
    revenue_ln ~ gallagher_ln + tax_rate_ln | county + year,
    data = dt
)
etable(rev, digits = 3)
