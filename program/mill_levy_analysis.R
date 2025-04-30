# Mill levy analysis script
library(here)
library(data.table)
library(ggplot2)
library(readxl)
library(stringr)

# Create directory for results
dir.create(here("results"), showWarnings = FALSE)

# Process all mill levy Excel files
mill_levy_files <- list.files(
  path = here("derived", "mill-levies"),
  pattern = "*.xlsx",
  full.names = TRUE
)

# Function to extract mill levy data from files
process_mill_levy_file <- function(file_path) {
  filename <- basename(file_path)
  year <- as.numeric(str_extract(filename, "^\\d{4}"))
  
  # Handle case when no year is found
  if (is.na(year)) {
    year <- as.numeric(str_extract(filename, "\\d{4}"))
  }
  
  tryCatch({
    dt <- as.data.table(read_xlsx(file_path, col_names = TRUE))
    
    # Convert column names to lowercase and replace spaces with underscores
    setnames(dt, tolower(gsub(" ", "_", names(dt))))
    
    # Print column names for debugging
    print(paste("File:", filename, "Columns:", paste(names(dt), collapse=", ")))
    
    # Find columns containing county names and mill levy data
    if ("...1" %in% names(dt)) {
      county_col <- "...1"  # First column is usually counties
    } else {
      county_col <- names(dt)[grepl("county$|counties$|^county", names(dt), ignore.case = TRUE)][1]
    }
    
    mill_levy_col <- names(dt)[grepl("county_mill_levy", names(dt), ignore.case = TRUE)][1]
    
    print(paste("Selected columns:", county_col, mill_levy_col))
    
    if (is.na(county_col) || is.na(mill_levy_col)) {
      warning(paste("Cannot identify county or mill levy column in", filename))
      return(NULL)
    }
    
    # Select and rename relevant columns
    result <- dt[, c(county_col, mill_levy_col), with = FALSE]
    setnames(result, c("county", "mill_levy"))
    
    # Clean county names and mill levy values
    result[, county := str_trim(gsub("\\$|\\*|\\s+$", "", county))]
    result <- result[!is.na(county) & county != "" & !grepl("(?i)(total|state|average)", county)]
    result[, mill_levy := as.numeric(gsub(",|\\$|\\s", "", mill_levy))]
    result[, year := year]
    
    return(result[, .(county, mill_levy, year)])
  }, error = function(e) {
    warning(paste("Error processing", filename, ":", e$message))
    return(NULL)
  })
}

# Process all files and combine results
all_mill_levies <- rbindlist(
  lapply(mill_levy_files, process_mill_levy_file),
  use.names = TRUE,
  fill = TRUE
)

# Data validation
cat("Mill levy data summary:\n")
cat("Total records:", nrow(all_mill_levies), "\n")
cat("Years covered:", paste(sort(unique(all_mill_levies$year)), collapse = ", "), "\n")
cat("Counties covered:", length(unique(all_mill_levies$county)), "\n")
cat("Missing mill levy values:", sum(is.na(all_mill_levies$mill_levy)), "\n")

# Save processed data
saveRDS(all_mill_levies, file = here("results", "mill_levies.Rds"))
write.csv(all_mill_levies, file = here("results", "mill_levies.csv"), row.names = FALSE)

# Summary statistics
summary_stats <- all_mill_levies[, .(
  mean_levy = mean(mill_levy, na.rm = TRUE),
  median_levy = median(mill_levy, na.rm = TRUE),
  min_levy = min(mill_levy, na.rm = TRUE),
  max_levy = max(mill_levy, na.rm = TRUE),
  sd_levy = sd(mill_levy, na.rm = TRUE),
  count = .N
), by = year]

# Save summary statistics
write.csv(summary_stats, file = here("results", "mill_levy_summary_by_year.csv"), row.names = FALSE)

# Create histogram of mill levy values
p1 <- ggplot(all_mill_levies, aes(x = mill_levy)) +
  geom_histogram(bins = 30, fill = "steelblue", color = "black") +
  labs(title = "Distribution of Mill Levy Values",
       x = "Mill Levy", y = "Count") +
  theme_minimal()
ggsave(here("results", "mill_levy_histogram.png"), p1, width = 8, height = 6)

# Create time series plot of average mill levy by year
p2 <- ggplot(summary_stats, aes(x = year, y = mean_levy)) +
  geom_line(color = "steelblue", size = 1) +
  geom_point(color = "steelblue", size = 3) +
  labs(title = "Average Mill Levy Over Time",
       x = "Year", y = "Average Mill Levy") +
  theme_minimal()
ggsave(here("results", "mill_levy_time_series.png"), p2, width = 8, height = 6)

# Create boxplot of mill levy distribution by year
p3 <- ggplot(all_mill_levies, aes(x = factor(year), y = mill_levy)) +
  geom_boxplot(fill = "steelblue", alpha = 0.7) +
  labs(title = "Mill Levy Distribution by Year",
       x = "Year", y = "Mill Levy") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(here("results", "mill_levy_boxplot_by_year.png"), p3, width = 10, height = 6)

cat("Analysis complete. Results saved to the 'results' directory.\n")