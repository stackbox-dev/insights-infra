CREATE TABLE wms_hht_pick_item_reduction (
    id VARCHAR(36) NOT NULL,
    sessionCreatedAt DATETIME NOT NULL,
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    groupId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    inventoryBinId VARCHAR(36),
    inventoryHUId VARCHAR(36),
    pickItemId VARCHAR(36) NOT NULL,
    qty INT NOT NULL,
    newQty INT NOT NULL,
    reason STRING,
    reducedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    reducedBy VARCHAR(36)
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
