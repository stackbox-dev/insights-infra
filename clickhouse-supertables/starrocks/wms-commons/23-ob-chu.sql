CREATE TABLE wms_ob_chu (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    chuId VARCHAR(36) NOT NULL,
    chuKindId VARCHAR(36),
    status STRING NOT NULL,
    lmTripId VARCHAR(36),
    mmTripId VARCHAR(36),
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    chuKind STRING,
    type STRING
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
