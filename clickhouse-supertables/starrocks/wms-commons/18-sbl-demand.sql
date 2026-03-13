CREATE TABLE wms_sbl_demand (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    zoneId VARCHAR(36) NOT NULL,
    binId VARCHAR(36),
    invoiceId VARCHAR(36),
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    qty INT NOT NULL,
    priority INT NOT NULL,
    batchAllocationType STRING NOT NULL DEFAULT 'FIXED',
    omsAllocationId VARCHAR(36),
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    invoiceLineId VARCHAR(36)
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
