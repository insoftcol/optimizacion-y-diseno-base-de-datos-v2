# Evidencias de Rendimiento — Ecommify

Generado: 20260616_000208

## Archivos

- `pg_benchmarks_20260616_000208.csv`: Métricas EXPLAIN ANALYZE PostgreSQL ANTES y DESPUÉS

- `mdb_benchmarks_20260616_000208.csv`: Métricas explain() MongoDB ANTES y DESPUÉS

- `explain_plans_20260616_000208.json`: Plans completos en formato JSON

- `benchmark_comparison_20260616_000208.png`: Gráfica comparativa

## Interpretación

- **PostgreSQL EXPLAIN**: Tiempo en ms. Menor = mejor. Partition pruning visible en Q1 (solo orders_2018 escaneada).

- **MongoDB Efficiency Ratio**: docs_examined / docs_returned. Ratio=1.0 es óptimo (cada documento examinado es retornado).

