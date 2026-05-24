#!/usr/bin/env python3
"""
Ecommify — Carga inicial del dataset Olist en PostgreSQL.

Lee los 9 CSV de Kaggle (Brazilian E-Commerce by Olist) y los inserta
en las tablas correspondientes respetando integridad referencial.

Orden de carga (respeta FKs):
  1. geolocation              ← olist_geolocation_dataset.csv (deduplicado)
  2. product_category_name_translation
  3. customers, sellers, products
  4. orders (particionada), order_items, order_payments

Uso:
    python load_olist_csv.py --data-dir ./data --pg-url postgresql://...

Prerrequisitos:
    pip install psycopg2-binary pandas python-dotenv tqdm
"""
import argparse
import json
import os
import sys
from pathlib import Path

import pandas as pd
import psycopg2
from psycopg2.extras import execute_batch, Json

DEFAULT_PG_URL = os.getenv("PG_URL", "postgresql://ecommify:ecommify@localhost:5432/ecommify")
DEFAULT_DATA_DIR = Path("./data")
BATCH_SIZE = 1000

CSV_LOAD_ORDER = [
    ("olist_geolocation_dataset.csv",         "geolocation",  "_load_geolocation"),
    ("product_category_name_translation.csv", "categories",   "_load_categories"),
    ("olist_customers_dataset.csv",           "customers",    "_load_customers"),
    ("olist_sellers_dataset.csv",             "sellers",      "_load_sellers"),
    ("olist_products_dataset.csv",            "products",     "_load_products"),
    ("olist_orders_dataset.csv",              "orders",       "_load_orders"),
    ("olist_order_items_dataset.csv",         "order_items",  "_load_order_items"),
    ("olist_order_payments_dataset.csv",      "order_payments","_load_payments"),
]


def _load_geolocation(conn, csv_path):
    """Deduplica por zip_code_prefix (mediana de coords)."""
    df = pd.read_csv(csv_path, dtype={"geolocation_zip_code_prefix": int})
    print(f"  Filas originales: {len(df):,}")
    dedup = df.groupby("geolocation_zip_code_prefix").agg(
        geolocation_lat=("geolocation_lat", "median"),
        geolocation_lng=("geolocation_lng", "median"),
        geolocation_city=("geolocation_city", "first"),
        geolocation_state=("geolocation_state", "first"),
    ).reset_index()
    print(f"  Filas deduplicadas: {len(dedup):,}")
    with conn.cursor() as cur:
        rows = [
            (int(r.geolocation_zip_code_prefix),
             float(r.geolocation_lat), float(r.geolocation_lng),
             str(r.geolocation_city)[:60], str(r.geolocation_state)[:2])
            for r in dedup.itertuples()
            if -34 <= r.geolocation_lat <= 5.3 and -74 <= r.geolocation_lng <= -34
        ]
        execute_batch(cur, """
            INSERT INTO geolocation (zip_code_prefix, geolocation_lat,
                geolocation_lng, geolocation_city, geolocation_state)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (zip_code_prefix) DO NOTHING
        """, rows, page_size=BATCH_SIZE)
    conn.commit()
    return len(rows)


def _load_categories(conn, csv_path):
    df = pd.read_csv(csv_path)
    with conn.cursor() as cur:
        execute_batch(cur, """
            INSERT INTO product_category_name_translation
                (product_category_name, product_category_name_english)
            VALUES (%s, %s) ON CONFLICT (product_category_name) DO NOTHING
        """, df.itertuples(index=False), page_size=BATCH_SIZE)
    conn.commit()
    return len(df)


def _load_customers(conn, csv_path):
    df = pd.read_csv(csv_path)
    with conn.cursor() as cur:
        execute_batch(cur, """
            INSERT INTO customers (customer_id, customer_unique_id,
                zip_code_prefix, customer_city, customer_state)
            SELECT gen_random_uuid(), %s::UUID, %s, %s, %s
            WHERE EXISTS (SELECT 1 FROM geolocation WHERE zip_code_prefix = %s)
            ON CONFLICT DO NOTHING
        """, [
            (str(r.customer_unique_id).replace('-','')[:32].ljust(32,'0'),
             int(r.customer_zip_code_prefix), str(r.customer_city)[:60],
             str(r.customer_state)[:2], int(r.customer_zip_code_prefix))
            for r in df.itertuples()
        ], page_size=BATCH_SIZE)
    conn.commit()
    return len(df)


