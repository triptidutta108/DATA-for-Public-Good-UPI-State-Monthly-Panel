# ============================================================
# UPI STATE-MONTH PANEL: REPRODUCIBLE DATA CONSTRUCTION
# ============================================================
#
# Purpose:
#   Reconstruct the India State/UT-level monthly UPI panel from
#   RBI State-wise UPI Product Statistics.
#
# Coverage:
#   April 2023 - June 2026
#   36 States/UTs x 39 months = 1,404 observations
#
# Expected repository structure:
#
#   upi-state-month-panel/
#   ├── raw/
#   │   └── [RBI monthly Excel files]
#   ├── output/
#   └── upi_state_month_panel_replication.R
#
# The script handles the RBI source-format change:
#   1. Earlier files report State/UT rows directly.
#   2. Later files contain district rows plus official State/UT
#      "Total" rows.
#
# For the later format, the RBI-provided State/UT total is used
# directly; district observations are NOT re-aggregated.
#
# ============================================================

# ============================================================
# 1. PACKAGES AND PROJECT FOLDERS
# ============================================================

required_packages <- c(
  "readxl",
  "dplyr",
  "stringr",
  "purrr",
  "lubridate",
  "readr"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Please install the following packages before running this script: ",
    paste(missing_packages, collapse = ", ")
  )
}

library(readxl)
library(dplyr)
library(stringr)
library(purrr)
library(lubridate)
library(readr)

raw_dir <- "raw"
output_dir <- "output"

if (!dir.exists(raw_dir)) {
  stop(
    "The 'raw/' folder was not found. ",
    "Place the original RBI monthly Excel files in raw/."
  )
}

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# ============================================================
# 2. FIND SOURCE FILES
# ============================================================

files <- list.files(
  path = raw_dir,
  pattern = "\\.(xlsx|xls)$",
  full.names = TRUE,
  ignore.case = TRUE
)

files <- files[
  !grepl("^~\\$", basename(files))
]

if (length(files) == 0) {
  stop("No RBI Excel files were found in raw/.")
}

cat("Excel files found:", length(files), "\n")

# ============================================================
# 3. EXTRACT MONTH FROM FILE NAME
# ============================================================

month_lookup <- c(
  jan = 1,
  january = 1,
  feb = 2,
  february = 2,
  mar = 3,
  march = 3,
  apr = 4,
  april = 4,
  may = 5,
  jun = 6,
  june = 6,
  jul = 7,
  july = 7,
  aug = 8,
  august = 8,
  sep = 9,
  sept = 9,
  september = 9,
  oct = 10,
  october = 10,
  nov = 11,
  november = 11,
  dec = 12,
  december = 12
)

extract_date <- function(file) {

  fname <- tools::file_path_sans_ext(basename(file))

  fname_clean <- fname %>%
    str_to_lower() %>%
    str_replace_all("[_-]", " ") %>%
    str_squish()

  year_text <- str_extract(fname_clean, "20\\d{2}")

  month_text <- str_extract(
    fname_clean,
    paste(names(month_lookup), collapse = "|")
  )

  if (is.na(year_text) || is.na(month_text)) {
    return(as.Date(NA))
  }

  month_number <- unname(month_lookup[month_text])

  as.Date(
    sprintf("%s-%02d-01", year_text, month_number)
  )
}

# ============================================================
# 4. FILE INVENTORY AND COVERAGE CHECK
# ============================================================

file_inventory <- tibble(
  file = files,
  filename = basename(files),
  month = as.Date(
    vapply(
      files,
      function(x) as.character(extract_date(x)),
      character(1)
    )
  )
) %>%
  mutate(
    year = year(month),
    month_number = month(month)
  ) %>%
  arrange(month)

if (any(is.na(file_inventory$month))) {
  print(
    file_inventory %>%
      filter(is.na(month))
  )
  stop("At least one filename has an unrecognised date.")
}

