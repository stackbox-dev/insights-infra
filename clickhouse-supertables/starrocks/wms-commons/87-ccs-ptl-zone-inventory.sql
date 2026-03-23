CREATE TABLE wms_ccs_ptl_zone_inventory (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    zoneId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    qty INT NOT NULL,
    assigned INT NOT NULL DEFAULT "0",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    price STRING
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
