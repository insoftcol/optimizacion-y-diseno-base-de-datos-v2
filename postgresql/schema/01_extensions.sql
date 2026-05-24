-- ═══════════════════════════════════════════════════════════════════════════
-- Ecommify — PostgreSQL 16
-- Script: 01_extensions.sql
-- Propósito: Habilitar extensiones requeridas por el esquema
-- Orden:    Ejecutar PRIMERO, antes de cualquier otro script
-- ═══════════════════════════════════════════════════════════════════════════

\echo '→ Habilitando extensiones de PostgreSQL...'

-- pgcrypto: gen_random_uuid(), crypt/bcrypt, pgp_sym_encrypt
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- PostGIS: GEOGRAPHY/GEOMETRY + funciones espaciales
CREATE EXTENSION IF NOT EXISTS postgis;

-- pg_trgm: similitud por trigramas (búsqueda fuzzy)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- btree_gin: índices GIN combinando JSONB + columnas escalares
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- Verificación
\echo '→ Extensiones instaladas:'
SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('pgcrypto','postgis','pg_trgm','btree_gin')
ORDER BY extname;

\echo '✓ Script 01_extensions.sql completado.'