expected_months <- seq(
  as.Date("2023-04-01"),
  as.Date("2026-06-01"),
  by = "month"
)

observed_months <- sort(unique(file_inventory$month))

missing_months <- setdiff(expected_months, observed_months)
extra_months <- setdiff(observed_months, expected_months)

duplicate_months <- file_inventory %>%
  count(month, name = "n_files") %>%
  filter(n_files > 1)

if (length(missing_months) > 0) {
  stop(
    "Missing expected months: ",
    paste(format(missing_months, "%Y-%m"), collapse = ", ")
  )
}

if (length(extra_months) > 0) {
  stop(
    "Files outside the expected coverage period: ",
    paste(format(extra_months, "%Y-%m"), collapse = ", ")
  )
}

if (nrow(duplicate_months) > 0) {
  stop("More than one source file was found for at least one month.")
}

if (nrow(file_inventory) != length(expected_months)) {
  stop(
    "Expected ",
    length(expected_months),
    " monthly files, but found ",
    nrow(file_inventory),
    "."
  )
}

cat("Coverage check: PASS\n")
cat("Months:", length(observed_months), "\n")
cat(
  "Date range:",
  format(min(observed_months), "%Y-%m"),
  "to",
  format(max(observed_months), "%Y-%m"),
  "\n"
)

# ============================================================
# 5. DETECT RBI SOURCE FORMAT
# ============================================================

detect_format <- function(file) {

  raw <- read_excel(
    file,
    sheet = 1,
    col_names = FALSE
  )

  n_cols <- ncol(raw)

  state_col <- as.character(raw[[2]])

  has_total_rows <- any(
    str_detect(
      str_to_upper(str_squish(state_col)),
      " TOTAL$"
    ),
    na.rm = TRUE
  )

  if (n_cols == 6 && !has_total_rows) {

    "old_state"

  } else if (n_cols == 7 && has_total_rows) {

    "new_district_total"

  } else {

    "UNKNOWN"
  }
}

file_inventory <- file_inventory %>%
  mutate(
    source_format = vapply(
      file,
      detect_format,
      character(1)
    )
  )

if (any(file_inventory$source_format == "UNKNOWN")) {
  print(
    file_inventory %>%
      filter(source_format == "UNKNOWN")
  )
  stop("At least one RBI file has an unrecognised structure.")
}

cat("\nSource formats:\n")
print(
  file_inventory %>%
    count(source_format)
)

# ============================================================
# 6. EXTRACT EARLIER RBI STATE-LEVEL FORMAT
# ============================================================

extract_old_format <- function(file) {

  raw <- read_excel(
    file,
    sheet = 1,
    col_names = FALSE
  )

  raw %>%
    slice(3:n()) %>%
    transmute(
      state = ...2,
      upi_volume_mn = ...3,
      volume_contribution = ...4,
      upi_value_cr = ...5,
      value_contribution = ...6
    ) %>%
    filter(
      !is.na(state),
      str_squish(as.character(state)) != "",
      !str_detect(
        str_to_upper(as.character(state)),
        "UNCLASSIFIED"
      )
    ) %>%
    mutate(
      state = str_squish(as.character(state)),
      upi_volume_mn = parse_number(
        as.character(upi_volume_mn),
        locale = locale(grouping_mark = ",")
      ),
      volume_contribution = parse_number(
        as.character(volume_contribution)
      ),
      upi_value_cr = parse_number(
        as.character(upi_value_cr),
        locale = locale(grouping_mark = ",")
      ),
      value_contribution = parse_number(
        as.character(value_contribution)
      ),
      month = extract_date(file),
      year = year(month),
      source_file = basename(file),
      source_format = "old_state"
    ) %>%
    select(
      month,
      year,
      state,
      upi_volume_mn,
      volume_contribution,
      upi_value_cr,
      value_contribution,
      source_file,
      source_format
    )
}

# ============================================================
# 7. EXTRACT NEWER RBI DISTRICT + STATE TOTAL FORMAT
# ============================================================

