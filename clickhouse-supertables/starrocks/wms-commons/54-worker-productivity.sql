CREATE TABLE wms_worker_productivity (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    workerId VARCHAR(36) NOT NULL,
    date DATE NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    activeTime INT NOT NULL DEFAULT "0",
    qtyL2 INT NOT NULL DEFAULT "0",
    qtyL0 INT NOT NULL DEFAULT "0"
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
