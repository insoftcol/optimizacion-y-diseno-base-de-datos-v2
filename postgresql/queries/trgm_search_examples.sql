-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — Ejemplos pg_trgm: búsqueda fuzzy
-- ═══════════════════════════════════════════════════════════════════════════

-- Q1: Buscar con error tipográfico
SELECT product_category_name, similarity(product_category_name, 'telefono') AS sim
FROM products WHERE product_category_name % 'telefono'
ORDER BY sim DESC LIMIT 5;

-- Q2: Umbral permisivo
SET pg_trgm.similarity_threshold = 0.2;
SELECT DISTINCT product_category_name,
    ROUND(similarity(product_category_name, 'casa_decoracon')::NUMERIC, 3) AS sim
FROM products WHERE product_category_name % 'casa_decoracon'
ORDER BY sim DESC LIMIT 10;
RESET pg_trgm.similarity_threshold;

-- Q3: Ordenar por distancia (<->)
SELECT DISTINCT product_category_name,
    product_category_name <-> 'eletronik' AS distance
FROM products WHERE product_category_name IS NOT NULL
ORDER BY product_category_name <-> 'eletronik' LIMIT 10;

-- Q4: Búsqueda combinada
SELECT product_id, product_category_name, product_photos_qty,
    similarity(product_category_name, 'esporte') AS sim
FROM products WHERE product_category_name % 'esporte' AND product_photos_qty > 5
ORDER BY sim DESC LIMIT 20;

-- Q5: Verificar uso del índice
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, product_category_name FROM products
WHERE product_category_name % 'celular' LIMIT 10;

-- Q6: Función autocomplete
CREATE OR REPLACE FUNCTION buscar_categorias_fuzzy(
    p_query TEXT, p_limit INT DEFAULT 10, p_min_similarity REAL DEFAULT 0.2
) RETURNS TABLE (
    category VARCHAR(100), similarity_score REAL, products_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.product_category_name::VARCHAR(100) AS category,
        similarity(p.product_category_name, p_query) AS similarity_score,
        COUNT(*)::BIGINT AS products_count
    FROM products p
    WHERE p.product_category_name IS NOT NULL
      AND similarity(p.product_category_name, p_query) >= p_min_similarity
    GROUP BY p.product_category_name
    ORDER BY similarity_score DESC, products_count DESC LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;
