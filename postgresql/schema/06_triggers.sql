-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — PostgreSQL 16
-- Script: 06_triggers.sql — Triggers de mantenimiento
-- ═══════════════════════════════════════════════════════════════════════════

\echo '→ Creando triggers de mantenimiento...'

-- Función reutilizable set_updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicación a cada tabla
DROP TRIGGER IF EXISTS trg_customers_updated_at ON customers;
CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_sellers_updated_at ON sellers;
CREATE TRIGGER trg_sellers_updated_at BEFORE UPDATE ON sellers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Función audit_changes (genérica)
CREATE OR REPLACE FUNCTION audit_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_changes JSONB;
    v_pk      TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_pk := COALESCE(OLD::TEXT, 'unknown');
        v_changes := jsonb_build_object('deleted_row', to_jsonb(OLD));
    ELSIF TG_OP = 'INSERT' THEN
        v_pk := COALESCE(NEW::TEXT, 'unknown');
        v_changes := jsonb_build_object('inserted_row', to_jsonb(NEW));
    ELSE
        v_pk := COALESCE(NEW::TEXT, OLD::TEXT, 'unknown');
        v_changes := jsonb_build_object('before', to_jsonb(OLD), 'after', to_jsonb(NEW));
    END IF;
    INSERT INTO audit_logs (table_name, record_pk, operation, changes)
    VALUES (TG_TABLE_NAME, v_pk, LEFT(TG_OP, 1), v_changes);
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Notificación ETL para orders → MongoDB
CREATE OR REPLACE FUNCTION notify_orders_change()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify(
        'orders_changed',
        jsonb_build_object('order_id', NEW.order_id, 'operation', TG_OP, 'updated_at', NEW.updated_at)::TEXT
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notify_orders ON orders;
CREATE TRIGGER trg_notify_orders AFTER INSERT OR UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION notify_orders_change();

\echo '✓ Script 06_triggers.sql completado.'
