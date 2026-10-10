-- ============================================================
-- Quantium Retail Analytics: Store trial analysis (BigQuery)
-- Goal: measure the impact of the trial in stores 77, 86 and 88
-- Data range: 2018-07-01 to 2019-06-30 (12 months)
-- Pre-trial period: Jul 2018 to Jan 2019 (7 months)
-- Trial period: Feb 2019 to Apr 2019 (3 months)
-- Source table: transaction_joined
-- ============================================================


-- ------------------------------------------------------------
-- Step 1: monthly metrics per store
-- (sales, transactions, customers, transactions per customer)
-- Saved as a table to reuse in the next steps
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE `core-craft-477518-h7.portfolio_quantium_project.store_monthly_metrics` AS
SELECT
  STORE_NBR,
  DATE_TRUNC(date_formatted, MONTH) AS month_start,
  COUNT(DISTINCT TXN_ID) AS transaction_count,
  ROUND(SUM(TOT_SALES_formatted), 2) AS total_sales,
  COUNT(DISTINCT LYLTY_CARD_NBR) AS unique_customers,
  ROUND(COUNT(DISTINCT TXN_ID) / COUNT(DISTINCT LYLTY_CARD_NBR), 2) AS avg_transactions_per_customer
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
GROUP BY STORE_NBR, month_start;
-- Check: 3,169 rows


-- ------------------------------------------------------------
-- Step 2: keep only stores with data for all 12 months
-- Stores with missing months cannot be compared fairly
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE `core-craft-477518-h7.portfolio_quantium_project.store_monthly_metrics_complete` AS
SELECT
  *
FROM `core-craft-477518-h7.portfolio_quantium_project.store_monthly_metrics`
WHERE STORE_NBR IN (
  SELECT
    STORE_NBR
  FROM `core-craft-477518-h7.portfolio_quantium_project.store_monthly_metrics`
  GROUP BY STORE_NBR
  HAVING COUNT(month_start) = 12
);
-- Check: 3,120 rows, 260 distinct stores


-- ------------------------------------------------------------
-- Step 3: pre-trial period (Jul 2018 to Jan 2019)
-- Reference period used to choose control stores
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE `core-craft-477518-h7.portfolio_quantium_project.store_pretrial_metrics` AS
SELECT
  *
FROM `core-craft-477518-h7.portfolio_quantium_project.store_monthly_metrics_complete`
WHERE month_start BETWEEN '2018-07-01' AND '2019-01-01';
-- Check: 1,820 rows (260 stores x 7 months)


-- ------------------------------------------------------------
-- Step 4: control store selection
-- For each trial store, compare its pre-trial monthly sales with every
-- other store using two criteria:
--   - correlation of monthly sales (similar shape)
--   - average absolute gap in monthly sales (similar size)
-- Keep candidates with correlation above 0.85, then pick the smallest gap.
-- The 0.85 threshold keeps only closely matching shapes.
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE `core-craft-477518-h7.portfolio_quantium_project.store_pairs` AS
WITH pair_metrics AS (
  SELECT
    candidate.STORE_NBR,
    trial.STORE_NBR AS trial_store,
    ROUND(CORR(trial.total_sales, candidate.total_sales), 2) AS sales_correlation,
    ROUND(AVG(ABS(trial.total_sales - candidate.total_sales)), 2) AS avg_sales_gap
  FROM `core-craft-477518-h7.portfolio_quantium_project.store_pretrial_metrics` AS trial
  JOIN `core-craft-477518-h7.portfolio_quantium_project.store_pretrial_metrics` AS candidate
    ON trial.month_start = candidate.month_start
  WHERE trial.STORE_NBR IN (77, 86, 88)
    AND candidate.STORE_NBR NOT IN (77, 86, 88)
  GROUP BY trial.STORE_NBR, candidate.STORE_NBR
  HAVING sales_correlation > 0.85
),
ranked_pairs AS (
  SELECT
    *,
    RANK() OVER (PARTITION BY trial_store ORDER BY avg_sales_gap) AS gap_rank
  FROM pair_metrics
)
SELECT
  STORE_NBR AS control_store,
  trial_store
FROM ranked_pairs
WHERE gap_rank = 1;
-- Result: 77 -> 233, 86 -> 155, 88 -> 134


-- ------------------------------------------------------------
-- Step 5: scale factor
-- Pre-trial sales of the trial store / pre-trial sales of its control store
-- Used to bring the control store to the size of the trial store
-- Note: store 88 has a factor of about 3, so its comparison is less reliable
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE `core-craft-477518-h7.portfolio_quantium_project.store_scale_factor` AS
WITH store_totals AS (
  SELECT
    STORE_NBR,
    ROUND(SUM(total_sales), 2) AS pretrial_sales
  FROM `core-craft-477518-h7.portfolio_quantium_project.store_pretrial_metrics`
  GROUP BY STORE_NBR
)
SELECT
  pairs.trial_store,
  pairs.control_store,
  ROUND(trial_totals.pretrial_sales / control_totals.pretrial_sales, 2) AS scale_factor
