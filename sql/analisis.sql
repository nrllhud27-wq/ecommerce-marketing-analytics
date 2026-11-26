-- Ringkasan KPI
USE ecommerce_marketing;

SELECT
    COUNT(*)                                              AS orders,
    COUNT(DISTINCT customer_id)                           AS active_customers,
    ROUND(SUM(net_revenue), 2)                            AS net_revenue,
    ROUND(SUM(gross_profit), 2)                           AS gross_profit,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2) AS margin_pct,
    ROUND(SUM(net_revenue) / COUNT(*), 2)                 AS aov,
    ROUND(SUM(discount_amount) * 100.0 / SUM(gross_sales), 2) AS discount_rate_pct
FROM fact_orders
WHERE is_valid_sale = 1;

SELECT ROUND(SUM(is_returned) * 100.0 / (SUM(is_valid_sale) + SUM(is_returned)), 2) AS return_rate_pct
FROM fact_orders;

-- Kinerja per marketing channel
SELECT
    marketing_channel,
    COUNT(*)                                                         AS orders,
    ROUND(SUM(net_revenue), 2)                                       AS net_revenue,
    ROUND(SUM(gross_profit), 2)                                      AS gross_profit,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2)           AS margin_pct,
    ROUND(SUM(net_revenue) * 100.0 / SUM(SUM(net_revenue)) OVER (), 2) AS revenue_share_pct,
    ROUND(SUM(gross_profit) * 100.0 / SUM(SUM(gross_profit)) OVER (), 2) AS profit_share_pct
FROM fact_orders
WHERE is_valid_sale = 1
GROUP BY marketing_channel
ORDER BY net_revenue DESC;

-- Tren tahunan dan pola musiman
WITH yearly AS (
    SELECT
        order_year,
        COUNT(*)                   AS orders,
        ROUND(SUM(net_revenue), 2) AS net_revenue,
        ROUND(SUM(gross_profit), 2) AS gross_profit
    FROM fact_orders
    WHERE is_valid_sale = 1
    GROUP BY order_year
)
SELECT
    order_year, orders, net_revenue, gross_profit,
    ROUND(gross_profit * 100.0 / net_revenue, 2) AS margin_pct,
    ROUND((net_revenue / LAG(net_revenue) OVER (ORDER BY order_year) - 1) * 100, 2) AS yoy_pct
FROM yearly
ORDER BY order_year;

WITH monthly AS (
    SELECT order_month, SUM(net_revenue) AS net_revenue
    FROM fact_orders
    WHERE is_valid_sale = 1
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(net_revenue, 2)                        AS net_revenue,
    ROUND(net_revenue / AVG(net_revenue) OVER (), 2) AS seasonal_index
FROM monthly
ORDER BY order_month;