-- ============================================================
-- Quantium project: customer segment analysis (LIFESTAGE, PREMIUM_CUSTOMER)
-- Source table: transaction_joined
-- ============================================================


-- 1. Lifestage analysis: quantity, % of total quantity, sales, % of total sales
SELECT
    LIFESTAGE,
    SUM(PROD_QTY) AS total_qty,
    ROUND(SUM(PROD_QTY) / SUM(SUM(PROD_QTY)) OVER () * 100, 2) AS pct_total_qty,
    ROUND(SUM(TOT_SALES_formatted), 2) AS total_sales,
    ROUND(SUM(TOT_SALES_formatted) / SUM(SUM(TOT_SALES_formatted)) OVER () * 100, 2) AS pct_total_sales
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
GROUP BY LIFESTAGE
ORDER BY total_sales DESC;


-- 2. Lifestage quantity: average units per transaction line and gap to the average group total
SELECT
    LIFESTAGE,
    -- Average quantity per transaction line in the group
    ROUND(AVG(PROD_QTY), 2) AS avg_qty_per_line,
    -- Group total quantity minus the average of all group totals
    SUM(PROD_QTY) - ROUND(AVG(SUM(PROD_QTY)) OVER ()) AS quantity_gap
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
GROUP BY LIFESTAGE
ORDER BY quantity_gap DESC;


-- 3. Product ranking by lifestage (rank 1 = most bought product of the lifestage)
WITH qty_by_product AS (
    SELECT
        LIFESTAGE,
        PROD_NAME,
        SUM(PROD_QTY) AS total_qty
    FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
    GROUP BY LIFESTAGE, PROD_NAME
)
SELECT
    *,
    RANK() OVER (PARTITION BY LIFESTAGE ORDER BY total_qty DESC) AS rank_in_lifestage
FROM qty_by_product
ORDER BY rank_in_lifestage, LIFESTAGE;


-- 4. Share of each transaction line in the total quantity of its store
SELECT
    STORE_NBR,
    TXN_ID,
    ROUND(PROD_QTY / SUM(PROD_QTY) OVER (PARTITION BY STORE_NBR) * 100, 2) AS qty_share_in_store
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
ORDER BY STORE_NBR ASC, qty_share_in_store DESC;


-- 5. Customer segmentation: number of distinct customers by lifestage and premium type
SELECT
    LIFESTAGE,
    PREMIUM_CUSTOMER,
    COUNT(DISTINCT LYLTY_CARD_NBR) AS customer_count
FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
GROUP BY LIFESTAGE, PREMIUM_CUSTOMER
ORDER BY LIFESTAGE, customer_count DESC;


-- 6. Average spend per customer, by segment
WITH segment_totals AS (
    SELECT
        LIFESTAGE,
        PREMIUM_CUSTOMER,
        SUM(TOT_SALES_formatted) AS total_sales,
        COUNT(DISTINCT LYLTY_CARD_NBR) AS customer_count
    FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
    GROUP BY LIFESTAGE, PREMIUM_CUSTOMER
)
SELECT
    LIFESTAGE,
    PREMIUM_CUSTOMER,
    customer_count,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_sales / customer_count, 2) AS avg_sales_per_customer
FROM segment_totals
ORDER BY avg_sales_per_customer DESC;


-- 7. Buying frequency: average number of transactions per customer, by segment
WITH segment_totals AS (
    SELECT
        LIFESTAGE,
        PREMIUM_CUSTOMER,
        COUNT(DISTINCT TXN_ID) AS transaction_count,
        COUNT(DISTINCT LYLTY_CARD_NBR) AS customer_count
    FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
    GROUP BY LIFESTAGE, PREMIUM_CUSTOMER
)
SELECT
    *,
    ROUND(transaction_count / customer_count, 2) AS avg_transactions_per_customer
FROM segment_totals
ORDER BY avg_transactions_per_customer DESC;


-- 8. Basket value: average sales per transaction, by segment
WITH segment_totals AS (
    SELECT
        LIFESTAGE,
        PREMIUM_CUSTOMER,
        COUNT(DISTINCT TXN_ID) AS transaction_count,
        SUM(TOT_SALES_formatted) AS total_sales
    FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
    GROUP BY LIFESTAGE, PREMIUM_CUSTOMER
)
SELECT
    LIFESTAGE,
    PREMIUM_CUSTOMER,
    transaction_count,
    ROUND(total_sales, 2) AS total_sales,
    ROUND(total_sales / transaction_count, 2) AS avg_sales_per_transaction
FROM segment_totals
ORDER BY avg_sales_per_transaction DESC;


-- 9. Basket size: average units bought per transaction, by segment
WITH segment_totals AS (
    SELECT
        LIFESTAGE,
        PREMIUM_CUSTOMER,
        COUNT(DISTINCT TXN_ID) AS transaction_count,
        SUM(PROD_QTY) AS total_qty
    FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
    GROUP BY LIFESTAGE, PREMIUM_CUSTOMER
)
SELECT
    *,
    ROUND(total_qty / transaction_count, 2) AS avg_qty_per_transaction
FROM segment_totals
ORDER BY avg_qty_per_transaction DESC;


-- 10. Summary: spend per customer decomposed into three levers, with a rank per lever
--     sales per customer = frequency x basket size x price per unit
WITH segment_totals AS (
    SELECT
        LIFESTAGE,
        PREMIUM_CUSTOMER,
        COUNT(DISTINCT LYLTY_CARD_NBR) AS customer_count,
        COUNT(DISTINCT TXN_ID) AS transaction_count,
        SUM(PROD_QTY) AS total_qty,
        SUM(TOT_SALES_formatted) AS total_sales
    FROM `core-craft-477518-h7.portfolio_quantium_project.transaction_joined`
    GROUP BY LIFESTAGE, PREMIUM_CUSTOMER
),
segment_metrics AS (
    SELECT
        LIFESTAGE,
        PREMIUM_CUSTOMER,
        customer_count,
        ROUND(transaction_count / customer_count, 2) AS avg_transactions_per_customer,
        ROUND(total_qty / transaction_count, 2) AS basket_size,
        ROUND(total_sales / total_qty, 2) AS avg_price_per_unit,
        ROUND(total_sales / customer_count, 2) AS avg_sales_per_customer
    FROM segment_totals
)
SELECT
    *,
    RANK() OVER (ORDER BY avg_sales_per_customer DESC) AS rank_sales_per_customer,
    RANK() OVER (ORDER BY avg_transactions_per_customer DESC) AS rank_frequency,
    RANK() OVER (ORDER BY basket_size DESC) AS rank_basket_size,
    RANK() OVER (ORDER BY avg_price_per_unit DESC) AS rank_price_per_unit
FROM segment_metrics
ORDER BY rank_sales_per_customer;
