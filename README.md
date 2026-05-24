# Ecommify — Diseño de Base de Datos Híbrida (PostgreSQL + MongoDB)

> Proyecto académico — Maestría en Arquitectura de Software con Énfasis en Big Data
> Universidad de La Sabana · Mayo 2026

## Equipo

| Rol | Nombre |
|---|---|
| Arquitecto de Datos / DBA | Fredy Pulido |
| Ingeniero de Datos / DevOps | Juan Pérez Vivanco |

## Descripción del proyecto

Ecommify es una plataforma de comercio electrónico modelada sobre el dataset Brazilian E-Commerce de Olist (2016-2018, 99.441 órdenes, 1.15 M registros geoespaciales). El proyecto implementa una arquitectura de **persistencia políglota híbrida**:

- **PostgreSQL 16 (CP)** — Núcleo transaccional ACID. Datos financieros, identidades de cliente/vendedor, catálogo de productos. Particionamiento RANGE anual sobre `orders`. Vistas materializadas para dashboards OLAP.
- **MongoDB 7.x (AP)** — Esquema flexible y datos geoespaciales. Reseñas (41,1 % campos opcionales), geolocalización (1 M+ coords con índice 2dsphere), proyección analítica `orders_summary` alimentada por ETL.

## Decisión de alcance — Geolocalización

En esta fase inicial, **la entidad `sellers` NO mantiene FK con `geolocation`**. La geolocalización aplica únicamente a `customers` para cálculo de costos de envío cliente↔depósito. Esta decisión simplifica el modelo y se revisará en fases posteriores.

## Estructura del repositorio

```
Ecommify_Database_Design/
├── README.md
├── docs/
│   ├── Documento_Tecnico_Diseno_Ecommify_APA7.docx
│   ├── Investigacion_PostgreSQL_Avanzado_APA7.docx
│   ├── Presentacion_Ejecutiva_Ecommify.pptx
│   ├── Diccionario_Datos_Ecommify.tsv
│   └── diagrams/
│       ├── er_postgresql_olist.html
│       └── er_mongodb_olist.html
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
└── notebooks/
    └── 01_Data_Exploration_Analysis.ipynb
```

## Cómo empezar

### Prerrequisitos

- PostgreSQL 16+ (local Docker o Supabase free tier)
- MongoDB 7.x (local Docker o MongoDB Atlas M0)
- Python 3.11+ con `psycopg2-binary`, `pymongo`, `pandas`
- Dataset Olist descargado de Kaggle en `./data/`

### Setup PostgreSQL (local con Docker)

```bash
# Levantar PostgreSQL 16 con PostGIS
docker run -d --name ecommify-pg \
  -e POSTGRES_USER=ecommify -e POSTGRES_PASSWORD=ecommify \
  -e POSTGRES_DB=ecommify \
  -p 5432:5432 \
  postgis/postgis:16-3.4

# Aplicar scripts DDL en orden
cd postgresql/schema
for f in 0*.sql; do
  echo "Aplicando $f..."
  psql -h localhost -U ecommify -d ecommify -f "$f"
done

# Cargar datos desde CSV
cd ../seed_data
python load_olist_csv.py
```

### Setup MongoDB (local con Docker)

```bash
docker run -d --name ecommify-mongo -p 27017:27017 mongo:7

# Crear colecciones e índices
mongosh "mongodb://localhost:27017/ecommify" mongodb/schema/01_collections.js
mongosh "mongodb://localhost:27017/ecommify" mongodb/schema/02_indexes.js

# Ejecutar ETL PG → MongoDB
python mongodb/schema/etl/pg_to_mongo_orders_summary.py --full
python mongodb/schema/etl/pg_to_mongo_products_catalog.py --full
```

## Configuración para Mac mini M4

El proyecto está optimizado para correr en Mac mini M4 (arm64). Imágenes recomendadas:

| Servicio | Imagen ARM | Comando |
|---|---|---|
| PostgreSQL + PostGIS | `postgis/postgis:16-3.4` | nativa arm64 |
| MongoDB | `mongo:7` | nativa arm64 |
| pgAdmin | `dpage/pgadmin4:latest` | nativa arm64 |
| mongo-express | `mongo-express:latest` | nativa arm64 |

## Resumen de decisiones arquitectónicas

| Aspecto | Decisión | Justificación |
|---|---|---|
| Motor transaccional | PostgreSQL 16 (CP) | ACID estricto requerido para pagos y órdenes |
| Motor flexible | MongoDB 7.x (AP) | 41,1 % nulos en `review_comment_message` justifica esquema flexible |
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

## Referencias

- Olist. (2018). *Brazilian E-Commerce public dataset by Olist* [Dataset]. Kaggle.
- PostgreSQL Global Development Group. (2025). *PostgreSQL 16 Documentation*. https://www.postgresql.org/docs/16/
- MongoDB, Inc. (2025). *MongoDB Manual*. https://www.mongodb.com/docs/manual/
- PostGIS Project. (2025). *PostGIS 3.4 Documentation*. https://postgis.net/documentation/

## Licencia

Proyecto académico — Universidad de La Sabana, 2026.
