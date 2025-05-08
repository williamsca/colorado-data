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

# inspect ----
# residential valuation shares in 1980
ggplot(dt[year == 1980], aes(x = val_share_resi * 100)) +
    geom_hline(yintercept = seq(0, 15, 3), linetype = "dotted", color = "gray") +
    geom_histogram(
        aes(y = after_stat(count)), binwidth = 15, boundary = 0,
        fill = v_palette[1]) +
    scale_x_continuous(breaks = seq(0, 90, 15)) +
    scale_y_continuous(breaks = seq(0, 15, 3)) +
    labs(
        x = "Residential Valuation Share (%)",
        y = "Count"
    ) +
    theme_classic(base_size = 14)
ggsave(here("results", "plots", "resi_val_share_1980.pdf"),
    width = 9, height = 5)

# effective residential tax rates over time
# ... across counties
ggplot(dt, aes(x = factor(year), y = tax_rate_res * 100)) +
    geom_boxplot(fill = v_palette[1], alpha = 0.7) +
    scale_y_continuous(breaks = seq(0, 1, 0.25), limits = c(0, 1.2)) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    labs(
        title = "Effective Tax Rates by Year",
        x = "", y = "Tax Rate (%)"
    ) +
    theme_classic()

# ... compared to the average tax rate
dt_long <- melt(dt,
    id.vars = c("county", "year"),
    measure.vars = c("tax_rate_res", "tax_rate_avg"),
    variable.name = "tax_rate_type", value.name = "tax_rate"
)
dt_long <- dt_long[,
    .(tax_rate = mean(tax_rate)), by = .(year, tax_rate_type)]
dt_long[, tax_rate_type := fifelse(tax_rate_type == "tax_rate_res",
    "Residential", "All Properties")]
ggplot(dt_long, aes(
    x = year, y = tax_rate * 100, color = tax_rate_type,
    group = tax_rate_type)
) +
    geom_hline(yintercept = seq(.2, .6, .2), linetype = "dotted", color = "gray") +
    geom_line(linewidth = 2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    labs(
        x = "", y = "Effective Tax Rate (%)"
    ) +
    theme_classic(base_size = 14) +
    scale_color_manual(values = v_palette[1:2], name = "") +
    theme(legend.position = "bottom")

# ... for high- and low-residential valuation share counties
dt_resi <- dt[, .(
    tax_rate = mean(tax_rate * 100),
    tax_rate_avg = mean(tax_rate_avg * 100)
), by = .(year, resi_group)]
ggplot(dt_resi, aes(
    x = year, y = tax_rate_avg, color = resi_group,
    group = resi_group)
) +
    geom_hline(
        yintercept = seq(.2, .6, .2), linetype = "dotted", color = "gray") +
    geom_line(linewidth = 2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    labs(
        x = "", y = "Effective Tax Rate (%)"
    ) +
    theme_classic(base_size = 14) +
    scale_color_manual(values = v_palette[1:2], name = "") +
    theme(legend.position = "bottom")
ggsave(here("results", "plots", "effective_tax_rate_by_resi_share.pdf"),
    width = 9, height = 5)

# tax revenues per capita over time
# ... for high and low-residential valuation share counties
dt_rev <- dt[, .(
    revenue = sum(revenue),
    pop = sum(pop),
    mkt_val_total = sum(mkt_val_total),
    mkt_val_resi = sum(mkt_val_resi),
    assessed_valuation = sum(assessed_valuation),
    assessed_resi = sum(assessed_resi)
), by = .(year, resi_group)]
dt_rev[, revenue_pcap := revenue / pop]
dt_rev[, val_share_resi := mkt_val_resi / mkt_val_total]
dt_rev[, assessed_share_resi := assessed_resi / assessed_valuation]

ggplot(dt_rev, aes(
    x = year, y = revenue_pcap, color = resi_group,
    group = resi_group)
) +
    # geom_hline(yintercept = seq(0, 2000, 500), linetype = "dotted", color = "gray") +
    geom_line(linewidth = 2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    labs(
        x = "", y = "Revenue per Capita ($)"
    ) +
    theme_classic(base_size = 14) +
    scale_color_manual(values = v_palette[1:2], name = "") +
    theme(legend.position = "bottom")

# resi value shares over time
# ... for high and low-residential valuation share counties
ggplot(dt_rev, aes(
        x = year, y = val_share_resi * 100,
        color = resi_group, group = resi_group)) +
    geom_line(linewidth = 2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    labs(
        x = "", y = "Market Valuation Share (%)"
    ) +
    scale_color_manual(values = v_palette[1:2], name = "") +
    theme_classic(base_size = 14)

ggplot(dt_rev, aes(
        x = year, y = assessed_share_resi * 100,
        color = resi_group, group = resi_group)) +
    geom_line(linewidth = 2) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    labs(
        x = "", y = "Assessed Valuation Share (%)"
    ) +
    scale_color_manual(values = v_palette[1:2], name = "") +
    theme_classic(base_size = 14)

# estimate ----

# accounting identity: coefficients should all equal 1
rev <- feols(
    revenue_ln ~ eff_ar_ln + tax_rate_ln + mkt_val_total_ln | county + year,
    data = dt
)
etable(rev, digits = 3)

# IV for effective assessment ratio using pre-determined shares
v_out <- c(
    "revenue_ln", "revenue_pcap", "mkt_val_total_ln",
    "mkt_val_resi_ln", "mkt_val_other_ln", "tax_rate_ln",
    "val_share_resi"
)
s_out <- paste0("c(", paste(v_out, collapse = ", "), ")")

fmla_iv <- as.formula(paste0(
    s_out, " ~ -1 | county + year | eff_ar_ln ~ gallagher_ln"
))

rev_iv <- feols(
    fmla_iv, data = dt, weights = ~pop_1980
)

# counties hit with a Gallagher shock to their effective assessment rates see *lower* "market" values (driven by lower non-residential values), *higher* mill rates, and *lower* revenues??? could treated counties be underassessing commercial/industrial properties? Need to think carefully about differences between high- and low-Gallagher counties
etable(rev_iv[lhs = "revenue"], digits = 3, stage = 1:2, fitstat = "ivf")

etable(rev_iv[lhs = "mkt_val_total"], digits = 3, stage = 1:2, fitstat = "ivf")

etable(rev_iv[lhs = "mkt_val_resi"], digits = 3, stage = 1:2, fitstat = "ivf")

etable(rev_iv[lhs = "mkt_val_other"], digits = 3, stage = 1:2, fitstat = "ivf")

etable(rev_iv[lhs = "tax_rate"], digits = 3, stage = 1:2, fitstat = "ivf")

etable(rev_iv[lhs = "val_share_resi"], digits = 3, stage = 1:2, fitstat = "ivf")
