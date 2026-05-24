#!/usr/bin/env python3
"""
Ecommify — ETL PostgreSQL → MongoDB orders_summary

Proyecta órdenes completas (orders + order_items + payments + customers)
desde PostgreSQL hacia la colección orders_summary en MongoDB.

Modos:
  --full          Carga completa (todas las órdenes)
  --incremental   Solo órdenes con updated_at > último etl_updated_at

Uso:
  python pg_to_mongo_orders_summary.py --full
  python pg_to_mongo_orders_summary.py --incremental
"""
import argparse
import os
from datetime import datetime, timezone

import psycopg2
from psycopg2.extras import RealDictCursor
from pymongo import MongoClient, UpdateOne

PG_URL    = os.getenv("PG_URL",    "postgresql://ecommify:ecommify@localhost:5432/ecommify")
MONGO_URL = os.getenv("MONGO_URL", "mongodb://localhost:27017/ecommify")
BATCH     = 500

SQL_ORDERS_SUMMARY = """
WITH base AS (
    SELECT o.order_id, o.order_status AS status, o.order_purchase_timestamp AS purchase_date,
           o.updated_at, c.customer_id::TEXT AS customer_uuid,
           c.customer_state AS state, c.customer_city AS city, c.zip_code_prefix
    FROM orders o JOIN customers c USING (customer_id)
    WHERE %s = TRUE OR o.updated_at > %s::TIMESTAMPTZ
),
items AS (
    SELECT oi.order_id, oi.order_purchase_timestamp,
           jsonb_agg(jsonb_build_object(
               'product_id', oi.product_id::TEXT, 'seller_id', oi.seller_id::TEXT,
               'price', oi.price::FLOAT, 'freight_value', oi.freight_value::FLOAT
           ) ORDER BY oi.order_item_id) AS items_array
    FROM order_items oi GROUP BY oi.order_id, oi.order_purchase_timestamp
),
payments AS (
    SELECT op.order_id, op.order_purchase_timestamp,
           SUM(op.payment_value)::FLOAT AS payment_total,
           (ARRAY_AGG(op.payment_type ORDER BY op.payment_value DESC))[1] AS payment_type_main
    FROM order_payments op GROUP BY op.order_id, op.order_purchase_timestamp
)
SELECT b.order_id::TEXT AS order_id, b.status, b.purchase_date, b.customer_uuid,
       b.state, b.city, b.zip_code_prefix, i.items_array, p.payment_total, p.payment_type_main
FROM base b
LEFT JOIN items i    ON i.order_id = b.order_id AND i.order_purchase_timestamp = b.purchase_date
LEFT JOIN payments p ON p.order_id = b.order_id AND p.order_purchase_timestamp = b.purchase_date
ORDER BY b.purchase_date
"""

def build_doc(row):
    return {
        "_id": row["order_id"], "status": row["status"], "purchase_date": row["purchase_date"],
        "customer": {
            "customer_id": row["customer_uuid"], "state": row["state"], "city": row["city"]
        },
        "items": row["items_array"] or [],
        "payment_total": row["payment_total"] or 0.0,
        "payment_type_main": row["payment_type_main"],
        "review_score": None,
        "etl_updated_at": datetime.now(timezone.utc),
    }

def main():
    parser = argparse.ArgumentParser()
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("--full",        action="store_true")
    g.add_argument("--incremental", action="store_true")
    args = parser.parse_args()
    full = args.full

    pg = psycopg2.connect(PG_URL, cursor_factory=RealDictCursor)
    mongo = MongoClient(MONGO_URL)
    db = mongo.get_default_database()
    coll = db.orders_summary

    last_ts = datetime(1970, 1, 1, tzinfo=timezone.utc)
    if args.incremental:
        last_doc = coll.find_one(sort=[("etl_updated_at", -1)])
        if last_doc: last_ts = last_doc["etl_updated_at"]
        print(f"→ Último etl_updated_at: {last_ts}")

    print(f"→ Modo: {'FULL' if full else 'INCREMENTAL'}")
    with pg.cursor() as cur:
        cur.execute(SQL_ORDERS_SUMMARY, (full, last_ts))
        rows = cur.fetchall()
    print(f"→ Filas extraídas: {len(rows):,}")

    ops, inserted, updated = [], 0, 0
    for row in rows:
        doc = build_doc(row)
        ops.append(UpdateOne({"_id": doc["_id"]}, {"$set": doc}, upsert=True))
        if len(ops) >= BATCH:
            result = coll.bulk_write(ops, ordered=False)
            inserted += result.upserted_count
            updated  += result.modified_count
            ops = []
    if ops:
        result = coll.bulk_write(ops, ordered=False)
        inserted += result.upserted_count
        updated  += result.modified_count

    print(f"\n✅ Insertados: {inserted:,}  Actualizados: {updated:,}")
    print(f"   Total documentos: {coll.count_documents({}):,}")
    pg.close(); mongo.close()

if __name__ == "__main__":
    main()
