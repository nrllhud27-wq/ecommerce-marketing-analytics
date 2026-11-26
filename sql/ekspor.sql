-- cek view
USE ecommerce_marketing;
SHOW FULL TABLES WHERE Table_type = 'VIEW';

USE ecommerce_marketing;

-- 1. Orders
CREATE OR REPLACE VIEW vw_fact_orders AS
SELECT
    order_id, order_date, order_year, order_month, order_status, sales_channel, customer_id,
    marketing_channel, campaign_group, campaign_name, discount_season, return_reason,
    quantity, gross_sales, discount_amount, net_revenue, gross_profit,
    is_valid_sale, is_returned,
    CASE
        WHEN discount_amount = 0                   THEN '1. 0%'
        WHEN discount_amount / gross_sales <= 0.05 THEN '2. 0-5%'
        WHEN discount_amount / gross_sales <= 0.10 THEN '3. 5-10%'
        WHEN discount_amount / gross_sales <= 0.20 THEN '4. 10-20%'
        WHEN discount_amount / gross_sales <= 0.30 THEN '5. 20-30%'
        WHEN discount_amount / gross_sales <= 0.40 THEN '6. 30-40%'
        WHEN discount_amount / gross_sales <= 0.50 THEN '7. 40-50%'
        ELSE '8. >50%'
    END AS discount_band
FROM fact_orders;

-- 2. RFM per customer
CREATE OR REPLACE VIEW vw_customer_rfm AS
WITH customer_rfm AS (
    SELECT
        customer_id,
        DATEDIFF('2026-01-01', MAX(order_date)) AS recency_days,
        COUNT(*)                                AS frequency,
        SUM(net_revenue)                        AS monetary,
        SUM(gross_profit)                       AS profit
    FROM fact_orders
    WHERE is_valid_sale = 1
    GROUP BY customer_id
),
scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC, customer_id) AS r_score,
        CASE WHEN frequency <= 2 THEN 1
             WHEN frequency = 3  THEN 2
             WHEN frequency = 4  THEN 3
             WHEN frequency <= 6 THEN 4
             ELSE 5 END                                          AS f_score
    FROM customer_rfm
)
SELECT
    customer_id, recency_days, frequency, monetary, profit, r_score, f_score,
    CASE WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
         WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
         WHEN f_score >= 4                    THEN 'Loyal'
         WHEN r_score >= 4                    THEN 'Recent'
         WHEN r_score <= 2                    THEN 'Inactive'
         ELSE 'Regular' END                                      AS rfm_segment
FROM scored;

-- 3. Customer dimension with RFM segment
CREATE OR REPLACE VIEW vw_dim_customer AS
SELECT
    c.customer_id, c.customer_segment, c.customer_country, c.region, c.gender, c.age_band,
    COALESCE(r.rfm_segment, 'No valid order') AS rfm_segment,
    r.recency_days, r.frequency
FROM dim_customer c
LEFT JOIN vw_customer_rfm r ON c.customer_id = r.customer_id;

SELECT
    (SELECT COUNT(*) FROM vw_fact_orders)   AS fact_orders_rows,
    (SELECT COUNT(*) FROM vw_dim_customer)  AS dim_customer_rows,
    (SELECT COUNT(*) FROM vw_valid_lines)   AS valid_lines_rows;
    
SELECT rfm_segment, COUNT(*) AS customers
FROM vw_dim_customer
GROUP BY rfm_segment
ORDER BY customers DESC;

SELECT order_id, order_date, order_year, order_month, order_status, sales_channel, customer_id,
       marketing_channel, campaign_group,
       COALESCE(campaign_name, 'Not tagged')   AS campaign_name,
       discount_season,
       COALESCE(return_reason, 'Not returned') AS return_reason,
       quantity, gross_sales, discount_amount, net_revenue, gross_profit,
       is_valid_sale, is_returned, discount_band
FROM vw_fact_orders;

SELECT customer_id, customer_segment, customer_country, region, gender, age_band, rfm_segment
FROM vw_dim_customer;

SELECT * FROM vw_valid_lines;