FROM `core-craft-477518-h7.portfolio_quantium_project.store_pairs` AS pairs
JOIN store_totals AS control_totals
  ON pairs.control_store = control_totals.STORE_NBR
JOIN store_totals AS trial_totals
  ON pairs.trial_store = trial_totals.STORE_NBR;
-- Result: 77 -> 1.02, 86 -> 0.97, 88 -> 3.07


-- ------------------------------------------------------------
-- Step 6: trial period comparison (Feb to Apr 2019)
-- Trial store sales vs control store sales scaled to trial store size
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE `core-craft-477518-h7.portfolio_quantium_project.trial_comparison` AS
WITH trial_period AS (
  SELECT
    STORE_NBR,
    month_start,
    total_sales
  FROM `core-craft-477518-h7.portfolio_quantium_project.store_monthly_metrics_complete`
  WHERE month_start BETWEEN '2019-02-01' AND '2019-04-01'
)
SELECT
  trial_sales.month_start,
  sf.trial_store,
  sf.control_store,
  trial_sales.total_sales AS trial_sales_amount,
  ROUND(control_sales.total_sales * sf.scale_factor, 2) AS scaled_control_sales,
  ROUND(
    (trial_sales.total_sales - control_sales.total_sales * sf.scale_factor)
    / (control_sales.total_sales * sf.scale_factor) * 100,
    2
  ) AS pct_difference
FROM trial_period AS trial_sales
JOIN `core-craft-477518-h7.portfolio_quantium_project.store_scale_factor` AS sf
  ON sf.trial_store = trial_sales.STORE_NBR
JOIN trial_period AS control_sales
  ON sf.control_store = control_sales.STORE_NBR
  AND trial_sales.month_start = control_sales.month_start;
-- Check: 9 rows (3 pairs x 3 months)


-- ------------------------------------------------------------
-- Step 7: same comparison on the pre-trial period (Jul 2018 to Jan 2019)
-- Gives the normal variation of the gap before the trial
-- ------------------------------------------------------------
CREATE OR REPLACE TABLE `core-craft-477518-h7.portfolio_quantium_project.pretrial_comparison` AS
SELECT
  trial_sales.month_start,
  sf.trial_store,
  sf.control_store,
  trial_sales.total_sales AS trial_sales_amount,
  ROUND(control_sales.total_sales * sf.scale_factor, 2) AS scaled_control_sales,
  ROUND(
    (trial_sales.total_sales - control_sales.total_sales * sf.scale_factor)
    / (control_sales.total_sales * sf.scale_factor) * 100,
    2
  ) AS pct_difference
FROM `core-craft-477518-h7.portfolio_quantium_project.store_pretrial_metrics` AS trial_sales
JOIN `core-craft-477518-h7.portfolio_quantium_project.store_scale_factor` AS sf
  ON sf.trial_store = trial_sales.STORE_NBR
JOIN `core-craft-477518-h7.portfolio_quantium_project.store_pretrial_metrics` AS control_sales
  ON sf.control_store = control_sales.STORE_NBR
  AND trial_sales.month_start = control_sales.month_start;
-- Check: 21 rows (3 pairs x 7 months)


-- ------------------------------------------------------------
-- Step 8: significance test
-- t_value = (trial gap - mean pre-trial gap) / std dev of pre-trial gap
-- Critical value 1.94 (95% one-sided, 6 degrees of freedom: 7 pre-trial months)
-- This tests an increase only. A two-sided test would use 2.45.
-- ------------------------------------------------------------
WITH pretrial_stats AS (
  SELECT
    trial_store,
    AVG(pct_difference) AS mean_pct_difference,
    STDDEV(pct_difference) AS std_pct_difference
  FROM `core-craft-477518-h7.portfolio_quantium_project.pretrial_comparison`
  GROUP BY trial_store
)
SELECT
  t.month_start,
  t.trial_store,
  t.control_store,
  t.pct_difference,
  ROUND(s.std_pct_difference, 2) AS pretrial_std,
  ROUND((t.pct_difference - s.mean_pct_difference) / s.std_pct_difference, 2) AS t_value,
  (t.pct_difference - s.mean_pct_difference) / s.std_pct_difference > 1.94 AS is_significant_increase
FROM `core-craft-477518-h7.portfolio_quantium_project.trial_comparison` AS t
JOIN pretrial_stats AS s
  ON t.trial_store = s.trial_store
ORDER BY t.trial_store, t.month_start;
-- Check: 9 rows
