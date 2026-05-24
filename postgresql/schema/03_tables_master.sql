-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — PostgreSQL 16
-- Script: 03_tables_master.sql — Tablas maestras
-- ═══════════════════════════════════════════════════════════════════════════

\echo '→ Creando tablas maestras...'

-- geolocation
CREATE TABLE IF NOT EXISTS geolocation (
    zip_code_prefix    INTEGER PRIMARY KEY,
    geolocation_lat    DOUBLE PRECISION NOT NULL
                       CHECK (geolocation_lat BETWEEN -33.75 AND 5.27),
    geolocation_lng    DOUBLE PRECISION NOT NULL
                       CHECK (geolocation_lng BETWEEN -73.99 AND -34.73),
    geolocation_city   VARCHAR(60) NOT NULL,
    geolocation_state  CHAR(2) NOT NULL CHECK (geolocation_state ~ '^[A-Z]{2}$'),
    location           GEOGRAPHY(POINT, 4326)
                       GENERATED ALWAYS AS
                       (ST_MakePoint(geolocation_lng, geolocation_lat)::geography)
                       STORED
);
CREATE INDEX idx_geo_location_gist ON geolocation USING GIST (location);
COMMENT ON TABLE geolocation IS 'Referencia geográfica deduplicada por código postal.';

-- categorías (traducción)
CREATE TABLE IF NOT EXISTS product_category_name_translation (
    product_category_name          VARCHAR(100) PRIMARY KEY,
    product_category_name_english  VARCHAR(100) NOT NULL
);

-- customers — CON FK a geolocation
CREATE TABLE IF NOT EXISTS customers (
    customer_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_unique_id    UUID NOT NULL UNIQUE,
    zip_code_prefix       INTEGER NOT NULL
                          REFERENCES geolocation(zip_code_prefix)
                          ON DELETE RESTRICT,
    customer_city         VARCHAR(60),
    customer_state        CHAR(2) NOT NULL CHECK (customer_state ~ '^[A-Z]{2}$'),
    shipping_address      address,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_customers_state ON customers (customer_state);
CREATE INDEX idx_customers_unique ON customers (customer_unique_id);

-- sellers — SIN FK a geolocation (decisión de alcance)
CREATE TABLE IF NOT EXISTS sellers (
    seller_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_zip_code_prefix INTEGER,  -- referencia lógica, sin FK
    seller_city            VARCHAR(60),
    seller_state           CHAR(2) CHECK (seller_state IS NULL OR seller_state ~ '^[A-Z]{2}$'),
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_sellers_state ON sellers (seller_state);
COMMENT ON TABLE sellers IS 'Vendedores. SIN FK a geolocation en esta fase.';

-- products — tipos avanzados
CREATE TABLE IF NOT EXISTS products (
    product_id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_category_name       VARCHAR(100)
                                REFERENCES product_category_name_translation
                                ON DELETE SET NULL,
    product_name_length         INTEGER CHECK (product_name_length >= 0),
    product_description_length  INTEGER CHECK (product_description_length >= 0),
    product_photos_qty          SMALLINT CHECK (product_photos_qty >= 0),
    dims                        dimensions,
    specifications              JSONB,
    photos                      TEXT[],
    tags                        TEXT[],
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_products_specs_gin ON products USING GIN (specifications jsonb_path_ops);
CREATE INDEX idx_products_tags_gin  ON products USING GIN (tags);
CREATE INDEX idx_products_cat_trgm  ON products USING GIN (product_category_name gin_trgm_ops);

-- warehouses (para PostGIS shipping)
CREATE TABLE IF NOT EXISTS warehouses (
    warehouse_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(120) NOT NULL,
    location      GEOGRAPHY(POINT, 4326) NOT NULL,
    address       address,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE warehouses IS 'Depósitos centrales para cálculo de envíos via PostGIS.';

-- app_users (autenticación)
CREATE TABLE IF NOT EXISTS app_users (
    user_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email          TEXT UNIQUE NOT NULL
                   CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    password_hash  TEXT NOT NULL,
    customer_id    UUID UNIQUE REFERENCES customers(customer_id),
    role           VARCHAR(20) NOT NULL DEFAULT 'customer'
                   CHECK (role IN ('customer','seller','admin')),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at  TIMESTAMPTZ
);

\echo '✓ Script 03_tables_master.sql completado.'
