-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — Consultas Analíticas (OLAP)
-- ═══════════════════════════════════════════════════════════════════════════

-- Q1: Top 10 categorías por ingresos en 2018
SELECT
    category,
    SUM(gross_revenue)::NUMERIC(12,2) AS revenue_2018,
    SUM(orders_count)                 AS orders,
    AVG(avg_item_price)::NUMERIC(8,2) AS avg_price
FROM mv_sales_by_category_monthly
WHERE year_month >= '2018-01-01' AND year_month < '2019-01-01'
GROUP BY category
ORDER BY revenue_2018 DESC LIMIT 10;

-- Q2: Tendencia mensual de ventas
SELECT year_month,
    SUM(orders_count) AS orders,
    SUM(gross_revenue)::NUMERIC(12,2) AS revenue
FROM mv_sales_by_category_monthly
GROUP BY year_month ORDER BY year_month;

-- Q3: Segmentación RFM
SELECT segment, COUNT(*) AS clients,
    AVG(monetary_value)::NUMERIC(10,2) AS avg_lifetime_value,
    AVG(frequency)::NUMERIC(4,2) AS avg_orders,
    AVG(days_since_last)::INT AS avg_days_since_last
FROM mv_customer_segments
GROUP BY segment ORDER BY avg_lifetime_value DESC;

-- Q4: Ranking de vendedores por estado
SELECT seller_state, COUNT(*) AS total_sellers,
    SUM(gross_sales)::NUMERIC(12,2) AS gross_sales_state,
    AVG(avg_price)::NUMERIC(8,2) AS avg_price_state
FROM mv_seller_performance
GROUP BY seller_state ORDER BY gross_sales_state DESC;

-- Q5: Métodos de pago por estado
SELECT c.customer_state, op.payment_type,
    COUNT(*) AS payments,
    AVG(op.payment_value)::NUMERIC(8,2) AS avg_value,
    AVG(op.payment_installments)::NUMERIC(4,2) AS avg_installments
FROM order_payments op
JOIN orders o ON o.order_id = op.order_id AND o.order_purchase_timestamp = op.order_purchase_timestamp
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2019-01-01'
GROUP BY c.customer_state, op.payment_type
ORDER BY c.customer_state, payments DESC;

-- Q6: Time-to-deliver por estado
SELECT c.customer_state,
    COUNT(*) AS delivered_orders,
    AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))/86400.0)::NUMERIC(5,2) AS avg_days_to_deliver,
    AVG(EXTRACT(EPOCH FROM (o.order_estimated_delivery_date - o.order_delivered_customer_date))/86400.0)::NUMERIC(5,2) AS avg_days_anticipation
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state ORDER BY avg_days_to_deliver;

-- Q7: Verificación de partition pruning
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT COUNT(*) FROM orders
WHERE order_purchase_timestamp >= '2018-06-01'
  AND order_purchase_timestamp <  '2018-07-01';
