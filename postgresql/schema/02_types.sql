-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — PostgreSQL 16
-- Script: 02_types.sql — Composite types reutilizables
-- ═══════════════════════════════════════════════════════════════════════════

\echo '→ Creando composite types reutilizables...'

DROP TYPE IF EXISTS address CASCADE;
CREATE TYPE address AS (
    street       TEXT,
    city         VARCHAR(60),
    state        CHAR(2),
    zip_code     INTEGER,
    country      CHAR(2)
);
COMMENT ON TYPE address IS 'Dirección postal compuesta reutilizable.';

DROP TYPE IF EXISTS dimensions CASCADE;
CREATE TYPE dimensions AS (
    length_cm    NUMERIC(6,2),
    height_cm    NUMERIC(6,2),
    width_cm     NUMERIC(6,2),
    weight_g     INTEGER
);
COMMENT ON TYPE dimensions IS 'Dimensiones físicas de productos.';

DROP TYPE IF EXISTS payment_summary CASCADE;
CREATE TYPE payment_summary AS (
    main_type    VARCHAR(15),
    installments SMALLINT,
    total_value  NUMERIC(10,2)
);
COMMENT ON TYPE payment_summary IS 'Resumen agregado de pagos por orden.';

\echo '→ Tipos compuestos creados:'
SELECT typname, typtype FROM pg_type
WHERE typname IN ('address','dimensions','payment_summary')
ORDER BY typname;

\echo '✓ Script 02_types.sql completado.'