extract_new_format <- function(file) {

  raw <- read_excel(
    file,
    sheet = 1,
    col_names = FALSE
  )

  raw %>%
    slice(3:n()) %>%
    filter(
      str_detect(
        str_to_upper(str_squish(as.character(...2))),
        " TOTAL$"
      )
    ) %>%
    transmute(
      state = str_remove(
        str_squish(as.character(...2)),
        regex("\\s+Total$", ignore_case = TRUE)
      ),
      upi_volume_mn = ...4,
      volume_contribution = ...5,
      upi_value_cr = ...6,
      value_contribution = ...7
    ) %>%
    mutate(
      state = str_squish(state),
      upi_volume_mn = parse_number(
        as.character(upi_volume_mn),
        locale = locale(grouping_mark = ",")
      ),
      volume_contribution = parse_number(
        as.character(volume_contribution)
      ),
      upi_value_cr = parse_number(
        as.character(upi_value_cr),
        locale = locale(grouping_mark = ",")
      ),
      value_contribution = parse_number(
        as.character(value_contribution)
      ),
      month = extract_date(file),
      year = year(month),
      source_file = basename(file),
      source_format = "new_district_total"
    ) %>%
    select(
      month,
      year,
      state,
      upi_volume_mn,
      volume_contribution,
      upi_value_cr,
      value_contribution,
      source_file,
      source_format
    )
}

# ============================================================
# 8. EXTRACT ALL MONTHS
# ============================================================

extract_file <- function(file, format) {

  if (format == "old_state") {

    extract_old_format(file)

  } else if (format == "new_district_total") {

    extract_new_format(file)

  } else {

    stop(
      "Unknown source format for: ",
      basename(file)
    )
  }
}

all_data <- vector("list", nrow(file_inventory))

for (i in seq_len(nrow(file_inventory))) {

  cat(
    "Processing",
    i,
    "of",
    nrow(file_inventory),
    ":",
    file_inventory$filename[i],
    "\n"
  )

  all_data[[i]] <- extract_file(
    file_inventory$file[i],
    file_inventory$source_format[i]
  )
}

extraction_check <- tibble(
  filename = file_inventory$filename,
  month = file_inventory$month,
  source_format = file_inventory$source_format,
  rows_extracted = vapply(all_data, nrow, integer(1))
)

print(extraction_check)

# ============================================================
# 9. COMBINE MONTHLY DATA
# ============================================================

upi_panel <- bind_rows(all_data)

# ============================================================
# 10. HARMONISE STATE NAME
# ============================================================

upi_panel <- upi_panel %>%
  mutate(
    state = case_when(
      state == "ANDAMAN & NICOBAR" ~
        "ANDAMAN AND NICOBAR ISLANDS",
      TRUE ~ state
    )
  )

# ============================================================
# 11. REMOVE UNCLASSIFIED
# ============================================================

upi_panel <- upi_panel %>%
  filter(
    !str_detect(
      str_to_upper(state),
      "UNCLASSIFIED"
    )
  )

# ============================================================
# 12. STANDARDISE CONTRIBUTION SCALE
# ============================================================
#
# Verified source files for these five months encode the RBI
# contribution fields as fractions rather than percentage points.
#
# 0.2098 therefore represents 20.98%.
#
# The conversion is applied ONCE.

fraction_months <- as.Date(c(
  "2023-04-01",
  "2025-04-01",
  "2025-05-01",
  "2025-06-01",
  "2025-07-01"
))

upi_panel <- upi_panel %>%
  mutate(
    volume_contribution = if_else(
      month %in% fraction_months,
      volume_contribution * 100,
      volume_contribution
    ),
    value_contribution = if_else(
      month %in% fraction_months,
      value_contribution * 100,
      value_contribution
    )
  )

# ============================================================
# 13. CREATE PANEL IDENTIFIERS
# ============================================================

