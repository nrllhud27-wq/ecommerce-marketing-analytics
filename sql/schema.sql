CREATE DATABASE IF NOT EXISTS ecommerce_marketing;
USE ecommerce_marketing;

-- Dimension: customers
CREATE TABLE dim_customer (
    customer_id               VARCHAR(15) PRIMARY KEY,
    customer_age              TINYINT UNSIGNED,
    gender                    VARCHAR(15),
    customer_segment          VARCHAR(15),
    customer_state            VARCHAR(30),
    customer_country          VARCHAR(20),
    region                    VARCHAR(15),
    customer_acquisition_cost DECIMAL(8,2),
    age_band                  VARCHAR(10)
);

-- Dimension: products
CREATE TABLE dim_product (
    product_id          VARCHAR(15) PRIMARY KEY,
    product_name        VARCHAR(100),
    product_category    VARCHAR(30),
    product_subcategory VARCHAR(30),
    brand               VARCHAR(30),
    supplier            VARCHAR(30),
    unit_price          DECIMAL(10,2),
    product_cost        DECIMAL(10,2),
    product_rating      DECIMAL(3,1)
);

-- Fact: orders (one row per order)
CREATE TABLE fact_orders (
    order_id                 VARCHAR(12) PRIMARY KEY,
    order_date               DATE,
    order_time               TIME,
    order_status             VARCHAR(12),
    sales_channel            VARCHAR(20),
    customer_id              VARCHAR(15),
    reported_customer_type   VARCHAR(15),
    payment_method           VARCHAR(25),
    payment_status           VARCHAR(15),
    currency                 CHAR(3),
    shipping_method          VARCHAR(15),
    warehouse                VARCHAR(10),
    delivery_days            TINYINT UNSIGNED NULL,
    estimated_delivery_days  TINYINT UNSIGNED NULL,
    delivery_status          VARCHAR(15),
    return_status            VARCHAR(15) NULL,
    return_reason            VARCHAR(30) NULL,
    customer_rating          DECIMAL(3,1) NULL,
    review_sentiment         VARCHAR(10) NULL,
    marketing_channel        VARCHAR(25),
    campaign_name            VARCHAR(30) NULL,
    coupon_code              VARCHAR(10) NULL,
    loyalty_points_earned    INT,
    loyalty_points_redeemed  INT,
    quantity                 INT,
    gross_sales              DECIMAL(12,2),
    discount_amount          DECIMAL(12,2),
    tax_amount               DECIMAL(12,2),
    shipping_cost            DECIMAL(10,2),
    invoice_total            DECIMAL(12,2),
    product_cost             DECIMAL(12,2),
    reported_profit          DECIMAL(12,2),
    reported_margin_pct      DECIMAL(8,2),
    reported_clv             DECIMAL(12,2),
    reported_is_repeat       TINYINT,
    reported_order_count     INT,
    order_year               SMALLINT,
    order_month              TINYINT,
    discount_season          VARCHAR(10),
    net_revenue              DECIMAL(12,2),
    gross_profit             DECIMAL(12,2),
    discount_rate            DECIMAL(6,4),
    is_valid_sale            TINYINT,
    is_returned              TINYINT,
    has_coupon               TINYINT,
    payment_pending          TINYINT,
    campaign_group           VARCHAR(12),
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
    INDEX idx_order_date (order_date),
    INDEX idx_order_status (order_status),
    INDEX idx_marketing_channel (marketing_channel)
);

-- Fact: order items (one row per product in an order)
CREATE TABLE fact_order_items (
    line_id             INT PRIMARY KEY,
    order_id            VARCHAR(12),
    product_id          VARCHAR(15),
    quantity            TINYINT UNSIGNED,
    unit_price          DECIMAL(10,2),
    discount_percentage DECIMAL(7,6),
    discount_amount     DECIMAL(12,2),
    gross_sales         DECIMAL(12,2),
    tax_amount          DECIMAL(12,2),
    shipping_cost       DECIMAL(10,2),
    invoice_total       DECIMAL(12,2),
    product_cost        DECIMAL(12,2),
    reported_profit     DECIMAL(12,2),
    is_reconciled_line  TINYINT,
    FOREIGN KEY (order_id)   REFERENCES fact_orders(order_id),
    FOREIGN KEY (product_id) REFERENCES dim_product(product_id)
);