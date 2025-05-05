# Mill levy analysis script

rm(list = ls())
library(here)
library(data.table)
library(ggplot2)
library(readxl)
library(stringr)
library(kableExtra)

# Create directory for results
dir.create(here("results"), showWarnings = FALSE)

# Import ----
dt_levies <- readRDS(here("derived", "mill-levies.Rds"))

# Summary statistics
summary_stats <- dt_levies[, .(
  mean_levy = mean(county_mill_levy, na.rm = TRUE),
  median_levy = median(county_mill_levy, na.rm = TRUE),
  min_levy = min(county_mill_levy, na.rm = TRUE),
  max_levy = max(county_mill_levy, na.rm = TRUE),
  sd_levy = sd(county_mill_levy, na.rm = TRUE),
  count = .N
), by = year]

kbl(summary_stats)

# Create histogram of mill levy values
ggplot(dt_levies, aes(x = mill_levy)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "black") +
  labs(title = "Distribution of Mill Levy Values",
       x = "Mill Levy", y = "Count") +
  theme_minimal()


# Create time series plot of average mill levy by year
ggplot(summary_stats[year >= 1980], aes(x = year, y = mean_levy)) +
  geom_line(color = "steelblue", size = 1) +
  geom_point(color = "steelblue", size = 3) +
  labs(title = "Average Mill Levy Over Time",
       x = "", y = "Average Mill Levy") +
  theme_classic()


# Create boxplot of mill levy distribution by year
ggplot(dt_levies, aes(x = factor(year), y = county_mill_levy)) +
  geom_boxplot(fill = "steelblue", alpha = 0.7) +
  labs(title = "Mill Levy Distribution by Year",
       x = "Year", y = "Mill Levy") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

cat("Analysis complete. Results saved to the 'results' directory.\n")