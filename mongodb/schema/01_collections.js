// ═══════════════════════════════════════════════════════════════════════════
// Ecommify — MongoDB 7.x — 01_collections.js
// Crear colecciones con validators JSON Schema
// Uso: mongosh "mongodb://localhost:27017/ecommify" 01_collections.js
// ═══════════════════════════════════════════════════════════════════════════

print("→ Creando colecciones de Ecommify en MongoDB...");

// reviews — esquema flexible (41% nulos)
db.createCollection("reviews", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["review_id", "order_id", "review_score", "review_creation_date"],
      properties: {
        review_id:               { bsonType: "string" },
        order_id:                { bsonType: "string" },
        review_score:            { bsonType: "int", minimum: 1, maximum: 5 },
        review_comment_title:    { bsonType: ["string", "null"] },
        review_comment_message:  { bsonType: ["string", "null"] },
        review_creation_date:    { bsonType: "date" },
        review_answer_timestamp: { bsonType: ["date", "null"] }
      }
    }
  }, validationLevel: "moderate", validationAction: "warn"
});
print("  ✓ reviews");

// geolocation — GeoJSON Point + 2dsphere
db.createCollection("geolocation", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["zip_code_prefix", "city", "state", "location"],
      properties: {
        zip_code_prefix: { bsonType: "int", minimum: 1000, maximum: 99999 },
        city:            { bsonType: "string", maxLength: 60 },
        state:           { bsonType: "string", pattern: "^[A-Z]{2}$" },
        location: {
          bsonType: "object", required: ["type", "coordinates"],
          properties: {
            type:        { enum: ["Point"] },
            coordinates: { bsonType: "array", minItems: 2, maxItems: 2 }
          }
        }
      }
    }
  }, validationLevel: "strict"
});
print("  ✓ geolocation");

// products_catalog — desnormalizado con category embebida
db.createCollection("products_catalog", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "etl_updated_at"],
      properties: {
        _id:                { bsonType: "string" },
        category: {
          bsonType: ["object", "null"],
          properties: {
            name_pt: { bsonType: "string" },
            name_en: { bsonType: "string" }
          }
        },
        weight_g:           { bsonType: ["int", "null"] },
        length_cm:          { bsonType: ["double", "null"] },
        height_cm:          { bsonType: ["double", "null"] },
        width_cm:           { bsonType: ["double", "null"] },
        photos_qty:         { bsonType: ["int", "null"] },
        name_length:        { bsonType: ["int", "null"] },
        description_length: { bsonType: ["int", "null"] },
        etl_updated_at:     { bsonType: "date" }
      }
    }
  }, validationLevel: "moderate"
});
print("  ✓ products_catalog");

// orders_summary — JOIN materializado de 5 tablas
db.createCollection("orders_summary", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["_id", "status", "purchase_date", "customer", "items", "etl_updated_at"],
      properties: {
        _id:           { bsonType: "string" },
        status:        { enum: ["delivered","shipped","canceled","approved","processing","unavailable","invoiced","created"] },
        purchase_date: { bsonType: "date" },
        customer: {
          bsonType: "object", required: ["customer_id", "state"],
          properties: {
            customer_id: { bsonType: "string" },
            state:       { bsonType: "string" },
            city:        { bsonType: ["string", "null"] }
          }
        },
        items: {
          bsonType: "array", minItems: 1,
          items: {
            bsonType: "object",
            required: ["product_id", "seller_id", "price"],
            properties: {
              product_id:    { bsonType: "string" },
              seller_id:     { bsonType: "string" },
              price:         { bsonType: "double", minimum: 0 },
              freight_value: { bsonType: "double", minimum: 0 }
            }
          }
        },
        payment_total:     { bsonType: "double" },
        payment_type_main: { bsonType: ["string", "null"] },
        review_score:      { bsonType: ["int", "null"], minimum: 1, maximum: 5 },
        etl_updated_at:    { bsonType: "date" }
      }
    }
  }, validationLevel: "moderate"
});
print("  ✓ orders_summary");

print("\n✅ Colecciones creadas. Siguiente: ejecutar 02_indexes.js");
db.getCollectionNames().forEach(name => {
  print(`  - ${name}`);
});
