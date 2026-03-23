CREATE TABLE wms_invoices (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    bbId VARCHAR(36),
    code STRING NOT NULL,
    lmTripId VARCHAR(36),
    mmTripId VARCHAR(36),
    retailerId VARCHAR(36),
    retailerCode STRING NOT NULL,
    distributorId VARCHAR(36),
    lmTripIndex INT NOT NULL DEFAULT "0",
    retailerName STRING,
    retailerChannel STRING,
    salesmanId VARCHAR(36),
    salesmanCode STRING NOT NULL,
    priority INT NOT NULL,
    attrs JSON,
    deliveryDate DATE,
    xdock STRING
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('MONTH', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
