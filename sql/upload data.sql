USE ecommerce_marketing;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers_clean.csv'
INTO TABLE dim_customer
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/products_clean.csv'
INTO TABLE dim_product
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/sales_clean.csv'
INTO TABLE fact_orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, order_date, order_time, order_status, sales_channel, customer_id,
 @skip_age, @skip_gender, @skip_segment, reported_customer_type,
 @skip_state, @skip_country, @skip_region,
 payment_method, payment_status, currency, shipping_method, warehouse,
 @delivery_days, @estimated_delivery_days, delivery_status,
 @return_status, @return_reason, @customer_rating, @review_sentiment,
 marketing_channel, @campaign_name, @coupon_code,
 loyalty_points_earned, loyalty_points_redeemed, quantity,
 gross_sales, discount_amount, tax_amount, shipping_cost, invoice_total, product_cost,
 reported_profit, reported_margin_pct, reported_clv, reported_is_repeat, reported_order_count,
 order_year, order_month, discount_season, net_revenue, gross_profit, discount_rate,
 is_valid_sale, is_returned, has_coupon, payment_pending, campaign_group)
SET
 delivery_days           = CAST(NULLIF(@delivery_days, '') AS DECIMAL(4,0)),
 estimated_delivery_days = CAST(NULLIF(@estimated_delivery_days, '') AS DECIMAL(4,0)),
 return_status           = NULLIF(@return_status, ''),
 return_reason           = NULLIF(@return_reason, ''),
 customer_rating         = NULLIF(@customer_rating, ''),
 review_sentiment        = NULLIF(@review_sentiment, ''),
 campaign_name           = NULLIF(@campaign_name, ''),
 coupon_code             = NULLIF(@coupon_code, '');
 
 LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/items_clean.csv'
INTO TABLE fact_order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id, product_id, quantity, unit_price, discount_percentage, discount_amount, gross_sales,
 tax_amount, shipping_cost, invoice_total, product_cost, reported_profit, line_id, is_reconciled_line);
 
 