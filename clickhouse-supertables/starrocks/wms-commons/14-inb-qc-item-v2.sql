CREATE TABLE wms_inb_qc_item_v2 (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    sessionId VARCHAR(36) NOT NULL,
    taskId VARCHAR(36) NOT NULL,
    skuId VARCHAR(36) NOT NULL,
    uom STRING NOT NULL DEFAULT '',
    batch STRING NOT NULL DEFAULT '',
    bucket STRING,
    price STRING,
    qty INT NOT NULL,
    receivedQty INT,
    sampleSize INT,
    inspectionLevel STRING,
    acceptableIssueSize INT,
    actualSkuId VARCHAR(36),
    actualUom STRING,
    actualBatch STRING,
    actualPrice STRING,
    actualBucket STRING,
    actualQty INT,
    actualQtyInside INT,
    parentItemId VARCHAR(36),
    createdBy VARCHAR(36),
    deactivatedAt DATETIME,
    deactivatedBy VARCHAR(36),
    updatedAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    movedAt DATETIME,
    movedBy VARCHAR(36),
    movedQty INT,
    processedAt DATETIME,
    uomInside STRING,
    reason STRING,
    subReason STRING,
    batchOverridden STRING
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
