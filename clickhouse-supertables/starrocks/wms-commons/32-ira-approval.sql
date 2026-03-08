CREATE TABLE wms_ira_approval (
    id VARCHAR(36) NOT NULL,
    timestamp DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    accountId BIGINT NOT NULL,
    approved JSON
)
ENGINE=OLAP
PRIMARY KEY(id, timestamp)
PARTITION BY date_trunc('DAY', timestamp)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
