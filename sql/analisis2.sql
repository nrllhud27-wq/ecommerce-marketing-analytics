-- Cakupan campaign
SELECT
    campaign_group,
    COUNT(*)                                              AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)    AS pct_orders,
    ROUND(SUM(net_revenue), 2)                            AS net_revenue,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2) AS margin_pct
FROM fact_orders
WHERE is_valid_sale = 1
GROUP BY campaign_group
ORDER BY orders DESC;

-- Peringkat campaign bernama (hanya 23.1% order di atas)
SELECT
    campaign_name,
    marketing_channel,
    COUNT(*)                                                         AS orders,
    ROUND(SUM(net_revenue), 2)                                       AS net_revenue,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2)           AS margin_pct,
    ROUND(SUM(net_revenue) * 100.0 / SUM(SUM(net_revenue)) OVER (), 2) AS share_of_named_pct,
    RANK() OVER (ORDER BY SUM(net_revenue) DESC)                     AS revenue_rank
FROM fact_orders
WHERE is_valid_sale = 1 AND campaign_group = 'Named'
GROUP BY campaign_name, marketing_channel
ORDER BY net_revenue DESC;

-- Nilai per segmen customer
SELECT
    c.customer_segment,
    COUNT(DISTINCT o.customer_id)                                        AS customers,
    COUNT(*)                                                             AS orders,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT o.customer_id), 2)             AS orders_per_customer,
    ROUND(SUM(o.net_revenue), 2)                                         AS net_revenue,
    ROUND(SUM(o.net_revenue) / COUNT(DISTINCT o.customer_id), 2)         AS revenue_per_customer,
    ROUND(SUM(o.gross_profit) / COUNT(DISTINCT o.customer_id), 2)        AS profit_per_customer,
    ROUND(SUM(o.discount_amount) * 100.0 / SUM(o.gross_sales), 2)        AS discount_rate_pct,
    ROUND(SUM(o.gross_profit) * 100.0 / SUM(o.net_revenue), 2)           AS margin_pct
FROM fact_orders o
JOIN dim_customer c ON o.customer_id = c.customer_id
WHERE o.is_valid_sale = 1
GROUP BY c.customer_segment
ORDER BY profit_per_customer DESC;

-- Segmentasi RFM
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
             ELSE 5 END                                          AS f_score,
        NTILE(5) OVER (ORDER BY monetary, customer_id)          AS m_score
    FROM customer_rfm
),
segmented AS (
    SELECT *,
        CASE WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
             WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
             WHEN f_score >= 4                    THEN 'Loyal'
             WHEN r_score >= 4                    THEN 'Recent'
             WHEN r_score <= 2                    THEN 'Inactive'
             ELSE 'Regular' END                                  AS rfm_segment
    FROM scored
)
SELECT
    rfm_segment,
    COUNT(*)                                                       AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)             AS customer_share_pct,
    ROUND(SUM(monetary), 2)                                        AS net_revenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 1)   AS revenue_share_pct,
    ROUND(AVG(frequency), 1)                                       AS avg_orders,
    ROUND(AVG(recency_days), 0)                                    AS avg_recency_days,
    ROUND(SUM(profit) / COUNT(*), 2)                               AS profit_per_customer
FROM segmented
GROUP BY rfm_segment
ORDER BY net_revenue DESC;

-- Margin per band diskon
WITH banded AS (
    SELECT
        CASE
            WHEN discount_amount = 0                    THEN '1. 0%'
            WHEN discount_amount / gross_sales <= 0.05  THEN '2. 0-5%'
            WHEN discount_amount / gross_sales <= 0.10  THEN '3. 5-10%'
            WHEN discount_amount / gross_sales <= 0.20  THEN '4. 10-20%'
            WHEN discount_amount / gross_sales <= 0.30  THEN '5. 20-30%'
            WHEN discount_amount / gross_sales <= 0.40  THEN '6. 30-40%'
            WHEN discount_amount / gross_sales <= 0.50  THEN '7. 40-50%'
            ELSE '8. >50%'
        END AS discount_band,
        net_revenue, gross_profit, quantity
    FROM fact_orders
    WHERE is_valid_sale = 1
)
SELECT
    discount_band,
    COUNT(*)                                               AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)     AS order_share_pct,
    ROUND(AVG(quantity), 2)                                AS avg_qty,
    ROUND(AVG(net_revenue), 2)                             AS aov,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2) AS margin_pct,
    ROUND(SUM(gross_profit < 0) * 100.0 / COUNT(*), 2)     AS loss_orders_pct
FROM banded
GROUP BY discount_band
ORDER BY discount_band;

