CREATE TABLE wms_inb_grn_line (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    grnId VARCHAR(36) NOT NULL,
    asnId VARCHAR(36),
    asnNo STRING,
    asnLineId VARCHAR(36),
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    price STRING,
    uom STRING NOT NULL DEFAULT '',
    qty INT NOT NULL,
    bucket STRING,
    huId VARCHAR(36),
    binId VARCHAR(36),
    shortage BOOLEAN NOT NULL DEFAULT "false",
    approvedBy BIGINT,
    approvedAt DATETIME,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    reason STRING,
    subReason STRING,
    deactivatedAt DATETIME,
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    updatedBy BIGINT
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
