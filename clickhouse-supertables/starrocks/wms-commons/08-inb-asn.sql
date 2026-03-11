CREATE TABLE wms_inb_asn (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    asnNo STRING NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT "true",
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    shipmentDate DATE,
    deliveryNo STRING,
    priority INT NOT NULL,
    asnType STRING NOT NULL DEFAULT ''
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