def _load_sellers(conn, csv_path):
    """sellers SIN FK a geolocation (decisión de alcance)."""
    df = pd.read_csv(csv_path)
    with conn.cursor() as cur:
        execute_batch(cur, """
            INSERT INTO sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state)
            VALUES (gen_random_uuid(), %s, %s, %s) ON CONFLICT DO NOTHING
        """, [
            (int(r.seller_zip_code_prefix), str(r.seller_city)[:60], str(r.seller_state)[:2])
            for r in df.itertuples()
        ], page_size=BATCH_SIZE)
    conn.commit()
    return len(df)


def _load_products(conn, csv_path):
    df = pd.read_csv(csv_path)
    samples_path = Path(__file__).parent / "sample_specifications.json"
    with open(samples_path) as f: samples = json.load(f)
    def get_specs(category): return samples.get(str(category), {})
    with conn.cursor() as cur:
        rows = []
        for r in df.itertuples():
            specs = get_specs(r.product_category_name)
            dims = (
                None if pd.isna(r.product_length_cm) else float(r.product_length_cm),
                None if pd.isna(r.product_height_cm) else float(r.product_height_cm),
                None if pd.isna(r.product_width_cm) else float(r.product_width_cm),
                None if pd.isna(r.product_weight_g) else int(r.product_weight_g),
            )
            rows.append((
                int(r.product_name_lenght) if not pd.isna(r.product_name_lenght) else None,
                int(r.product_description_lenght) if not pd.isna(r.product_description_lenght) else None,
                int(r.product_photos_qty) if not pd.isna(r.product_photos_qty) else None,
                str(r.product_category_name) if not pd.isna(r.product_category_name) else None,
                dims, Json(specs) if specs else None,
                ['photo_1.jpg', 'photo_2.jpg'] if r.product_photos_qty and r.product_photos_qty > 1 else None,
                [r.product_category_name] if not pd.isna(r.product_category_name) else None,
            ))
        execute_batch(cur, """
            INSERT INTO products (product_id, product_name_length, product_description_length,
                product_photos_qty, product_category_name, dims, specifications, photos, tags)
            VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s)
        """, rows, page_size=BATCH_SIZE)
    conn.commit()
    return len(df)


def _load_orders(conn, csv_path):
    df = pd.read_csv(csv_path, parse_dates=[
        "order_purchase_timestamp", "order_approved_at",
        "order_delivered_carrier_date", "order_delivered_customer_date",
        "order_estimated_delivery_date"])
    with conn.cursor() as cur:
        cur.execute("SELECT customer_unique_id, customer_id FROM customers")
        cust_map = {row[0]: row[1] for row in cur.fetchall()}
    rows, skipped = [], 0
    for r in df.itertuples():
        cust_unique = str(r.customer_id).replace('-','')[:32].ljust(32,'0')
        if cust_unique not in cust_map:
            skipped += 1
            continue
        rows.append((
            cust_map[cust_unique], str(r.order_status)[:20], r.order_purchase_timestamp,
            r.order_approved_at if not pd.isna(r.order_approved_at) else None,
            r.order_delivered_carrier_date if not pd.isna(r.order_delivered_carrier_date) else None,
            r.order_delivered_customer_date if not pd.isna(r.order_delivered_customer_date) else None,
            r.order_estimated_delivery_date if not pd.isna(r.order_estimated_delivery_date) else None,
        ))
    print(f"  Saltados (sin cliente): {skipped:,}")
    with conn.cursor() as cur:
        execute_batch(cur, """
            INSERT INTO orders (order_id, customer_id, order_status,
                order_purchase_timestamp, order_approved_at,
                order_delivered_carrier_date, order_delivered_customer_date,
                order_estimated_delivery_date)
            VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s)
        """, rows, page_size=BATCH_SIZE)
    conn.commit()
    return len(rows)


def _load_order_items(conn, csv_path):
    print("  → order_items: implementación con lookup tablas pendiente.")
    return 0


def _load_payments(conn, csv_path):
    print("  → order_payments: implementación con lookup tablas pendiente.")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", default=str(DEFAULT_DATA_DIR))
    parser.add_argument("--pg-url",   default=DEFAULT_PG_URL)
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    if not data_dir.exists():
        print(f"❌ Directorio de datos no existe: {data_dir}")
        sys.exit(1)

    conn = psycopg2.connect(args.pg_url)
    try:
        for csv_name, label, fn_name in CSV_LOAD_ORDER:
            csv_path = data_dir / csv_name
            if not csv_path.exists():
                print(f"⚠ {csv_name}: archivo no encontrado, salto.")
                continue
            print(f"\n→ Cargando {label} desde {csv_name}...")
            fn = globals()[fn_name]
            n = fn(conn, csv_path)
            print(f"  ✓ {n:,} filas cargadas en {label}.")
    finally:
        conn.close()
    print("\n✅ Carga completada.")


if __name__ == "__main__":
    main()
