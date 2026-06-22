# Ecommify — Diseño y Optimización de Base de Datos Híbrida (PostgreSQL + MongoDB)

> Proyecto académico — Maestría en Arquitectura de Software, Énfasis en Optimización de Bases de Datos
> Universidad de La Sabana · Bogotá D.C., Colombia · Junio 2026

## a. Carta de presentación del proyecto

Ecommify es el proyecto final del equipo E11 para la Maestría en Arquitectura de Software con énfasis en Optimización de Bases de Datos de la Universidad de La Sabana. El proyecto modela una plataforma de comercio electrónico sobre el dataset público *Brazilian E-Commerce* de Olist (2016-2018, 99.441 órdenes, 1,15 M de registros geoespaciales), implementando una **arquitectura de persistencia políglota**: PostgreSQL 16 (Supabase) como motor transaccional CP, y MongoDB 7.x (Atlas M0) como motor documental AP para catálogo flexible, reseñas, geolocalización y proyecciones analíticas.

El trabajo se desarrolló en dos etapas evaluativas:

1. **Etapa 1 — Diseño y optimización** (`Optimizacion/`): modelado conceptual/lógico con matriz CAP por entidad, implementación de tipos avanzados, extensiones (PostGIS, pg_trgm, pgcrypto), particionamiento RANGE, vistas materializadas y un ETL PostgreSQL → MongoDB, con evidencia cuantitativa `EXPLAIN ANALYZE` / `.explain()` antes y después de cada optimización.
2. **Etapa 2 — Pruebas de carga, concurrencia y escalabilidad** (`PruebasCarga/`): un harness único de carga (Python `ThreadPoolExecutor`, reutilizado sin modificación para ambos motores) que midió throughput y latencia (p50/p95/p99) bajo 1 a 30 clientes concurrentes, identificó puntos de quiebre por motor, y evaluó escalabilidad sobre subconjuntos crecientes del dataset aprovechando el particionamiento ya existente.

El hallazgo central de la Etapa 2 — y la razón por la que esta documentación insiste en la reproducibilidad exacta del entorno — es que la degradación observada en PostgreSQL bajo carga (p95 de 527 ms a 9.978 ms entre concurrencia 1 y 10) **no es una limitación del motor relacional**, sino la saturación del pool de conexiones (PgBouncer) del *free tier* de Supabase, cuyo patrón de espera en cola FIFO se ajusta matemáticamente a los tiempos medidos. MongoDB Atlas M0, en el mismo experimento, toleró hasta 30 clientes concurrentes con degradación controlada y cero errores. El análisis completo, las tablas de evidencia y las recomendaciones de escalamiento están en `PruebasCarga/Informe_Tecnico_Integral_Ecommify_APA7.docx`.

## Equipo E11

| Rol | Nombre |
|---|---|
| Arquitecto de Datos / DBA / Ingeniero de Datos / DevOps | Fredy Orlando Pulido Quintero |
| Arquitecto de Datos / DBA / Ingeniero de Datos / DevOps | Myriam Andrea Martinez Fontecha |
| Arquitecto de Datos / DBA / Ingeniero de Datos / DevOps | Nicolas Felipe Torres Amaya |
| Arquitecto de Datos / DBA / Ingeniero de Datos / DevOps | Juan Francisco Javier Perez Rivero |

## Descripción del proyecto

- **PostgreSQL / Supabase** como motor relacional transaccional, con integridad referencial, particionamiento, PostGIS, pg_trgm, JSONB, arreglos, vistas materializadas e índices especializados.
- **MongoDB / Atlas** como motor documental para consultas flexibles, reseñas, geolocalización y proyecciones analíticas optimizadas mediante índices simples, compuestos, textuales y geoespaciales.
- **Google Colab** como entorno de carga, ETL, ejecución de benchmarks y generación de evidencias.
- **Evidencias cuantitativas** mediante `EXPLAIN ANALYZE`, `.explain()`, CSV de métricas, JSON de planes y gráficas comparativas.
- **Harness de pruebas de carga** (`PruebasCarga/`) único y reutilizado entre ambos motores, para que throughput, percentiles de latencia y tasa de error sean directamente comparables.

## Estructura del repositorio

