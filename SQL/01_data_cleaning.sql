-- ============================================================
-- Quantium Retail Analytics: SQL Rebuild (BigQuery)
-- Phase 1: Data Cleaning & Preparation
-- ============================================================

-- Initial data exploration
SELECT * FROM `core-craft-477518-h7.portfolio_quantium_project.purchase_behavior` LIMIT 100;
SELECT * FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_data` LIMIT 100;


-- ------------------------------------------------------------
-- 1.1 Fix DATE column
-- Issue: DATE was stored as an Excel serial number (days since
-- 1899-12-30), not a native SQL date, due to xlsx-to-CSV export.
-- ------------------------------------------------------------

ALTER TABLE `core-craft-477518-h7.portfolio_quantium_project.transaction_data`
ADD COLUMN IF NOT EXISTS date_formatted DATE;

UPDATE `core-craft-477518-h7.portfolio_quantium_project.transaction_data`
SET date_formatted = DATE_ADD(DATE '1899-12-30', INTERVAL `DATE` DAY)
WHERE TRUE;

ALTER TABLE `core-craft-477518-h7.portfolio_quantium_project.transaction_data`
DROP COLUMN IF EXISTS DATE;


-- ------------------------------------------------------------
-- 1.2 Fix TOT_SALES column
-- Issue: decimal separator was a comma (French locale CSV export),
-- causing BigQuery's auto-detect to misread values (e.g. 5,7 -> 57).
-- Fix: column was re-imported as STRING, then converted to FLOAT64
-- after replacing the comma with a period.
-- ------------------------------------------------------------

ALTER TABLE `core-craft-477518-h7.portfolio_quantium_project.transaction_data`
ADD COLUMN IF NOT EXISTS TOT_SALES_formatted FLOAT64;

UPDATE `core-craft-477518-h7.portfolio_quantium_project.transaction_data`
SET TOT_SALES_formatted = CAST(REPLACE(TOT_SALES, ',', '.') AS FLOAT64)
WHERE TRUE;

ALTER TABLE `core-craft-477518-h7.portfolio_quantium_project.transaction_data`
DROP COLUMN IF EXISTS TOT_SALES;


-- ------------------------------------------------------------
-- 1.3 Join transactions with customer segments
-- Combines transaction-level data with customer loyalty profile
-- (LIFESTAGE, PREMIUM_CUSTOMER) via LYLTY_CARD_NBR.
-- ------------------------------------------------------------

CREATE TABLE `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
AS SELECT
    t.*,
    p.LIFESTAGE,
    p.PREMIUM_CUSTOMER
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_data` AS t
JOIN `core-craft-477518-h7.portfolio_quantium_project.purchase_behavior` AS p
  ON t.LYLTY_CARD_NBR = p.LYLTY_CARD_NBR;
