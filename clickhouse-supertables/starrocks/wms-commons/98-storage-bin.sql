CREATE TABLE wms_storage_bin (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    code STRING NOT NULL,
    description STRING,
    binTypeId VARCHAR(36) NOT NULL,
    zoneId VARCHAR(36) NOT NULL,
    binHuId VARCHAR(36),
    multiSku BOOLEAN NOT NULL DEFAULT "true",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    multiBatch BOOLEAN NOT NULL DEFAULT "true",
    pickingPosition INT NOT NULL DEFAULT "0",
    putawayPosition INT NOT NULL DEFAULT "0",
    status STRING NOT NULL DEFAULT 'ACTIVE',
    rank INT NOT NULL DEFAULT "1",
    aisle STRING,
    bay STRING,
    level STRING,
    position STRING,
    depth STRING,
    maxSkuCount INT,
    maxSkuBatchCount INT,
    attrs JSON
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
DISTRIBUTED BY HASH(id)
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
