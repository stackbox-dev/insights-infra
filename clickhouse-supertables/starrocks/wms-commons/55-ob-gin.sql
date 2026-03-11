CREATE TABLE wms_ob_gin (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    invoiceId VARCHAR(36) NOT NULL,
    invoiceCode STRING NOT NULL,
    tripCode STRING NOT NULL,
    tripId VARCHAR(36) NOT NULL,
    status STRING NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    submittedAt DATETIME,
    loadCompletedAt DATETIME
)
ENGINE=OLAP
PRIMARY KEY(id, sessionCreatedAt)
PARTITION BY date_trunc('DAY', sessionCreatedAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
