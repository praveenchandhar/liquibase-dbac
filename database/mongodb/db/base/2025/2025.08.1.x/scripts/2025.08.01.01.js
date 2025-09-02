use pp_common_db_stage;

db.createCollection("testing");

db.createCollection("products");

db.products.createIndex({ "sku": 1 }, { unique: true });

use order_service_dev;

db.createCollection("orders");

db.orders.createIndex({ "orderNumber": 1 }, { unique: true });

print("Collections created successfully");
