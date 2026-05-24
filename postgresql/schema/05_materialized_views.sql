-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — PostgreSQL 16
-- Script: 05_materialized_views.sql — Vistas materializadas para OLAP
-- ═══════════════════════════════════════════════════════════════════════════

\echo '→ Creando vistas materializadas...'

-- MV 1: Ventas mensuales por categoría
DROP MATERIALIZED VIEW IF EXISTS mv_sales_by_category_monthly CASCADE;
CREATE MATERIALIZED VIEW mv_sales_by_category_monthly AS
SELECT
    date_trunc('month', o.order_purchase_timestamp)  AS year_month,
    COALESCE(pcnt.product_category_name_english, 'sin_categoria') AS category,
    COUNT(DISTINCT o.order_id)                       AS orders_count,
    COUNT(oi.*)                                      AS items_count,
    SUM(oi.price)                                    AS gross_sales,
    SUM(oi.freight_value)                            AS total_freight,
    SUM(oi.price + oi.freight_value)                 AS gross_revenue,
    AVG(oi.price)                                    AS avg_item_price,
    AVG(oi.freight_value)                            AS avg_freight
FROM orders o
JOIN order_items oi
    ON  oi.order_id = o.order_id
    AND oi.order_purchase_timestamp = o.order_purchase_timestamp
JOIN products p ON p.product_id = oi.product_id
LEFT JOIN product_category_name_translation pcnt
    ON pcnt.product_category_name = p.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY 1, 2
WITH NO DATA;

CREATE UNIQUE INDEX uidx_mv_sales_cat_month
    ON mv_sales_by_category_monthly (year_month, category);
CREATE INDEX idx_mv_sales_cat
    ON mv_sales_by_category_monthly (category);

-- MV 2: Segmentos RFM
DROP MATERIALIZED VIEW IF EXISTS mv_customer_segments CASCADE;
CREATE MATERIALIZED VIEW mv_customer_segments AS
WITH base AS (
    SELECT
        o.customer_id,
        MAX(o.order_purchase_timestamp)             AS last_order_date,
        COUNT(DISTINCT o.order_id)                  AS frequency,
        SUM(op.payment_value)                       AS monetary_value,
        EXTRACT(DAY FROM NOW() - MAX(o.order_purchase_timestamp)) AS days_since_last
    FROM orders o
    JOIN order_payments op
        ON  op.order_id = o.order_id
        AND op.order_purchase_timestamp = o.order_purchase_timestamp
    WHERE o.order_status = 'delivered'
    GROUP BY o.customer_id
),
rfm AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY last_order_date DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency        DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value   DESC) AS m_score
    FROM base
)
SELECT
    customer_id, last_order_date,
    days_since_last::INTEGER AS days_since_last,
    frequency, monetary_value, r_score, f_score, m_score,
    (r_score * 100 + f_score * 10 + m_score) AS rfm_score,
    CASE
        WHEN r_score = 1 AND f_score <= 2 AND m_score <= 2 THEN 'champion'
        WHEN r_score <= 2 AND f_score <= 2                  THEN 'loyal'
        WHEN r_score >= 4                                   THEN 'at_risk'
        WHEN r_score >= 3 AND m_score >= 4                  THEN 'big_spender'
        ELSE 'regular'
    END AS segment,
    NOW() AS computed_at
FROM rfm
WITH NO DATA;

CREATE UNIQUE INDEX uidx_mv_segments ON mv_customer_segments (customer_id);
CREATE INDEX idx_mv_segments_seg ON mv_customer_segments (segment);

-- MV 3: Performance de vendedores
DROP MATERIALIZED VIEW IF EXISTS mv_seller_performance CASCADE;
CREATE MATERIALIZED VIEW mv_seller_performance AS
WITH seller_sales AS (
    SELECT
        oi.seller_id,
        COUNT(DISTINCT oi.order_id)  AS total_orders,
        COUNT(*)                     AS total_items,
        SUM(oi.price)                AS gross_sales,
        AVG(oi.price)                AS avg_price
    FROM order_items oi
    JOIN orders o
        ON  o.order_id = oi.order_id
        AND o.order_purchase_timestamp = oi.order_purchase_timestamp
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT
    s.seller_id, s.seller_state, s.seller_city,
    COALESCE(ss.total_orders, 0)  AS total_orders,
    COALESCE(ss.total_items, 0)   AS total_items,
    COALESCE(ss.gross_sales, 0)   AS gross_sales,
    COALESCE(ss.avg_price, 0)     AS avg_price,
    NOW() AS computed_at
FROM sellers s
LEFT JOIN seller_sales ss USING (seller_id)
WITH NO DATA;

CREATE UNIQUE INDEX uidx_mv_seller_perf ON mv_seller_performance (seller_id);
CREATE INDEX idx_mv_seller_state ON mv_seller_performance (seller_state);

\echo '✓ Script 05_materialized_views.sql completado.'
\echo '  Ejecutar REFRESH MATERIALIZED VIEW <nombre> después de cargar datos.'