```
optimizacion-y-diseno-base-de-datos-v2/
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
│       ├── er_mongodb_olist.html
│       └── mongodb_model_olist.svg
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
│   └── Data_Exploration_Analysis.ipynb
├── Optimizacion/                         ← Etapa 1: optimización PostgreSQL/MongoDB (antes/después)
│   ├── README.md                        ← cómo interpretar las evidencias de la Etapa 1
│   ├── Colab/
│   │   ├── 01_pg_supabase_setup.ipynb
│   │   ├── 02_olist_data_load.ipynb
│   │   ├── 03_benchmarks_evidencias.ipynb
│   │   └── 04_etl_pg_to_mongo.ipynb
│   ├── Evidencia/
│   │   ├── pg_benchmarks_20260616_000208.csv
│   │   ├── mdb_benchmarks_20260616_000208.csv
│   │   ├── explain_plans_20260616_000208.json
│   │   └── benchmark_comparison_20260616_000208.png
│   ├── Documento_tecnico_Ecommify_U5.docx
│   └── Documento_tecnico_Ecommify_U5.pdf
├── PruebasCarga/                         ← Etapa 2: pruebas de carga, concurrencia y escalabilidad
│   ├── 05_load_testing-2.ipynb           ← Notebook 05, requiere 01-04 ya ejecutados
│   ├── Informe_Tecnico_Integral_Ecommify_APA7.docx   ← Informe consolidado (Secciones a-i)
│   └── Ecommify.pptx                     ← Presentación de resultados de carga
└── EvidenciaPruebasCarga/                ← Salida cruda del Notebook 05 (Anexo A del Informe)
    ├── README_load_testing_20260621_011737.md        ← Metodología del run, autogenerado
    ├── load_test_concurrencia_20260621_011737.csv    ← 24 mediciones throughput/latencia (concurrencia × motor × tipo query)
    ├── load_test_concurrencia_20260621_011737.png    ← Figura 1: throughput y p95 vs. concurrencia
    ├── puntos_quiebre_20260621_011737.csv             ← 4 puntos de quiebre identificados automáticamente
    ├── conteos_subconjuntos_20260621_011737.csv      ← Conteo real de filas por subconjunto de escalabilidad
    ├── load_test_consolidado_20260621_011737.json    ← Resultados crudos completos (concurrencia + escalabilidad + quiebres)
    ├── load_test_escalabilidad_20260621_011737.csv   ← 6 mediciones de escalabilidad por subconjunto × motor
    └── load_test_escalabilidad_20260621_011737.png   ← Figura 2: degradación de p95 vs. tamaño de dataset
```

## b. Cómo reproducir la implementación

### Prerrequisitos

