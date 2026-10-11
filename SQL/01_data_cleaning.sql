-- ============================================================
-- Quantium Retail Analytics: SQL Rebuild (BigQuery)
-- Phase 1: Data Cleaning & Preparation
-- Input (raw imports, never modified): transaction_data, purchase_behavior
-- Output: transaction_joined
-- The script can be re-run safely: it only (re)creates the output table.
-- ============================================================

-- Initial data exploration
SELECT * FROM `core-craft-477518-h7.portfolio_quantium_project.purchase_behavior` LIMIT 100;
SELECT * FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_data` LIMIT 100;


-- ------------------------------------------------------------
-- Format issues found in the raw transaction data
--
-- DATE: stored as an Excel serial number (days since 1899-12-30),
-- not a native SQL date, due to xlsx-to-CSV export.
-- Fix: add the number of days to 1899-12-30.
--
-- TOT_SALES: decimal separator was a comma (French locale CSV export),
-- causing BigQuery's auto-detect to misread values (e.g. 5,7 -> 57).
-- Fix: column imported as STRING, then converted to FLOAT64
-- after replacing the comma with a period.
-- ------------------------------------------------------------


-- ------------------------------------------------------------
-- Build the clean table
-- Fixes both formats and joins transactions with the customer
-- loyalty profile (LIFESTAGE, PREMIUM_CUSTOMER) via LYLTY_CARD_NBR.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE `core-craft-477518-h7.portfolio_quantium_project.transaction_joined` AS
SELECT
    t.* EXCEPT (`DATE`, TOT_SALES),
    CAST(REPLACE(t.TOT_SALES, ',', '.') AS FLOAT64) AS TOT_SALES_formatted,
    DATE_ADD(DATE '1899-12-30', INTERVAL t.`DATE` DAY) AS date_formatted,
    p.LIFESTAGE,
    p.PREMIUM_CUSTOMER
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_data` AS t
JOIN `core-craft-477518-h7.portfolio_quantium_project.purchase_behavior` AS p
  ON t.LYLTY_CARD_NBR = p.LYLTY_CARD_NBR;


-- ------------------------------------------------------------
-- Checks on the clean table
-- ------------------------------------------------------------

-- Row count and date range
-- Expected: 264,836 rows, from 2018-07-01 to 2019-06-30
SELECT
    COUNT(*) AS row_count,
    MIN(date_formatted) AS first_date,
    MAX(date_formatted) AS last_date
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`;

-- No missing values after conversion
-- Expected: 0 for each column
SELECT
    COUNTIF(date_formatted IS NULL) AS missing_dates,
    COUNTIF(TOT_SALES_formatted IS NULL) AS missing_sales,
    COUNTIF(LIFESTAGE IS NULL) AS missing_lifestage
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`;
