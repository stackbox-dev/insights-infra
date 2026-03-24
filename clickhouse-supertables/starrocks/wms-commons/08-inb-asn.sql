CREATE TABLE wms_inb_asn (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    asnNo STRING NOT NULL,
    sessionId VARCHAR(36) NULL,
    sessionCreatedAt DATETIME NULL,
    active BOOLEAN NOT NULL DEFAULT "true",
    shipmentDate DATE NULL,
    deliveryNo STRING NULL,
    priority INT NULL,
    asnType STRING NOT NULL DEFAULT ''
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('MONTH', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
