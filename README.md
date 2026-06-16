# Ecommify — Diseño de Base de Datos Híbrida (PostgreSQL + MongoDB)

> Proyecto académico — Maestría en Arquitectura de Software
> Universidad de La Sabana · Mayo 2026

## Equipo E11

| Rol | Nombre |
|---|---|
| Arquitecto de Datos / DBA /Ingeniero de Datos / DevOps / DBA | Fredy Orlando Pulido Quintero |
| Arquitecto de Datos / DBA /Ingeniero de Datos / DevOps | Myriam Andrea Martinez Fontecha |
| Arquitecto de Datos / DBA /Ingeniero de Datos / DevOps | Nicolas Felipe Torres Amaya |
| Arquitecto de Datos / DBA /Ingeniero de Datos / DevOps | Juan Francisco Javier Perez Rivero |

## Descripción del proyecto

Ecommify es una plataforma de comercio electrónico modelada sobre el dataset Brazilian E-Commerce de Olist (2016-2018, 99.441 órdenes, 1.15 M registros geoespaciales). El proyecto implementa una arquitectura de **persistencia políglota híbrida**:

- - **PostgreSQL / Supabase** como motor relacional transaccional, con integridad referencial, particionamiento, PostGIS, pg_trgm, JSONB, arreglos, vistas materializadas e índices especializados.
- **MongoDB / Atlas** como motor documental para consultas flexibles, reseñas, geolocalización y proyecciones analíticas optimizadas mediante índices simples, compuestos, textuales y geoespaciales.
- **Google Colab** como entorno de carga, ETL, ejecución de benchmarks y generación de evidencias.
- **Evidencias cuantitativas** mediante `EXPLAIN ANALYZE`, `.explain()`, CSV de métricas, JSON de planes y gráficas comparativas.

## Estructura del repositorio

```
Ecommify_Database_Design/
├── README.md
├── docs/
│   ├── Documento_Tecnico_Diseno_Ecommify_APA7.docx
│   ├── Documento_Tecnico_Diseno_Ecommify_APA7.pdf
│   ├── Investigacion_PostgreSQL_Avanzado_APA7.docx
│   ├── Investigacion_PostgreSQL_Avanzado_APA7.pdf
│   ├── Presentacion_Ejecutiva_Ecommify.pptx
│   ├── Presentacion_Ejecutiva_Ecommify.pdf
│   ├── Diccionario_Datos_Ecommify.tsv
│   └── diagrams/
│       ├── er_postgresql_olist.html
│       ├── er_postgresql_olist.svg
│       └── er_mongodb_olist.html
│       └── er_mongodb_olist.svg
├── postgresql/
│   ├── schema/                          ← 8 scripts DDL ordenados
│   │   ├── 01_extensions.sql
│   │   ├── 02_types.sql
│   │   ├── 03_tables_master.sql
│   │   ├── 04_tables_transactional.sql
│   │   ├── 05_materialized_views.sql
│   │   ├── 06_triggers.sql
│   │   ├── 07_indexes.sql
│   │   └── 08_jobs.sql
│   ├── seed_data/
│   │   ├── load_olist_csv.py            ← ETL Python para carga inicial
│   │   └── sample_specifications.json
│   └── queries/
│       ├── analytical_queries.sql
│       ├── postgis_examples.sql
│       └── trgm_search_examples.sql
├── mongodb/
│   └── schema/
│       ├── 01_collections.js
│       ├── 02_indexes.js
│       ├── examples/
│       │   ├── reviews.json
│       │   ├── geolocation.json
│       │   ├── products_catalog.json
│       │   └── orders_summary.json
│       └── etl/
│           ├── pg_to_mongo_orders_summary.py
│           └── pg_to_mongo_products_catalog.py
├── notebooks/
|    └── Data_Exploration_Analysis.ipynb
├── Optimizacion/
|   └── Evidencia/
│   |    ├── benchmark_comparison_20260616_000208.png
│   |    ├── pg_benchmarks_20260616_000208.csv
│   |    ├── mdb_benchmarks_20260616_000208.csv
│   |    └── explain_plans_20260616_000208.json
|   |
|   ├──Colab/
│   |   ├── 01_pg_supabase_setup.ipynb
│   |   ├── 02_olist_data_load.ipynb
│   |   ├── 03_benchmarks_evidencias.ipynb
│   |   └── 04_etl_pg_to_mongo.ipynb
|   |
│   ├── Documento_tecnico_Ecommify_U5.docx
│   └── Documento_tecnico_Ecommify_U5.pdf
```

## Cómo empezar

### Prerrequisitos

- Cuenta supabase.com Free Tier
- Cuenta MongoDB atlas (https://cloud.mongodb.com/) Free Tier Atlas M)
- Python 3.11+ con `psycopg2-binary`, `pymongo`, `pandas`
- Dataset Olist descargado desde Drive google `./content/Drive`

## Resumen de decisiones arquitectónicas

| Aspecto | Decisión | Justificación |
|---|---|---|
| Motor transaccional | PostgreSQL Supabase Free tier | ACID estricto requerido para pagos y órdenes |
| Motor flexible | MongoDB Atlas M0 Free tier | 41,1 % nulos en `review_comment_message` justifica esquema flexible |
| Posición CAP `orders` | CP | Una orden duplicada es un error financiero |
| Posición CAP `reviews` | AP | Una reseña con 30 s de retraso no es un error |
| Particionamiento | RANGE anual en `orders` | 95 % de datos concentrados en 2017-2018 |
| Tipos avanzados | JSONB, TEXT[], TSTZRANGE, composite | Categorías variables, fotos múltiples, promociones |
| Extensiones PG | PostGIS, pg_trgm, pgcrypto, btree_gin | Envíos, búsqueda fuzzy, cifrado |
| ETL PG → MongoDB | Unidireccional batch + incremental | Una sola fuente de verdad (PostgreSQL) |
| `sellers` → `geolocation` | ELIMINADO en este alcance | Simplificación inicial; revisión futura |

## Documentación principal

| Documento | Ubicación | Propósito |
|---|---|---|
| Documento Técnico de Diseño | `docs/Documento_Tecnico_Diseno_Ecommify_APA7.docx` | Entregable evaluativo completo (B-G) |
| Investigación Formativa | `docs/Investigacion_PostgreSQL_Avanzado_APA7.docx` | Tipos avanzados, extensiones, OLTP/OLAP |
| Presentación Ejecutiva | `docs/Presentacion_Ejecutiva_Ecommify.pptx` | 12 slides — contexto, ER, CAP, plan |
| Diccionario de Datos | `docs/Diccionario_Datos_Ecommify.tsv` | 14 entidades, 144 campos |
| Diagrama ER PostgreSQL | `docs/diagrams/er_postgresql_olist.html` | Interactivo con mermaid.js |
| Diagrama MongoDB | `docs/diagrams/er_mongodb_olist.html` | Modelo documental con ETL |
| Documento Técnico optimizacion | `Optimizacion/Documento_tecnico_Ecommify_U5.pdf` | explicacion tecnica de la implementacion y optimizacion realizada|

## Referencias

- Olist. (2018). *Brazilian E-Commerce public dataset by Olist* [Dataset]. Kaggle.
- PostgreSQL Global Development Group. (2025). *PostgreSQL 16 Documentation*. https://www.postgresql.org/docs/16/
- MongoDB, Inc. (2025). *MongoDB Manual*. https://www.mongodb.com/docs/manual/
- PostGIS Project. (2025). *PostGIS 3.4 Documentation*. https://postgis.net/documentation/

## Licencia

Proyecto académico — Universidad de La Sabana, 2026.
