-- PostgreSQL schema for the portfolio dataset
CREATE TABLE products (
  product_id INTEGER PRIMARY KEY,
  product_name VARCHAR(160), brand VARCHAR(60), category VARCHAR(80), subcategory VARCHAR(100),
  list_price INTEGER, cost_price INTEGER, active_from DATE, active_to DATE
);
CREATE TABLE customers (
  customer_id INTEGER PRIMARY KEY, full_name VARCHAR(160), registration_date DATE, city VARCHAR(80), first_touch_channel VARCHAR(40)
);
CREATE TABLE sessions (
  session_id BIGINT PRIMARY KEY, session_start TIMESTAMP, customer_id INTEGER, city VARCHAR(80), device_type VARCHAR(20),
  channel VARCHAR(40), campaign_id VARCHAR(30), landing_category VARCHAR(80), product_views INTEGER, add_to_cart INTEGER,
  checkout_started INTEGER, order_id BIGINT, purchase_completed INTEGER
);
CREATE TABLE orders (
  order_id BIGINT PRIMARY KEY, customer_id INTEGER, session_id BIGINT, order_datetime TIMESTAMP, order_status VARCHAR(30),
  delivery_type VARCHAR(40), delivery_city VARCHAR(80), gross_amount INTEGER, discount_amount INTEGER, delivery_fee INTEGER, final_amount INTEGER
);
CREATE TABLE order_items (
  order_item_id BIGINT PRIMARY KEY, order_id BIGINT, product_id INTEGER, quantity INTEGER, unit_price INTEGER, discount_pct INTEGER, line_amount INTEGER
);
CREATE TABLE payments (
  payment_id BIGINT PRIMARY KEY, order_id BIGINT, payment_datetime TIMESTAMP, payment_method VARCHAR(60),
  payment_status VARCHAR(30), failure_reason VARCHAR(120), amount INTEGER
);
CREATE TABLE marketing_spend (
  spend_id INTEGER PRIMARY KEY, spend_date DATE, campaign_id VARCHAR(30), campaign_name VARCHAR(80), channel VARCHAR(40),
  impressions INTEGER, clicks INTEGER, spend_rub INTEGER
);
