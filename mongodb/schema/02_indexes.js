// ═══════════════════════════════════════════════════════════════════════════
// Ecommify — MongoDB — 02_indexes.js
// ═══════════════════════════════════════════════════════════════════════════

print("→ Creando índices...");

// reviews
db.reviews.createIndex({ review_id: 1 }, { unique: true });
db.reviews.createIndex({ order_id: 1 });
db.reviews.createIndex({ review_score: 1 });
db.reviews.createIndex({ review_creation_date: -1 });
db.reviews.createIndex(
  { review_comment_message: "text", review_comment_title: "text" },
  { name: "reviews_text_search", default_language: "portuguese",
    weights: { review_comment_title: 3, review_comment_message: 1 } }
);
print("  ✓ reviews (5 índices)");

// geolocation — incluye 2dsphere crítico
db.geolocation.createIndex({ zip_code_prefix: 1 }, { unique: true });
db.geolocation.createIndex({ state: 1, city: 1 });
db.geolocation.createIndex({ location: "2dsphere" });
print("  ✓ geolocation (3 índices, incluye 2dsphere)");

// products_catalog
db.products_catalog.createIndex({ "category.name_en": 1 });
db.products_catalog.createIndex({ "category.name_pt": 1 });
db.products_catalog.createIndex({ etl_updated_at: 1 });
print("  ✓ products_catalog (3 índices)");

// orders_summary
db.orders_summary.createIndex({ purchase_date: -1 });
db.orders_summary.createIndex({ status: 1 });
db.orders_summary.createIndex({ "customer.state": 1 });
db.orders_summary.createIndex({ "customer.customer_id": 1 });
db.orders_summary.createIndex({ review_score: 1 });
db.orders_summary.createIndex({ payment_type_main: 1 });
db.orders_summary.createIndex({ etl_updated_at: 1 });
db.orders_summary.createIndex({ "customer.state": 1, purchase_date: -1 });
print("  ✓ orders_summary (8 índices)");

// SHARDING (descomentar en Atlas M10+ o cluster con replica set)
// sh.enableSharding("ecommify");
// sh.shardCollection("ecommify.orders_summary", { _id: "hashed" });
// sh.shardCollection("ecommify.geolocation",    { zip_code_prefix: "hashed" });

print("\n✅ Índices creados.");
db.getCollectionNames().forEach(name => {
  const idxs = db.getCollection(name).getIndexes();
  print(`  - ${name.padEnd(20)} ${idxs.length} índices`);
});
