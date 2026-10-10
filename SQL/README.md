# Quantium Retail Analytics: customer segments and store trial in SQL (BigQuery)

SQL redo of the Quantium retail case study (Forage virtual internship), built to practice SQL on BigQuery. The project answers two business questions using SQL only:

1. **Which customer segments spend the most, and why?**
2. **Did the trial increase sales in test stores 77, 86 and 88?**

> This version focuses on SQL. The full case study (business context, data quality checks, statistical tests and final presentation) is documented in the [Python/R version](../Python/README.md).

## Data

Transaction data joined with customer attributes (`transaction_joined` in BigQuery): about 265k transaction lines, 72.6k customers, 1.93M in total sales, from July 2018 to June 2019. The cleaning step is in [`01_data_cleaning.sql`](01_data_cleaning.sql).

**Scope of this version:** the goal here is to show SQL techniques, so the cleaning only fixes formats (dates and sales). The full cleaning (excluding salsa and dip products, which are not chips, the outlier loyalty card 226000 and duplicate rows) is done in the [Python/R version](../Python/README.md), which is the reference analysis. The figures and the selected control stores therefore differ between the two versions. For business conclusions, refer to the Python/R version.

## Part 1: customer segment analysis

### Business question

Quantium's retail client wants to know which customer segments to target. For each combination of `LIFESTAGE` (7 values) and `PREMIUM_CUSTOMER` (Budget, Mainstream, Premium), 21 segments in total, I break down spend per customer into three levers:

> sales per customer = purchase frequency x basket size x price per unit

| Lever | Definition |
|-------|------------|
| Purchase frequency | transactions per customer |
| Basket size | units per transaction |
| Price per unit | sales divided by units |

### Method

- BigQuery (GoogleSQL), free sandbox.
- CTEs to chain aggregation steps (`GROUP BY`, then ratios, then ranking).
- Window functions: `SUM(...) OVER ()`, `SUM(...) OVER (PARTITION BY ...)`, `RANK() OVER (ORDER BY ...)`.
- Distinct counts (`COUNT(DISTINCT ...)`) to count customers and transactions rather than rows.

Checks run on the results:
- Frequency x basket size x price per unit matches sales per customer (up to rounding).
- Orders of magnitude are plausible (basket size never below 1, price per unit of a few dollars).
- Segment totals reconcile with the table totals.

### Key findings

1. **Purchase frequency explains almost all of the gap.** The ranking of spend per customer is nearly identical to the ranking of frequency. From the best to the weakest segment, frequency is multiplied by 2 (4.99 vs 2.43 transactions per customer), while basket size varies by about 10% and price per unit by about 11%.
2. **Families spend the most.** Older Families and Young Families take the top 6 places with 34 to 36.5 per customer, roughly twice Young Singles/Couples (16 to 19.5).
3. **Premium status barely matters.** Within a `LIFESTAGE`, the three customer types differ by less than 1 per customer among families. `LIFESTAGE` is the segmentation that matters.
4. **Price per unit moves the other way.** Young Singles/Couples Mainstream pay the highest price per unit (4.08) but buy least often. Families buy more often at a lower price per unit.
5. **The largest segment spends little.** Young Singles/Couples Mainstream is 11% of customers (8,088) and 8.1% of sales, but spends 19.49 per customer.

### Recommendations

- **Retain families**: they already buy 4.7 to 5 times per customer. Loyalty programs and larger formats protect that.
- **Increase frequency of Young Singles/Couples Mainstream**: they already pay the highest price per unit, so one extra visit per period has the largest upside.
- **Segment on `LIFESTAGE` rather than on premium status**, since the latter differentiates spend very little.

### Limitations

- The period covered is not used in these queries, so "per customer" means over the whole period.
- Basket size and price per unit vary little between segments, so their rankings are fragile (differences of 0.01 change the rank).
- A line is not always a full transaction (about 0.65% more lines than distinct `TXN_ID`), and 2 transactions appear in two segments.
- These are correlations: the data does not say why families buy more often.

## Part 2: store trial analysis (stores 77, 86, 88)

### Business question

Did the trial, run in test stores 77, 86 and 88 from February to April 2019, increase their sales compared with similar stores that did not run it?

### Method

1. **Monthly metrics per store** (sales, transactions, customers), kept only for the 260 stores that have all 12 months.
2. **Pre-trial period**: July 2018 to January 2019 (7 months), used as the reference.
3. **Control store selection**: for each test store, compare its pre-trial monthly sales with every other store using two criteria. The **correlation** (similar shape, threshold 0.85) and the **average absolute gap** (similar size). Among candidates above the threshold, keep the smallest gap.
4. **Scaling**: multiply each control store's sales by the ratio of pre-trial sales (test store / control store), so both stores have the same size.
5. **Trial comparison**: monthly percentage difference between test store sales and scaled control sales, from February to April 2019.
6. **Significance test**: t-value = (trial gap minus mean pre-trial gap) divided by the standard deviation of the pre-trial gap. Critical value 1.94 (95% one-sided, 6 degrees of freedom).

SQL techniques: self-join, `CORR`, `STDDEV`, `RANK() OVER (PARTITION BY ...)`, CTEs, saved intermediate tables with `CREATE OR REPLACE TABLE`.

### Results

| Test store | Control store | Scale factor | February | March | April |
|---|---|---|---|---|---|
| 77 | 233 | 1.02 | -5.6% (not sig.) | +37.1% (sig.) | +62.9% (sig.) |
| 86 | 155 | 0.97 | +5.6% (not sig.) | +31.6% (sig.) | +3.5% (not sig.) |
| 88 | 134 | 3.07 | +28.4% (sig.) | +23.8% (sig.) | -21.2% (not sig.) |

Values are the difference between test store sales and scaled control sales. "sig." means a t-value above 1.94.

### Key findings

1. **Store 77: clear and growing uplift.** Not significant in February, then +37% in March (t = 3.54) and +63% in April (t = 6.11). This is the strongest evidence of an effect.
2. **Store 86: isolated spike.** Only March is significant (t = 8.34). February and April are within normal variation, so the effect is not sustained.
3. **Store 88: inconclusive.** Positive in February and March, then a drop in April. The swing comes mostly from the control store, whose sales are multiplied by 3.07, which amplifies its own fluctuations.

### Recommendations

- Treat the result for store 77 as the main evidence that the trial works.
- Do not conclude on store 86 from a single month. Check whether the effect repeats with more data.
- For store 88, look for a better sized control store or extend the period before drawing any conclusion.

### Limitations

- Only 7 pre-trial months are used to estimate normal variation, so t-values are indicative.
- 9 tests are run in parallel, which increases the risk of false positives.
- The one-sided test detects increases only, and says nothing about what the trial changed.
- Control store 134 is about 3 times smaller than store 88, so this comparison is the least reliable.
- The selection thresholds (correlation above 0.85) are a judgment call.

## Repository content

| File | Content |
|------|---------|
| [`01_data_cleaning.sql`](01_data_cleaning.sql) | Data cleaning (date and sales formats) and creation of `transaction_joined` |
| [`02_customer_analysis.sql`](02_customer_analysis.sql) | 10 analysis queries, from lifestage totals to the final segment summary (query 10) |
| [`03_store_matching.sql`](03_store_matching.sql) | Store trial analysis: control store selection, scaling, trial comparison and significance test |

## Tools

BigQuery, SQL (CTEs, window functions, self-joins, statistical aggregates).
