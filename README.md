# UPI State-Month Panel for India

A reproducible state/Union Territory-level monthly panel of UPI activity in India, constructed from the Reserve Bank of India (RBI) **State-wise UPI Product Statistics**.

The dataset is designed as a public research resource for work on digital payments, financial inclusion, digitalisation, regional development, and state-level panel analysis.

## Dataset Overview

* **Geographic unit:** State / Union Territory
* **Frequency:** Monthly
* **Period:** April 2023 – June 2026
* **States/UTs:** 36
* **Months:** 39
* **Observations:** 1,404
* **Source:** Reserve Bank of India (RBI)

The final dataset is a balanced panel:

**36 States/UTs × 39 months = 1,404 observations**

---

## Data Source

The underlying data come from the RBI's **State-wise UPI Product Statistics**.

The monthly RBI files report UPI transaction volume and transaction value by State/UT. During the period covered by this dataset, the structure of the RBI files changed.

### Why are there two source formats?

The RBI changed the structure of its State-wise UPI Product Statistics during the study period.

**Earlier files** report State/UT totals directly:

```text
State / Union Territory | Volume | Volume Contribution | Value | Value Contribution
```

**Later files** contain district-level observations as well as explicit State/UT total rows:

```text
State / Union Territory | District | Volume | Volume Contribution | Value | Value Contribution
```

For example, later files contain rows such as:

```text
MAHARASHTRA Total
KARNATAKA Total
UTTAR PRADESH Total
```

The replication script automatically detects which format each monthly file uses and applies the appropriate extraction method.

### Why are official State/UT totals used in the newer format?

For files containing district-level data, the pipeline uses the **official State/UT total reported by RBI** rather than reconstructing the State/UT total by summing districts.

This preserves the aggregate reported by the original source and avoids introducing discrepancies through independent aggregation.

Both source formats are then harmonised into a single State/UT-month panel.

---

## Variables

| Variable                       | Description                                                      | Unit                 |
| ------------------------------ | ---------------------------------------------------------------- | -------------------- |
| `state_id`                     | Numeric State/UT identifier                                      | Integer              |
| `state`                        | Harmonised State/UT name                                         | Text                 |
| `month`                        | Observation month                                                | Date                 |
| `year`                         | Calendar year                                                    | Integer              |
| `month_num`                    | Month number                                                     | Integer              |
| `year_month`                   | Year-month identifier                                            | YYYY-MM              |
| `time_id`                      | Sequential monthly time identifier                               | Integer              |
| `upi_volume_mn`                | UPI transaction volume                                           | Million transactions |
| `volume_contribution`          | State/UT contribution to national UPI volume                     | Percent              |
| `upi_value_cr`                 | UPI transaction value                                            | ₹ crore              |
| `value_contribution`           | State/UT contribution to national UPI value                      | Percent              |
| `source_file`                  | Original RBI source filename                                     | Text                 |
| `source_format`                | RBI source format used for extraction                            | Text                 |
---

## State/UT Harmonisation

One State/UT naming inconsistency was identified across the source files.

Earlier files use:

```text
ANDAMAN & NICOBAR
```

while later files use:

```text
ANDAMAN AND NICOBAR ISLANDS
```

The pipeline harmonises these to:

```text
ANDAMAN AND NICOBAR ISLANDS
```

This ensures that the State/UT is treated consistently across all months.

---

## Contribution Variables

The RBI-reported `volume_contribution` and `value_contribution` variables are retained rather than recalculated using only the 36 State/UT observations.

The RBI contribution measures use a national denominator that includes the **Unclassified** category.

Therefore, State/UT contribution percentages will generally **not sum to 100%** after the unclassified category is excluded.

This is intentional and preserves the meaning of the RBI-reported statistics.

### Contribution-scale correction

In five monthly source files, contribution values were stored as fractions rather than percentage points.

The affected months are:

* April 2023
* April 2025
* May 2025
* June 2025
* July 2025

For these months, contribution values are multiplied by 100.

For example:

```text
0.2098 → 20.98%
```

The original UPI transaction volume and transaction value are not altered.

The `contribution_scale_corrected` variable identifies observations affected by this transformation.

---

## Treatment of Unclassified Transactions

The RBI source contains an `UNCLASSIFIED#` category.

These observations are excluded from the State/UT panel because the purpose of this dataset is to provide comparable State/UT-level observations.

However, the unclassified category remains important when interpreting the contribution variables because the RBI-reported contribution shares use the national total.

Therefore, researchers should **not replace the RBI contribution variables with State/UT-only shares** unless they explicitly want to construct a different measure.

---

## Reproducibility

The complete data-construction pipeline is provided in:

```text
upi_state_month_panel_build.R
```

The script:

1. Identifies the monthly RBI Excel files.
2. Extracts the observation month from filenames.
3. Checks monthly coverage.
4. Detects the RBI source format.
5. Extracts State/UT observations.
6. Uses official State/UT totals in the newer district-level format.
7. Removes the unclassified category from the State/UT panel.
8. Harmonises State/UT names.
9. Applies the documented contribution-scale correction.
10. Creates State/UT and time identifiers.
11. Performs panel-quality checks.
12. Produces the final dataset.

### Reproduce the dataset

Place the original RBI Excel files in:

```text
raw/
```

Then run from the repository root:

```r
source("upi_state_month_panel_build.R")
```

The script will create the final dataset in:

```text
output/
```

---

## Repository Structure

```text
upi-state-month-panel/
│
├── README.md
├── upi_state_month_panel_build.R│
└── output/
    ├── upi_state_month_panel.csv
```

The original RBI Excel files are not included in this repository. Users can obtain the source files from RBI and reproduce the panel using the provided R script.

---

## Quality Checks

The construction pipeline verifies that the final panel has:

* 36 States/UTs
* 39 monthly observations per State/UT
* 1,404 total observations
* No duplicate `state_id × month` observations
* No missing State/UT or month identifiers
* Consistent State/UT naming
* Valid source-format classification
* A balanced State/UT-month panel

---

## Limitations

### UPI activity is not the same as the number of users

Transaction volume measures the number of transactions, not the number of unique UPI users.

Higher transaction volume may reflect differences in adoption, transaction frequency, merchant acceptance, or other factors.

### State-level aggregation

The dataset is aggregated to the State/UT level and does not provide individual-level information.

### Unclassified transactions

The treatment of the unclassified category means that RBI-reported contribution shares should not be interpreted as shares calculated only among the 36 included States/UTs.

### Source coverage

The panel begins in April 2023 because that is the earliest month included in this release. January–March 2023 are outside the coverage period rather than being imputed missing months.

---

## Research Applications

The panel can support research on:

* Digital payments
* Financial inclusion
* Digitalisation
* Regional development
* Digital public infrastructure
* State-level policy analysis
* Spatial differences in digital-payment activity
* State-level panel econometrics

The dataset can also be merged with other State/UT-level socioeconomic and development indicators, subject to appropriate geographic and temporal harmonisation.

---

## Citation

If you use this dataset, please cite:

1. The original Reserve Bank of India **State-wise UPI Product Statistics**.
2. This GitHub repository and its associated dataset release.

---

## Version

**Coverage:** April 2023 – June 2026
**Geography:** 36 States/UTs
**Frequency:** Monthly
**Observations:** 1,404
