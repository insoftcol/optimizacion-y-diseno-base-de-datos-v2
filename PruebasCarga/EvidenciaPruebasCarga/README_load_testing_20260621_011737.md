# Evidencias de Carga y Escalabilidad — Ecommify

Generado: 20260621_011737

## Metodologia

Harness unico (ThreadPoolExecutor) reusado para PostgreSQL y MongoDB.

Cada punto de la matriz corre durante 10 segundos a concurrencia fija.

## Archivos

- load_test_concurrencia_20260621_011737.csv: throughput/latencia por nivel de concurrencia x motor x tipo de query

- load_test_escalabilidad_20260621_011737.csv: latencia por tamano de dataset (particiones 2016/2017/2018)

- puntos_quiebre_20260621_011737.csv: concurrencia donde aparece degradacion o errores

- conteos_subconjuntos_20260621_011737.csv: filas reales por subconjunto de escalabilidad

- load_test_consolidado_20260621_011737.json: todos los resultados crudos en JSON

- load_test_concurrencia_20260621_011737.png / load_test_escalabilidad_20260621_011737.png: graficas

