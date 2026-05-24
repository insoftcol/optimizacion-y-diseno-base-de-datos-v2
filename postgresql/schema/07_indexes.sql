-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — Script: 07_indexes.sql — Índices adicionales
-- ═══════════════════════════════════════════════════════════════════════════

\echo '→ Creando índices adicionales...'

-- geolocation
CREATE INDEX IF NOT EXISTS idx_geolocation_state ON geolocation (geolocation_state);
CREATE INDEX IF NOT EXISTS idx_geolocation_city ON geolocation (geolocation_city);

-- customers
CREATE INDEX IF NOT EXISTS idx_customers_zip ON customers (zip_code_prefix);
CREATE INDEX IF NOT EXISTS idx_customers_state ON customers (customer_state);
CREATE INDEX IF NOT EXISTS idx_customers_updated ON customers (updated_at);

-- sellers
CREATE INDEX IF NOT EXISTS idx_sellers_zip ON sellers (seller_zip_code_prefix);
CREATE INDEX IF NOT EXISTS idx_sellers_updated ON sellers (updated_at);

-- products
CREATE INDEX IF NOT EXISTS idx_products_category ON products (product_category_name);
CREATE INDEX IF NOT EXISTS idx_products_updated ON products (updated_at);

-- orders (heredados por particiones)
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status_active ON orders (order_status)
    WHERE order_status NOT IN ('delivered','canceled');
CREATE INDEX IF NOT EXISTS idx_orders_purchase_brin ON orders USING BRIN (order_purchase_timestamp);
CREATE INDEX IF NOT EXISTS idx_orders_updated ON orders (updated_at);

-- order_items
CREATE INDEX IF NOT EXISTS idx_items_product ON order_items (product_id);
CREATE INDEX IF NOT EXISTS idx_items_seller ON order_items (seller_id);

-- order_payments
CREATE INDEX IF NOT EXISTS idx_payments_type ON order_payments (payment_type);

-- promotions
CREATE INDEX IF NOT EXISTS idx_promo_product ON promotions (product_id);

-- audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_table ON audit_logs (table_name, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_changes_gin ON audit_logs USING GIN (changes);

\echo '→ Índices creados.'
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

\echo '✓ Script 07_indexes.sql completado.'
