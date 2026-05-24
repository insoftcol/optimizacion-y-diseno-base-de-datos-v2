-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — PostgreSQL 16
-- Script: 04_tables_transactional.sql — Tablas transaccionales + particionamiento
-- ═══════════════════════════════════════════════════════════════════════════

\echo '→ Creando tablas transaccionales...'

-- orders — PARTICIONADA por RANGE
CREATE TABLE IF NOT EXISTS orders (
    order_id                       UUID NOT NULL,
    customer_id                    UUID NOT NULL
                                   REFERENCES customers(customer_id)
                                   ON DELETE RESTRICT,
    order_status                   VARCHAR(20) NOT NULL
                                   CHECK (order_status IN (
                                       'delivered','shipped','canceled','approved',
                                       'processing','unavailable','invoiced','created')),
    order_purchase_timestamp       TIMESTAMPTZ NOT NULL,
    order_approved_at              TIMESTAMPTZ,
    order_delivered_carrier_date   TIMESTAMPTZ,
    order_delivered_customer_date  TIMESTAMPTZ,
    order_estimated_delivery_date  TIMESTAMPTZ,
    audit_log                      JSONB,
    updated_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (order_id, order_purchase_timestamp)
) PARTITION BY RANGE (order_purchase_timestamp);
COMMENT ON TABLE orders IS 'Tabla de hechos particionada anualmente.';

-- Particiones
CREATE TABLE IF NOT EXISTS orders_2016 PARTITION OF orders
    FOR VALUES FROM ('2016-01-01') TO ('2017-01-01');
CREATE TABLE IF NOT EXISTS orders_2017 PARTITION OF orders
    FOR VALUES FROM ('2017-01-01') TO ('2018-01-01');
CREATE TABLE IF NOT EXISTS orders_2018 PARTITION OF orders
    FOR VALUES FROM ('2018-01-01') TO ('2019-01-01');
CREATE TABLE IF NOT EXISTS orders_2019 PARTITION OF orders
    FOR VALUES FROM ('2019-01-01') TO ('2020-01-01');
CREATE TABLE IF NOT EXISTS orders_2020 PARTITION OF orders
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE IF NOT EXISTS orders_default PARTITION OF orders DEFAULT;

-- order_items
CREATE TABLE IF NOT EXISTS order_items (
    order_id                  UUID NOT NULL,
    order_purchase_timestamp  TIMESTAMPTZ NOT NULL,
    order_item_id             SMALLINT NOT NULL CHECK (order_item_id > 0),
    product_id                UUID NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    seller_id                 UUID NOT NULL REFERENCES sellers(seller_id)  ON DELETE RESTRICT,
    shipping_limit_date       TIMESTAMPTZ NOT NULL,
    price                     NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    freight_value             NUMERIC(10,2) NOT NULL CHECK (freight_value >= 0),
    PRIMARY KEY (order_id, order_purchase_timestamp, order_item_id),
    FOREIGN KEY (order_id, order_purchase_timestamp)
        REFERENCES orders(order_id, order_purchase_timestamp) ON DELETE RESTRICT
);

-- order_payments
CREATE TABLE IF NOT EXISTS order_payments (
    order_id                  UUID NOT NULL,
    order_purchase_timestamp  TIMESTAMPTZ NOT NULL,
    payment_sequential        SMALLINT NOT NULL CHECK (payment_sequential >= 1),
    payment_type              VARCHAR(15) NOT NULL
                              CHECK (payment_type IN ('credit_card','debit_card','boleto','voucher','not_defined')),
    payment_installments      SMALLINT NOT NULL CHECK (payment_installments >= 1),
    payment_value             NUMERIC(10,2) NOT NULL CHECK (payment_value > 0),
    PRIMARY KEY (order_id, order_purchase_timestamp, payment_sequential),
    FOREIGN KEY (order_id, order_purchase_timestamp)
        REFERENCES orders(order_id, order_purchase_timestamp)
);

-- promotions (TSTZRANGE + EXCLUDE)
CREATE TABLE IF NOT EXISTS promotions (
    promotion_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id     UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    discount_pct   NUMERIC(5,2) NOT NULL CHECK (discount_pct BETWEEN 0 AND 100),
    period         TSTZRANGE NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    EXCLUDE USING GIST (product_id WITH =, period WITH &&)
);
COMMENT ON TABLE promotions IS 'Promociones con TSTZRANGE. EXCLUDE impide solapamiento por producto.';

-- audit_logs
CREATE TABLE IF NOT EXISTS audit_logs (
    audit_id     BIGSERIAL PRIMARY KEY,
    table_name   VARCHAR(60) NOT NULL,
    record_pk    TEXT NOT NULL,
    operation    CHAR(1) NOT NULL CHECK (operation IN ('I','U','D')),
    changes      JSONB NOT NULL,
    changed_by   UUID,
    changed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

\echo '✓ Script 04_tables_transactional.sql completado.'
