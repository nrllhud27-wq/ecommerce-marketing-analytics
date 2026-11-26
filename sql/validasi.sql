SELECT 'dim_customer' AS tbl, COUNT(*) AS n FROM dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL SELECT 'fact_orders', COUNT(*) FROM fact_orders
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM fact_order_items;

SELECT COUNT(*) AS valid_orders, ROUND(SUM(net_revenue), 2) AS valid_revenue
FROM fact_orders
WHERE is_valid_sale = 1;

SELECT
  (SELECT ROUND(SUM(gross_sales), 2) FROM fact_orders) AS orders_gross,
  (SELECT ROUND(SUM(gross_sales), 2) FROM fact_order_items WHERE is_reconciled_line = 1) AS reconciled_items_gross;
  
  SELECT SUM(delivery_days IS NULL)     AS no_delivery,
       SUM(coupon_code IS NULL)       AS no_coupon,
       SUM(campaign_name IS NULL)     AS no_campaign,
       SUM(return_status IS NOT NULL) AS returned
FROM fact_orders;