# Stable numeric State/UT identifier within this dataset release.
# The state name remains in the dataset so the mapping is explicit.

state_lookup <- upi_panel %>%
  distinct(state) %>%
  arrange(state) %>%
  mutate(
    state_id = row_number()
  )

upi_panel <- upi_panel %>%
  left_join(
    state_lookup,
    by = "state"
  ) %>%
  mutate(
    year = year(month),
    month_num = month(month),
    year_month = format(month, "%Y-%m"),
    time_id = interval(
      min(month),
      month
    ) %/% months(1) + 1
  ) %>%
  select(
    state_id,
    state,
    month,
    year,
    month_num,
    year_month,
    time_id,
    upi_volume_mn,
    volume_contribution,
    upi_value_cr,
    value_contribution,
    source_file,
    source_format
  ) %>%
  arrange(state_id, month)

# ============================================================
# 14. FINAL QUALITY CONTROL
# ============================================================

expected_states <- 36
expected_months_n <- 39
expected_observations <- expected_states * expected_months_n

cat("\n========== FINAL QC ==========\n")
cat("Rows:", nrow(upi_panel), "\n")
cat("Columns:", ncol(upi_panel), "\n")
cat("States/UTs:", n_distinct(upi_panel$state), "\n")
cat("Months:", n_distinct(upi_panel$month), "\n")
cat(
  "Date range:",
  format(min(upi_panel$month), "%Y-%m"),
  "to",
  format(max(upi_panel$month), "%Y-%m"),
  "\n"
)

if (nrow(upi_panel) != expected_observations) {
  stop(
    "Unexpected number of observations. Expected ",
    expected_observations,
    ", found ",
    nrow(upi_panel),
    "."
  )
}

if (n_distinct(upi_panel$state) != expected_states) {
  stop("Expected 36 States/UTs.")
}

if (n_distinct(upi_panel$month) != expected_months_n) {
  stop("Expected 39 monthly periods.")
}

duplicates <- upi_panel %>%
  count(state_id, month) %>%
  filter(n > 1)

if (nrow(duplicates) > 0) {
  stop("Duplicate state_id x month observations found.")
}

state_month_counts <- upi_panel %>%
  count(state_id, name = "n_months")

if (any(state_month_counts$n_months != expected_months_n)) {
  stop("Panel is not balanced.")
}

missing_key_values <- upi_panel %>%
  summarise(
    missing_state_id = sum(is.na(state_id)),
    missing_state = sum(is.na(state)),
    missing_month = sum(is.na(month)),
    missing_volume = sum(is.na(upi_volume_mn)),
    missing_value = sum(is.na(upi_value_cr))
  )

print(missing_key_values)

if (any(missing_key_values > 0)) {
  stop("Missing values found in required panel variables.")
}

# Ensure contributions are percentage-point values after correction.
fraction_check <- upi_panel %>%
  filter(
    (volume_contribution > 0 & volume_contribution < 1) |
      (value_contribution > 0 & value_contribution < 1)
  )

if (nrow(fraction_check) > 0) {
  stop("Fraction-scale contribution values remain after correction.")
}

cat("\nSource format distribution:\n")
print(upi_panel %>% count(source_format))

cat("\nFINAL QC: PASS\n")

# ============================================================
# 15. SAVE FINAL DATASET
# ============================================================

csv_path <- file.path(
  output_dir,
  "upi_state_month_panel.csv"
)

rds_path <- file.path(
  output_dir,
  "upi_state_month_panel.rds"
)

write_csv(
  upi_panel,
  csv_path
)

saveRDS(
  upi_panel,
  rds_path
)

cat("\n========== OUTPUTS SAVED ==========\n")
cat(csv_path, "\n")
cat(rds_path, "\n")
cat(
  "\nFinal dataset:",
  nrow(upi_panel),
  "rows x",
  ncol(upi_panel),
  "columns\n"
)

# ============================================================
# END
# ============================================================
