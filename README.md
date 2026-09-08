# Quantium Retail Strategy & Analytics

This project was completed as part of the Quantium Virtual Internship (Forage). It analyzes chip category sales for a retail client, using transaction and customer loyalty data, to answer two business questions: who are the most valuable customer segments, and did a new store layout trial actually work?

## Structure

### [1. Data preparation & customer analytics](<1. Data preparation & customer analytics>)
Cleans and merges transaction and customer loyalty data, then profiles customer segments by life stage and spending tier. Identifies Mainstream Young Singles/Couples as the priority segment, and confirms with a statistical test that this segment pays a significant price premium over Budget/Premium shoppers in the same life stage.

- `1.0 Data cleaning.ipynb` (Python)
- `1.1 Customer analytics.Rmd` (R) / `report/1.1-Customer-analytics.md` (rendered version, GitHub doesn't preview `.Rmd` source directly)

### [2. Experimentation and uplift testing](<2. Experimentation and uplift testing>)
Assesses whether a new store layout, trialled in three stores, produced a statistically significant sales uplift. Matches each trial store to a control store based on pre-trial performance, then tests the trial period against a confidence interval built from pre-trial variability.

- `2.0 Experimentation and uplift testing.ipynb` (Python)

### [3. Analytics and commercial application](<3. Analytics and commercial application>)
Synthesizes the findings from parts 1 and 2 into a business-facing presentation for a Category Manager, structured using the Pyramid Principle (conclusion first, supporting evidence after).

- `3.0 Category review - Chips.pptx` / `.pdf`

## Tools

Python (pandas, matplotlib, seaborn, scipy), R (dplyr, ggplot2), Jupyter, R Markdown.

## Data

Source data provided by the Quantium Virtual Internship program (not included in this repository where restricted).
