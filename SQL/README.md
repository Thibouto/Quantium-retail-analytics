# Quantium Retail Analytics: customer segment analysis in SQL (BigQuery)

SQL redo of the Quantium retail case study (Forage virtual internship). The goal of this version is to answer one business question using SQL only: **which customer segments spend the most, and why?**

> This version focuses on SQL. The full case study (business context, data cleaning choices, statistical tests, store trial uplift analysis and final presentation) is documented in the [Python/R version](../Python/README.md).

## Business question

Which customer segments should the client target? For each combination of `LIFESTAGE` (7 values) and `PREMIUM_CUSTOMER` (Budget, Mainstream, Premium), 21 segments in total, I break down spend per customer into three levers:

> sales per customer = purchase frequency x basket size x price per unit

| Lever | Definition |
|-------|------------|
| Purchase frequency | transactions per customer |
| Basket size | units per transaction |
| Price per unit | sales divided by units |

## Data

Transaction data joined with customer attributes (`transaction_joined` in BigQuery): about 265k transaction lines, 72.6k customers, 1.93M in total sales. The cleaning step is in [`01_data_cleaning.sql`](01_data_cleaning.sql). For a description of the raw data, see the [Python/R version](../Python/README.md).

## Method

- BigQuery (GoogleSQL), free sandbox.
- CTEs to chain aggregation steps (`GROUP BY`, then ratios, then ranking).
- Window functions: `SUM(...) OVER ()`, `SUM(...) OVER (PARTITION BY ...)`, `RANK() OVER (ORDER BY ...)`.
- Distinct counts (`COUNT(DISTINCT ...)`) to count customers and transactions rather than rows.

Checks run on the results:
- Frequency x basket size x price per unit matches sales per customer (up to rounding).
- Orders of magnitude are plausible (basket size never below 1, price per unit of a few dollars).
- Segment totals reconcile with the table totals.

## Key findings

1. **Purchase frequency explains almost all of the gap.** The ranking of spend per customer is nearly identical to the ranking of frequency. From the best to the weakest segment, frequency is multiplied by 2 (4.99 vs 2.43 transactions per customer), while basket size varies by about 10% and price per unit by about 11%.
2. **Families spend the most.** Older Families and Young Families take the top 6 places with 34 to 36.5 per customer, roughly twice Young Singles/Couples (16 to 19.5).
3. **Premium status barely matters.** Within a `LIFESTAGE`, the three customer types differ by less than 1 per customer among families. `LIFESTAGE` is the segmentation that matters.
4. **Price per unit moves the other way.** Young Singles/Couples Mainstream pay the highest price per unit (4.08) but buy least often. Families buy more often at a lower price per unit.
5. **The largest segment spends little.** Young Singles/Couples Mainstream is 11% of customers (8,088) and 8.1% of sales, but spends 19.49 per customer.

## Recommendations

- **Retain families**: they already buy 4.7 to 5 times per customer. Loyalty programs and larger formats protect that.
- **Increase frequency of Young Singles/Couples Mainstream**: they already pay the highest price per unit, so one extra visit per period has the largest upside.
- **Segment on `LIFESTAGE` rather than on premium status**, since the latter differentiates spend very little.

## Limitations

- The period covered is not used in these queries, so "per customer" means over the whole period.
- Basket size and price per unit vary little between segments, so their rankings are fragile (differences of 0.01 change the rank).
- A line is not always a full transaction (about 0.65% more lines than distinct `TXN_ID`), and 2 transactions appear in two segments.
- These are correlations: the data does not say why families buy more often.

## Repository content

| File | Content |
|------|---------|
| [`01_data_cleaning.sql`](01_data_cleaning.sql) | Data cleaning (date and sales formats) and creation of `transaction_joined` |
| [`02_data_analysis.sql`](02_data_analysis.sql) | 10 analysis queries, from lifestage totals to the final segment summary (query 10) |

## Tools

BigQuery, SQL (CTEs, window functions).
