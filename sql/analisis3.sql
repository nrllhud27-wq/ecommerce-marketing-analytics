-- membuat view vw_valid_lines
USE ecommerce_marketing;

CREATE OR REPLACE VIEW vw_valid_lines AS
SELECT
    i.line_id,
    i.order_id,
    o.order_date,
    o.marketing_channel,
    p.product_id,
    p.product_name,
    p.product_category,
    p.product_subcategory,
    p.brand,
    i.quantity,
    i.gross_sales - i.discount_amount                      AS net_revenue,
    i.gross_sales - i.discount_amount - i.product_cost     AS gross_profit
FROM fact_order_items i
JOIN fact_orders o ON i.order_id = o.order_id
JOIN dim_product p ON i.product_id = p.product_id
WHERE o.is_valid_sale = 1
  AND i.is_reconciled_line = 1;

-- validasi view  
SELECT COUNT(*) AS line_count,
       ROUND(SUM(net_revenue), 2)  AS net_revenue,
       ROUND(SUM(gross_profit), 2) AS gross_profit
FROM vw_valid_lines;

-- Performa per musim diskon
SELECT
    discount_season,
    COUNT(DISTINCT order_date)                                 AS active_days,
    COUNT(*)                                                   AS orders,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT order_date), 1)      AS orders_per_day,
    ROUND(AVG(quantity), 2)                                    AS avg_qty,
    ROUND(SUM(net_revenue) / COUNT(*), 2)                      AS aov,
    ROUND(SUM(discount_amount) * 100.0 / SUM(gross_sales), 2)  AS discount_rate_pct,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2)     AS margin_pct,
    ROUND(SUM(net_revenue) / COUNT(DISTINCT order_date), 0)    AS revenue_per_day,
    ROUND(SUM(gross_profit) / COUNT(DISTINCT order_date), 0)   AS profit_per_day
FROM fact_orders
WHERE is_valid_sale = 1
GROUP BY discount_season
ORDER BY discount_rate_pct;

-- per kategori
SELECT
    product_category,
    SUM(quantity)                                                      AS units,
    ROUND(SUM(net_revenue), 2)                                         AS net_revenue,
    ROUND(SUM(gross_profit), 2)                                        AS gross_profit,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2)             AS margin_pct,
    ROUND(SUM(net_revenue) * 100.0 / SUM(SUM(net_revenue)) OVER (), 2) AS revenue_share_pct,
    ROUND(SUM(gross_profit) * 100.0 / SUM(SUM(gross_profit)) OVER (), 2) AS profit_share_pct,
    RANK() OVER (ORDER BY SUM(gross_profit) DESC)                      AS profit_rank
FROM vw_valid_lines
GROUP BY product_category
ORDER BY gross_profit DESC;

-- 10 brand dengan profit terbesar
SELECT
    brand,
    COUNT(DISTINCT product_id)                              AS products,
    ROUND(SUM(net_revenue), 2)                              AS net_revenue,
    ROUND(SUM(gross_profit), 2)                             AS gross_profit,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2)  AS margin_pct,
    RANK() OVER (ORDER BY SUM(gross_profit) DESC)           AS profit_rank
FROM vw_valid_lines
GROUP BY brand
ORDER BY gross_profit DESC
LIMIT 10;

-- 10 produk dengan profit terbesar
SELECT
    product_name,
    product_category,
    SUM(quantity)                                           AS units,
    ROUND(SUM(net_revenue), 2)                              AS net_revenue,
    ROUND(SUM(gross_profit), 2)                             AS gross_profit,
    ROUND(SUM(gross_profit) * 100.0 / SUM(net_revenue), 2)  AS margin_pct,
    RANK() OVER (ORDER BY SUM(gross_profit) DESC)           AS profit_rank
FROM vw_valid_lines
GROUP BY product_id, product_name, product_category
ORDER BY gross_profit DESC
LIMIT 10;

-- Brand teratas di setiap kategori (ROW_NUMBER() dengan PARTITION BY)
WITH brand_profit AS (
    SELECT product_category, brand, SUM(gross_profit) AS gross_profit
    FROM vw_valid_lines
    GROUP BY product_category, brand
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY product_category ORDER BY gross_profit DESC) AS rn
    FROM brand_profit
)
SELECT product_category, brand AS top_brand, ROUND(gross_profit, 2) AS gross_profit
FROM ranked
WHERE rn = 1
ORDER BY gross_profit DESC;

-- Return Per channel
SELECT
    marketing_channel,
    SUM(is_valid_sale) AS completed,
    SUM(is_returned)   AS returned,
    ROUND(SUM(is_returned) * 100.0 / (SUM(is_valid_sale) + SUM(is_returned)), 2) AS return_rate_pct
FROM fact_orders
GROUP BY marketing_channel
ORDER BY return_rate_pct DESC;

-- Return Per kategori (per baris item yang tercatat di total order)
SELECT
    p.product_category,
    COUNT(*)                                          AS lines_total,
    SUM(o.is_returned)                                AS returned_lines,
    ROUND(SUM(o.is_returned) * 100.0 / COUNT(*), 2)   AS return_rate_pct
FROM fact_order_items i
JOIN fact_orders o ON i.order_id = o.order_id
JOIN dim_product p ON i.product_id = p.product_id
WHERE i.is_reconciled_line = 1
  AND (o.is_valid_sale = 1 OR o.is_returned = 1)
GROUP BY p.product_category
ORDER BY return_rate_pct DESC;

-- Alasan return
SELECT
    return_reason,
    COUNT(*)                                            AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)  AS pct_of_returns
FROM fact_orders
WHERE is_returned = 1
GROUP BY return_reason
ORDER BY orders DESC;