- Cuenta supabase.com (Free Tier)
- Cuenta MongoDB Atlas (https://cloud.mongodb.com/) Free Tier (M0)
- Python 3.11+ con `psycopg2-binary`, `pymongo`, `pandas`, `numpy`, `matplotlib`
- Dataset Olist descargado y montado en Google Drive (`./content/drive`), por ser el entorno de ejecución de los notebooks (Google Colab)
- Credenciales `SUPABASE_URI` y `ATLAS_URI` configuradas como *secrets* de Colab (`userdata.get(...)`)

### Secuencia de ejecución

La implementación se ejecuta en **6 pasos ordenados**. Los pasos 1-4 corresponden a la Etapa 1 (diseño y optimización) y son prerrequisito obligatorio de los pasos 5-6 (Etapa 2, pruebas de carga).

| Paso | Qué hace | Código a ejecutar | Ruta en el repo |
|---|---|---|---|
| 1 | Crea extensiones, tipos, tablas y configura Supabase | Notebook `01_pg_supabase_setup.ipynb`, que ejecuta en orden los 8 scripts DDL | `Optimizacion/Colab/01_pg_supabase_setup.ipynb` → `postgresql/schema/01_extensions.sql` … `08_jobs.sql` |
| 2 | Carga el dataset Olist en PostgreSQL y crea las colecciones base en MongoDB | Notebook `02_olist_data_load.ipynb` (PG) usando `load_olist_csv.py`; script `01_collections.js` + `02_indexes.js` (MongoDB) | `Optimizacion/Colab/02_olist_data_load.ipynb`, `postgresql/seed_data/load_olist_csv.py`, `mongodb/schema/01_collections.js`, `mongodb/schema/02_indexes.js` |
| 3 | Ejecuta ETL PostgreSQL → MongoDB (`orders_summary`, `products_catalog`) | Notebook `04_etl_pg_to_mongo.ipynb`, que invoca los scripts Python de ETL | `Optimizacion/Colab/04_etl_pg_to_mongo.ipynb` → `mongodb/schema/etl/pg_to_mongo_orders_summary.py`, `pg_to_mongo_products_catalog.py` |
| 4 | Captura evidencia `EXPLAIN ANALYZE` / `.explain()` antes y después de optimizar (índices, particionamiento, vistas materializadas) | Notebook `03_benchmarks_evidencias.ipynb` | `Optimizacion/Colab/03_benchmarks_evidencias.ipynb` → exporta a `Optimizacion/Evidencia/` |
| 5 | **(Prerrequisito: pasos 1-4 ya ejecutados)** Corre el harness de carga único sobre PostgreSQL y MongoDB: matriz de concurrencia (1/5/10/15/20/30 clientes × punto/compleja), detección de puntos de quiebre, y escalabilidad sobre subconjuntos crecientes del dataset | Notebook `05_load_testing-2.ipynb` | `PruebasCarga/05_load_testing-2.ipynb` |
| 6 | Analiza, interpreta y documenta los resultados crudos del paso 5 (incluye el hallazgo de saturación del connection pooler) | Lectura/edición del informe y la presentación, con base en los crudos exportados | `PruebasCarga/Informe_Tecnico_Integral_Ecommify_APA7.docx`, `PruebasCarga/Ecommify.pptx` ← `EvidenciaPruebasCarga/` |

### Rutas de scripts de setup y configuración

| Componente | Ruta en el repo | Notas |
|---|---|---|
| DDL PostgreSQL (orden estricto 01→08) | `postgresql/schema/` | Extensiones → tipos → tablas maestras → tablas transaccionales → vistas materializadas → triggers → índices → jobs |
| Carga inicial / seed data | `postgresql/seed_data/load_olist_csv.py`, `postgresql/seed_data/sample_specifications.json` | ETL Python de carga del dataset Olist |
| Setup y configuración Supabase (Colab) | `Optimizacion/Colab/01_pg_supabase_setup.ipynb` | Aplica los 8 scripts DDL contra la instancia real de Supabase |
| Carga de datos (Colab) | `Optimizacion/Colab/02_olist_data_load.ipynb` | |
| Esquema y colecciones MongoDB | `mongodb/schema/01_collections.js`, `mongodb/schema/02_indexes.js` | |
| ETL PostgreSQL → MongoDB | `mongodb/schema/etl/pg_to_mongo_orders_summary.py`, `mongodb/schema/etl/pg_to_mongo_products_catalog.py` (orquestados desde `Optimizacion/Colab/04_etl_pg_to_mongo.ipynb`) | |
| Harness de pruebas de carga (setup/configuración del experimento) | `PruebasCarga/05_load_testing-2.ipynb` | Pool de conexiones PG (`ThreadedConnectionPool`), cliente MongoDB, niveles de concurrencia, duración por punto, queries punto/compleja |

### Rutas de resultados de pruebas de carga consolidados

| Resultado | Ruta en el repo | Contenido |
|---|---|---|
| **Informe consolidado de pruebas de carga** | `PruebasCarga/Informe_Tecnico_Integral_Ecommify_APA7.docx` | Metodología, Tablas 2-12 (matriz de concurrencia, puntos de quiebre, escalabilidad, ratios comparativos), Figuras 1-2, análisis crítico CAP vs. disponibilidad bajo carga, plan de escalamiento 10×, y Anexo A con el listado exacto de archivos de evidencia |
| **Presentación de resultados** | `PruebasCarga/Ecommify.pptx` | Síntesis ejecutiva de la Etapa 2 |
| **Notebook fuente (reproducible)** | `PruebasCarga/05_load_testing-2.ipynb` | Al re-ejecutarse, regenera las métricas crudas |
| **Evidencia cruda consolidada de la corrida (Anexo A)** | `EvidenciaPruebasCarga/` | `load_test_concurrencia_20260621_011737.csv` (matriz de concurrencia), `load_test_escalabilidad_20260621_011737.csv` (escalabilidad por subconjunto), `puntos_quiebre_20260621_011737.csv` (puntos de quiebre), `conteos_subconjuntos_20260621_011737.csv` (conteo real de filas), `load_test_consolidado_20260621_011737.json` (resultados crudos completos), `load_test_concurrencia_20260621_011737.png` / `load_test_escalabilidad_20260621_011737.png` (Figuras 1 y 2), `README_load_testing_20260621_011737.md` (metodología del run) |
| Evidencia de optimización Etapa 1 (`EXPLAIN ANALYZE` antes/después, no es la prueba de carga) | `Optimizacion/Evidencia/` (`pg_benchmarks_*.csv`, `mdb_benchmarks_*.csv`, `explain_plans_*.json`, `benchmark_comparison_*.png`) | Ver `Optimizacion/README.md` para la interpretación |

> **Nota:** el notebook `05_load_testing-2.ipynb` exporta sus resultados, por defecto, a Google Drive (`/content/drive/MyDrive/Colab Notebooks/MaestriaArch-OBD-U5/evidencias/`). El equipo descargó esa corrida (timestamp `20260621_011737`, la misma referenciada en el Anexo A del informe) y la versionó en el repositorio bajo `EvidenciaPruebasCarga/`, por lo que estos archivos ya son reproducibles y consultables directamente desde git, sin depender de Drive. Si se ejecuta una nueva corrida del notebook, se recomienda copiar sus salidas a `EvidenciaPruebasCarga/` siguiendo la misma convención de nombres (`*_<timestamp>.*`).

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
| Cuello de botella bajo carga (validado empíricamente) | Pool de conexiones (PgBouncer) del free tier de Supabase, no el motor relacional | Patrón de cola FIFO confirmado en concurrencia 15/20/30; ver `PruebasCarga/Informe_Tecnico_Integral_Ecommify_APA7.docx`, Sección e.4 |

## Documentación principal

| Documento | Ubicación | Propósito |
|---|---|---|
| Documento Técnico de Diseño | `docs/Documento_Tecnico_Diseno_Ecommify_APA7.docx` | Entregable evaluativo completo (B-G), Etapa 1 |
| Investigación Formativa | `docs/Investigacion_PostgreSQL_Avanzado_APA7.docx` | Tipos avanzados, extensiones, OLTP/OLAP |
| Presentación Ejecutiva | `docs/Presentacion_Ejecutiva_Ecommify.pptx` | 12 slides — contexto, ER, CAP, plan |
| Diccionario de Datos | `docs/Diccionario_Datos_Ecommify.tsv` | 14 entidades, 144 campos |
| Diagrama ER PostgreSQL | `docs/diagrams/er_postgresql_olist.html` | Interactivo con mermaid.js |
| Diagrama MongoDB | `docs/diagrams/er_mongodb_olist.html` | Modelo documental con ETL |
| Documento Técnico de Optimización | `Optimizacion/Documento_tecnico_Ecommify_U5.pdf` | Explicación técnica de la implementación y optimización, Etapa 1 |
| **Informe Técnico Integral (Proyecto Final)** | `PruebasCarga/Informe_Tecnico_Integral_Ecommify_APA7.docx` | Entregable evaluativo completo (Secciones a-i): arquitectura, evaluación de rendimiento, análisis crítico y recomendaciones, Etapa 2 |
| **Presentación de pruebas de carga** | `PruebasCarga/Ecommify.pptx` | Síntesis ejecutiva de los resultados de carga |
| **Evidencia cruda de pruebas de carga (Anexo A)** | `EvidenciaPruebasCarga/` | CSV/JSON/PNG de la corrida `20260621_011737` + README de metodología, base empírica del Informe Técnico Integral |

## Referencias

- Brewer, E. A. (2000). *Towards robust distributed systems* [Keynote]. Proceedings of the 19th Annual ACM Symposium on Principles of Distributed Computing. https://doi.org/10.1145/343477.343502
- Gilbert, S., & Lynch, N. (2002). Brewer's conjecture and the feasibility of consistent, available, partition-tolerant web services. *ACM SIGACT News*, *33*(2), 51-59.
- Kleppmann, M. (2017). *Designing data-intensive applications: The big ideas behind reliable, scalable, and maintainable systems*. O'Reilly Media.
- MongoDB, Inc. (2025). *Replication*. MongoDB Manual. https://www.mongodb.com/docs/manual/replication/
- MongoDB, Inc. (2025). *Sharding*. MongoDB Manual. https://www.mongodb.com/docs/manual/sharding/
- MongoDB, Inc. (2025). *MongoDB Manual*. https://www.mongodb.com/docs/manual/
- Olist. (2018). *Brazilian E-Commerce public dataset by Olist* [Dataset]. Kaggle. https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
- PostgreSQL Global Development Group. (2025). *PostgreSQL 16 Documentation*. https://www.postgresql.org/docs/16/
- PostGIS Project. (2025). *PostGIS 3.4 Documentation*. https://postgis.net/documentation/
- Supabase, Inc. (2025). *Connection pooling*. Supabase Documentation. https://supabase.com/docs/guides/database/connecting-to-postgres

## Licencia

Proyecto académico — Universidad de La Sabana, 2026.
