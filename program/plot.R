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

# RAR by year
dt_year <- unique(dt[, .(year, rar, nrar)])
dt_year <- melt(
    dt_year, id.vars = "year", variable.name = "property_type",
    value.name = "assessment_rate")
dt_year[, property_type := fifelse(
    property_type == "rar",
    "Residential", "Non-Residential")]

ggplot(dt_year,
    aes(x = year, y = assessment_rate, color = property_type,
    group = property_type, shape = property_type)) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_line(linewidth = 1) +
    geom_point(size = 3) +
    scale_color_manual(values = v_palette, name = "") +
    scale_shape(name = "") +
    theme_classic(base_size = 14) +
    labs(x = "", y = "Assessment Rate")
ggsave(here("results", "plots", "rar_by_year.pdf"),
    width = 9, height = 5)

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
    tax_rate = weighted.mean(tax_rate * 100, pop_1980),
    tax_rate_avg = weighted.mean(tax_rate_avg * 100, pop_1980),
    permits_tot = sum(permits_tot_pcap, na.rm = TRUE),
    hpi = weighted.mean(hpi, pop_1980, na.rm = TRUE),
    revenue = sum(revenue),
    pop = sum(pop),
    pop_1980 = sum(pop_1980),
    mkt_val_total = sum(mkt_val_total),
    mkt_val_resi = sum(mkt_val_resi),
    assessed_valuation = sum(assessed_valuation),
    assessed_resi = sum(assessed_resi)
), by = .(year, resi_group)]
dt_resi[, revenue_pcap := revenue / pop]
dt_resi[, val_share_resi := mkt_val_resi / mkt_val_total]
dt_resi[, assessed_share_resi := assessed_resi / assessed_valuation]
dt_resi[, permits_tot_pcap := 1000 * permits_tot / pop_1980]
dt_resi[, hpi := 100 * hpi / hpi[year == 1990], by = resi_group]
dt_resi[, assessed_val_pcap := assessed_valuation / pop_1980]
dt_resi[, assessed_val_resi_pcap := assessed_resi / pop_1980]

v_labs <- c(
    tax_rate_avg = "Effective Tax Rate (%)",
    tax_rate = "Effective Residential Tax Rate (%)",
    revenue_pcap = "Revenue per Capita ($)",
    hpi = "HPI (1990 = 100)",
    val_share_resi = "Market Valuation Share (%)",
    assessed_share_resi = "Assessed Valuation Share (%)",
    assessed_val_pcap = "Assessed Valuation per Capita ($)",
    assessed_val_resi_pcap = "Assessed Residential Valuation per Capita ($)",
    permits_tot_pcap = "Permits per 1000",
    eff_ar = "Effective Assessment Ratio"
)

plot_by_group <- function(var) {
    dt_graph <- copy(dt_resi)

    setnames(dt_graph, var, "outcome")

    ggplot(dt_graph, aes(
        x = year, y = outcome, color = resi_group,
        group = resi_group)
    ) +
    geom_point() +
    geom_line(linetype = "dashed") +
        geom_hline(yintercept = 0, linetype = "dashed") +
        labs(
            x = "", y = v_labs[[var]]
        ) +
        theme_classic(base_size = 14) +
        scale_color_manual(values = v_palette, name = "") +
        theme(
            legend.position = "right")

    ggsave(here("results", "plots", paste0(var, "_by_resi_group.pdf")),
        width = 9, height = 5)
}

v_out <- names(v_labs)

lapply(v_out, plot_by_group)
