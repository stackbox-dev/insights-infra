CREATE TABLE wms_ob_order (
    id VARCHAR(255),
    createdAt DATETIME DEFAULT "1970-01-01 00:00:00",
    whId BIGINT DEFAULT "0",
    tripCode VARCHAR(255) DEFAULT "",
    code VARCHAR(255) DEFAULT "",
    retailerId INT DEFAULT "0",
    retailerCode VARCHAR(255) DEFAULT "",
    retailerChannel VARCHAR(255) DEFAULT "",
    retailerName VARCHAR(500) DEFAULT "",
    tripDate DATETIME,
    deliveryDate DATETIME DEFAULT "1970-01-01 00:00:00",
    priority INT DEFAULT "0",
    sessionId VARCHAR(255) DEFAULT "",
    active BOOLEAN DEFAULT "1",
    sessionCreatedAt DATETIME,
    salesmanCode VARCHAR(255) DEFAULT "",
    ginStatus VARCHAR(100) DEFAULT "PENDING",
    ginTriggeredAt DATETIME,
    cancelledAt DATETIME,
    tripPriority INT DEFAULT "0",
    truckType VARCHAR(255) DEFAULT "",
    transporterCode VARCHAR(255) DEFAULT "",
    advanceReplenSessionId VARCHAR(255) DEFAULT "",
    orderType VARCHAR(255) DEFAULT "",
    loadingSeq INT DEFAULT "0",
    latestPickDate DATE,
    earliestPickDate DATE,
    documentType VARCHAR(100) DEFAULT "DELIVERY_ORDER",
    orderReferenceId VARCHAR(255) DEFAULT "",
    orderReferenceCode VARCHAR(255) DEFAULT "",
    erpChannel VARCHAR(255) DEFAULT "",
    delinkedAt DATETIME,
    relinkedAt DATETIME,
    erpInvoiceCode VARCHAR(255) DEFAULT "",
    provisionalGinStatus VARCHAR(100) DEFAULT "PENDING",
    provisionalGinTriggeredAt DATETIME,
    erpInvoiceCodes JSON,
    ginDocumentUrl VARCHAR(1000) DEFAULT ""
)
ENGINE=OLAP
DUPLICATE KEY(id, createdAt)
PARTITION BY date_trunc('MONTH', createdAt)
DISTRIBUTED BY HASH(id) BUCKETS 16
PROPERTIES (
    "compression" = "LZ4",
    "enable_persistent_index" = "true",
    "fast_schema_evolution" = "true",
    "replicated_storage" = "true",
    "replication_num" = "2"
);