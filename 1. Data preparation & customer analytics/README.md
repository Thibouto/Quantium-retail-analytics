# Data Preparation & Customer Analytics

This folder covers the first part of the Quantium retail analytics case study: cleaning the raw transaction and customer loyalty data, then profiling customer segments to identify the category's priority audience.

## Contents

- **`1.0 Data cleaning.ipynb`** (Python): merges the transaction and customer loyalty datasets, checks data quality, and removes outliers.
- **[`1.1-Customer-analytics.md`](<1.1-Customer-analytics.md>)** (rendered from `1.1 Customer analytics.Rmd`, R): profiles customer segments by life stage and spending tier (Budget/Mainstream/Premium), analyzes sales and pricing patterns, and runs a statistical test to confirm a key finding. Read the `.md` for the formatted version with output and plots, GitHub doesn't render the `.Rmd` source directly.
- **`cleaned_data.csv`**: the merged, cleaned dataset used as input for both this analysis and Part 2.

## Data quality checks

- **Missing, null, or inconsistent values**: none found (e.g. no negative sales).
- **Outlier removed**: loyalty card 226000 recorded two transactions of 200 units of "Dorito Corn Chp Supreme 380g" ($650 each, on 19/08/2018 and 20/05/2019, different transaction IDs, so not duplicates). This is far above the dataset average (1.9 units / $7.3 per transaction). With only these two transactions across the full year, both at unusually high quantities, this pattern is more consistent with commercial resale than typical retail customer behavior, so the card was excluded from the analysis.
- **Date continuity**: across the full observation period (01/07/2018-30/06/2019, 365 days), only one date is missing from the data: 25/12/2018 (Christmas Day), consistent with stores being closed rather than a data issue.

## Key findings

- **Mainstream Young Singles/Couples** is the priority segment for the chips category: it accounts for the highest concentration of sales among all life stage x spending tier combinations, and Mainstream shoppers in this segment pay a statistically significant price premium (+9%, p < 2.2e-16) over Budget/Premium shoppers in the same life stage.
- Older families and retirees drive volume primarily through purchase frequency rather than price, the opposite pattern from the priority segment.
- Within the priority segment, Kettle is the leading brand by sales, and the 175g pack size is the most popular.
