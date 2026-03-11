CREATE TABLE wms_pd_pick_drop_item_inner_hu (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    batch STRING NOT NULL DEFAULT '',
    uom STRING NOT NULL DEFAULT '',
    bucket STRING NOT NULL DEFAULT '',
    innerHUId VARCHAR(36) NOT NULL,
    innerHUCode STRING NOT NULL,
    huId VARCHAR(36) NOT NULL,
    huCode STRING NOT NULL,
    type STRING NOT NULL,
    processedAt DATETIME,
    qty INT NOT NULL DEFAULT "1",
    innerHUKind STRING NOT NULL DEFAULT 'CARTON',
    iloc STRING NOT NULL DEFAULT ''
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
