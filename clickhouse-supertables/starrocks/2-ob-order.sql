CREATE TABLE wms_ob_order (
    id VARCHAR(36) NOT NULL,
    createdAt DATETIME NOT NULL DEFAULT "1970-01-01 00:00:00",
    whId BIGINT NOT NULL,
    tripCode STRING,
    code STRING NOT NULL,
    retailerId INT NOT NULL,
    retailerCode STRING NOT NULL,
    retailerChannel STRING,
    retailerName STRING NOT NULL DEFAULT '',
    tripDate DATETIME,
    deliveryDate DATETIME NOT NULL,
    priority INT NOT NULL,
    sessionId VARCHAR(36),
    active BOOLEAN NOT NULL DEFAULT "true",
    sessionCreatedAt DATETIME,
    salesmanCode STRING NOT NULL,
    ginStatus STRING NOT NULL DEFAULT 'PENDING',
    ginTriggeredAt DATETIME,
    cancelledAt DATETIME,
    tripPriority INT,
    truckType STRING,
    transporterCode STRING,
    advanceReplenSessionId VARCHAR(36),
    orderType STRING,
    loadingSeq INT,
    latestPickDate DATE,
    earliestPickDate DATE,
    documentType STRING NOT NULL DEFAULT 'DELIVERY_ORDER',
    orderReferenceId VARCHAR(36),
    orderReferenceCode STRING,
    erpChannel STRING,
    delinkedAt DATETIME,
    relinkedAt DATETIME,
    erpInvoiceCode STRING,
    provisionalGinStatus STRING NOT NULL DEFAULT 'PENDING',
    provisionalGinTriggeredAt DATETIME,
    erpInvoiceCodes JSON,
    ginDocumentUrl STRING
)
ENGINE=OLAP
PRIMARY KEY(id, createdAt)
PARTITION BY date_trunc('DAY', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
ORDER BY (whId, id)
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);