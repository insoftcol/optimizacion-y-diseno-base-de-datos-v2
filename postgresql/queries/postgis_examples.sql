-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — Ejemplos PostGIS para cálculo de envíos
-- ═══════════════════════════════════════════════════════════════════════════

-- Insertar depósitos centrales
INSERT INTO warehouses (name, location, address)
VALUES
    ('Depósito SP Centro',
     ST_MakePoint(-46.6333, -23.5505)::geography,
     ROW('Av. Paulista 1500', 'São Paulo', 'SP', 1310, 'BR')::address),
    ('Depósito RJ Zona Norte',
     ST_MakePoint(-43.2096, -22.9035)::geography,
     ROW('Av. Brasil 5000', 'Rio de Janeiro', 'RJ', 21041, 'BR')::address),
    ('Depósito BH',
     ST_MakePoint(-43.9352, -19.9167)::geography,
     ROW('Av. Afonso Pena 1000', 'Belo Horizonte', 'MG', 30130, 'BR')::address)
ON CONFLICT DO NOTHING;

-- Q1: Distancia de un cliente a todos los depósitos
WITH cliente AS (
    SELECT c.customer_id, c.customer_state, g.location AS client_loc
    FROM customers c JOIN geolocation g ON g.zip_code_prefix = c.zip_code_prefix LIMIT 1
)
SELECT cliente.customer_id, cliente.customer_state, w.name AS warehouse,
    ROUND((ST_Distance(cliente.client_loc, w.location)/1000.0)::NUMERIC, 2) AS distance_km
FROM cliente CROSS JOIN warehouses w WHERE w.active
ORDER BY ST_Distance(cliente.client_loc, w.location);

-- Q2: Depósito más cercano para cada cliente (KNN)
SELECT c.customer_id, c.customer_state, nearest.warehouse_name,
    ROUND(nearest.distance_km::NUMERIC, 2) AS distance_km
FROM customers c JOIN geolocation g ON g.zip_code_prefix = c.zip_code_prefix
CROSS JOIN LATERAL (
    SELECT w.name AS warehouse_name, ST_Distance(g.location, w.location)/1000.0 AS distance_km
    FROM warehouses w WHERE w.active
    ORDER BY g.location <-> w.location LIMIT 1
) AS nearest LIMIT 20;

-- Q3: Cobertura - clientes en radio de 50km de SP
SELECT COUNT(*) AS clientes_en_50km
FROM customers c JOIN geolocation g ON g.zip_code_prefix = c.zip_code_prefix
JOIN warehouses w ON w.name = 'Depósito SP Centro'
WHERE ST_DWithin(g.location, w.location, 50000);

-- Q4: Función de costo de envío
CREATE OR REPLACE FUNCTION calcular_costo_envio(p_customer_id UUID, p_warehouse_id UUID DEFAULT NULL)
RETURNS NUMERIC AS $$
DECLARE v_distance_km NUMERIC; v_base_fee NUMERIC := 5.00; v_per_km NUMERIC := 0.50;
BEGIN
    SELECT (ST_Distance(g.location, w.location)/1000.0)::NUMERIC
    INTO v_distance_km
    FROM customers c JOIN geolocation g ON g.zip_code_prefix = c.zip_code_prefix
    CROSS JOIN LATERAL (
        SELECT location FROM warehouses
        WHERE active AND (warehouse_id = p_warehouse_id OR p_warehouse_id IS NULL)
        ORDER BY g.location <-> warehouses.location LIMIT 1
    ) AS w WHERE c.customer_id = p_customer_id;
    RETURN ROUND(v_base_fee + v_per_km * COALESCE(v_distance_km, 0), 2);
END;
$$ LANGUAGE plpgsql STABLE;
