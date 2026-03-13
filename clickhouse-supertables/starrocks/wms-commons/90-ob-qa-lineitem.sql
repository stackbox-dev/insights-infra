CREATE TABLE wms_ob_qa_lineitem (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    invoiceId VARCHAR(36) NOT NULL,
    invoiceCode STRING NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    skuClass STRING,
    skuCategory STRING,
    uom STRING NOT NULL DEFAULT '',
    orderedQty INT NOT NULL DEFAULT "0",
    pickedQty INT NOT NULL DEFAULT "0",
    packedQty INT NOT NULL DEFAULT "0",
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    updatedBy VARCHAR(36),
    tripId VARCHAR(36),
    tripCode STRING,
    batch STRING NOT NULL DEFAULT '',
    retailerId VARCHAR(36),
    retailerCode STRING
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 2
ORDER BY (id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);
