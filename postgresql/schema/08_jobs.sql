-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — Script: 08_jobs.sql — Jobs programados (pg_cron)
-- ═══════════════════════════════════════════════════════════════════════════

\echo '→ Configurando jobs programados...'

-- CREATE EXTENSION IF NOT EXISTS pg_cron;  -- requiere config en postgresql.conf

-- Mantenimiento diario
CREATE OR REPLACE FUNCTION mantenimiento_diario()
RETURNS TEXT AS $$
DECLARE v_log TEXT := '';
BEGIN
    v_log := 'Iniciando mantenimiento diario: ' || NOW() || E'\n';
    EXECUTE 'VACUUM (ANALYZE) orders';
    EXECUTE 'VACUUM (ANALYZE) order_items';
    EXECUTE 'VACUUM (ANALYZE) order_payments';
    EXECUTE 'VACUUM (ANALYZE) customers';
    EXECUTE 'VACUUM (ANALYZE) products';
    v_log := v_log || 'VACUUM ANALYZE completado.' || E'\n';
    RETURN v_log;
END;
$$ LANGUAGE plpgsql;

-- Refresh de MVs
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS TEXT AS $$
DECLARE v_log TEXT := '';
BEGIN
    v_log := 'Iniciando refresh de MVs: ' || NOW() || E'\n';
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_sales_by_category_monthly;
    v_log := v_log || 'mv_sales_by_category_monthly: OK' || E'\n';
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_customer_segments;
    v_log := v_log || 'mv_customer_segments: OK' || E'\n';
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_seller_performance;
    v_log := v_log || 'mv_seller_performance: OK' || E'\n';
    RETURN v_log;
EXCEPTION WHEN OTHERS THEN
    REFRESH MATERIALIZED VIEW mv_sales_by_category_monthly;
    REFRESH MATERIALIZED VIEW mv_customer_segments;
    REFRESH MATERIALIZED VIEW mv_seller_performance;
    RETURN 'Refresh completado en modo no concurrent.';
END;
$$ LANGUAGE plpgsql;

-- Crear partición anual
CREATE OR REPLACE FUNCTION crear_particion_anual(p_year INT)
RETURNS TEXT AS $$
DECLARE v_part_name TEXT; v_start DATE; v_end DATE;
BEGIN
    v_part_name := 'orders_' || p_year;
    v_start := MAKE_DATE(p_year, 1, 1);
    v_end   := MAKE_DATE(p_year + 1, 1, 1);
    IF EXISTS (SELECT 1 FROM pg_class WHERE relname = v_part_name AND relkind = 'r') THEN
        RETURN 'Partición ' || v_part_name || ' ya existe.';
    END IF;
    EXECUTE format(
        'CREATE TABLE %I PARTITION OF orders FOR VALUES FROM (%L) TO (%L)',
        v_part_name, v_start::TEXT, v_end::TEXT);
    RETURN 'Partición ' || v_part_name || ' creada.';
END;
$$ LANGUAGE plpgsql;

-- Programación pg_cron (descomentar al habilitar):
-- SELECT cron.schedule('mantenimiento-diario', '0 3 * * *', 'SELECT mantenimiento_diario();');
-- SELECT cron.schedule('refresh-mvs-semanal', '0 2 * * 0', 'SELECT refresh_materialized_views();');
-- SELECT cron.schedule('crear-particion-anual', '0 1 1 12 *',
--     'SELECT crear_particion_anual(EXTRACT(YEAR FROM NOW())::INT + 1);');

-- Vistas de métricas
CREATE OR REPLACE VIEW v_metricas_oltp AS
SELECT 'orders' AS tabla,
    pg_size_pretty(pg_relation_size('orders')) AS tamano,
    (SELECT COUNT(*) FROM orders) AS registros,
    (SELECT n_tup_ins FROM pg_stat_user_tables WHERE relname='orders') AS inserts,
    (SELECT n_tup_upd FROM pg_stat_user_tables WHERE relname='orders') AS updates
UNION ALL
SELECT 'order_items',
    pg_size_pretty(pg_relation_size('order_items')),
    (SELECT COUNT(*) FROM order_items),
    (SELECT n_tup_ins FROM pg_stat_user_tables WHERE relname='order_items'),
    (SELECT n_tup_upd FROM pg_stat_user_tables WHERE relname='order_items');

CREATE OR REPLACE VIEW v_metricas_olap AS
SELECT schemaname, matviewname, ispopulated,
       pg_size_pretty(pg_relation_size(schemaname||'.'||matviewname)) AS tamano
FROM pg_matviews WHERE schemaname = 'public';

\echo '✓ Script 08_jobs.sql completado.'
