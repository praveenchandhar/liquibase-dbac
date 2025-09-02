use pp_common_db_stage;

db.createCollection("testing");

use order_service_dev;

db.createCollection("orders");

print("Collections created in multiple databases successfully");
