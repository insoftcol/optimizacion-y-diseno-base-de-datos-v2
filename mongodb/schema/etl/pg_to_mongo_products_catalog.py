#!/usr/bin/env python3
"""
Ecommify — ETL PostgreSQL → MongoDB products_catalog

Sincroniza catálogo embebiendo category (PT + EN) para evitar JOINs.

Uso:
  python pg_to_mongo_products_catalog.py --full
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

SQL_PRODUCTS = """
SELECT p.product_id::TEXT AS product_id,
       p.product_category_name AS cat_pt,
       pcnt.product_category_name_english AS cat_en,
       (p.dims).weight_g AS weight_g,
       (p.dims).length_cm::FLOAT AS length_cm,
       (p.dims).height_cm::FLOAT AS height_cm,
       (p.dims).width_cm::FLOAT AS width_cm,
       p.product_photos_qty AS photos_qty,
       p.product_name_length AS name_length,
       p.product_description_length AS description_length
FROM products p
LEFT JOIN product_category_name_translation pcnt
    ON pcnt.product_category_name = p.product_category_name
WHERE %s = TRUE OR p.updated_at > %s::TIMESTAMPTZ
"""

def build_doc(row):
    category = None
    if row["cat_pt"]:
        category = {"name_pt": row["cat_pt"], "name_en": row["cat_en"] or row["cat_pt"]}
    return {
        "_id": row["product_id"],
        "category": category,
        "weight_g": row["weight_g"],
        "length_cm": row["length_cm"], "height_cm": row["height_cm"], "width_cm": row["width_cm"],
        "photos_qty": row["photos_qty"],
        "name_length": row["name_length"], "description_length": row["description_length"],
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
    coll = db.products_catalog

    last_ts = datetime(1970, 1, 1, tzinfo=timezone.utc)
    if args.incremental:
        last_doc = coll.find_one(sort=[("etl_updated_at", -1)])
        if last_doc: last_ts = last_doc["etl_updated_at"]

    print(f"→ Modo: {'FULL' if full else 'INCREMENTAL'}")
    with pg.cursor() as cur:
        cur.execute(SQL_PRODUCTS, (full, last_ts))
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
